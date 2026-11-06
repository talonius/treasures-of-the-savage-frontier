{ View3D -- the dungeon view: wall, barrier and event queries on the GEO map (GetWallType, GetBarrierType, GetMapEvent),
  the 3-D view and automap renderer (Display3DMapView), the overland map view, and the WALLDEF1.DAX and GEO1.DAX loaders
  (LoadWallSet, Load3DMap). TGeoMap and TWallDef lay out the two resources. }
{$O+,F+,I-,S+,A+,V-}
unit View3D;

interface

{ Stores the four 3D view band colors: sky, the two horizon bands and floor.
  @param(cSky The sky color.)
  @param(cHorz1 The first horizon band's color.)
  @param(cHorz2 The second horizon band's color.)
  @param(cFloor The floor color.) }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Reads the wall type on one side of a cell: north and east come from wallsNE, south and west from wallsSW, one nibble
  each. Off-map coordinates give 0.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The wall type, 0 for none. Note: a facing other than the four compass points leaves it undefined.) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the barrier on one side of a cell. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @param(facing The side, one of the four compass points.)
  @returns(The two-bit barrier type of the wall there, or 1 when there is no wall.) }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads a cell's event from the 3D map. Off the 16x16 map it returns 0 while script 0 or 80 is loaded, and otherwise
  wraps around the edges.
  @param(x The map column.)
  @param(y The map row.)
  @returns(The cell event.) }
function GetMapEvent(x, y: ShortInt): Byte;

{ The view renderer: the overland map or the automap when either is on; otherwise the backdrop, then three rows of walls
  far to near, starting two squares ahead and stepping back. In each row the leftward and the rightward scan both draw
  the center front.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The party's facing.) }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Load wall set fileId into slot wsSlot, showing 'Loading...Please Wait' (and, as a debug print with
  GDConsts.editorEnabled and GDConsts.debugToggle, 'walls <fileId> <wsSlot>'). On the overland map it loads OVER picture
  fileId instead (LoadOverMap). Otherwise it frees the overland map and, for a slot below 3, copies WALLDEF1.DAX record
  fileId's wall definitions into sets wsSlot+1..3, each drawing from tile bank wsSlot. When the slot's bank is missing
  or held another set, it loads the bank (8x8 tiles, Load8x8Set) and copies palette entries $20..$92. A missing record
  is reported and, unless graphicsBusy, halts with code 100.
  @param(fileId The WALLDEF1.DAX record, or on the overland map the OVER picture.)
  @param(wsSlot The wall-set slot, 0..2.) }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Load GEO1.DAX record mapId, a 2-byte header and the four planes ($402 bytes), and record mapId as the current map. The
  sizeRead = 0 test is redundant.
  @param(mapId The GEO1.DAX record.) }
procedure Load3DMap(mapId: Byte);

{ Take the overland palette: load OVER picture gameState^.overMapId + 1, keep the over-map palette as the saved one,
  copy palette entries $20..$FF from the picture into GDVars.activePalette (marked pending) and free the picture. }
procedure LoadOverPalette;

{ Re-reads the event at the party's cell and the wall ahead of it into GDVars.partyPos.eventAtCell and
  GDVars.partyPos.wallAhead. }
procedure RefreshCurrentMapCell;

{ Tells whether a cell is on the 16x16 map.
  @param(y The map column.)
  @param(x The map row.)
  @returns(True when the cell is on the map.) }
function Valid3DCoords(y, x: ShortInt): Boolean;

implementation

uses Types, Crt, GDConsts, GDVars, C_Dir, Blit, Border, Sym8x8, TextRend,
  DaxIo, GameIo, ZeroFree;

const
  { a cell event's flag: the cell shows the backdrop picture instead of the sky }
  BACKDROP_EVENT_MASK = $80;

type
  { the wallset buffer, two views over the same pointer tile: LoadWallSet copies WALLDEF records into [set
    1..3][type-row 1..5][cell 0..155]; DrawWallSlice indexes the same bytes flat as [wallType 1..20][cell]. }
  TWallDef = array[1..5, 0..$9B] of Byte;
  TWallDefs = array[1..4] of TWallDef;
  PWallDefs = ^TWallDefs;
  TWallSlices = array[1..20, 0..$9B] of Byte;
  PWallSlices = ^TWallSlices;

var
  wallSlices: PWallSlices absolute GDVars.wallDefs;
  wallDefs33: PWallDefs absolute GDVars.wallDefs;
  { the pointer's word halves }
  overMapWords: Types.TPtrRec absolute GDConsts.extraPictureA;
  viewImageWords: Types.TPtrRec absolute GDVars.viewSurface;

procedure LoadBackdrop(imageId: Byte); forward;

procedure LoadOverMap(mapX, mapY: Byte); forward;

procedure RefreshCurrentMapCell;
begin
  GDVars.partyPos.eventAtCell := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
  GDVars.partyPos.wallAhead := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                   GDVars.partyPos.facing)
end;

{ Draws the overhead automap: an 11 x 11 window of wall symbols around the party, kept on the map, each symbol picked by
  which of the cell's four sides have walls, with the party's facing arrow on top. With GDConsts.displayToggle set, a
  white dot marks a cell with event bits 0..6 and a green dot one with bit 7.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The party's facing.) }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  { party column inside the window }
  pwx: ShortInt;
  pwy: ShortInt;
  { inner loop }
  wx: ShortInt;
  { outer loop }
  wy: ShortInt;
  { window origin }
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  { Unused in this version; see the other implementations of this routine. }
  symbolText: String;
begin
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := GDConsts.bankFirstTile[3];
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, True, Byte(False));
    end;
  end;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + GDConsts.bankFirstTile[3] + $10, True, Byte(True));
  Blit.FlushView;
  if GDConsts.displayToggle <> 0 then
   for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
     mx := wx + xLo;
     if (GDVars.geoMap^.events[my][mx] and $7F) <> 0 then
      Blit.PlotViewPixel((wx + 3) * 8 + 2, (wy + 3) * 8 + 3, $F);
     if (GDVars.geoMap^.events[my][mx] and $80) <> 0 then
      Blit.PlotViewPixel((wx + 3) * 8 + 5, (wy + 3) * 8 + 3, $A)
    end
   end;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.viewColors[0] := cSky;
  GDVars.viewColors[1] := cHorz1;
  GDVars.viewColors[2] := cHorz2;
  GDVars.viewColors[3] := cFloor;
end;

{ Fill the sky, horizon and floor, then draw over them either the game state's backdrop picture, when the current map
  event has BACKDROP_EVENT_MASK set, or the sky picture chosen by sky level and hour of day. Switching between the two
  marks the palette dirty, so Display3DMapView loads the matching one. }
procedure DrawBackdrop;
var
  skyId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  deadWord: Word;
  imageX: Byte;
  imageY: Byte;
  { Unused in this version; see the other implementations of this routine. }
  columnWidth: Byte;
  { Unused in this version; see the other implementations of this routine. }
  rowHeight: Byte;
begin
  Blit.FillPicRect(2, 16, 11, 44, GDVars.viewColors[0], GDConsts.fillColorMap, GDVars.viewSurface);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.viewColors[2], GDConsts.fillColorMap, GDVars.viewSurface);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.viewColors[3], GDConsts.fillColorMap, GDVars.viewSurface);
  imageX := 2;
  imageY := 2;
  columnWidth := 12;
  rowHeight := 12;
  if (GDVars.partyPos.eventAtCell and View3D.BACKDROP_EVENT_MASK) <> 0 then begin
    if (GDVars.backdropImage = nil) or (GDVars.gameState^.backdropId <> GDConsts.backdropLoadedId) then
      View3D.LoadBackdrop(GDVars.gameState^.backdropId);
    Blit.BlitTileClipped(imageX, imageY, 0, 0, GDVars.backdropImage, GDVars.viewSurface);
    if GDVars.backdropPaletteSelected = 0 then begin
      GDVars.automapDirty := 1;
      GDVars.backdropPaletteSelected := 1
    end
  end else begin
    case GDVars.gameState^.hour of
      8..$10: skyId := 2;
      0..4, $13..$17: skyId := 1;
    else
      skyId := 0
    end;
    GDVars.previousSkyId := GDVars.currentSkyId;
    GDVars.currentSkyId := GDVars.gameState^.skyLevel * 3 + skyId;
    if (GDVars.previousSkyId <> GDVars.currentSkyId) or (GDVars.skyImage = nil) then begin
      Blit.FreePic(GDVars.skyImage);
      Blit.LoadPicFromList('skygrnd', GDVars.currentSkyId, 0, 13, GDVars.skyImage);
      Blit.ShadowPaletteEntries(144, 32, GDVars.paletteScratch);
      GDVars.backdropPaletteSelected := 1
    end;
    if GDVars.backdropPaletteSelected <> 0 then begin
      GDVars.automapDirty := 1;
      GDVars.backdropPaletteSelected := 0
    end;
    Blit.BlitTileClipped(imageX, imageY, 0, 0, GDVars.skyImage, GDVars.viewSurface)
  end
end;

{ Draw the rectangle of view slot slot, in wall type wallType, at char (x+2, y+2), skipping zero symbols and cells
  outside the 11 x 11 view; cnt advances on every cell, drawn or not.
  @param(x The view column of its top left symbol.)
  @param(y The view row of its top left symbol.)
  @param(wallType The wall type, an index into the loaded wall graphics; not range-checked.)
  @param(slot The perspective form; not range-checked.) }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  setNo: Byte;
  cnt: Byte;
begin
  setNo := (wallType - 1) div 5 + 1;
  cnt := GDConsts.viewSlotTable.start[slot];
  colLim := GDConsts.viewSlotTable.cols[slot] + x - 1;
  rowLim := GDConsts.viewSlotTable.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (wallSlices^[wallType][cnt] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, wallSlices^[wallType][cnt] + GDVars.symbolOffset[setNo], True,
                         Byte(True));
      Inc(cnt);
    end;
end;

function Valid3DCoords(y, x: ShortInt): Boolean;
begin
  if (y > 15) or (y < 0) or (x > 15) or (x < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.environmentId = 0) or (GDVars.environmentId = 80)) then
    GetBarrierType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.geoMap^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.geoMap^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.geoMap^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.geoMap^.barriers[y][x] and 3;
      end;
    GetBarrierType := b;
  end;
end;

function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) then
    GetWallType := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0 else if y < 0 then y := 15;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.geoMap^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.geoMap^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.geoMap^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.geoMap^.wallsSW[y][x] and $0F;
    end;
  end;
end;

function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.environmentId = 0) or (GDVars.environmentId = 80)) then
    GetMapEvent := 0
  else begin
    if x > 15 then x := 0 else if x < 0 then x := 15;
    if y > 15 then y := 0;
    if y < 0 then y := 15;
    GetMapEvent := GDVars.geoMap^.events[y][x];
  end;
end;

{ Draws the overland map view: an 11x11 window of the overland picture around the party, kept on the map, loading the
  picture and its border first when they are not shown, with the party's facing arrow on top. Arms the picture's palette
  cycling and programs a pending palette before flushing the view.
  @param(x The party's map column.)
  @param(y The party's map row.)
  @param(facing The party's facing.) }
procedure DrawOverMap(x, y, facing: Byte);
var
  partyX: ShortInt;
  partyY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  partyYTail: Byte;
  { Unused in this version; see the other implementations of this routine. }
  xLoLead: Byte;
  xLo: ShortInt;
  yLo: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  yLoTail: Byte;
begin
  if GDConsts.borderLoadState <> 2 then
    Border.DrawMapPictureBorder;
  if GDConsts.extraPictureA = nil then
    View3D.LoadOverMap(GDVars.wallSetCache[1].overMapX, GDVars.wallSetCache[1].overMapY);
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  partyX := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  partyY := y - yLo;
  if GDConsts.extraPictureA <> nil then
    Blit.RenderRegion(2, 2, 0, overMapWords.seg, overMapWords.ofs, viewImageWords.seg, viewImageWords.ofs, xLo,
                      yLo, $0B, $0B);
  Sym8x8.Put8x8Sym(partyX + 3 - 1, partyY + 3 - 1, facing div 2 + GDConsts.bankFirstTile[3] + $10, True, 1);
  if GDVars.savedCycleChunk[1] <> 0 then begin
    FillChar(GDVars.palettePreset, SizeOf(GDVars.palettePreset), 0);
    GDVars.palettePreset[1] := GDVars.savedCycleChunk;
    GDVars.palettePresetOn := 1;
    GDVars.overMapCycle := 1
  end;
  if GDVars.palettePending <> 0 then begin
    Blit.BlankDirtySpans;
    Blit.SetDacPalette($20, $E0, GDVars.activePalette);
    GDVars.palettePending := 0
  end;
  Blit.FlushView
end;

procedure LoadOverPalette;
var image: Types.PImage;
begin
  image := nil;
  Blit.LoadPicFromList('over', GDVars.gameState^.overMapId + 1, 0, $0D, image);
  GDVars.savedCycleChunk := GDVars.picCycleChunk3;
  GDVars.palettePending := 1;
  Blit.ShadowPaletteEntries($20, $E0, GDVars.activePalette);
  Blit.FreePic(image)
end;

{ Free the three wall banks, the sky and the backdrop, load OVER picture mapX into extraPictureA, take the overland
  palette (LoadOverPalette) and remember mapX and mapY in wall-set cache slot 1.
  @param(mapX The overland picture, also kept as the map's column.)
  @param(mapY Kept as the map's row.) }
procedure LoadOverMap(mapX, mapY: Byte);
begin
  Blit.FreePic(GDVars.banks[0]);
  Blit.FreePic(GDVars.banks[1]);
  Blit.FreePic(GDVars.banks[2]);
  Blit.FreePic(GDVars.skyImage);
  Blit.FreePic(GDVars.backdropImage);
  GDVars.previousSkyId := 0;
  GDVars.currentSkyId := 0;
  Blit.LoadPicFromList('over', mapX, 0, $0D, GDConsts.extraPictureA);
  View3D.LoadOverPalette;
  GDVars.wallSetCache[1].overMapX := mapX;
  GDVars.wallSetCache[1].overMapY := mapY
end;

{ Free the overland map and reload each cached wall set, slots 0..2, whose bank is empty. }
procedure LoadWallSets;
var slot: Byte;
begin
  Blit.FreePic(GDConsts.extraPictureA);
  for slot := 0 to 2 do
    if (GDVars.wallSetCache[slot + 1].wallDefId <> 0) and (GDVars.wallSetCache[slot + 1].wallDefId <> $FF) and
        (GDVars.banks[slot] = nil) then
      View3D.LoadWallSet(GDVars.wallSetCache[slot + 1].wallDefId, slot)
end;

procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  { (facing+6) mod 8 }
  fL: Byte;
  { (facing+2) mod 8 }
  fR: Byte;
  { (facing+4) mod 8 }
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  { Word forces the unsigned MUL }
  dxF: Word;
  dyF: Word;
  wx: Integer;
  wy: Integer;
  side: Byte;
  symOfs: Integer;
  dist: Byte;
  wallFront: Byte;
  wallSide: Byte;
  { Unused in this version; see the other implementations of this routine. }
  wallBack: Byte;
  prevWall: Byte;
begin
  if GDVars.gameState^.overMap <> 0 then begin
    View3D.DrawOverMap(x, y, facing);
    Exit
  end;
  if GDConsts.borderLoadState <> 1 then
    Border.DrawMapPictureBorder;
  if GDConsts.overViewTransition = 2 then
    GDConsts.overViewTransition := 1
  else if GDConsts.overViewTransition = 1 then begin
    GDConsts.overViewTransition := 0;
    GDVars.automapShown := True
  end;
  if GDVars.automapShown then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.LoadWallSets;
    GDVars.palettePresetOn := 0;
    View3D.DrawBackdrop;
    fL := (facing + C_Dir.WEST) mod 8;
    fB := (facing + C_Dir.SOUTH) mod 8;
    fR := (facing + C_Dir.EAST) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirDx[facing];
    dyF := GDConsts.dirDy[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          { far row: fronts + corner slot 9, walking LEFT }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[9] + symOfs + 1, GDConsts.viewSlotTable.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[0] + symOfs, GDConsts.viewSlotTable.yRow[0], wallFront,
                                   0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fL], wy - GDConsts.dirDy[fL], fL) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[9] + symOfs + 1, GDConsts.viewSlotTable.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
          { far row: fronts + corner slot 9, walking RIGHT }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          prevWall := 0;
          while side < 4 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then begin
              if prevWall > 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[9] + symOfs - 1, GDConsts.viewSlotTable.yRow[9],
                                     prevWall, 9);
              prevWall := wallFront;
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[0] + symOfs, GDConsts.viewSlotTable.yRow[0], wallFront,
                                   0);
            end else begin
              if (prevWall > 0) and (View3D.GetWallType(wx - GDConsts.dirDx[fR], wy - GDConsts.dirDy[fR], fR) <> 0) then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[9] + symOfs - 1, GDConsts.viewSlotTable.yRow[9],
                                     prevWall, 9);
              prevWall := 0;
            end;
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { far row left-side walls, slot 1 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[1] + symOfs, GDConsts.viewSlotTable.yRow[1], wallSide,
                                     1)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[1] + symOfs - 1, GDConsts.viewSlotTable.yRow[1],
                                     wallSide, 1);
            Inc(side);
            Dec(symOfs, 2);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
          { far row right-side walls, slot 2 }
          wx := cxPos;
          wy := cyPos;
          side := 0;
          symOfs := 0;
          while side < 3 do begin
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              if side = 0 then
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[2] + symOfs, GDConsts.viewSlotTable.yRow[2], wallSide,
                                     2)
              else
                View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[2] + symOfs + 1, GDConsts.viewSlotTable.yRow[2],
                                     wallSide, 2);
            Inc(side);
            Inc(symOfs, 2);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
        end;
        1: begin
          { middle row: from 2-left, scanning right; fronts slot 3 + left sides slot 4 }
          wx := cxPos + GDConsts.dirDx[fL];
          wx := wx + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          wy := wy + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[3] + symOfs, GDConsts.viewSlotTable.yRow[3], wallFront,
                                   3);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[4] + symOfs, GDConsts.viewSlotTable.yRow[4], wallSide,
                                   4);
            Inc(side);
            Inc(symOfs, 3);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { middle row: from 2-right, scanning left; fronts slot 3 + right sides slot 5 }
          wx := cxPos + GDConsts.dirDx[fR];
          wx := wx + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          wy := wy + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 6;
          while side < 3 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[3] + symOfs, GDConsts.viewSlotTable.yRow[3], wallFront,
                                   3);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[5] + symOfs, GDConsts.viewSlotTable.yRow[5], wallSide,
                                   5);
            Inc(side);
            Dec(symOfs, 3);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
        end;
        0: begin
          { near row: left cell + center; fronts slot 6 + left slot 7 }
          wx := cxPos + GDConsts.dirDx[fL];
          wy := cyPos + GDConsts.dirDy[fL];
          side := 0;
          symOfs := -7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[6] + symOfs, GDConsts.viewSlotTable.yRow[6], wallFront,
                                   6);
            wallSide := View3D.GetWallType(wx, wy, fL);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[7] + symOfs, GDConsts.viewSlotTable.yRow[7], wallSide,
                                   7);
            Inc(side);
            Inc(symOfs, 7);
            wx := wx + GDConsts.dirDx[fR];
            wy := wy + GDConsts.dirDy[fR];
          end;
          { near row: right cell + center; fronts slot 6 + right slot 8 }
          wx := cxPos + GDConsts.dirDx[fR];
          wy := cyPos + GDConsts.dirDy[fR];
          side := 0;
          symOfs := 7;
          while side < 2 do begin
            wallFront := View3D.GetWallType(wx, wy, facing);
            if wallFront <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[6] + symOfs, GDConsts.viewSlotTable.yRow[6], wallFront,
                                   6);
            wallSide := View3D.GetWallType(wx, wy, fR);
            if wallSide <> 0 then
              View3D.DrawWallSlice(GDConsts.viewSlotTable.xCol[8] + symOfs, GDConsts.viewSlotTable.yRow[8], wallSide,
                                   8);
            Inc(side);
            Dec(symOfs, 7);
            wx := wx + GDConsts.dirDx[fL];
            wy := wy + GDConsts.dirDy[fL];
          end;
        end;
      end;
      cxPos := cxPos + GDConsts.dirDx[fB];
      cyPos := cyPos + GDConsts.dirDy[fB];
      Dec(dist);
    until dist = 255;
    if (GDVars.automapDirty <> 0) or (GDVars.palettePending <> 0) then
      Blit.BlankDirtySpans;
    if GDVars.automapDirty <> 0 then begin
      if GDVars.backdropPaletteSelected <> 0 then begin
        Blit.SetDacPalette(144, 32, GDVars.backdropPalette);
        Blit.CopyPaletteEntries(144, 32, @GDVars.backdropPalette, @GDVars.activePalette)
      end else begin
        Blit.SetDacPalette(144, 32, GDVars.paletteScratch);
        Blit.CopyPaletteEntries(144, 32, @GDVars.paletteScratch, @GDVars.activePalette)
      end;
      GDVars.automapDirty := 0
    end;
    if GDVars.palettePending <> 0 then begin
      Blit.SetDacPalette($20, $94, GDVars.activePalette);
      GDVars.palettePending := 0
    end;
    Blit.FlushView
  end;
end;

{ Load BACK1.DAX picture imageId into GDVars.backdropImage, copy its palette entries $90..$AF and record it as the
  loaded backdrop; nothing more when the picture does not load.
  @param(imageId Picture number within BACK1.DAX.) }
procedure LoadBackdrop(imageId: Byte);
var
  resourceName: String[5];
  { Unused in this version; see the other implementations of this routine. }
  resourceNameTail: LongInt;
begin
  resourceName := 'back1';
  Blit.LoadPic(resourceName, imageId, 0, GDVars.viewColors[0], GDVars.backdropImage);
  if GDVars.backdropImage = nil then Exit;
  Blit.ShadowPaletteEntries(144, 32, GDVars.backdropPalette);
  GDVars.automapDirty := 1;
  GDConsts.backdropLoadedId := imageId
end;

procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PByteBuffer;
  offset: Word;
  { Unused in this version; see the other implementations of this routine. }
  deadRow: Byte;
  i: Word;
  { Unused in this version; see the other implementations of this routine. }
  deadColumn: Integer;
  { Unused in this version; see the other implementations of this routine. }
  count: Byte;
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  GDVars.freeAnimationHook;
  TextRend.ClearStatusLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  if GDConsts.editorEnabled and (GDConsts.debugToggle) then
    GDVars.bottomMessageHook('walls ' + GDVars.intToStringHook(fileId) + ' ' + GDVars.intToStringHook(wsSlot));
  if GDVars.gameState^.overMap <> 0 then begin
    View3D.LoadOverMap(fileId, wsSlot);
    TextRend.ClearStatusLine;
    Exit
  end;
  Blit.FreePic(GDConsts.extraPictureA);
  if wsSlot >= 3 then Exit;
  DaxIo.LoadDax('WALLDEF1', '.dax', fileId, sizeRead, data);
  if sizeRead = 0 then begin
    GDVars.showMessage('No #' + GDVars.intToStringHook(fileId) + ' in WALLDEF1.');
    if GDConsts.graphicsBusy = 0 then GameIo.ExitGame(100)
  end;
  offset := 0;
  i := 1;
  while (offset < sizeRead) and (wsSlot + i <= 3) do begin
    GDVars.symbolOffset[wsSlot + i] := wsSlot * $100;
    Move(data^[offset], wallDefs33^[wsSlot + i], SizeOf(TWallDef));
    Inc(offset, SizeOf(TWallDef));
    Inc(i)
  end;
  ZeroFree.PrefixFree(data, sizeRead);
  count := i - 1;
  if (GDVars.wallSetCache[wsSlot + 1].wallDefId <> fileId) or (GDVars.banks[wsSlot] = nil) then begin
    Sym8x8.Load8x8Set(fileId, wsSlot);
    Blit.ShadowPaletteEntries(32, 115, GDVars.activePalette);
    GDVars.palettePending := 1
  end;
  GDVars.wallSetCache[wsSlot + 1].wallDefId := fileId;
  GDVars.wallSetCache[wsSlot + 1].symbolSlot := wsSlot;
  TextRend.ClearStatusLine;
  GDVars.automapDirty := 1
end;

procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PByteBuffer;
  offset: Word;
begin
  DaxIo.LoadDax('GEO1', '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> $402) then
    GDVars.fatalMessageHook('Unable to load geo in Load3DMap.');
  offset := 2;
  Move(data^[offset], GDVars.geoMap^.wallsNE, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.wallsSW, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.events, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.geoMap^.barriers, SizeOf(Types.TGeoPlane));
  ZeroFree.PrefixFree(data, sizeRead);
  GDVars.gameState^.loadedMap := mapId
end;

begin
end.
