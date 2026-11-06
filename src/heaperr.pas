{ Resident allocation-failure callback. Offers an emergency save, then exits to DOS. }
{$O+,F+,S+}
{$A+}
unit HeapErr;

interface

{ Installed as HeapError, so the heap manager calls it when an allocation fails. For a nonzero request it shows an
  insufficient-memory warning; while a game is active it runs the save menu and repeats until a save sets the
  recently-saved flag, otherwise it says the program is exiting. Either way it then quits through GameIo.ExitGame. A
  zero-size request returns at once. Note: the result is never assigned.
  @param(size Bytes requested; 0 does nothing.)
  @returns(Nothing: the result is never assigned.) }
function HeapErrorHandler(size: Word): Word;

implementation

uses Crt, GDVars, TextRend, GameIo, SaveLoad;

function HeapErrorHandler(size: Word): Word;
var
  exitFlag: Byte;
begin
  if size > 0 then begin
    exitFlag := 0;
    repeat
      TextRend.DisplayAndPause(Yellow, 0, 'WARNING: Insufficient Memory');
      if GDVars.gameUp <> 0 then begin
        SaveLoad.SaveGame(1, 0);
        { recentlySaved is not cleared before this save attempt. }
        exitFlag := GDVars.recentlySaved
      end else begin
        exitFlag := 1;
        TextRend.DisplayAndPause(Yellow, 0, 'Insufficient Memory. Exiting Program')
      end
    until exitFlag <> 0;
    GameIo.ExitGame(0)
  end
end;

begin
  HeapError := @HeapErr.HeapErrorHandler
end.
