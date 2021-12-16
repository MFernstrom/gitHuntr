{
          (`-')  _       (`-')          (`-')  _    (`-')      (`-')  _ <-. (`-')_ (`-')  _ <-. (`-')  <-. (`-')   (`-')  _
          (OO ).-/      _(OO )   <-.    (OO ).-/ <-.(OO )      (OO ).-/    \( OO) )(OO ).-/    \(OO )_    \(OO )_  (OO ).-/
   <-.--. / ,---.  ,--.(_/,-.\ ,--. )   / ,---.  ,------,)     / ,---.  ,--./ ,--/ / ,---.  ,--./  ,-.),--./  ,-.) / ,---.
 (`-'| ,| | \ /`.\ \   \ / (_/ |  (`-') | \ /`.\ |   /`. '     | \ /`.\ |   \ |  | | \ /`.\ |   `.'   ||   `.'   | | \ /`.\
 (OO |(_| '-'|_.' | \   /   /  |  |OO ) '-'|_.' ||  |_.' |     '-'|_.' ||  . '|  |)'-'|_.' ||  |'.'|  ||  |'.'|  | '-'|_.' |
,--. |  |(|  .-.  |_ \     /_)(|  '__ |(|  .-.  ||  .   .'    (|  .-.  ||  |\    |(|  .-.  ||  |   |  ||  |   |  |(|  .-.  |
|  '-'  / |  | |  |\-'\   /    |     |' |  | |  ||  |\  \      |  | |  ||  | \   | |  | |  ||  |   |  ||  |   |  | |  | |  |
 `-----'  `--' `--'    `-'     `-----'  `--' `--'`--' '--'     `--' `--'`--'  `--' `--' `--'`--'   `--'`--'   `--' `--' `--'


 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
 -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

                                      ,--,
                       ___          ,--.'|                             ___
              ,--,   ,--.'|_     ,--,  | :    Värsion 0.1            ,--.'|_
            ,--.'|   |  | :,' ,---.'|  : '         ,--,      ,---,   |  | :,'   __  ,-.
   ,----._,.|  |,    :  : ' : |   | : _' |       ,'_ /|  ,-+-. /  |  :  : ' : ,' ,'/ /|
  /   /  ' /`--'_  .;__,'  /  :   : |.'  |  .--. |  | : ,--.'|'   |.;__,'  /  '  | |' |
 |   :     |,' ,'| |  |   |   |   ' '  ; :,'_ /| :  . ||   |  ,"' ||  |   |   |  |   ,'
 |   | .\  .'  | | :__,'| :   '   |  .'. ||  ' | |  . .|   | /  | |:__,'| :   '  :  /
 .   ; ';  ||  | :   '  : |__ |   | :  | '|  | ' |  | ||   | |  | |  '  : |__ |  | '
 '   .   . |'  : |__ |  | '.'|'   : |  : ;:  | : ;  ; ||   | |  |/   |  | '.'|;  : |
  `---`-'| ||  | '.'|;  :    ;|   | '  ,/ '  :  `--'   \   | |--'    ;  :    ;|  , ;
  .'__/\_: |;  :    ;|  ,   / ;   : ;--'  :  ,      .-./   |/        |  ,   /  ---'
  |   :    :|  ,   /  ---`-'  |   ,/       `--`----'   '---'          ---`-'
   \   \  /  ---`-'           '---'
    `--`-'



    Author      Marcus Fernström
    License     Apache 2.0
    Version     0.1
    GitHub      https://github.com/MFernstrom/gitHuntr
    Notes       This is version 0.1 expect bugs and non-optimized code. Bugreports welcome.
}

program gitHuntr_lazproject;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp,
  fpjson,
  Math,
  StrUtils, FileUtil,
  flre, Crt,
  Process;

type

  { TgitHuntrApplication }

  TgitHuntrApplication = class(TCustomApplication)
  protected
    filenameRegexString, contentRegexString: String;
    outputFilename: String;
    workingDirectory: String;
    workingDirectoryRoot: String;
    repo: String;
    reponame: String;
    currentBranch: Integer;
    currentBranchName: String;
    hasOutputCurrentBranchName: Boolean;
    hasOutputCurrentBranchContent: Boolean;
    hasOutputCurrentEntropyMatch: Boolean;
    filenameMatches, entropyMatches, regexMatches: String;
    doEntropyScan: Boolean;
    branches: array of string;
    branchFileList: TStringList;
    jsonReport: TJSONObject;
    debugMode: Boolean;


    function createTempDirectory:String;
    function runProcess(parameters:string):string;
    function filenameMatchesRegex(str: String):boolean;
    function ExtractShortPath(fullpath: string):string;
    function getEntropyScore(str: String):Single;
    function contentMatchesRegex(shortPath, content:String):boolean;
    procedure writeDebug(str: String);
    procedure echoOptions;
    procedure getBranches;
    procedure gitCheckout(url: String);
    procedure findMatchingFilenames;
    procedure entropyScan(shortPath, content:String);
    procedure outputIfNotEmpty(str:String);
    procedure searchNextBranch;
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TgitHuntrApplication }

const
  // Used for entropy scan
  BASE64_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=';

function TgitHuntrApplication.createTempDirectory: String;
var
  guid: TGuid;
  tempDir: String;
begin
  CreateGUID(guid);
  tempDir := GetTempDir(true) + 'gitHuntr-' + GUIDToString(guid);
  writeln('Temp dir ', tempDir);
  CreateDir(tempDir);
  Result := tempDir;
end;

function TgitHuntrApplication.runProcess(parameters: string): string;
var
  AProcess: TProcess;
  sl: TStringList;
  i: Integer;
begin
  AProcess := TProcess.Create(nil);
  sl := TStringList.create;
  writeDebug('Running process git ' + parameters);
  try
    AProcess.Executable := 'git';

    for i := 1 to WordCount(parameters, [' ']) do begin
      AProcess.Parameters.add(ExtractWord(i, parameters, [' ']));
    end;

    AProcess.CurrentDirectory := workingDirectory;
    AProcess.Options := [poWaitOnExit, poUsePipes, poStderrToOutPut];
    AProcess.Execute;

    sl.LoadFromStream(AProcess.Output);
  finally
    result := sl.Text;
    writeDebug(result);
    sl.Free;
    AProcess.Free;
  end;
end;


function TgitHuntrApplication.filenameMatchesRegex(str: String): boolean;
var
  re : TFLRE;
  Captures:TFLREMultiCaptures;
begin
  re := TFLRE.Create(filenameRegexString, [rfUTF8]);
  try
    re.MatchAll(str, Captures);
    result := length(captures) > 0;
  finally
    re.Free;
  end;
end;


procedure TgitHuntrApplication.gitCheckout(url: String);
begin
  runProcess('clone ' + url);
  workingDirectory := workingDirectory + DirectorySeparator + reponame;
  runProcess('fetch');
end;


function TgitHuntrApplication.ExtractShortPath(fullpath: string): string;
begin
  result := RightStr(fullpath, length(fullpath) - length(workingDirectory));
end;


procedure TgitHuntrApplication.findMatchingFilenames;
var
  fileList: TStringList;
  item: string;
  shortPath: string;
  filename: string;
begin
  fileList := TStringList.Create;
  try
    FindAllFiles(fileList, workingDirectory, '*.*', true);
    for item in fileList do begin
      filename := ExtractFileName(item);
      shortPath := ExtractShortPath(item);
      if filenameMatchesRegex(filename) then begin
        if not hasOutputCurrentBranchName then begin
          filenameMatches := filenameMatches + '=== Matching filenames ===' + LineEnding;
          hasOutputCurrentBranchName := true;
        end;

        // Add filename to json
        jsonReport.Objects['branches'].Objects[currentBranchName].Arrays['filenames'].Add(shortPath);

        filenameMatches := filenameMatches + shortPath + LineEnding;
        //writeln(shortpath);
      end;
    end;
  finally
    fileList.Free;
  end;
end;


function TgitHuntrApplication.getEntropyScore(str: String): Single;
var
  ch: Char;
  p_x: Single;
begin
  result := 0;
  try
    for ch in BASE64_CHARS do begin
      p_x := str.CountChar(ch) / length(str);

      if not IsZero(p_x) then
        result := result + (-p_x * Log2(p_x));
    end;
  except
    on E:Exception do begin
      writeln(e.Message);
      writeln('::::', str);
    end;
  end;
end;


function TgitHuntrApplication.contentMatchesRegex(shortPath, content: String): boolean;
var
  re : TFLRE;
  parts : TFLREMultiStrings;
  i: Integer;
  foundMatches: boolean;
begin
  re := TFLRE.Create(contentRegexString, [rfUTF8]);
  try
    parts := nil;
    foundMatches := re.UTF8ExtractAll(content, parts);

    if foundMatches then begin
      regexMatches := regexMatches +  '== ' + shortPath + LineEnding;

      jsonReport.Objects['branches'].Objects[currentBranchName].Objects['content'].Add(shortPath, TJSONArray.Create);

      for i := 1 to Length( parts[0] ) - 1 do begin
        jsonReport.Objects['branches'].Objects[currentBranchName].Objects['content'].Arrays[shortPath].Add(trim(string(parts[0][i])));
        regexMatches := regexMatches + trim(string(parts[0][i])) + LineEnding;
      end;

      regexMatches := regexMatches + LineEnding;
    end;

    result := foundMatches;
  finally
    re.Free;
  end;
end;

procedure TgitHuntrApplication.writeDebug(str: String);
begin
  if debugMode then writeln(str);
end;

procedure TgitHuntrApplication.echoOptions;
begin
  WriteLn('Starting with options: ');
  WriteLn('filenameregex: ', filenameRegexString);
  WriteLn('contentregex: ', contentRegexString);
  WriteLn('outputfile: ', outputFilename);
  WriteLn('repo: ', repo);
  WriteLn('entropy: ', doEntropyScan);
  writeln;
end;

procedure TgitHuntrApplication.getBranches;
var
  lines: TStringList;
  line: string;
  tmp: string;
begin
  lines := TStringList.Create;
  writeDebug('Extracting list of branches');

  try
    lines.text := runProcess('branch -r ');
    for tmp in lines do begin
      line := trim(tmp);
      setlength(branches, length(branches) +1);
      branches[length(branches) -1] := ExtractWord(1, line, [' ']);
      writeDebug(ExtractWord(1, line, [' ']));
    end;
  finally
    lines.Free;
  end;
end;


procedure TgitHuntrApplication.entropyScan(shortPath, content: String);
var
  currentWord: string;
  i: Integer;
  entropyScore: single;
  enteredData: Boolean;
begin
  enteredData := false;
  writeDebug('Starting entropy scan');
  for i := 1 to WordCount(content, [' ', ':', '=', chr(10)]) do begin
    currentWord := ExtractWord(i, content, [' ', ':', '=', chr(10)]);
    currentWord := trim(currentWord);

    if length(currentWord) > 0 then begin
      entropyScore := getEntropyScore(currentWord);
      if (length(currentWord) > 15) AND (entropyScore > 4.3) then begin
        if not hasOutputCurrentEntropyMatch then begin
           entropyMatches := entropyMatches + '=== High entropy strings ===' + LineEnding;
          hasOutputCurrentEntropyMatch := true;
        end;

        if not enteredData then begin
          entropyMatches := entropyMatches + '== ' + shortPath + LineEnding;
          enteredData := true;
        end;

        // Add filename to json
        if TJSONData(jsonReport.Objects['branches'].Objects[currentBranchName].Objects['entropy'].Find(shortPath)) = NIL then
          jsonReport.Objects['branches'].Objects[currentBranchName].Objects['entropy'].Add(shortPath, TJSONArray.Create);

        jsonReport.Objects['branches'].Objects[currentBranchName].Objects['entropy'].Arrays[shortPath].Add(currentWord);
        entropyMatches := entropyMatches + currentWord + LineEnding;
      end;
    end;
  end;

  if enteredData then
    entropyMatches := entropyMatches + LineEnding;
end;


procedure TgitHuntrApplication.outputIfNotEmpty(str: String);
begin
  if length(str) > 0 then
    writeln(str);
end;


procedure TgitHuntrApplication.searchNextBranch;
var
  fileList: TStringList;
  fileContent: TStringList;
  shortPath: string;
  item: string;
begin
  // Check out next branch
  writeDebug('Checking out branch');
  currentBranch := currentBranch + 1;
  currentBranchName := branches[currentBranch];
  hasOutputCurrentBranchName := false;
  hasOutputCurrentBranchContent := false;
  hasOutputCurrentEntropyMatch := false;

  filenameMatches := '';
  entropyMatches := '';
  regexMatches := '';

  writeln('Checking out ', currentBranchName);
  runProcess('checkout ' + currentBranchName);

  jsonReport.Objects['branches'].Add(currentBranchName, TJSONObject.Create);
  jsonReport.Objects['branches'].Objects[currentBranchName].Add('filenames', TJSONArray.Create);
  jsonReport.Objects['branches'].Objects[currentBranchName].Add('content', TJSONObject.Create);
  jsonReport.Objects['branches'].Objects[currentBranchName].Add('entropy', TJSONObject.Create);

  if length(trim(filenameRegexString)) > 0 then
    findMatchingFilenames;

  if (length(filenameMatches) > 0) OR (length(entropyMatches) > 0) OR ( length(regexMatches) > 0) then begin
    writeln(LineEnding + '==== Matches in branch ' + currentBranchName + ' ====' + LineEnding);
    outputIfNotEmpty(filenameMatches);
  end;

  if (length(trim(contentRegexString)) > 0) OR (doEntropyScan) then begin
    try
      fileContent := TStringList.Create;
      fileList := TStringList.Create;

      FindAllFiles(fileList, workingDirectory, '*.*', true);

      for item in fileList do begin
        fileContent.LoadFromFile(item);
        shortPath := ExtractShortPath(item);

        if length(trim(contentRegexString)) > 0 then
          contentMatchesRegex(shortPath, fileContent.Text);

        if doEntropyScan then
          entropyScan(shortPath, fileContent.Text);
      end;

      outputIfNotEmpty(filenameMatches);
      outputIfNotEmpty(entropyMatches);
      outputIfNotEmpty(regexMatches);
    finally
      fileContent.Free;
      fileList.Free;
    end;
  end;
end;


procedure TgitHuntrApplication.DoRun;
var
  ErrorMsg: String;
  outputSL: TStringList;
begin
  ErrorMsg := CheckOptions('hfcodre', '');
  if ErrorMsg <> '' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  if HasOption('h') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  filenameRegexString := getOptionValue('f');
  contentRegexString := getOptionValue('c');
  outputFilename := GetOptionValue('o');
  workingDirectory := GetOptionValue('d');
  repo := GetOptionValue('r');
  doEntropyScan := HasOption('e');
  debugMode := HasOption('d');

  echoOptions;

  if (length(filenameRegexString) = 0) AND (length(contentRegexString) = 0) AND (doEntropyScan = false) then begin
    writeln();
    writeln('Nothing to search for. Must specify a regex or entropy. See gitHuntr -h for help');
    Halt;
  end;

  if length(filenameRegexString) > 0 then filenameRegexString := '(' + filenameRegexString + ')';
  if length(contentRegexString) > 0 then contentRegexString := '(' + contentRegexString + ')';

  jsonReport := TJSONObject.Create;

  try
    jsonReport.Strings['repo'] := repo;
    jsonReport.Add('branches', TJSONObject.Create);

    if length(workingDirectory) = 0 then begin
      workingDirectory := createTempDirectory;
    end;

    workingDirectoryRoot := workingDirectory;

    currentBranch := -1;
    branchFileList := TStringList.Create;
    try
      reponame := ExtractWord(WordCount(repo, ['/']), repo, ['/']);

      gitCheckout(repo);
      getBranches;

      if Length(repo) > 0 then begin
        while currentBranch < length(branches) -1 do
          searchNextBranch;
      end else begin

      end;
    finally
      branchFileList.Free;
    end;

  finally
    // Reset terminal color
    TextColor(White);

    // Clean up the temp directory
    writeln('Checking if ', workingDirectoryRoot, ' exists, and attempting to delete');
    if DirectoryExists(workingDirectoryRoot) then DeleteDirectory(workingDirectoryRoot, false);

    if DirectoryExists(workingDirectoryRoot) then writeln('Could not remove temp directory, please remove manually - ', workingDirectoryRoot);

    if length(outputFilename) = 0 then writeln(jsonReport.FormatJSON)
    else begin
      // An output file was specified so let's save to it
      outputSL := TStringList.Create;
      try
        outputSL.Text := jsonReport.FormatJSON;
        outputSL.SaveToFile(outputFilename);
      finally
        outputSL.Free;
      end;
    end;

    jsonReport.Free;
    Terminate;
  end;
end;

constructor TgitHuntrApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException := True;
end;

destructor TgitHuntrApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TgitHuntrApplication.WriteHelp;
begin
  TextColor(LightBlue);

  WriteLn('                                      ,--,');
  WriteLn('                       ___          ,--.''|                             ___');
  WriteLn('              ,--,   ,--.''|_     ,--,  | :    Version 0.1            ,--.''|_');
  WriteLn('            ,--.''|   |  | :,'' ,---.''|  : ''         ,--,      ,---,   |  | :,''   __  ,-.');
  WriteLn('   ,----._,.|  |,    :  : '' : |   | : _'' |       ,''_ /|  ,-+-. /  |  :  : '' : ,'' ,''/ /|');
  WriteLn('  /   /  '' /`--''_  .;__,''  /  :   : |.''  |  .--. |  | : ,--.''|''   |.;__,''  /  ''  | |'' |');
  WriteLn(' |   :     |,'' ,''| |  |   |   |   '' ''  ; :,''_ /| :  . ||   |  ,"'' ||  |   |   |  |   ,''');
  WriteLn(' |   | .\  .''  | | :__,''| :   ''   |  .''. ||  '' | |  . .|   | /  | |:__,''| :   ''  :  /');
  WriteLn(' .   ; '';  ||  | :   ''  : |__ |   | :  | ''|  | '' |  | ||   | |  | |  ''  : |__ |  | ''');
  WriteLn(' ''   .   . |''  : |__ |  | ''.''|''   : |  : ;:  | : ;  ; ||   | |  |/   |  | ''.''|;  : |');
  WriteLn('  `---`-''| ||  | ''.''|;  :    ;|   | ''  ,/ ''  :  `--''   \   | |--''    ;  :    ;|  , ;');
  WriteLn('  .''__/\_: |;  :    ;|  ,   / ;   : ;--''  :  ,      .-./   |/        |  ,   /  ---''');
  WriteLn('  |   :    :|  ,   /  ---`-''  |   ,/       `--`----''   ''---''          ---`-''');
  WriteLn('   \   \  /  ---`-''           ''---''');
  WriteLn('    `--`-''');

  writeln('');
  TextColor(white);
  writeln('Usage: gitHuntr -r <github url> <options>');
  writeln;
  writeln('Options');
  writeln;
  writeln('-h                   Show this help');
  writeln;
  writeln('-f                   Regex to match filenames');
  writeln;
  writeln('-c                   Regex to match file content');
  writeln;
  writeln('-o                   File to write report json to');
  //writeln;
  //writeln('-d');
  //writeln('--directory    Not yet implemented');
  writeln;
  writeln('-r                   URL for repo to scan');
  writeln;
  writeln('-e                   Perform Entropy search (slow)');

  //'hfcodre', 'help fileregex contentregex outputfile directory repo entropy'
end;

var
  Application: TgitHuntrApplication;
begin
  Application := TgitHuntrApplication.Create(nil);
  Application.Title := 'gitHuntr';
  Application.Run;
  Application.Free;
end.
