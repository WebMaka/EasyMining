program EasyMining;

uses
  Forms,
  SysUtils,
  ShlObj,
  MainUnit in 'MainUnit.pas' {MainForm},
  MonitorThreadUnit in 'MonitorThreadUnit.pas';

{$R *.res}

function GetSpecialFolder(const ASpecialFolderID: Integer): string;
var
  vSFolder:  pItemIDList;
  vSpecialPath: array[0..255] of Char;

begin
  SHGetSpecialFolderLocation(0, ASpecialFolderID, vSFolder);
  SHGetPathFromIDList(vSFolder, vSpecialPath);
  Result := StrPas(vSpecialPath);
end;

var
  LogFileLoc: string;
  LogFileName: string;

begin
  Application.Initialize;
  Application.Title := 'Easy Mining';

  try
    // Attempt to derive the path to COMMON DOCUMENTS, and check for a log directory.
    // If none exists, try to create it.
    LogFileLoc := GetSpecialFolder($002E {CSIDL_COMMON_DOCUMENTS});
    if (not DirectoryExists(LogFileLoc + '\EasyMining\logs')) then
      ForceDirectories(LogFileLoc + '\EasyMining\logs');

    // Start the log file.
    LogFileName := LogFileLoc + '\EasyMining\logs\log_' + FormatDateTime('dMMMyyyy_HHmm', now) + '.txt';
    AssignFile(LogFile, LogFileName);
    ReWrite(LogFile);

    WriteLn(LogFile, '[EASY MINING] Easy Mining is starting up!');
    WriteLn(LogFile, '[EASY MINING] Logging activities to file "' + LogFileName + '"');

    try
      Application.CreateForm(TMainForm, MainForm);
      Application.Run;

      repeat
        Application.ProcessMessages;
        Sleep(0);
      until (Application.Terminated);
    except
      ; // Sink any unhandled errors.
    end;

  finally
    WriteLn(LogFile, '[EASY MINING] Easy Mining is stopping!');
    WriteLn(LogFile, '[EASY MINING] Closing log file as of ' + FormatDateTime('hh:mm AM/PM, d MMM yyyy', now));

    CloseFile(LogFile);
  end;
end.
