{ MapCurs -- the overland-map cursor. It saves the screen cell under the party's map square, draws the cursor picture
  over a copy of it, and puts the saved cell back before the party moves. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit MapCurs;

interface

{ Draws the party cursor on the overland map: saves the map cell under the party (one cell in from the map's corner)
  into a buffer, lays the cursor image over a copy of it through its mask, shows the result and clears the dirty spans
  the drawing recorded. }
procedure DrawCursor;

{ Erases the party cursor by putting back the map cell DrawCursor saved. }
procedure RestoreCursorBackground;

implementation

uses Types, GDVars, Blit, GameIo;

procedure DrawCursor;
begin
  Blit.GrabPic(GDVars.gameState^.cursorX + 1, GDVars.gameState^.cursorY + 1, GDVars.banks[4]);
  Blit.BlitTileCell(0, 0, 0, 0, GDVars.banks[4], GDVars.secondaryViewBank);
  Blit.BlitTileCell(0, 0, 0, 1, GDVars.scratchViewBank, GDVars.secondaryViewBank);
  Blit.DrawFirstFrame(GDVars.gameState^.cursorX + 1, GDVars.gameState^.cursorY + 1, GDVars.secondaryViewBank);
  GameIo.ZeroFill(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.ZeroFill(GDVars.spanLow, SizeOf(GDVars.spanLow));
  FillChar(GDVars.spanHigh, SizeOf(GDVars.spanHigh), $FF);
  GameIo.ZeroFill(GDVars.spanExtra, SizeOf(GDVars.spanExtra))
end;

procedure RestoreCursorBackground;
begin
  Blit.DrawFirstFrame(GDVars.gameState^.cursorX + 1, GDVars.gameState^.cursorY + 1, GDVars.banks[4])
end;

begin
end.
