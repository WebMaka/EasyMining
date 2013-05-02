unit MonitorThreadUnit;

interface

uses
  Windows, Forms, Classes, Graphics, StrUtils;

type
  TTextLineEvent = procedure(Sender: TObject; aLine: string; aIconIndex: Integer) of object;

  TMonitorThread = class(TThread)
  private
    fCommandLine: string;
    fStarted: boolean;
    fAbort: boolean;
    fForceTerminate: boolean;
    fActive: boolean;
    fDefaultIcon: integer;
    fOnLineEvent: TTextLineEvent;
    fOnWorking: TNotifyEvent;
    function Is64BitOS: Boolean;
  public
    CritSect: TRTLCriticalSection;
    procedure Start;
    function DoWork: DWORD;
    property CommandLine: string read fCommandLine write fCommandLine;
    procedure Abort;
    procedure ForceTerminate;
    property DefaultIcon: integer read fDefaultIcon write fDefaultIcon;
    property OnWorking: TNotifyEvent read fOnWorking write fOnWorking;
    property OnNewLine: TTextLineEvent read fOnLineEvent write fOnLineEvent;
    property Aborted: boolean read fAbort;
    property Active: boolean read fActive write fActive;
  protected
    procedure Execute; override;
  end;

implementation

function AttachConsole(dwProcessId: Cardinal): Cardinal; stdcall; external kernel32 name 'AttachConsole';

//uses
//  SysUtils;

{ MonitorThread }

procedure TMonitorThread.Execute;
begin
  inherited;

  // Preset some variables.
  fStarted := false;
  fCommandLine := '';

  // This strange approach to a thread's execute function allows us to call this
  // thread's workhorse function asynchronously, by simply calling TMonitorThread.Start.
  // That procedure will return immediately without hanging the calling thread, which
  // allows this thread to start on its own.
  repeat
    if (fStarted) then
    begin
      fStarted := false;
      DoWork;
    end;

    // This monitoring thread needs to idle when it's not actually doing something.
    // So, process messages and relinquish any remaining CPU time on the current
    // multitasking timeslice.
    Application.ProcessMessages;
    Sleep(0);
  until (Self.Terminated);
end;

procedure TMonitorThread.Abort;
begin
  // Setting fAbort to true will cause it to try to gracefully close the monitored
  // program if it's running.
  fAbort := true;
end;

procedure TMonitorThread.ForceTerminate;
begin
  // Setting fForceTerminate to true will cause it to forcibly kill the monitored
  // program's process if it's running.
  fForceTerminate := true;
end;


procedure TMonitorThread.Start;
begin
  // Setting fStarted to true will cause this thread to launch whatever program it
  // has a filename and command-line parameter set for, and report anything said
  // program emits on STDOUT or STDERR to the log box on the main thread.
  fStarted := true;
end;

function TMonitorThread.DoWork: DWORD;
const
  cBadExitCode = 9999;

var
  SecurityAttributes: TSecurityAttributes;
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  StdOutPipeRead: THandle;
  StdOutPipeWrite: THandle;
  CreateProcOK: boolean;
  Buffer: array[0..16384] of Char;
  BytesRead: DWORD;
  Text: string;
  aLine: string;
  lp1: integer;
  AppRunning: THandle;
  DataAvailable: DWORD;
  SignalSent: boolean;

begin
  // Note that we are starting to do work.
  if Assigned(fOnLineEvent) then
    fOnLineEvent(Self, '*** Monitor Thread Worker Code Starting. ***', fDefaultIcon);

  // Preset the active flag.
  fActive := true;

  // Preset the abort flag.
  fAbort := false;

  // Preset the signal-sent flag.
  SignalSent := false;

  // Preset the force-terminate flag.
  fForceTerminate := false;

  // Preset AppRunning so the compiler won't complain about it not having been
  // initialized.
  AppRunning := 0;

  // Preset the exit code to an error value.
  Result := cBadExitCode;

  // Init our critical section for when it comes time to write data to the log
  // box running in the main thread.
  InitializeCriticalSection(CritSect);

  // Sanity check! If we don't have a command line to invoke, bail.
  if (fCommandLine <> '') then begin

    // Prep the security attribute structure.
    with SecurityAttributes do begin
      nLength := SizeOf(SecurityAttributes);
      bInheritHandle := true;
      lpSecurityDescriptor := nil;
    end;

    // Open input/output pipes.
    CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SecurityAttributes, 0);

    // Prep the statup info structure. Note that we're going to launch the monitored
    // program as a windowless (hidden) app.
    try
      with StartupInfo do begin
        FillChar(StartupInfo, SizeOf(StartupInfo), 0);
        cb := SizeOf(StartupInfo);
        dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
        wShowWindow := SW_HIDE;
        hStdInput := GetStdHandle(STD_INPUT_HANDLE);
        hStdOutput := StdOutPipeWrite;
        hStdError  := StdOutPipeWrite;
      end;

      // Attempt to launch the monitored program. Note that we have to use two different
      // API calls, as 64-bit Windows versions don't like piping STDOUT/STDERR without
      // a reference to the user trying to invoke the redirect.
      //
      // By the way, CREATE_NEW_PROCESS_GROUP is in here so that we can send SIGINT
      // (CTRL-C)/SIGBREAL (CTRL-BREAK) signals to the processes to cause them to
      // close gracefully.
      if (Is64BitOS) then
        CreateProcOK := CreateProcessAsUser(0, nil, PChar(fCommandLine), nil, nil, true,
          NORMAL_PRIORITY_CLASS or {DETACHED_PROCESS or} CREATE_NEW_CONSOLE or CREATE_NEW_PROCESS_GROUP or CREATE_NO_WINDOW,
          nil, nil, StartupInfo, ProcessInfo)
      else
        CreateProcOK := CreateProcess(nil, PChar(fCommandLine), nil, nil, true,
          NORMAL_PRIORITY_CLASS or {DETACHED_PROCESS or} CREATE_NEW_CONSOLE or CREATE_NEW_PROCESS_GROUP or CREATE_NO_WINDOW,
          nil, nil, StartupInfo, ProcessInfo);
      

      // Close the pipe's write side so we don't send things to the monitored program that
      // could make it unhappy, as an output pipe probably won't react well to being
      // written to.
      CloseHandle(StdOutPipeWrite);

      if not CreateProcOK then
      begin
        // Something bad happened - the monitored program couldn't be launched.
        if Assigned(fOnLineEvent) then
        begin
          EnterCriticalSection(CritSect);
          Application.ProcessMessages;
          fOnLineEvent(Self, 'CRITICAL ERROR: Could not launch application.', 6);
          LeaveCriticalSection(CritSect);
        end;
      end else begin
        // Successful launch of monitored program!
        try

          // Now that the monitored program is running, what we'll do is watch its
          // output pipe for data, read it when something comes, and send the data
          // read from it to the main thread's log box. This process repeats until
          // either the monitored program drops or the main thread invokes this
          // thread's "abort" function, which will trigger this thread to terminate
          // the monitored program directly.
          repeat
            Text := '';

            // Fire the OnWorking event if it's assigned.
            if Assigned(fOnWorking) then
              fOnWorking(Self);

            // Allow cooperative timesharing by giving the system more control over
            // this thread's run time - this allows the CPU usage to drop to near-zero
            // when nothing's going on with any monitored programs.
            Application.ProcessMessages;
            Sleep(0);

            // This is an important bit of code: we take a peek at the output pipe
            // to see if there's any data in it. This allows us to avoid trying to
            // read from an empty pipe, which will just sit there and wait until
            // data comes in! This is the key to monitoring a console application
            // without having to wait for it to terminate before working with its
            // output.
            PeekNamedPipe(StdOutPipeRead, nil, 0, nil, @DataAvailable, nil);
            if (DataAvailable > 0) then
            begin
              // Since there's actually something to read, read it. Note that
              // we are reading blocks of 16 kilobytes of characters at a time.
              if ReadFile(StdOutPipeRead, Buffer, 16384, BytesRead, nil) then
              begin
                if (BytesRead > 0) then
                begin
                  // Make sure the buffer ends in a null character.
                  Buffer[BytesRead] := #0;

                  // Concatenate with any previous data.
                  Text := Text + Buffer;
                end;
              end;
            end;

            // Loop through the data we have received, with the idea of breaking
            // it into lines separated by CRLFs and sending those to the main
            // thread's log box.
            if (Length(Text) > 0) then
            begin
              lp1 := 1;
              while (lp1 < Length(Text)) do
              begin
                if (Text[lp1] = #13) and (Text[succ(lp1)] = #10) then
                begin
                  // Copy a line of text from a null-terminated string into an
                  // ANSI string.
                  aLine := Copy(Text, 1, pred(lp1));

                  // If we have an OnLine event defined, enter a critical section
                  // for thread safety (read: sync this thread to the main) and
                  // send the line of text to the event handler.
                  if Assigned(fOnLineEvent) then
                  begin
                    EnterCriticalSection(CritSect);
                    Application.ProcessMessages;
                    sleep(0);
                    fOnLineEvent(Self, aLine, fDefaultIcon);
                    LeaveCriticalSection(CritSect);
                  end;

                  // Remove the sent line from the text buffer.
                  Delete(Text, 1, succ(lp1));
                  lp1 := 1;
                end else
                  inc(lp1);
              end;
            end;

            // Allow the main thread to terminate the monitored program by invoking the
            // "abort" function. This will send a SIGINT (CTRL-C) signal to the monitored
            // program, triggering it to execute its shutdown routines and close gracefully.
            // If SIGINT fails, we'll try SIGBREAK, and if SIGBREAK fails we'll just do a
            // process terminate.
            if (fAbort) then
            begin
              if (not SignalSent) then
              begin
                SignalSent := true;

                // Disable our own SIGINT/SIGBREAK handling so we don't close ourselves.
                SetConsoleCtrlHandler(nil, true);

                try
                  // Attempt to attach a console to the monitored program. If this
                  // fails or throws an error (AttachConsole is Windows XP and later)
                  // we'll simply terminate the process. This is necessary because
                  // you can only send signals into a console whose process is
                  // connected to the caller.
                  if (AttachConsole(ProcessInfo.dwProcessId) > 0) then
                  begin
                    // Throw a SIGINT at the monitored program. If that fails, throw
                    // a SIGBREAK instead.
                    if (not GenerateConsoleCtrlEvent(CTRL_C_EVENT, ProcessInfo.dwProcessId)) then
                      GenerateConsoleCtrlEvent(CTRL_BREAK_EVENT, ProcessInfo.dwProcessId);

                    // Free our attached console.
                    FreeConsole();
                  end else begin
                    TerminateProcess(ProcessInfo.hProcess, 0);
                  end;
                except
                  TerminateProcess(ProcessInfo.hProcess, 0);
                end;

                // Restore our signal handler.
                SetConsoleCtrlHandler(nil, false);

                Application.ProcessMessages;
                sleep(0);
              end;
            end;

            // Force termination - necessary if the monitored program ignores the
            // SIGINT/SIGBREAK signal.
            if (fForceTerminate) then
            begin
              fForceTerminate := false;
              TerminateProcess(ProcessInfo.hProcess, 0);
            end;

            // Check to see if the monitored program is still running. Note we're NOT
            // using the blocking/timeout version - with the timeout set to zero the
            // WaitForSingleObject call will return immediately.
            AppRunning := WaitForSingleObject(ProcessInfo.hProcess, 0);

          // Keep looping while the monitored program is running. Note that most
          // other forms of this code watch for program termination, which can cause
          // a lockup if the output pipe read returns zero, but since we peek at the
          // pipe before trying a read we should avoid deadlocking the thread by waiting
          // for nothing.
          until (AppRunning <> WAIT_TIMEOUT);

          // Return the exit code from the monitored program.
          GetExitCodeProcess(ProcessInfo.hProcess, Result);
        finally
          // Close the monitored program's thread/process.
          CloseHandle(ProcessInfo.hThread);
          CloseHandle(ProcessInfo.hProcess);
        end;
      end;
    finally
      // Close the output pipe handle.
      CloseHandle(StdOutPipeRead);
    end;
  end;

  // Clear the critical section since we're done with it.
  DeleteCriticalSection(CritSect);


  // Unset the active flag.
  fActive := false;

  // Note the thread has terminated.
  if Assigned(fOnLineEvent) then
    fOnLineEvent(Self, '*** Monitor Thread Worker Code Finished. ***', fDefaultIcon);
end;

// Originally posted by "Blorgbeard" on StackOverflow
// Used under the Creative Commons, Share Alike, By Attribution License
// User profile: http://stackoverflow.com/users/369/blorgbeard
// Thread: http://stackoverflow.com/questions/601089/detect-whether-current-windows-version-is-32-bit-or-64-bit
function TMonitorThread.Is64BitOS: Boolean;
type
  TIsWow64Process = function(Handle:THandle; var IsWow64 : BOOL) : BOOL; stdcall;

var
  hKernel32 : Integer;
  IsWow64Process : TIsWow64Process;
  IsWow64 : BOOL;

begin
  // we can check if the operating system is 64-bit by checking whether
  // we are running under Wow64 (we are 32-bit code). We must check if this
  // function is implemented before we call it, because some older versions
  // of kernel32.dll (eg. Windows 2000) don't know about it.
  // see http://msdn.microsoft.com/en-us/library/ms684139%28VS.85%29.aspx
  Result := False;
  hKernel32 := LoadLibrary('kernel32.dll');
  //if (hKernel32 = 0) then RaiseLastOSError;
  @IsWow64Process := GetProcAddress(hkernel32, 'IsWow64Process');
  if Assigned(IsWow64Process) then begin
    IsWow64 := False;
    if (IsWow64Process(GetCurrentProcess, IsWow64)) then begin
      Result := IsWow64;
    end
    //else RaiseLastOSError;
  end;
  FreeLibrary(hKernel32);
end;

end.
