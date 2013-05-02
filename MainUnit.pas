unit MainUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls, IniFiles, ComCtrls, MonitorThreadUnit,
  ActiveX, ComObj, StrUtils, ShellAPI, Clipbrd, ImgList;

type
  TAnoPipe=record
    Input : THandle;
    Output: THandle;
  end;

  TMainForm = class(TForm)
    ConfigPanel: TPanel;
    StratumProxyGroup: TGroupBox;
    Label18: TLabel;
    Label19: TLabel;
    StratumProxyPort: TEdit;
    StratumProxyHost: TEdit;
    UseStratumProxyOption: TCheckBox;
    CPUMiningGroup: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    CPUMinerUsername: TEdit;
    CPUMinerPort: TEdit;
    CPUMinerPassword: TEdit;
    CPUMinerHost: TEdit;
    GPUMiningGroup: TGroupBox;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    GPUMinerUsername: TEdit;
    GPUMinerPort: TEdit;
    GPUMinerPassword: TEdit;
    GPUMinerHost: TEdit;
    StartButton: TButton;
    AboutButtonFromSettings: TButton;
    LogPanel: TPanel;
    LogBackButton: TButton;
    LogGroup: TGroupBox;
    AboutButtonFromLog: TButton;
    LogList: TListView;
    LogIconImageList: TImageList;
    AggressiveMode: TCheckBox;
    DialogPanel: TPanel;
    DialogPromptPanel: TPanel;
    DialogMemo: TMemo;
    DialogOKButton: TButton;
    FormImage: TImage;
    StartupCheckTimer: TTimer;
    procedure UseStratumProxyOptionClick(Sender: TObject);
    procedure AboutButtonFromSettingsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure LogBackButtonClick(Sender: TObject);
    procedure AboutButtonFromLogClick(Sender: TObject);
    procedure LogListDrawItem(Sender: TCustomListView; Item: TListItem;
      Rect: TRect; State: TOwnerDrawState);
    procedure DialogOKButtonClick(Sender: TObject);
    procedure StartupCheckTimerTimer(Sender: TObject);
    procedure FormImageClick(Sender: TObject);
  private
    ProxyThread: TMonitorThread;
    CPUMinerThread: TMonitorThread;
    GPUMinerThread: TMonitorThread;
    UseCUDA: boolean;
    UseOpenCL: boolean;
    function Is64BitOS: Boolean;
    procedure GetWin32_VideoControllerInfo;
    procedure WhiteWash(src: TBitmap; ARect : TRect; WhiteWashValue : integer = 128);
    procedure StopMonitoredThreads;
  public
    procedure AddLogLineEvent(Sender: TObject; aLine: string; aIconIndex: Integer);
    procedure ShowDialog(dText: string);
  end;

var
  MainForm: TMainForm;
  LogFile: TextFile;

implementation

{$R *.dfm}

procedure TMainForm.UseStratumProxyOptionClick(Sender: TObject);
begin
  // If the "use stratum proxy" box is checked, we'll do a few things:
  // 1. cpuminer's host/port are set to localhost:8332, and the edit boxes are
  //    disabled so these can't be changed;
  // 2. Stratum proxy is launched before cpuminer when "save & start" is clicked.
  if (UseStratumProxyOption.Checked) then
  begin
    CPUMinerHost.Text := 'localhost';
    GPUMinerHost.Text := StratumProxyHost.Text;
    CPUMinerHost.Enabled := false;
    GPUMinerHost.Enabled := false;
    CPUMinerPort.Text := '8332';
    GPUMinerPort.Text := StratumProxyPort.Text;
    CPUMinerPort.Enabled := false;
    GPUMinerPort.Enabled := false;
    if (UseCUDA) then
    begin
      GPUMinerHost.Text := 'localhost';
      GPUMinerPort.Text := '8332';
    end;
  end else begin
    CPUMinerHost.Enabled := true;
    GPUMinerHost.Enabled := true;
    CPUMinerPort.Enabled := true;
    GPUMinerPort.Enabled := true;
  end;
end;

procedure TMainForm.AboutButtonFromSettingsClick(Sender: TObject);
begin
  ShellExecute(Self.WindowHandle, 'open', 'about.htm', nil, PChar(ExtractFilePath(Application.ExeName) + 'docs'), SW_SHOWNORMAL);
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  IniSettings: TMemIniFile;

begin
  // Make sure the "config" panel is shown first.
  ConfigPanel.Visible := true;
  ConfigPanel.BringToFront;

  // Create an INI file object.
  IniSettings := TMemIniFile.Create(ExtractFilePath(Application.ExeName) + 'easy_mining.ini');

  // Load settings from INI file, and populate editboxes.
  StratumProxyHost.Text := IniSettings.ReadString('Stratum', 'stratumhost', '');
  StratumProxyPort.Text := IniSettings.ReadString('Stratum', 'stratumport', '');
  UseStratumProxyOption.Checked := IniSettings.ReadBool('Stratum', 'useproxy', false);
  CPUMinerUsername.Text := IniSettings.ReadString('CPU', 'username', '');
  CPUMinerPassword.Text := IniSettings.ReadString('CPU', 'password', '');
  CPUMinerHost.Text := IniSettings.ReadString('CPU', 'host', '');
  CPUMinerPort.Text := IniSettings.ReadString('CPU', 'port', '');
  GPUMinerUsername.Text := IniSettings.ReadString('GPU', 'username', '');
  GPUMinerPassword.Text := IniSettings.ReadString('GPU', 'password', '');
  GPUMinerHost.Text := IniSettings.ReadString('GPU', 'host', '');
  GPUMinerPort.Text := IniSettings.ReadString('GPU', 'port', '');

  // If this is the first run, trigger a browser load to display the "getting
  // started" doc page. Then, mark the INI so we know we've run before.
  if (IniSettings.ReadBool('first', 'first', false) = true) then
  begin
    ShellExecute(Self.WindowHandle, 'open', 'getting_started.htm', nil, PChar(ExtractFilePath(Application.ExeName) + 'docs'), SW_SHOWNORMAL);
    IniSettings.WriteBool('first', 'first', false);
    IniSettings.UpdateFile;
    Application.ProcessMessages;
  end;

  // Free the INI file object.
  IniSettings.Free;



  // Prepare the proxy thread.
  ProxyThread := TMonitorThread.Create(false);
  //ProxyThread.FreeOnTerminate := true; < NOTE: This causes an invalid-pointer error on close.
  ProxyThread.OnNewLine := AddLogLineEvent;
  ProxyThread.DefaultIcon := 1;

  // Prepare the CPU miner thread.
  CPUMinerThread := TMonitorThread.Create(false);
  CPUMinerThread.OnNewLine := AddLogLineEvent;
  CPUMinerThread.DefaultIcon := 2;

  // Prepare the GPU miner thread.
  GPUMinerThread := TMonitorThread.Create(false);
  GPUMinerThread.OnNewLine := AddLogLineEvent;
  GPUMinerThread.DefaultIcon := 3;


  // Attempt to detect the first video card on the system.
  UseCUDA := false;
  UseOpenCL := false;
  try
    CoInitialize(nil);
    try
      GetWin32_VideoControllerInfo;
    finally
      CoUninitialize;
    end;
  except
    on E:EOleException do
      MessageDlg(Format('EOleException %s %x', [E.Message,E.ErrorCode]), mtError, [mbOK], 0);
    on E:Exception do
      MessageDlg(E.Classname + ': ' + E.Message, mtError, [mbOK], 0);
  end;

  StartupCheckTimer.Enabled := true;
end;

procedure TMainForm.StartButtonClick(Sender: TObject);
var
  IniSettings: TMemIniFile;
  ProxyCommand: string;
  CPUMinerCommand: string;
  GPUMinerCommand: string;
  index: integer;

begin
  // Switch to the "log" panel.
  LogPanel.Visible := true;
  LogPanel.BringToFront;
  ConfigPanel.Visible := false;

  // Create an INI file object.
  IniSettings := TMemIniFile.Create(ExtractFilePath(Application.ExeName) + 'easy_mining.ini');

  // Save settings to INI file.
  IniSettings.WriteString('Stratum', 'stratumhost', StratumProxyHost.Text);
  IniSettings.WriteString('Stratum', 'stratumport', StratumProxyPort.Text);
  IniSettings.WriteBool('Stratum', 'useproxy', UseStratumProxyOption.Checked);
  IniSettings.WriteString('CPU', 'username', CPUMinerUsername.Text);
  IniSettings.WriteString('CPU', 'password', CPUMinerPassword.Text);
  IniSettings.WriteString('CPU', 'host', CPUMinerHost.Text);
  IniSettings.WriteString('CPU', 'port', CPUMinerPort.Text);
  IniSettings.WriteString('GPU', 'username', GPUMinerUsername.Text);
  IniSettings.WriteString('GPU', 'password', GPUMinerPassword.Text);
  IniSettings.WriteString('GPU', 'host', GPUMinerHost.Text);
  IniSettings.WriteString('GPU', 'port', GPUMinerPort.Text);

  // Write out INI file.
  IniSettings.UpdateFile;
  Application.ProcessMessages;

  // Free the INI file object.
  IniSettings.Free;

  // Show in the log that we're starting up a mining session.
  AddLogLineEvent(Self, 'Easy Mining is starting a mining session at ' + FormatDateTime('hh:mm AM/PM, d MMM yyyy', now), 0);

  // If stratum proxy is selected, launch it first and wait for it to do its thing.
  if (UseStratumProxyOption.Checked) then
  begin
    AddLogLineEvent(Self, 'Stratum Proxy Mode!', 0);
    AddLogLineEvent(Self, 'Launching stratum proxy with the following arguments:', 0);

    ProxyCommand := ExtractFilePath(Application.ExeName)
      + 'stratumproxy\mining_proxy.exe -pa scrypt '
      + '-o ' + StratumProxyHost.Text + ' -p '
      + StratumProxyPort.Text;

    AddLogLineEvent(Self, ProxyCommand, 0);

    // Send the command line to the proxy monitor.
    ProxyThread.CommandLine := ProxyCommand;

    // Launch the proxy server.
    ProxyThread.Start;

    // Wait 10 seconds for the proxy server to connect.
    for index := 0 to 1000 do
    begin
      if (index mod 100) = 0 then
        AddLogLineEvent(Self, 'Waiting ' + IntTostr(10 - round(index / 100))
          + ' seconds for proxy server to connect...', 4);
      Application.ProcessMessages;
      sleep(10);
    end;
  end;


  // Launch the GPU miner. Note that we take advantage of our video card detection
  // to launch a miner appropriate to the API supported by hardware - cgminer for
  // OpenCL (AMD Radeon), cudaminer for CUDA (Nvidia GeForce).
  if (UseOpenCL) then
  begin
    if (GPUMinerHost.Text = '') or
      (GPUMinerPort.Text = '') or
      (GPUMinerUsername.Text = '') or
      (GPUMinerPassword.Text = '') then
    begin
      AddLogLineEvent(Self, 'WARNING: Can''t launch cgminer.exe!', 6);
      AddLogLineEvent(Self, 'Some information is missing. Please click "Save Settings & Start Mining!" to back up and check your settings.', 6);
    end else begin
      // Launch GPU-based OpenCL miner, cgminer.exe. Note that we include automatic fan settings
      // and aim for a target of 60 deg. C, so that the fan(s) on the video card more
      // accurately track what the car'd doing, as most default fan profiles are woefully
      // inadequate for mining. We want to run the card as cool as possible regardless of
      // the noise.
      AddLogLineEvent(Self, 'Launching GPU Miner (cgminer.exe) with the following arguments:', 4);

      if (AggressiveMode.Checked) then
        GPUMinerCommand := ExtractFilePath(Application.ExeName)
          + 'cgminer\cgminer.exe --scrypt -u ' + GPUMinerUsername.Text
          + ' -p ' + GPUMinerPassword.Text
          + ' -o ' + GPUMinerHost.Text + ':' + GPUMinerPort.Text
          + ' --gpu-fan 25-100 --auto-fan --temp-target 60 -I 18 -T'
      else
        GPUMinerCommand := ExtractFilePath(Application.ExeName)
          + 'cgminer\cgminer.exe --scrypt -u ' + GPUMinerUsername.Text
          + ' -p ' + GPUMinerPassword.Text
          + ' -o ' + GPUMinerHost.Text + ':' + GPUMinerPort.Text
          + ' --gpu-fan 25-100 --auto-fan --temp-target 60 -I 12 -T';

      AddLogLineEvent(Self, GPUMinerCommand, 4);

      // Send the command line to the miner's monitor thread.
      GPUMinerThread.CommandLine := GPUMinerCommand;

      // Launch the miner.
      GPUMinerThread.Start;
    end;
  end;

  if (UseCUDA) then
  begin
    if (GPUMinerHost.Text = '') or
      (GPUMinerPort.Text = '') or
      (GPUMinerUsername.Text = '') or
      (GPUMinerPassword.Text = '') then
    begin
      AddLogLineEvent(Self, 'WARNING: Can''t launch cudaminer.exe!', 6);
      AddLogLineEvent(Self, 'Some information is missing. Please click "Save Settings & Start Mining!" to back up and check your settings.', 6);
    end else begin
      // Launch GPU-based CUDA miner, cudaminer.exe. Since cudaminer is built off the
      // cpuminer minerd.exe codebase, it uses automatic card parameter detection
      // and optimizes itself at runtime to suit the hardware. As such, all it
      // needs is a pool to point to.
      //
      // NOTE: Nvidia cards will require some form of overclocking utility that can
      // be used to manualy force the fan speed to maximum, as automatic fan speed
      // adjustment will NOT be adequate for mining.
      AddLogLineEvent(Self, 'Launching GPU Miner (cudaminer.exe) with the following arguments:', 4);

      if (AggressiveMode.Checked) then
        GPUMinerCommand := ExtractFilePath(Application.ExeName) + 'cudaminer\cudaminer.exe'
          + ' --algo scrypt -i 0 --url '
          + GPUMinerHost.Text + ':' + GPUMinerPort.Text
          + ' --userpass ' + GPUMinerUsername.Text + ':'
          + GPUMinerPassword.Text
      else
        GPUMinerCommand := ExtractFilePath(Application.ExeName) + 'cudaminer\cudaminer.exe'
          + ' --algo scrypt -i 1 --url '
          + GPUMinerHost.Text + ':' + GPUMinerPort.Text
          + ' --userpass ' + GPUMinerUsername.Text + ':'
          + GPUMinerPassword.Text;


      AddLogLineEvent(Self, GPUMinerCommand, 4);
      AddLogLineEvent(Self, 'NOTE: cudaminer likes to report in bursts, so expect no reports for a while.', 5);

      // Send the command line to the miner's monitor thread.
      GPUMinerThread.CommandLine := GPUMinerCommand;

      // Launch the miner.
      GPUMinerThread.Start;
    end;
  end;

  if (CPUMinerHost.Text = '') or
    (CPUMinerPort.Text = '') or
    (CPUMinerUsername.Text = '') or
    (CPUMinerPassword.Text = '') then
  begin
    AddLogLineEvent(Self, 'WARNING: Can''t launch minerd.exe!', 6);
    AddLogLineEvent(Self, 'Some information is missing. Please click "Save Settings & Start Mining!" to back up and check your settings.', 6);
  end else begin
    // Launch the CPU-based miner, minerd.exe. Note that we're using the customized
    // Litecoin version written by pooler. A quick 32-/64-bit OS detection is performed,
    // and then the appropriate-bit-depth version of minerd.exe is invoked.
    //
    // For details on cpuminer/minerd.exe, check out this thread:
    // https://bitcointalk.org/index.php?topic=55038.0
    AddLogLineEvent(Self, 'Launching CPU Miner (minerd.exe) with the following arguments:', 4);

    CPUMinerCommand := ExtractFilePath(Application.ExeName);
    if (Is64BitOS) then
      CPUMinerCommand := CPUMinerCommand + 'cpuminer-x64\minerd.exe'
    else
      CPUMinerCommand := CPUMinerCommand + 'cpuminer-x32\minerd.exe';
    CPUMinerCommand := CPUMinerCommand + ' --algo scrypt --url '
      + CPUMinerHost.Text + ':' + CPUMinerPort.Text
      + ' --userpass ' + CPUMinerUsername.Text + ':'
      + CPUMinerPassword.Text;

    AddLogLineEvent(Self, CPUMinerCommand, 4);
    AddLogLineEvent(Self, 'NOTE: minerd likes to report in bursts, so expect no reports for a while.', 5);

    // Send the command line to the miner's monitor thread.
    CPUMinerThread.CommandLine := CPUMinerCommand;

    // Launch the miner.
    CPUMinerThread.Start;
  end;
end;

procedure TMainForm.AddLogLineEvent(Sender: TObject; aLine: string; aIconIndex: Integer);
var
  NewEntry: TListItem;
begin
    // Remove excess items - we only need to store about 500 of them since there's
    // a log file as well.
  if (LogList.Items.Count > 500) then
  repeat
    LogList.Items.Delete(0);
  until (LogList.Items.Count < 500);

  // Create a new entry.
  NewEntry := LogList.Items.Add;
  NewEntry.Caption := aLine;
  NewEntry.ImageIndex := aIconIndex;

  // Scroll the listview to show the new entry.
  NewEntry.MakeVisible(false);

  // Write the line to the log file, tagging it based on the icon.
  try
    case aIconIndex of
      0: {monitor} WriteLn(LogFile, '[EASY MINING] ' + aLine);
      1: {proxy}   WriteLn(LogFile, '[   PROXY   ] ' + aLine);
      2: {cpu}     WriteLn(LogFile, '[ CPU MINER ] ' + aLine);
      3: {gpu}     WriteLn(LogFile, '[ GPU MINER ] ' + aLine);
      4: {info}    WriteLn(LogFile, '[   INFO    ] ' + aLine);
      5: {warning} WriteLn(LogFile, '[  WARNING  ] ' + aLine);
      6: {error}   WriteLn(LogFile, '[** ERROR **] ' + aLine);
    else
      WriteLn(LogFile, '[EASY MINING] ' + aLine);
    end;
  except
    ;
  end;
end;

procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
var
  index: integer;

begin
  if (LogPanel.Visible) then
  begin
    AddLogLineEvent(Self, 'Easy Mining received a program close request and is shutting down.', 4);
    AddLogLineEvent(Self, 'Closing any running mining programs - one moment...', 4);

    // Signal the monitor threads to close.
    StopMonitoredThreads;

    // Now that the threads have unwound, let the application close.
    CanClose := true;
  end;
end;

procedure TMainForm.LogBackButtonClick(Sender: TObject);
var
  index: integer;
  
begin
  LogBackButton.Enabled := false;

  AddLogLineEvent(Self, 'Easy Mining received a stop-mining request.', 4);
  AddLogLineEvent(Self, 'Closing running mining programs - one moment...', 4);

  // Signal the monitor threads to close.
  StopMonitoredThreads;

  ConfigPanel.Visible := true;
  ConfigPanel.BringToFront;
  LogPanel.Visible := false;

  LogBackButton.Enabled := true;
end;

procedure TMainForm.StopMonitoredThreads;
var
  index: integer;

begin
  // Signal the monitor threads to close. We will do this one at a time, so that
  // each closes in an orderly manner. We don't, after all, want the miners to be
  // trying to send their last work items to the stratum proxy while it's onloading.

  // Step one: close the CPU miner...
  if (CPUMinerThread.Active) then
  begin
    CPUMinerThread.Abort;

    // Wait 10 seconds for the monitored program to close gracefully.
    index := 0;
    repeat
      if (index mod 100) = 0 then
        AddLogLineEvent(Self, 'Waiting ' + IntTostr(10 - round(index / 100))
          + ' seconds for the CPU miner to close gracefully...', 4);
      Application.ProcessMessages;
      sleep(10);
      inc(index);
    until (not CPUMinerThread.Active) or (index >= 1000);

    if (CPUMinerThread.Active) then
    begin
        AddLogLineEvent(Self, 'Forcing the CPU miner to terminate...', 4);
      CPUMinerThread.ForceTerminate;
    end;
  end;

  // Step two: close the GPU miner...
  if (GPUMinerThread.Active) then
  begin
    GPUMinerThread.Abort;

    // Wait 10 seconds for the monitored program to close gracefully.
    index := 0;
    repeat
      if (index mod 100) = 0 then
        AddLogLineEvent(Self, 'Waiting ' + IntTostr(10 - round(index / 100))
          + ' seconds for the GPU miner to close gracefully...', 4);
      Application.ProcessMessages;
      sleep(10);
      inc(index);
    until (not GPUMinerThread.Active) or (index >= 1000);

    if (GPUMinerThread.Active) then
    begin
        AddLogLineEvent(Self, 'Forcing the GPU miner to terminate...', 4);
      GPUMinerThread.ForceTerminate;
    end;
  end;

  // Step three: close the stratum proxy...
  if (ProxyThread.Active) then
  begin
    ProxyThread.Abort;

    // Wait 10 seconds for the monitored program to close gracefully.
    index := 0;
    repeat
      if (index mod 100) = 0 then
        AddLogLineEvent(Self, 'Waiting ' + IntTostr(10 - round(index / 100))
          + ' seconds for the stratum proxy to close gracefully...', 4);
      Application.ProcessMessages;
      sleep(10);
      inc(index);
    until (not ProxyThread.Active) or (index >= 1000);

    if (ProxyThread.Active) then
    begin
        AddLogLineEvent(Self, 'Forcing the stratum proxy to terminate...', 4);
      ProxyThread.ForceTerminate;
    end;
  end;
end;

// Originally posted by "Blorgbeard" on StackOverflow
// Used under the Creative Commons, Share Alike, By Attribution License
// User profile: http://stackoverflow.com/users/369/blorgbeard
// Thread: http://stackoverflow.com/questions/601089/detect-whether-current-windows-version-is-32-bit-or-64-bit
function TMainForm.Is64BitOS: Boolean;
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
  if (hKernel32 = 0) then RaiseLastOSError;
  @IsWow64Process := GetProcAddress(hkernel32, 'IsWow64Process');
  if Assigned(IsWow64Process) then begin
    IsWow64 := False;
    if (IsWow64Process(GetCurrentProcess, IsWow64)) then begin
      Result := IsWow64;
    end
    else RaiseLastOSError;
  end;
  FreeLibrary(hKernel32);
end;

// Based on code originally posted by "RRUZ" on StackOverflow, and modified to
// suit this project.
// Used under the Creative Commons, Share Alike, By Attribution License
// User profile: http://stackoverflow.com/users/91299/rruz
// Thread: http://stackoverflow.com/questions/12966946/how-to-get-the-installed-video-card-delphi
procedure  TMainForm.GetWin32_VideoControllerInfo;
const
  WbemUser            ='';
  WbemPassword        ='';
  WbemComputer        ='localhost';
  wbemFlagForwardOnly = $00000020;
var
  FSWbemLocator : OLEVariant;
  FWMIService   : OLEVariant;
  FWbemObjectSet: OLEVariant;
  FWbemObject   : OLEVariant;
  oEnum         : IEnumvariant;
  iValue        : LongWord;
begin;
  FSWbemLocator := CreateOleObject('WbemScripting.SWbemLocator');
  FWMIService   := FSWbemLocator.ConnectServer(WbemComputer, 'root\CIMV2', WbemUser, WbemPassword);
  FWbemObjectSet:= FWMIService.ExecQuery('SELECT Name,PNPDeviceID  FROM Win32_VideoController','WQL',wbemFlagForwardOnly);
  oEnum         := IUnknown(FWbemObjectSet._NewEnum) as IEnumVariant;
  while oEnum.Next(1, FWbemObject, iValue) = 0 do
  begin
    // Since this project is only designed for single video cards, only check
    // the frist video card that we can identify.
    if (not UseCUDA) and (not UseOpenCL) then
    begin
      if (AnsiContainsText(String(FWbemObject.Name), 'AMD')) then UseOpenCL := true;
      if (AnsiContainsText(String(FWbemObject.Name), 'ATI')) then UseOpenCL := true;
      if (AnsiContainsText(String(FWbemObject.Name), 'Radeon')) then UseOpenCL := true;
      if (AnsiContainsText(String(FWbemObject.Name), 'Nvidia')) then UseCUDA := true;
      if (AnsiContainsText(String(FWbemObject.Name), 'GeForce')) then UseCUDA := true;
      if (AnsiContainsText(String(FWbemObject.Name), 'GTX')) then UseCUDA := true;
    end;
    FWbemObject:=Unassigned;
  end;
end;
procedure TMainForm.AboutButtonFromLogClick(Sender: TObject);
begin
  ShellExecute(Self.WindowHandle, 'open', 'about.htm', nil, PChar(ExtractFilePath(Application.ExeName) + 'docs'), SW_SHOWNORMAL);
end;

procedure TMainForm.LogListDrawItem(Sender: TCustomListView;
  Item: TListItem; Rect: TRect; State: TOwnerDrawState);
var
  wRect: TRect;
  nRect: TRect;

begin
  // Do a test to see if the text will wrap around to a second line. If so, we'll
  // try to more-or-less center the text vertically.
  wRect := Rect;
  DrawText(Sender.Canvas.Handle, PChar(Item.Caption), Length(Item.Caption), wRect, DT_CALCRECT or DT_WORDBREAK);

  // Draw the background - white or light silver, alternating.
  Sender.Canvas.Brush.Color := clWhite;

  // Draw the icon onto the new canvas.
  LogIconImageList.Draw(Sender.Canvas, Rect.Left + 2, Rect.Top + 2, Item.ImageIndex);

  // Create a bounding area for the text. This area will be offset to allow for the
  // icon. If the
  nRect := Rect;
  nRect.Left := LogIconImageList.Width + 4;
  nRect.Top := nRect.Top + round((nRect.Bottom - wRect.Bottom) / 2);

  // Draw the text.
  DrawText(Sender.Canvas.Handle, PChar(Item.Caption), Length(Item.Caption), nRect, DT_WORDBREAK);
end;

procedure TMainForm.ShowDialog(dText: string);
begin
  // Start by copying the main form's visible area to the dialog panel.
  FormImage.Picture.Bitmap.Assign(GetFormImage);

  // Then, darken the copied form imagery.
  WhiteWash(FormImage.Picture.Bitmap, FormImage.ClientRect, -64);

  // Finally, show it and the dialog panel.
  DialogMemo.Text := dText;
  DialogPanel.Visible := true;
  DialogPanel.BringToFront;
end;

procedure TMainForm.DialogOKButtonClick(Sender: TObject);
begin
  DialogPanel.Visible := false;
end;

procedure TMainForm.WhiteWash(src: TBitmap; ARect : TRect; WhiteWashValue : integer = 128);
  function GetPixel(x,y : integer) : pRGBTriple;
  var
    line : pbytearray;
  begin
    line := src.ScanLine[y];
    result := @line[x*3];
  end;

  function IntToByte(i:Integer):Byte;
  begin
    if i>255 then
      Result:=255
    else if i<0 then
      Result:=0
    else
      Result:=i;
  end;

var
  x,y : integer;
begin
  src.PixelFormat:=pf24bit;

  if ARect.Top < 0 then exit;
  if ARect.left < 0 then exit;
  if ARect.bottom > src.Height then exit;
  if ARect.right > src.Width then exit;

  for y := ARect.top to ARect.bottom-1  do
    for x := ARect.left to Arect.right-1 do
    begin
      getpixel(x,y).rgbtRed := IntToByte(WhiteWashValue + getpixel(x,y).rgbtRed );
      getpixel(x,y).rgbtGreen := IntToByte(WhiteWashValue + getpixel(x,y).rgbtGreen );
      getpixel(x,y).rgbtBlue := IntToByte(WhiteWashValue + getpixel(x,y).rgbtBlue );
    end;
end;


procedure TMainForm.StartupCheckTimerTimer(Sender: TObject);
var
  dText: string;

begin
  StartupCheckTimer.Enabled := false;

  // If the video card detection didn't pick up either Nvidia or AMD cards, alert
  // the user.
  if ((not UseCuda) and (not UseOpenCL)) then
  begin
    dText := #13#10 + 'Easy Mining was not able to determine whether your computer is using '
     + 'a Nvidia GeForce or AMD Radeon based video card. Easy Mining will default to '
     + 'OpenCL support, but this may or may not work with your hardware.' + #13#10#13#10
     + 'For best mining results, install a powerful Radeon-based video card and try again.';
    ShowDialog(dText);
    UseOpenCL := true;
  end;
end;

procedure TMainForm.FormImageClick(Sender: TObject);
begin
  Beep;
end;

end.

