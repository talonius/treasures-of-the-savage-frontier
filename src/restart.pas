{ Transfer-save and restart handoff to CONTROL. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Restart;

interface

{ Saves the game to the transfer slot, then exits with code 23 so that CONTROL relaunches the game. Whether the save
  succeeded is not checked. }
procedure RequestRestart;

implementation

uses SaveLoad, GameIo;

procedure RequestRestart;
begin
  SaveLoad.SaveGame(0, 1);
  GameIo.ExitGame(23)
end;

begin
end.
