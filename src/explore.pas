{ Explore -- movement resolution and the map main menu: the 3-D view's Move/Area/Cast/View/Encamp/Search/Look menu and
  its arrow-key mode, and the overland map's direction menu. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Explore;

interface

{ Applies the pending move: in the dungeon, marks the map for redraw and steps forward when the way ahead is open; on
  the overland map, takes a MovePartyWilderness step; either way the position and time are redrawn. A suppressed
  movement state (255) is cleared instead in the dungeon and in any other interface state, but kept on the overland map.
  Finally frees the portrait animation. }
procedure ResolveMovement;

{ Reads one movement command. In the dungeon the menu offers Move, Area (unless the map is hidden), Cast, View, Encamp,
  Search (a toggle), Look (runs the look script) and, with the editor enabled, the developer menu; Delete opens GeoEdit
  and other extended keys change the selected character. After Move, the up arrow steps, down turns around and left and
  right turn, until Exit or Escape returns to the menu. On the overland map only Move and Encamp are offered, and after
  Move a direction key sets the facing for the next scroll. The bottom window is cleared once afterwards.
  @returns(The last input code, #255 after a step or turn. Note: it is undefined on the overland map with layout flag 0
    and in any other interface state.) }
function MapMainMenu: Char;

implementation

uses Types, Border, TextRend, Music, Mouse, Crt, GDConsts, GDVars, C_Dir, C_Keys, C_Status, C_Ifc,
  GeoEdit, DevMenu, Camp, ViewChar, GameTime, CharHlp, MapCurs, MenuCore, Portrait, View3D;

const
  { the movement state while a move is held back }
  MOVE_STATE_SUPPRESSED = $FF;
  { the search and look bits of the travel flags }
  SEARCH_FLAG = 1;
  LOOK_FLAG = 2;

{ Clears the zone's leave-map flag, then, when the barrier ahead lets the party through and the step would leave the
  16x16 map, clamps the position to the edge and sets the flag. }
procedure MoveForward;
var
  x: Integer;
  y: Integer;
  facing: Integer;
begin
  x := GDVars.partyPos.x;
  y := GDVars.partyPos.y;
  facing := GDVars.partyPos.facing;
  GDVars.gameState^.leaveMap := 0;
  if View3D.GetBarrierType(x, y, facing) <> 0 then begin
    Inc(x, GDConsts.dirDx[facing]);
    Inc(y, GDConsts.dirDy[facing]);
    if x > 15 then begin
      GDVars.partyPos.x := 15;
      GDVars.gameState^.leaveMap := 1
    end;
    if x < 0 then begin
      GDVars.partyPos.x := 0;
      GDVars.gameState^.leaveMap := 1
    end;
    if y > 15 then begin
      GDVars.partyPos.y := 15;
      GDVars.gameState^.leaveMap := 1
    end;
    if y < 0 then begin
      GDVars.partyPos.y := 0;
      GDVars.gameState^.leaveMap := 1
    end
  end
end;

{ Take one step forward with the step sound, wrapping around the map edge, and look up the wall ahead and the new cell's
  event. Off the overland map, advance the clock: one minute, or ten while searching. }
procedure MovePartyForward3D;
begin
  Music.SendSoundCommand(GDConsts.soundIds[8]);
  Inc(GDVars.partyPos.x, GDConsts.dirDx[GDVars.partyPos.facing]);
  Inc(GDVars.partyPos.y, GDConsts.dirDy[GDVars.partyPos.facing]);
  if GDVars.partyPos.x < 0 then GDVars.partyPos.x := 15;
  if GDVars.partyPos.x > 15 then GDVars.partyPos.x := 0;
  if GDVars.partyPos.y < 0 then GDVars.partyPos.y := 15;
  if GDVars.partyPos.y > 15 then GDVars.partyPos.y := 0;
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
  if GDVars.gameState^.overMap = 0 then
    if GDVars.gameState^.searchFlags and Explore.SEARCH_FLAG > 0 then
      GameTime.AdvanceTime(1, 2)
    else
      GameTime.AdvanceTime(1, 1)
end;

{ Scroll the overland map window one cell toward the party's facing, kept within its 38-by-15 grid, and charge
  wilderness travel time. }
procedure MovePartyWilderness;
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  x: ShortInt;
  y: ShortInt;
begin
  Mouse.HideMouse;
  MapCurs.RestoreCursorBackground;
  GDVars.gameState^.savedX := GDVars.gameState^.cursorX;
  GDVars.gameState^.savedY := GDVars.gameState^.cursorY;
  x := GDVars.gameState^.cursorX + GDConsts.dirDx[GDVars.partyPos.facing];
  y := GDVars.gameState^.cursorY + GDConsts.dirDy[GDVars.partyPos.facing];
  if x < 0 then x := 0;
  if x > 37 then x := 37;
  if y < 0 then y := 0;
  if y > 14 then y := 14;
  GDVars.gameState^.cursorX := x;
  GDVars.gameState^.cursorY := y;
  MapCurs.DrawCursor;
  Mouse.ShowMouse;
  GameTime.AdvanceTime(12, 3)
end;

function MapMainMenu: Char;
var
  done: Byte;
  menuPos: Byte;
  c: Char;
  viewDone: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedMenu: array[0..12] of Byte;
  savedChoice: Byte;
begin
  CharHlp.PrintPositionAndTime;
  GDVars.gameState^.movementState := 0;
  savedChoice := GDVars.horizChoice;
  case GDVars.locState.current of
    C_Ifc.DUNGEON: begin
      done := 0;
      c := #255;
      repeat
        if GDVars.isMoveMode = 0 then begin
          FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
          menuPos := 0;
          MenuCore.AppendSlot(0, menuPos);
          if (GDVars.gameState^.overMap = 0) and ((GDVars.gameState^.mapHidden = 0) or GDConsts.editorEnabled) then
            MenuCore.AppendSlot(1, menuPos);
          MenuCore.AppendSlot(2, menuPos);
          MenuCore.AppendSlot(3, menuPos);
          MenuCore.AppendSlot(4, menuPos);
          MenuCore.AppendSlot(5, menuPos);
          MenuCore.AppendSlot(6, menuPos);
          if GDConsts.editorEnabled then MenuCore.AppendSlot(7, menuPos);
          GDVars.horizChoice := savedChoice;
          c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.movementMenu, 1, 0);
          savedChoice := GDVars.horizChoice;
          if not GDVars.menuReturnedKey then begin
            case Ord(c) of
              0: begin MenuCore.ClearBottomLine; GDVars.isMoveMode := 1 end;
              1:
                if (GDVars.gameState^.mapHidden = 0) or GDConsts.editorEnabled or
                    (ParamStr(3) = GDVars.automapPassword) then begin
                  GDVars.automapShown := GDVars.automapShown = False;
                  GDVars.automapDirty := 1;
                  View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing)
                end else
                  TextRend.PrintAndPause(GDConsts.notHereMsg, Yellow, Black);
              2: begin
                GDConsts.actionDone := 0;
                if GDVars.curChar^.status = C_Status.OKAY then Camp.NoncombatCastMenu;
                if GDConsts.actionDone <> 0 then done := 1
              end;
              3: ViewChar.ViewCharMenu(viewDone);
              4: done := 1;
              5: begin
                GDVars.gameState^.searchFlags := GDVars.gameState^.searchFlags xor Explore.SEARCH_FLAG;
                CharHlp.PrintPositionAndTime
              end;
              6: begin
                GDVars.gameState^.searchFlags := GDVars.gameState^.searchFlags or Explore.LOOK_FLAG;
                CharHlp.PrintPositionAndTime;
                GameTime.AdvanceTime(1, 2);
                GDVars.vmBand.eclIp := GDVars.vmBand.vmRun[2];
                done := 1
              end;
              7: DevMenu.DeveloperMenu(done)
            end
          end else begin
            case c of
              C_Keys.ESCAPE: begin MenuCore.ClearBottomLine; GDVars.isMoveMode := 1 end;
              C_Keys.DELETE_KEY: GeoEdit.GeoEditor
            else
              CharHlp.PrintMiscInfo(GDVars.curChar, 0);
              ViewChar.SelectPrevNextChar(c);
              CharHlp.PrintMiscInfo(GDVars.curChar, 1);
              CharHlp.PrintPositionAndTime
            end
          end
        end else begin
          FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
          MenuCore.ResetMenuSlots(0);
          c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.exitMenu, 1, 0);
          if not GDVars.menuReturnedKey then begin
            if c = #0 then GDVars.isMoveMode := 0
          end else begin
            case c of
              C_Keys.UP: begin Explore.MoveForward; done := 1; CharHlp.PrintPositionAndTime; c := #255 end;
              C_Keys.DOWN: begin
                GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
                GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                         GDVars.partyPos.facing);
                View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
                CharHlp.PrintPositionAndTime;
                c := #255
              end;
              C_Keys.LEFT: begin
                GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
                GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                         GDVars.partyPos.facing);
                View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
                CharHlp.PrintPositionAndTime;
                c := #255
              end;
              C_Keys.RIGHT: begin
                GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
                GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                         GDVars.partyPos.facing);
                View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
                CharHlp.PrintPositionAndTime;
                c := #255
              end;
              C_Keys.ESCAPE: GDVars.isMoveMode := 0;
              C_Keys.DELETE_KEY: GeoEdit.GeoEditor
            end
          end
        end
      until done <> 0
    end;
    3: if GDVars.gameState^.layoutFlag <> 0 then begin
      done := 0;
      repeat
        FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
        if GDVars.isMoveMode = 0 then begin
          menuPos := 0;
          MenuCore.AppendSlot(0, menuPos);
          MenuCore.AppendSlot(4, menuPos);
          GDVars.horizChoice := savedChoice;
          c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.movementMenu, 1, 0);
          savedChoice := GDVars.horizChoice;
          if not GDVars.menuReturnedKey then
            case Ord(c) of
              0: begin MenuCore.ClearBottomLine; GDVars.isMoveMode := 1 end;
              4: done := 1
            end
        end else begin
          FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
          GDVars.menuSlots[0].optionId := 0;
          c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.exitMenu, 1, 0);
          if not GDVars.menuReturnedKey then begin
            if c = #0 then GDVars.isMoveMode := 0
          end else begin
            done := 1;
            case c of
              C_Keys.UP: GDVars.partyPos.facing := C_Dir.NORTH;
              C_Keys.PAGE_UP: GDVars.partyPos.facing := C_Dir.NORTHEAST;
              C_Keys.RIGHT: GDVars.partyPos.facing := C_Dir.EAST;
              C_Keys.PAGE_DOWN: GDVars.partyPos.facing := C_Dir.SOUTHEAST;
              C_Keys.DOWN: GDVars.partyPos.facing := C_Dir.SOUTH;
              C_Keys.END_KEY: GDVars.partyPos.facing := C_Dir.SOUTHWEST;
              C_Keys.LEFT: GDVars.partyPos.facing := C_Dir.WEST;
              C_Keys.HOME: GDVars.partyPos.facing := C_Dir.NORTHWEST;
              C_Keys.ESCAPE: GDVars.isMoveMode := 0
            end;
            CharHlp.PrintPositionAndTime
          end
        end
      until done <> 0
    end
  end;
  if GDVars.bottomCleared = 0 then begin
    Border.EraseBox(1, 17, 38, 22);
    GDVars.bottomCleared := 1
  end;
  MapMainMenu := c
end;

procedure ResolveMovement;
var
  { Unused in this version; see the other implementations of this routine. }
  moved: Byte;
begin
  moved := 0;
  case GDVars.locState.current of
    C_Ifc.DUNGEON:
      if GDVars.gameState^.movementState < Explore.MOVE_STATE_SUPPRESSED then begin
        GDVars.pendingRefresh := 1;
        if View3D.GetBarrierType(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing) = 1 then begin
          moved := 1;
          Explore.MovePartyForward3D
        end;
        CharHlp.PrintPositionAndTime
      end else
        GDVars.gameState^.movementState := 0;
    C_Ifc.AREA_MAP:
      if GDVars.gameState^.movementState < Explore.MOVE_STATE_SUPPRESSED then begin
        Explore.MovePartyWilderness;
        CharHlp.PrintPositionAndTime
      end;
  else
    GDVars.gameState^.movementState := 0
  end;
  Portrait.FreeAnimation
end;

begin
end.
