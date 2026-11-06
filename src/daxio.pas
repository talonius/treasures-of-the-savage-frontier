{ DaxIo -- DOS file helpers (exists, delete, rename, open with a disk prompt, file-name sanitizing), rounded and checked
  allocation, and DAX archive loading with its run-length decompression. }
{$O-,F+,I-,R-,S+,V-,B-,A-}
unit DaxIo;

interface

uses Types, GDConsts, GDVars, C_Driver, Dos, GameIo, SoundDrv;

type
  TString20 = string[20];
  TString2 = string[2];

{ Stops the sound for a disk access: saves the resident driver mode for PopSoundState and, when the built-in driver is
  in use, sends it the reset request and marks no driver until then. }
procedure PushSoundState;

{ Restores the driver mode PushSoundState saved and, when it is the built-in driver, starts it again. }
procedure PopSoundState;

{ Rounds a block size up to the heap's granularity.
  @param(n The size.)
  @returns(n rounded up to a multiple of 8.) }
function RoundSize(n: Word): Word;

{ Frees a block allocated by AllocRounded, with the same rounding of its size.
  @param(p The block.)
  @param(n The size it was allocated with.) }
procedure FreeRounded(var p: Pointer; n: Word);

{ Allocates a block with its size rounded up to a multiple of eight bytes.
  @param(p Receives the block.)
  @param(n The size wanted.) }
procedure AllocRounded(var p: Pointer; n: Word);

{ Erases a file if it exists.
  @param(name The file's name.) }
procedure DeleteIfPresent(name: Types.TStr80);

{ Renames a file if it exists.
  @param(oldName The file.)
  @param(newName Its new name.) }
procedure RenameIfExists(oldName, newName: Types.TStr80);

{ Waits until game.ovr can be found, asking for the overlay disk after each miss. }
procedure OverlayPrompt;

{ Reads a drive's volume label. The FindFirst status is not checked: the name buffer is cleared first, so a failed
  search leaves it empty.
  @param(drive The drive letter.)
  @returns(The label, or an empty string when it has none.) }
function GetVolumeLabel(drive: TString2): Types.TStr40;

{ Opens a file for reading in one-byte records. A name with no directory is looked for on the current data path; on a
  miss the two data paths are swapped, so later opens search the drive that held the file first. With prompts enabled, a
  file still missing on a floppy drive asks for the disk (the prompt plus the drive letter) and retries, and one missing
  on a hard drive reports a bad install and aborts.
  @param(fileName The file.)
  @param(promptMsg The disk prompt, before the drive letter.)
  @param(noPrompt Anything but zero returns False at once on a miss instead of prompting.)
  @param(f Receives the opened file.)
  @returns(True when the file was found and opened.) }
function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Byte; var f: file): Boolean;

{ Tells whether a normal file matching a name exists.
  @param(fileName The file name or pattern; an empty name never exists.)
  @returns(True when one exists.) }
function FileExists(fileName: Types.TStr80): Boolean;

{ Removes the occurrences of one string from another. Note: the scan limit is computed once from the starting lengths
  and the scan moves on after each deletion, so a match shifted into the current position survives, and a substring
  longer than the string wraps the limit round to a large byte value.
  @param(src The string.)
  @param(del The text to remove.)
  @returns(The string without the text.) }
function SanitizeString(src, del: string): string;

{ Makes a file name from a string: removes the characters a DOS file name cannot hold, in SanitizeString's single pass,
  keeps the first eight characters and uppercases them.
  @param(name The string.)
  @returns(The file name.) }
function SanitizeFileName(name: string): Types.TStr80;

{ Decodes a run-length packed entry. A control byte 0..$7E copies the next control+1 bytes; -127..-1 repeats the next
  byte -control times. Note: controls $7F and $80 do nothing, so a stream holding one makes no progress, and
  lenDecompressed is checked only between runs, so bad data can overrun the buffer by one run.
  @param(dst The buffer that receives the decoded bytes.)
  @param(lenDecompressed The number of bytes to decode.)
  @param(f The archive, positioned at the entry.) }
procedure DecompressDax(var dst: Types.PByteBuffer; var lenDecompressed: Word; var f: file);

{ Expands DAX run-length data. A control byte from 0 to $7E copies the next control + 1 bytes; one from $81 to $FF
  repeats the next byte -control times. The data is read at least once, even when it is empty, and neither buffer's
  bounds are checked. Note: control bytes $7F and $80 do not advance the input, so such data loops forever.
  @param(src The compressed data.)
  @param(dst Receives the expanded data.)
  @param(lenCompressed Length of the compressed data.)
  @param(lenDecompressed Unused.) }
procedure DecompressDaxBuffer(var src, dst: Types.PByteBuffer; var lenCompressed, lenDecompressed: Word);

{ Opens an archive twice, one handle for its entry directory from the start and one positioned at the first data byte.
  Note: if the second open fails, the first handle is left open.
  @param(fileName The archive's base name.)
  @param(extension Its extension.)
  @param(headerSize Receives the offset of the first data byte.)
  @param(dataFile Receives the handle positioned at the data.)
  @param(directoryFile Receives the handle that reads the directory.)
  @returns(True when both opens succeeded.) }
function OpenDax(fileName, extension: TString20; var headerSize: Word; var dataFile, directoryFile: file): Boolean;

{ Closes both handles of a DAX archive.
  @param(dataFile The data handle.)
  @param(directoryFile The directory handle.) }
procedure CloseDax(var dataFile, directoryFile: file);

{ Load block fileId of a DAX archive; when it is missing report 'No <id> in <file>' and, unless graphicsBusy is set, try
  again.
  @param(fileName The archive's base name.)
  @param(extension Its extension.)
  @param(fileId The block's id.)
  @param(sizeRead Receives the block's size; 0 when it is missing.)
  @param(data Receives the block.) }
procedure LoadDaxRetrying(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word;
                          var data: Types.PByteBuffer);

{ Load block fileId from the first of a comma-separated list of archives that holds it; when none does, report it and,
  with mode 0, start the list again.
  @param(fileName The archive base names, separated by commas.)
  @param(extension Their extension.)
  @param(fileId The block's id.)
  @param(sizeRead Receives the block's size; 0 when it is missing.)
  @param(data Receives the block.)
  @param(mode 0 to keep retrying, anything else to try the list once.) }
procedure LoadDaxFromList(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word;
                          var data: Types.PByteBuffer; mode: Byte);

{ Loads an archive entry into a fresh heap block, inside PushSoundState and PopSoundState. A directory entry is the id,
  a four-byte data offset, the decoded size and the packed size. A packed entry too big to buffer whole is decoded
  straight from the file.
  @param(fileName The archive's base name.)
  @param(extension Its extension.)
  @param(fileId The entry's id.)
  @param(sizeRead Receives the entry's size; 0 when the archive or the entry is missing.)
  @param(data Receives the block; nil when the archive or the entry is missing.) }
procedure LoadDax(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PByteBuffer);

{ Allocates a heap block, stopping the game with 'Out of memory' when there is none.
  @param(p Receives the block.)
  @param(n Its size.) }
procedure SafeGetMem(var p: Pointer; n: Word);

implementation

procedure PushSoundState;
begin
  GDVars.savedResidentMode := GDVars.residentMode;
  if GDVars.residentMode = C_Driver.SOUND_EFFECTS then begin
    SoundDrv.SoundCommand(GDConsts.resetSoundId);
    GDVars.residentMode := C_Driver.NO_DRIVER
  end
end;

procedure PopSoundState;
begin
  GDVars.residentMode := GDVars.savedResidentMode;
  if GDVars.residentMode = C_Driver.SOUND_EFFECTS then SoundDrv.StartSound
end;

function RoundSize(n: Word): Word;
begin
  RoundSize := (n + 7) and $FFF8
end;

procedure FreeRounded(var p: Pointer; n: Word);
begin
  FreeMem(p, (n + 7) and $FFF8)
end;

procedure AllocRounded(var p: Pointer; n: Word);
begin
  DaxIo.SafeGetMem(p, (n + 7) and $FFF8)
end;

procedure DeleteIfPresent(name: Types.TStr80);
begin
  if DaxIo.FileExists(name) then begin
    Assign(GDVars.ioScratchFile, name);
    Close(GDVars.ioScratchFile);
    Erase(GDVars.ioScratchFile)
  end
end;

procedure RenameIfExists(oldName, newName: Types.TStr80);
begin
  if DaxIo.FileExists(oldName) then begin
    Assign(GDVars.ioScratchFile, oldName);
    Close(GDVars.ioScratchFile);
    Rename(GDVars.ioScratchFile, newName)
  end
end;

procedure OverlayPrompt;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  found: Boolean;
begin
  repeat
    found := DaxIo.FileExists('game.ovr');
    if not found then begin
      Writeln('Please insert overlay disk.');
      key := GameIo.ReadGameKey
    end
  until found
end;

function GetVolumeLabel(drive: TString2): Types.TStr40;
var sr: SearchRec;
begin
  GameIo.ZeroFill(sr.Name, SizeOf(sr.Name));
  FindFirst(drive + ':\*.*', VolumeID, sr);
  GetVolumeLabel := sr.Name
end;

function OpenWithRetry(fileName, promptMsg: Types.TStr80; noPrompt: Byte; var f: file): Boolean;
var found: Boolean; oldDir: string[79]; dir: DirStr;
    name: NameStr; extension: ExtStr;
begin
  FSplit(fileName, dir, name, extension);
  if dir = '' then dir := GDVars.exeDir;
  repeat
    found := DaxIo.FileExists(dir + name + extension);
    if (not found) and (dir = GDVars.exeDir) then begin
      oldDir := GDVars.exeDir;
      GDVars.exeDir := GDVars.overlayDir;
      GDVars.overlayDir := oldDir;
      dir := GDVars.exeDir;
      found := DaxIo.FileExists(dir + name + extension)
    end;
    if (not found) and (noPrompt = 0) then
      if dir[1] < 'C' then
        GDVars.pauseHook(14, 0, promptMsg + GDVars.overlayDrive + ': <ENTER>')
      else
        GDVars.fatalMessageHook('Couldn''t find ' + name + extension + '. Check install.');
  until found or (noPrompt <> 0);
  if found then begin
    Assign(f, dir + name + extension);
    Reset(f, 1)
  end;
  OpenWithRetry := found
end;

function FileExists(fileName: Types.TStr80): Boolean;
var sr: SearchRec;
begin
  FindFirst(fileName, 0, sr);
  FileExists := (DosError = 0) and (fileName <> '')
end;

function SanitizeString(src, del: string): string;
var
  limit: Byte;
  delLen: Byte;
  i: Byte;
begin
  delLen := Length(del);
  limit := Length(src) - delLen + 1;
  for i := 1 to limit do
    if Copy(src, i, delLen) = del then Delete(src, i, delLen);
  SanitizeString := src
end;

function SanitizeFileName(name: string): Types.TStr80;
var i: Byte;
begin
  for i := 1 to 10 do
    name := DaxIo.SanitizeString(name, GDConsts.invalidFileCharTable[i]);
  name := Copy(name, 1, 8);
  for i := 1 to Length(name) do name[i] := UpCase(name[i]);
  SanitizeFileName := name
end;

procedure DecompressDax(var dst: Types.PByteBuffer; var lenDecompressed: Word; var f: file);
var
  { Unused in this version; see the other implementations of this routine. }
  srcIdx: Word;
  dstIdx: Word;
  b: ShortInt;
  fillByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  deadBuf: array[0..511] of Byte;
  nread: Word;
begin
  srcIdx := 0;
  dstIdx := 0;
  repeat
    BlockRead(f, b, SizeOf(b));
    case b of
      0..126:
        begin
          BlockRead(f, dst^[dstIdx], b + 1, nread);
          Inc(dstIdx, b + 1)
        end;
      -127..-1:
        begin
          b := -b;
          BlockRead(f, fillByte, SizeOf(fillByte), nread);
          FillChar(dst^[dstIdx], b, fillByte);
          Inc(dstIdx, b)
        end
    end
  until dstIdx >= lenDecompressed
end;

procedure DecompressDaxBuffer(var src, dst: Types.PByteBuffer; var lenCompressed, lenDecompressed: Word);
var
  srcIdx: Word;
  dstIdx: Word; b: ShortInt;
begin
  srcIdx := 0;
  dstIdx := 0;
  repeat
    b := ShortInt(src^[srcIdx]);
    case b of
      0..126:
        begin
          Move(src^[srcIdx + 1], dst^[dstIdx], b + 1);
          Inc(srcIdx, b + 2);
          Inc(dstIdx, b + 1)
        end;
      -127..-1:
        begin
          b := -b;
          FillChar(dst^[dstIdx], b, src^[srcIdx + 1]);
          Inc(srcIdx, 2);
          Inc(dstIdx, b)
        end
    end
  until srcIdx >= lenCompressed
end;

function OpenDax(fileName, extension: TString20; var headerSize: Word; var dataFile, directoryFile: file): Boolean;
var
  nread: Word;
  { Unused in this version; see the other implementations of this routine. }
  ioStatus: Word;
begin
  if DaxIo.OpenWithRetry(fileName + extension, GDConsts.diskPrompt, GDVars.suppressDiskPrompt,
                         dataFile) then begin
    if not DaxIo.OpenWithRetry(fileName + extension, GDConsts.diskPrompt, GDVars.suppressDiskPrompt,
                               directoryFile) then begin
      OpenDax := False;
      Exit
    end;
    BlockRead(directoryFile, headerSize, SizeOf(headerSize), nread);
    Inc(headerSize, SizeOf(headerSize));
    Seek(dataFile, headerSize);
    OpenDax := True
  end else OpenDax := False
end;

procedure CloseDax(var dataFile, directoryFile: file);
begin
  Close(dataFile);
  Close(directoryFile)
end;

procedure LoadDaxRetrying(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word;
                          var data: Types.PByteBuffer);
begin
  repeat
    DaxIo.LoadDax(fileName, extension, fileId, sizeRead, data);
    if sizeRead <> 0 then Exit;
    GDVars.showMessage('No ' + GDVars.intToStringHook(fileId) + ' in ' + fileName);
  until GDConsts.graphicsBusy <> 0;
end;

procedure LoadDaxFromList(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word;
                          var data: Types.PByteBuffer; mode: Byte);
var
  item: string;
  index: Byte;
begin
  repeat
    index := 1;
    repeat
      item := '';
      while (index <= Length(fileName)) and (fileName[index] <> ',') do
      begin
        item := item + fileName[index];
        Inc(index)
      end;
      if (index <= Length(fileName)) and (fileName[index] = ',') then Inc(index);
      DaxIo.LoadDax(item, extension, fileId, sizeRead, data);
      if sizeRead <> 0 then Exit;
    until index > Length(fileName);
    GDVars.showMessage('No ' + GDVars.intToStringHook(fileId) + ' in ' + fileName);
  until mode <> 0;
end;

procedure LoadDax(fileName, extension: Types.TStr80; fileId: Byte; var sizeRead: Word; var data: Types.PByteBuffer);
type
  TDaxEntry = packed record
    id: Byte;
    fileOffset: LongInt;
    unpackedSize: Word;
    packedSize: Word;
  end;
var
  entry: TDaxEntry;
  packedData: Types.PByteBuffer;
  nread: Word;
  dataFile: file;
  directoryFile: file;
  headerSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  numStr: array[0..8] of Byte;
begin
  DaxIo.PushSoundState;
  if not DaxIo.OpenDax(fileName, extension, headerSize, dataFile, directoryFile) then begin
    sizeRead := 0;
    data := nil;
    DaxIo.PopSoundState;
    Exit
  end;
  repeat
    BlockRead(directoryFile, entry, SizeOf(entry), nread)
  until (entry.id = fileId) or (FilePos(directoryFile) >= headerSize);
  if entry.id <> fileId then begin
    sizeRead := 0;
    data := nil;
    DaxIo.CloseDax(dataFile, directoryFile);
    DaxIo.PopSoundState;
    Exit
  end;
  sizeRead := entry.unpackedSize;
  DaxIo.SafeGetMem(Pointer(data), sizeRead);
  FillChar(data^, sizeRead, 0);
  Seek(dataFile, headerSize + entry.fileOffset);
  if DaxIo.RoundSize(entry.packedSize) >= MaxAvail then
    DaxIo.DecompressDax(data, sizeRead, dataFile)
  else begin
    DaxIo.AllocRounded(Pointer(packedData), entry.packedSize);
    BlockRead(dataFile, packedData^, entry.packedSize, nread);
    DaxIo.DecompressDaxBuffer(packedData, data, entry.packedSize, sizeRead);
    DaxIo.FreeRounded(Pointer(packedData), entry.packedSize)
  end;
  DaxIo.CloseDax(dataFile, directoryFile);
  DaxIo.PopSoundState
end;

procedure SafeGetMem(var p: Pointer; n: Word);
begin
  GetMem(p, n);
  if p = nil then
    GDVars.fatalMessageHook('Out of memory')
end;

begin
end.
