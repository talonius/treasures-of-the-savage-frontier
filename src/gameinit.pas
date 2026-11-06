{ GameInit -- the game's one-time set-up (buffers, mouse, screen-row tables, the starting game state, fonts, symbols,
  the item table, sounds and border data) and the reset to a new game's state after a defeat. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit GameInit;

interface

{ Copy the 16 default colors into palette, copy entries 0..15 of the picture palette into the two palette buffers
  (workPalette and the active palette; VGA only), and program the 16 colors. Note: GDConsts.defaultColors holds four
  colors, so colors 4 to 15 are read from the bytes that follow it. }
procedure ResetPalette;

{ One-time start-up: the palette and random seed; the mouse (cursor, resolution, center) or joystick center; the
  game-state, script, font, wall, map and symbol buffers; the screen-row table (EGA linear, Tandy four interleaved
  banks); the starting game state (gameLevel 3, location 1, interface state 4); the font, symbol banks, cursor image,
  ITEMS file, effect handlers (EffHndlr.InitEffectHandlers), item table, sounds, border data and backdrop. }
procedure InitializeGame;

{ Reset to a new game's state after the scripts end (FixMain's loop): the same game-state defaults as InitializeGame,
  without reloading anything. }
procedure ResetGameState;

implementation

uses Types, Crt, GDConsts, GDVars, C_Video, C_Driver, C_Dir, C_Ifc,
  Blit, DaxIo, GameIo, ZeroFree, Mouse, TextRend, Border, EffHndlr, Magic, MenuCore, Sym8x8;

{ Fills the item definition table with $FF, then copies the 17-byte records of ITEM0.DAX resource 1 into it, at most
  254, and frees the loaded data. A missing item file is fatal. }
procedure LoadItems;
var
  sizeRead: Word;
  offset: Word;
  index: Byte;
  data: Types.PByteBuffer;
  item: Types.TItemDef;
begin
  FillChar(GDVars.itemDefs^, SizeOf(Types.TItemDefs), $FF);
  DaxIo.LoadDaxRetrying('ITEM0', '.dax', 1, sizeRead, data);
  if sizeRead = 0 then GDVars.fatalMessageHook('No item0.dax');
  offset := 0;
  index := 1;
  repeat
    Move(data^[offset], item, SizeOf(item));
    GDVars.itemDefs^[index] := item;
    Inc(index);
    Inc(offset, SizeOf(item))
  until (offset >= sizeRead) or (index > 254);
  ZeroFree.PrefixFree(data, sizeRead)
end;

{ Clear the sound table, then load zounds resources 1 to 11 into it, the retrying loader filling each entry's size and
  data. }
procedure LoadSoundDefs;
var
  index: Byte;
begin
  GameIo.ZeroFill(GDVars.soundTable, SizeOf(GDVars.soundTable));
  for index := 1 to 11 do
    with GDVars.soundTable[index] do
      DaxIo.LoadDaxRetrying('zounds', '.dax', index, size, data)
end;

procedure ResetPalette;
var
  i: Byte;
  j: Byte;
begin
  for i := 0 to 15 do begin
    for j := 0 to 2 do
      GDVars.gamePalette[i, j] := GDConsts.defaultColors[i, j];
    GDVars.gfxNibbleTable[i] := i
  end;
  Blit.ShadowPaletteEntries(0, 16, GDVars.workPalette);
  Blit.ShadowPaletteEntries(0, 16, GDVars.activePalette);
  Blit.SetDacPalette(0, 16, GDVars.gamePalette)
end;

procedure InitializeGame;
var
  { Unused in this version; see the other implementations of this routine. }
  scratch: array[0..255] of Byte;
  sizeRead: Word;
begin
  GameInit.ResetPalette;
  Randomize;
  if GDVars.mousePresent then begin
    GDVars.partyClickMode := 1;
    GDVars.mouseButtonCount := 0;
    Mouse.InitMouse;
    if GDVars.mousePresent then begin
      GDVars.mouseHiRes := True;
      GDVars.cursorMask := @GDConsts.cursorMask19;
      Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
      Mouse.SetMouse(639, 100);
      Mouse.GetMouse(GDVars.mouseButtons, GDVars.probeMouseX, GDVars.probeMouseY);
      GDVars.mouseHiRes := (GDVars.probeMouseX >= 321) = False;
      Mouse.ShowMouse
    end;
    GDVars.mouseX := 160;
    GDVars.mouseY := 100;
    Mouse.SetMouse(GDVars.mouseX, GDVars.mouseY);
    GDVars.mouseCurX := 0;
    GDVars.mouseCurY := 0
  end;
  if GDVars.joystickPresent then begin
    GDVars.joystickCenterX := 160;
    GDVars.joystickCenterY := 100
  end;
  GetMem(GDVars.gameState, SizeOf(Types.TGameState));
  GetMem(GDVars.vmBand.zone2, SizeOf(Types.TZone2));
  GetMem(GDVars.gameFontPtr, 1416);
  GetMem(GDVars.wallDefs, 2340);
  GetMem(GDVars.geoMap, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.banks[3]);
  Blit.AllocPic(8, 1, 1, 0, GDVars.banks[4]);
  Blit.AllocPic(8, 1, 1, 0, GDVars.secondaryViewBank);
  GDVars.scratchViewBank := nil;
  Blit.AllocPic(168, 21, 1, 0, GDVars.viewSurface);
  Blit.AllocPic(24, 3, 1, 0, GDVars.savedPic);
  GameIo.ZeroFill(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.ZeroFill(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.ZeroFill(GDVars.spanLow, SizeOf(GDVars.spanLow));
  FillChar(GDVars.spanHigh, SizeOf(GDVars.spanHigh), $FF);
  GameIo.ZeroFill(GDVars.spanExtra, SizeOf(GDVars.spanExtra));
  case GDVars.graphicsClass of
    C_Video.VM_EGA:
      begin
        GDVars.rowOffset := 0;
        for GDVars.rowIndex := 0 to 199 do begin
          GDVars.egaRowOffset[GDVars.rowIndex] := GDVars.rowOffset;
          Inc(GDVars.rowOffset, 40)
        end
      end;
    C_Video.VM_TANDY:
      begin
        GDVars.rowIndex := 0;
        GDVars.rowOffset := 0;
        while GDVars.rowIndex <= 199 do begin
          GDVars.tandyRowSegment[GDVars.rowIndex] := GDVars.rowOffset + $B800;
          Inc(GDVars.rowIndex);
          GDVars.tandyRowSegment[GDVars.rowIndex] := GDVars.rowOffset + $BA00;
          Inc(GDVars.rowIndex);
          GDVars.tandyRowSegment[GDVars.rowIndex] := GDVars.rowOffset + $BC00;
          Inc(GDVars.rowIndex);
          GDVars.tandyRowSegment[GDVars.rowIndex] := GDVars.rowOffset + $BE00;
          Inc(GDVars.rowIndex);
          GDVars.rowOffset := GDVars.rowOffset + 10
        end
      end
  end;
  GameIo.ZeroFill(GDVars.banks, $0C);
  GameIo.ZeroFill(GDVars.icon24Bank, SizeOf(GDVars.icon24Bank));
  GDVars.driverImageBuffer := nil;
  GDVars.driverParamsBuffer := nil;
  GetMem(GDVars.driverImageBuffer, 13000);
  GetMem(GDVars.driverParamsBuffer, 6144);
  GameIo.ZeroFill(GDVars.backdropImage, 8);
  GDVars.previousSkyId := 0;
  GDVars.currentSkyId := 0;
  GameIo.ZeroFill(GDVars.gameState^, SizeOf(Types.TGameState));
  GDVars.gameState^.gameLevel := 3;
  GDVars.gameState^.location := 1;
  GDVars.gameState^.areaScriptId := 0;
  GDVars.gameState^.printColor := 10;
  GDVars.gameState^.weather := 2;
  GDVars.gameState^.backdropId := 3;
  GameIo.ZeroFill(GDVars.vmBand.zone2^, SizeOf(Types.TZone2));
  GameIo.ZeroFill(GDVars.iconSet, SizeOf(GDVars.iconSet));
  GameIo.ZeroFill(GDVars.animFrames, SizeOf(GDVars.animFrames));
  GameIo.ZeroFill(GDVars.vgaState, SizeOf(GDVars.vgaState));
  GameIo.ZeroFill(GDVars.imageFrames, SizeOf(GDVars.imageFrames));
  GameIo.ZeroFill(GDVars.menuAnimDelays, $1F);
  GDVars.bigPicture := nil;
  GDVars.treasureItems := nil;
  GameIo.ZeroFill(GDVars.partyPos, SizeOf(GDVars.partyPos));
  GDVars.partyPos.x := 7;
  GDVars.partyPos.y := 13;
  GDVars.partyPos.facing := C_Dir.NORTH;
  GameIo.ZeroFill(GDVars.wallSetCache, SizeOf(GDVars.wallSetCache));
  GDVars.queryColor := 13;
  GDVars.menuTextColor := 10;
  GDVars.highlightColor := 15;
  GDVars.loadComplete := 1;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSavedGameFlag := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.highlightedCharacter := nil;
  GDVars.lastSpellTarget := nil;
  GDVars.vmBand.eclIp := $8000;
  GDVars.gameState^.gameDelay := 4;
  GDVars.inputAbort := False;
  GDVars.automapShown := False;
  LastMode := 1;
  GDVars.gameState^.partySize := 0;
  GDVars.vertTop := 1;
  GDVars.noBorder := 0;
  GDVars.combatSideByte := 0;
  GDVars.hardExitFlag := 0;
  GDVars.msgLineFlag := 0;
  GDVars.eclPicShown := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.resourceCurrentName[0] := #0;
  GDVars.resourceSavedName[0] := #0;
  GDVars.resourceCurrentId := $FF;
  GDVars.resourceSavedId := $FF;
  GDVars.recentlySaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncounterMenu := 0;
  GDVars.selectionMode := 0;
  GDVars.combatGfxOn := 1;
  GDVars.bigPicId := $FF;
  GDVars.trainMode := 0;
  GDVars.horizChoice := 1;
  GDVars.locState.current := C_Ifc.DUNGEON;
  GDVars.locState.previous := C_Ifc.MAIN_MENU;
  GDVars.overrideFlag := 0;
  GDVars.partyShown := 0;
  GDVars.skyPtrA := nil;
  GDVars.skyPtrB := nil;
  GDVars.skyPtrC := nil;
  GDVars.clickInputMode := 0;
  GDVars.arenaClickA := 0;
  GDVars.aimCursorActive := 0;
  GDVars.isMoveMode := 0;
  GDVars.mouseClicked := False;
  GDVars.modifyActive := 0;
  GDVars.agingFlag := 0;
  GDVars.residentToggle := True;
  GDVars.savedResidentMode := C_Driver.NO_DRIVER;
  GDVars.residentMode := C_Driver.NO_DRIVER;
  GDVars.driverImageLoaded := 0;
  GDVars.loadedParamsDaxId := $FF;
  GDVars.fixBusy := 0;
  GDVars.palettePresetOn := 0;
  GDVars.vaultDirty := 0;
  GDVars.wallDirty[0] := 0;
  TextRend.LoadGameFont;
  TextRend.DisplayLoading;
  Sym8x8.Load8x8Set(202, 3);
  Sym8x8.Load8x8Set(0, 4);
  Blit.ShadowPaletteEntries(16, 16, GDVars.activePalette);
  Blit.SetDacPalette(16, 16, GDVars.gamePalette);
  Blit.LoadPicFromList('cursor', 1, 1, 13, GDVars.scratchViewBank);
  GDVars.itemsFileOpen := DaxIo.OpenWithRetry('ITEMS', GDConsts.diskPrompt, 0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  BlockRead(GDVars.itemsFile, GDVars.baseItems, SizeOf(GDVars.baseItems), GDVars.itemsBytesRead);
  Close(GDVars.itemsFile);
  GameIo.ZeroFill(GDVars.itemPool, SizeOf(GDVars.itemPool));
  GDVars.backdropPaletteSelected := 0;
  GDVars.automapDirty := 0;
  Magic.InitSpellFns;
  EffHndlr.InitEffectHandlers;
  GetMem(GDVars.itemDefs, SizeOf(Types.TItemDefs));
  GameInit.LoadItems;
  GetMem(GDVars.stagingBuffer, 9000);
  GameInit.LoadSoundDefs;
  DaxIo.LoadDaxRetrying('bord', '.dax', 7, sizeRead, GDVars.borderLayout);
  DaxIo.LoadDaxRetrying('bord', '.dax', 9, sizeRead, Types.PByteBuffer(GDVars.effectNames));
  Border.LoadBorderBackdrop
end;

procedure ResetGameState;
begin
  GameIo.ZeroFill(GDVars.spanActive, SizeOf(GDVars.spanActive));
  GameIo.ZeroFill(GDVars.spanLow, SizeOf(GDVars.spanLow));
  FillChar(GDVars.spanHigh, SizeOf(GDVars.spanHigh), $FF);
  GameIo.ZeroFill(GDVars.spanExtra, SizeOf(GDVars.spanExtra));
  GameIo.ZeroFill(GDVars.gameState^, SizeOf(Types.TGameState));
  GDVars.gameState^.gameLevel := 3;
  GDVars.gameState^.location := 1;
  GDVars.gameState^.areaScriptId := 0;
  GDVars.gameState^.printColor := 10;
  GDVars.gameState^.weather := 2;
  GDVars.gameState^.backdropId := 3;
  GameIo.ZeroFill(GDVars.vmBand.zone2^, SizeOf(Types.TZone2));
  GameIo.ZeroFill(GDVars.partyPos, SizeOf(GDVars.partyPos));
  GDVars.partyPos.x := 7;
  GDVars.partyPos.y := 13;
  GDVars.partyPos.facing := C_Dir.EAST;
  GDVars.partyClickMode := 1;
  GameIo.ZeroFill(GDVars.wallSetCache, SizeOf(GDVars.wallSetCache));
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSavedGameFlag := 0;
  GDVars.restTicks := 0;
  GDVars.partyHead := nil;
  GDVars.curChar := nil;
  GDVars.highlightedCharacter := nil;
  GDVars.vmBand.eclIp := $8000;
  GDVars.gameState^.gameDelay := 4;
  GDVars.automapShown := False;
  LastMode := 1;
  GDVars.gameState^.partySize := 0;
  GDVars.vertTop := 1;
  GDVars.noBorder := 0;
  GDVars.combatSideByte := 0;
  GDVars.hardExitFlag := 0;
  GDVars.msgLineFlag := 0;
  GDVars.eclPicShown := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := 0;
  GDVars.suppressDiskPrompt := 0;
  GDVars.resourceCurrentName[0] := #0;
  GDVars.resourceSavedName[0] := #0;
  GDVars.resourceCurrentId := $FF;
  GDVars.resourceSavedId := $FF;
  GDVars.recentlySaved := 0;
  GDVars.ceilFloorColorSel := $E8;
  GDVars.wallColorSel := $DB;
  GDVars.inEncounterMenu := 0;
  GDVars.combatGfxOn := 1;
  GDVars.bigPicId := $FF;
  GDVars.trainMode := 0;
  MenuCore.ClearBottomLine;
  GDVars.horizChoice := 1;
  GDVars.locState.current := C_Ifc.DUNGEON;
  GDVars.locState.previous := C_Ifc.MAIN_MENU;
  GDVars.overrideFlag := 0;
  GDVars.clickInputMode := 0;
  GDVars.arenaClickA := 0;
  GDVars.aimCursorActive := 0;
  GDVars.isMoveMode := 0;
  GDVars.mouseClicked := False;
  GDVars.selectionMode := 0;
  GDVars.modifyActive := 0;
  GDVars.partyShown := 0;
  GDVars.agingFlag := 0;
  GDVars.monstersLoaded := 0;
  GDVars.vaultDirty := 0;
  GDVars.wallDirty[0] := 0
end;

begin
end.
