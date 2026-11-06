{ Screen frames and clearing: the border layouts drawn from BORD.DAX tile streams (GDVars.borderLayout), the picture
  frame's border banks, the VGA backdrop, and the rectangle fills that clear to black or restore the backdrop. The unit
  init installs EraseBox and ClearBoxToBackdrop as GDVars' clear-rect hooks. }
{$F+,O-,S+,A+,R-,V-,B-,I-}
unit Border;

interface

{ Draws the main screen frame through DrawCharViewFrame.
  @param(layout Unused.) }
procedure DrawWindowFrame(layout: Byte);

{ ClearBoxToBackdrop with the mouse hidden.
  @param(ulCol Left column.)
  @param(ulRow Top row; 25 selects the text window.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure EraseBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Clear the whole screen to black with the mouse hidden. }
procedure ClearScreenBlack;

{ Clear a text-cell rectangle, restoring the VGA backdrop where there is one (rows 0 to 23) and filling black elsewhere.
  A top row of 25 means the text window, rows 17 to 22.
  @param(ulCol Left column.)
  @param(ulRow Top row; 25 selects the text window.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBoxToBackdrop(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Fill a text-cell rectangle black with the mouse hidden, ignoring the backdrop.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure BlankBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

{ Load the picture-frame banks for the current place (BORD blocks 4 and 6 on the overland map, 3 and 5 elsewhere) if
  needed, and draw the frame around the picture area. }
procedure DrawMapPictureBorder;

{ Draw the screen layout with the picture frame: clear, frame the picture, and draw layout A's borders. }
procedure DrawExploreFrame;

{ Free the picture-frame banks. }
procedure FreePictureBorder;

{ Clear the screen and draw the main layout's outer border. }
procedure DrawCharViewFrame;

{ DrawCharViewFrame under a second entry. }
procedure DrawListFrame;

{ Clear the screen, draw layout B (a full-width rule at row 16) and set the view bounds to the text area, columns 1 to
  38, rows 17 to 22. }
procedure ScreenText;

{ Clear the screen, draw layout C (a vertical rule at column 22) and set the view bounds to the right pane, column 23,
  rows 1 to 21. }
procedure DrawCombatFrame;

{ VGA only: load the backdrop picture (BORD block 1) unless it is loaded. }
procedure LoadBorderBackdrop;

{ Free the backdrop picture. }
procedure FreeBorderBackdrop;

implementation

uses Types, Crt, GDConsts, GDVars, C_Video, C_Ifc, Blit, TextRend, GameIo, Mouse, Sym8x8;

type
  TTandyBank = array[0..49] of array[0..$9F] of Byte;
  TVgaBank = array[0..65520] of Byte;
  PVgaBank = ^TVgaBank;

var
  tandy0: TTandyBank absolute $B800:$0000;
  tandy1: TTandyBank absolute $BA00:$0000;
  tandy2: TTandyBank absolute $BC00:$0000;
  tandy3: TTandyBank absolute $BE00:$0000;
  vga: TVgaBank absolute $A000:$0000;

{$F-}
{ Clear the whole 40x25 text screen through EraseBox. }
procedure ClearScreenToBackdrop;
begin
  Border.EraseBox(0, 0, 39, 24)
end;

{ Clears a rectangle of character cells, corners included, to color 0 directly in video memory. EGA clears both display
  pages through TextRend, Tandy clears two scanlines in each of its four banks and VGA clears eight scanlines per cell
  row.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.) }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  top: Word;
  bot: Word;
  colOff: Word;
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  cgaColumnOffset: Word;
  r: Word;
  screenOff: Word;
  mode3Width: Word;
begin
  case GDVars.graphicsClass of
    C_Video.VM_EGA:
      begin
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
        TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black)
      end;
    C_Video.VM_TANDY:
      begin
        top := ulRow * 2;
        bot := lrRow * 2 + 1;
        colOff := ulCol * 4;
        rowBytes := (lrCol - ulCol + 1) * 4;
        for r := top to bot do begin
          GameIo.ZeroFill(tandy0[r][colOff], rowBytes);
          GameIo.ZeroFill(tandy1[r][colOff], rowBytes);
          GameIo.ZeroFill(tandy2[r][colOff], rowBytes);
          GameIo.ZeroFill(tandy3[r][colOff], rowBytes)
        end
      end;
    C_Video.VM_VGA:
      begin
        screenOff := ulRow * 8 * 320 + ulCol * 8;
        mode3Width := (lrCol - ulCol + 1) * 8;
        for r := ulRow * 8 to (lrRow + 1) * 8 - 1 do begin
          GameIo.ZeroFill(PVgaBank(LongInt($A0000000) + screenOff)^, mode3Width);
          Inc(screenOff, 320)
        end
      end
  end
end;

{$F+}
procedure ClearScreenBlack;
begin
  Mouse.HideMouse;
  Border.ClearBox(0, 0, 39, 24);
  Mouse.ShowMouse
end;

procedure ClearBoxToBackdrop(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  if ulRow = 25 then begin
    ulRow := 17;
    lrRow := 22
  end;
  if GDConsts.borderBackdrop <> nil then begin
    if lrRow < 24 then
      Blit.DrawFramePart(ulCol, ulRow, GDConsts.borderBackdrop, 0, ulCol, ulRow, lrCol - ulCol + 1, lrRow - ulRow + 1)
    else begin
      if ulRow < 24 then
        Blit.DrawFramePart(ulCol, ulRow, GDConsts.borderBackdrop, 0, ulCol, ulRow, lrCol - ulCol + 1, 23 - ulRow + 1);
      Border.ClearBox(ulCol, 24, lrCol, lrRow)
    end
  end else
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow)
end;

procedure EraseBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  Mouse.HideMouse;
  Border.ClearBoxToBackdrop(ulCol, ulRow, lrCol, lrRow);
  Mouse.ShowMouse
end;

procedure BlankBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  Mouse.HideMouse;
  Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
  Mouse.ShowMouse
end;

{$F-}
{ Draw a BORD.DAX tile stream left to right from (x, y): $FE ends it, $FF skips a cell.
  @param(x Starting column.)
  @param(y Row.)
  @param(stream The tile stream, an offset into GDVars.borderLayout.) }
procedure DrawBorderRow(x, y: Byte; stream: Types.PByteBuffer);
var i: Word;
begin
  i := 0;
  while stream^[i] <> $FE do begin
    if stream^[i] <> $FF then
      { bank 4 is BORD.DAX }
      Sym8x8.Put8x8Sym(x, y, stream^[i] + GDConsts.bankFirstTile[4], False, 1);
    Inc(x);
    Inc(i)
  end
end;

{ Draw a BORD.DAX tile stream top to bottom from (x, y): $FE ends it, $FF skips a cell.
  @param(x Column.)
  @param(y Starting row.)
  @param(stream The tile stream, an offset into GDVars.borderLayout.) }
procedure DrawBorderColumn(x, y: Byte; stream: Types.PByteBuffer);
var i: Word;
begin
  i := 0;
  while stream^[i] <> $FE do begin
    if stream^[i] <> $FF then
      { bank 4 is BORD.DAX }
      Sym8x8.Put8x8Sym(x, y, stream^[i] + GDConsts.bankFirstTile[4], False, 1);
    Inc(y);
    Inc(i)
  end
end;

{ Load the dungeon picture-frame banks (BORD blocks 3 and 5) if they are not loaded, and draw the frame around the
  picture area. }
procedure DrawPictureBorder;
begin
  if GDConsts.borderLoadState <> 1 then begin
    GDConsts.borderLoadState := 1;
    Blit.LoadPicFromList('bord', 3, 1, 13, GDConsts.borderBankA);
    Blit.LoadPicFromList('bord', 5, 0, 13, GDConsts.borderBankB)
  end;
  Blit.ShowPicMasked(0, 0, GDConsts.borderBankA, 0);
  Blit.ShowPicMasked(0, 14, GDConsts.borderBankA, 1);
  Blit.ShowPic(0, 3, GDConsts.borderBankB, 0);
  Blit.ShowPic(14, 3, GDConsts.borderBankB, 1)
end;

{$F+}
procedure DrawMapPictureBorder;
begin
  if (GDVars.locState.current = C_Ifc.DUNGEON) and (GDVars.gameState^.overMap <> 0) then begin
    if GDConsts.borderLoadState <> 2 then begin
      GDConsts.borderLoadState := 2;
      Blit.LoadPicFromList('bord', 4, 1, 13, GDConsts.borderBankA);
      Blit.LoadPicFromList('bord', 6, 0, 13, GDConsts.borderBankB)
    end
  end else if GDConsts.borderLoadState <> 1 then begin
    GDConsts.borderLoadState := 1;
    Blit.LoadPicFromList('bord', 3, 1, 13, GDConsts.borderBankA);
    Blit.LoadPicFromList('bord', 5, 0, 13, GDConsts.borderBankB)
  end;
  Blit.ShowPicMasked(0, 0, GDConsts.borderBankA, 0);
  Blit.ShowPicMasked(0, 14, GDConsts.borderBankA, 1);
  Blit.ShowPic(0, 3, GDConsts.borderBankB, 0);
  Blit.ShowPic(14, 3, GDConsts.borderBankB, 1)
end;

procedure DrawExploreFrame;
begin
  Mouse.HideMouse;
  Border.ClearScreenToBackdrop;
  Border.DrawPictureBorder;
  Border.DrawBorderRow(17, 0, @GDVars.borderLayout^[$00]);
  Border.DrawBorderRow(17, 16, @GDVars.borderLayout^[$18]);
  Border.DrawBorderRow(0, 23, @GDVars.borderLayout^[$30]);
  Border.DrawBorderColumn(0, 17, @GDVars.borderLayout^[$59]);
  Border.DrawBorderColumn(39, 0, @GDVars.borderLayout^[$61]);
  Mouse.ShowMouse
end;

procedure FreePictureBorder;
begin
  Blit.FreePic(GDConsts.borderBankA);
  Blit.FreePic(GDConsts.borderBankB);
  GDConsts.borderLoadState := 0
end;

procedure DrawWindowFrame(layout: Byte);
begin
  Border.DrawCharViewFrame
end;

procedure DrawCharViewFrame;
begin
  Mouse.HideMouse;
  Border.ClearScreenToBackdrop;
  Border.DrawBorderRow(0, 0, @GDVars.borderLayout^[$7A]);
  Border.DrawBorderRow(0, 23, @GDVars.borderLayout^[$A3]);
  Border.DrawBorderColumn(0, 0, @GDVars.borderLayout^[$CC]);
  Border.DrawBorderColumn(39, 0, @GDVars.borderLayout^[$E5]);
  Mouse.ShowMouse
end;

procedure DrawListFrame;
begin
  Border.DrawCharViewFrame
end;

procedure ScreenText;
begin
  Mouse.HideMouse;
  Border.ClearScreenToBackdrop;
  Border.DrawBorderRow(0, 0, @GDVars.borderLayout^[$FE]);
  Border.DrawBorderRow(0, 16, @GDVars.borderLayout^[$127]);
  Border.DrawBorderRow(0, 23, @GDVars.borderLayout^[$150]);
  Border.DrawBorderColumn(0, 0, @GDVars.borderLayout^[$179]);
  Border.DrawBorderColumn(39, 0, @GDVars.borderLayout^[$192]);
  GDVars.viewBounds[0] := 1;
  GDVars.viewBounds[1] := 17;
  GDVars.viewBounds[2] := 38;
  GDVars.viewBounds[3] := 22;
  Mouse.ShowMouse
end;

procedure DrawCombatFrame;
begin
  Mouse.HideMouse;
  Border.ClearScreenToBackdrop;
  Border.DrawBorderRow(0, 0, @GDVars.borderLayout^[$1AB]);
  Border.DrawBorderRow(0, 22, @GDVars.borderLayout^[$1D4]);
  Border.DrawBorderColumn(0, 0, @GDVars.borderLayout^[$1FD]);
  Border.DrawBorderColumn(22, 0, @GDVars.borderLayout^[$215]);
  Border.DrawBorderColumn(39, 0, @GDVars.borderLayout^[$22D]);
  GDVars.viewBounds[0] := 23;
  GDVars.viewBounds[1] := 1;
  GDVars.viewBounds[2] := 23;
  GDVars.viewBounds[3] := 21;
  Mouse.ShowMouse
end;

procedure LoadBorderBackdrop;
begin
  if GDConsts.borderBackdrop <> nil then Exit;
  if GDVars.graphicsClass <> C_Video.VM_VGA then Exit;
  Blit.LoadPicFromList('bord', 1, 0, 13, GDConsts.borderBackdrop)
end;

procedure FreeBorderBackdrop;
begin
  Blit.FreePic(GDConsts.borderBackdrop)
end;

begin
  GDVars.clearRectHook := Border.EraseBox;
  GDVars.clearRectCoreHook := Border.ClearBoxToBackdrop

end.
