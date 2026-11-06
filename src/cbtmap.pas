{ CbtMap -- the combat map view: the actor grid over the 50x25 combat map, cell lookup, the 7x7 viewport and figure
  redraw. }
{$O+,F+,S+}
unit CbtMap;

interface

uses Types, GDConsts, GDVars, C_Terr, C_Dir, C_Ifc, C_Status, Crt, GameIo, Blit, TextRend, Music,
  MapTiles;

{ Gives the direction from one combatant's arena cell to another's.
  @param(src The combatant looked from.)
  @param(dst The combatant looked at.)
  @returns(The direction 0..7.) }
function DirectionToward(src, dst: Pointer): Byte;

{ Gives the direction, clockwise from north, from one point to another: the first of the eight whose sector holds the
  second. The tests multiply by 106 or 618 and divide by 256: 106/256 and 618/256 approximate tan 22.5 and tan 67.5
  degrees.
  @param(x2 The column looked from.)
  @param(y2 The row looked from.)
  @param(x1 The column looked at.)
  @param(y1 The row looked at.)
  @returns(The direction 0..7.) }
function DirectionBetween(x2, y2, x1, y1: Integer): Byte;

{ Finds the terrain beneath an arena cell: under a cloud or barrier, what the covering patch recorded; under a corpse,
  what the corpse lies on. Note: the coordinates are not checked, and a cyclic patch list would never end.
  @param(x The arena column.)
  @param(y The arena row.)
  @returns(The terrain.) }
function ResolveTerrain(x, y: ShortInt): Byte;

{ Finds the offset of one cell of an icon from its anchor cell. Neither sizeCode nor idx is range-checked.
  @param(sizeCode The icon's size code.)
  @param(idx The cell, 0..5.)
  @param(offsetX Receives the column offset.)
  @param(offsetY Receives the row offset.)
  @returns(False when the icon has no such cell or the size is 0.) }
function FootprintCell(sizeCode, idx: Byte; var offsetX, offsetY: ShortInt): Boolean;

{ Empty: the palette is left as it is after combat. }
procedure SetNoncombatPalette;

{ Redraws one arena cell: repaints its terrain (the whole icon footprint when a creature stands there, through
  UpdateCombatMapTile), then the creature's sprite if it is visible.
  @param(mapX Arena column of the cell.)
  @param(mapY Arena row of the cell.) }
procedure RedrawArenaCell(mapX, mapY: ShortInt);

{ Rebuilds the arena's creature-index grid: clears it, then for each creature with a nonzero icon size marks every cell
  its icon covers with the creature's combat slot and recomputes the creature's view coordinates. }
procedure BuildArenaArrays;

{ Looks up what lies on an arena cell.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(occupant Receives the combat slot of the creature standing there; 0 for none or outside the arena.)
  @param(terrainId Receives the cell's terrain; 0 outside the arena.) }
procedure GetArenaContents(x, y: ShortInt; var occupant, terrainId: Byte);

{ Repaints the terrain under each visible tile of a creature's icon, erasing its sprite, or under the single view cell
  when no creature is there.
  @param(x View column of the cell; the creature's own view column replaces it.)
  @param(y View row of the cell; the creature's own view row replaces it.)
  @param(mode The creature's combat slot, or 0 to look up the creature standing on the cell.) }
procedure UpdateCombatMapTile(x, y: ShortInt; mode: Byte);

{ Tells whether a view cell lies inside the 7x7 view.
  @param(x View column.)
  @param(y View row.)
  @returns(True when both coordinates lie inside the view.) }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Tests whether a creature's icon is visible in the view.
  @param(p The creature.)
  @param(mode Nonzero to require each tile of the icon in view, 0 to require one.)
  @returns(True when the icon is visible; False when the creature has no icon.) }
function CombatIconVisible(p: Pointer; mode: Byte): Boolean;

{ Targets the arena cell one step in the given direction from a cell and redraws the whole view if needed
  (BuildViewBuffer), redrawing each visible icon of a creature in play after a full redraw. Then redraws the cell, draws
  the cursor at the target (kept inside the arena) and flushes the view.
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(radius How far the target may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(direction Direction of the target, 0 to 7; 8 for the cell itself.) }
procedure ScrollView(x, y: ShortInt; radius, direction: Byte);

{ Turns a creature. While the combat map shows, it scrolls the creature into view unless it is wholly visible, and
  repaints its terrain when the facing crosses between 0 to 3 and 4 to 7 (the mirrored sprites) or `sub` or `flag` is
  nonzero. It stores the new facing and, unless `flag` is set, draws its sprite and flushes when it is visible and the
  map shows.
  @param(p The creature.)
  @param(mode The new facing, 0 to 7.)
  @param(sub The animation frame to draw.)
  @param(flag Nonzero to erase the sprite without drawing it again.) }
procedure SetCreatureFacing(p: Pointer; mode, sub, flag: Byte);

{ Finds a creature's arena column.
  @param(p The creature.)
  @returns(The column of its icon's upper-left cell.) }
function CombatCellX(p: Pointer): ShortInt;

{ Finds a creature's arena row.
  @param(p The creature.)
  @returns(The row of its icon's upper-left cell.) }
function CombatCellY(p: Pointer): ShortInt;

{ Finds a creature's icon size in the arena.
  @param(p The creature.)
  @returns(The icon size; 0 when it has no icon.) }
function GetIconSize(p: Pointer): Byte;

{ Finds a combatant's combat slot. Note: with no combatants, or more than 72, the search runs past the end of the table.
  @param(p The combatant.)
  @returns(The slot, or 0 if it is not in the fight.) }
function CombatSlot(p: Pointer): Byte;

{ Looks one step in a direction from every cell of a combatant's icon.
  @param(p The combatant.)
  @param(direction The direction, 8 for where it stands.)
  @param(occupant Receives another combatant in the way, or 0.)
  @param(bestTile Receives the costliest terrain there, or 0 if any cell is off the map.)
  @param(terrainId Receives any cloud or barrier terrain met, or 0.) }
procedure ProbeDirection(p: Pointer; direction: Byte; var occupant, bestTile, terrainId);

{ Shows a combatant falling. Outside combat this is just a sound and a pause. In combat it plays the death animation
  over the icon, once per fall, then, for a regular combatant (notPcNpc clear) that is not gone entirely, leaves a
  corpse, or a petrified one, on its cell unless a cloud covers it, remembering the terrain beneath. Finally it takes
  the creature off the map with no turn left. Note: nothing checks that the corpse table has room.
  @param(p The combatant.) }
procedure CreatureDowned(p: Pointer);

{ Places a creature on an arena cell if it fits. Outside combat it does nothing. In combat it places the creature at the
  cell, probes its own cells and rejects the place, zeroing the icon size, on any creature, terrain 0 or impassable
  terrain. On success with `clearEvent` set, for a party member it clears the creature's body entries and, unless
  another body lies on the cell, writes into it the terrain its last body covered, or the probed terrain when it has no
  body entry or the body covered a corpse cell. The creature grid is then refilled.
  @param(p The creature.)
  @param(x Arena column of the cell.)
  @param(y Arena row of the cell.)
  @param(clearEvent True when the creature moves there, so its bodies are cleared.)
  @returns(True outside combat or when the creature fits.) }
function IsValidCreatureLoc(p: Pointer; x, y: Byte; clearEvent: Boolean): Boolean;

{ Scrolls the view to the creature (ScrollView toward its own cell) when the combat map shows, drawing the cursor over
  its icon footprint when `mode` is set; afterwards the cursor is off with size 1.
  @param(p The creature.)
  @param(radius How far it may lie from the view center before the view moves; 255 forces a full redraw.)
  @param(mode True to draw the cursor.) }
procedure DisplayMapViewCentered(p: Pointer; radius, mode: Byte);

implementation

const
  { terrain values only this unit names }
  { a stoned creature (status 7) }
  TERRAIN_STATUE = 30;

const
  { the terrain drawn for an out-of-range terrain value }
  DEFAULT_TERRAIN_INDEX = 21;
  { cloud and barrier patches (27..29) and the downed creatures (30 and 31) }
  SPECIAL_TERRAIN_FIRST = 27;
  PATCH_TERRAIN_LAST = 29;
  FOOTPRINT_SIZE_MASK = $7F;
  DEFAULT_PROBE_TERRAIN = 23;
  { icon animation entries }
  CURSOR_ANIMATION_INDEX = 28;
  CORPSE_ANIMATION_INDEX = 22;

function FootprintCell(sizeCode, idx: Byte; var offsetX, offsetY: ShortInt): Boolean;
begin
  FootprintCell := False;
  if sizeCode = 0 then Exit;
  offsetX := GDConsts.iconDelta[sizeCode, idx].dx;
  offsetY := GDConsts.iconDelta[sizeCode, idx].dy;
  if offsetX >= 0 then FootprintCell := True;
end;

{ Recomputes each arena creature's view coordinates from its arena cell and the view's upper-left cell. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.actorCount do begin
    GDVars.work.relX[i] := GDVars.actor[i].x - GDVars.combatMap^.originX;
    GDVars.work.relY[i] := GDVars.actor[i].y - GDVars.combatMap^.originY;
  end;
end;

procedure SetNoncombatPalette;
begin
end;

{ Draws an arena cell at a view cell. A cloud, barrier or corpse cell shows the terrain beneath it with its own icon
  drawn on top.
  @param(screenX The view column.)
  @param(screenY The view row.)
  @param(mapX The arena column.)
  @param(mapY The arena row.) }
procedure DrawTerrainCell(screenX, screenY, mapX, mapY: ShortInt);
var
  tile: Byte;
  baseStyle: Byte;
  style: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellPointer: array[1..4] of Byte;
begin
  screenX := screenX * 3;
  screenY := screenY * 3;
  tile := GDVars.combatMap^.cells[mapY, mapX];
  if (tile > $45) or (tile = 0) then tile := CbtMap.DEFAULT_TERRAIN_INDEX;
  baseStyle := GDConsts.terrain[tile].code;
  if tile in [C_Terr.TERRAIN_BLADE_BARRIER..C_Terr.TERRAIN_CORPSE] then begin
    tile := CbtMap.ResolveTerrain(mapX, mapY);
    style := GDConsts.terrain[tile].code;
    case tile of
    C_Terr.TERRAIN_CORPSE, CbtMap.TERRAIN_STATUE:
      begin
      for i := 1 to GDVars.downedCount do
        if (GDVars.downed[i].x = mapX) and (GDVars.downed[i].y = mapY) then
          tile := GDVars.downed[i].terrain;
      end;
    end;
    if (tile > $45) or (tile = 0) then tile := CbtMap.DEFAULT_TERRAIN_INDEX;
    style := GDConsts.terrain[tile].code;
    Blit.BlitTileCell(screenX, screenY, style, 0, GDVars.icon24Bank, GDVars.viewSurface);
    Blit.BlitTileCell(screenX, screenY, 0, 1, GDVars.iconSet[baseStyle + 13, 0], GDVars.viewSurface)
  end else
    Blit.BlitTileCell(screenX, screenY, baseStyle, 0, GDVars.icon24Bank, GDVars.viewSurface)
end;

{ Repaints the terrain under the cursor's footprint at an arena cell, draws the cursor there when it is on, then redraws
  the creature standing on the cell if it is visible.
  @param(mapX Arena column of the cell.)
  @param(mapY Arena row of the cell.) }
procedure DrawCursorCell(mapX, mapY: ShortInt);
var
  baseX: ShortInt;
  baseY: ShortInt;
  dx: ShortInt;
  dy: ShortInt;
  direction: Byte;
  occupant: Byte;
  terrainId: Byte;
begin
  baseX := mapX - GDVars.combatMap^.originX;
  baseY := mapY - GDVars.combatMap^.originY;
  for direction := 0 to 5 do begin
    if CbtMap.FootprintCell(GDVars.combatMap^.cursorSize, direction, dx, dy) then
      if CbtMap.ViewCoordsValid(baseX + dx, baseY + dy) then begin
        CbtMap.DrawTerrainCell(baseX + dx, baseY + dy, mapX + dx, mapY + dy);
        if GDVars.combatMap^.cursorOn then
          MapTiles.DrawIconAnimSprite(baseX + dx, baseY + dy, 0, 0, CbtMap.CURSOR_ANIMATION_INDEX)
      end
  end;
  CbtMap.GetArenaContents(mapX, mapY, occupant, terrainId);
  if Byte(occupant) > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatureArr[Byte(occupant)], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.work.relX[Byte(occupant)], GDVars.work.relY[Byte(occupant)],
                         Types.PCharacter(GDVars.creatureArr[Byte(occupant)])^.combatAddr^.direction, 0,
                         Types.PCharacter(GDVars.creatureArr[Byte(occupant)])^.icon)
end;

procedure RedrawArenaCell(mapX, mapY: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  occupant: Byte;
  terrainId: Byte;
begin
  relX := mapX - GDVars.combatMap^.originX;
  relY := mapY - GDVars.combatMap^.originY;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  CbtMap.GetArenaContents(mapX, mapY, occupant, terrainId);
  if Byte(occupant) > 0 then
    if CbtMap.CombatIconVisible(GDVars.creatureArr[Byte(occupant)], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.work.relX[Byte(occupant)], GDVars.work.relY[Byte(occupant)],
                         Types.PCharacter(GDVars.creatureArr[Byte(occupant)])^.combatAddr^.direction, 0,
                         Types.PCharacter(GDVars.creatureArr[Byte(occupant)])^.icon)
end;

procedure BuildArenaArrays;
var
  i: Byte;
  direction: Byte;
  dx: ShortInt;
  dy: ShortInt;
begin
  GameIo.ZeroFill(GDVars.actorGrid, SizeOf(GDVars.actorGrid));
  for i := 1 to GDVars.actorCount do
    if GDVars.actor[i].size > 0 then begin
      for direction := 0 to 5 do
        if CbtMap.FootprintCell(GDVars.actor[i].size, direction, dx, dy) then
          GDVars.actorGrid[GDVars.actor[i].y + dy, GDVars.actor[i].x + dx] := i;
      GDVars.work.relX[i] := GDVars.actor[i].x - GDVars.combatMap^.originX;
      GDVars.work.relY[i] := GDVars.actor[i].y - GDVars.combatMap^.originY;
    end;
end;

procedure GetArenaContents(x, y: ShortInt; var occupant, terrainId: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrainId := GDVars.combatMap^.cells[y, x];
    occupant := GDVars.actorGrid[y, x];
  end else begin
    occupant := 0;
    terrainId := 0;
  end;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; mode: Byte);
var
  worldX: ShortInt;
  worldY: ShortInt;
  dx: ShortInt;
  dy: ShortInt;
  direction: Byte;
  terrainId: Byte;
  actorKind: Byte;
begin
  if mode = 0 then begin
    worldX := x + GDVars.combatMap^.originX;
    worldY := y + GDVars.combatMap^.originY;
    CbtMap.GetArenaContents(worldX, worldY, mode, terrainId)
  end;
  if mode > 0 then begin
    x := GDVars.work.relX[mode];
    y := GDVars.work.relY[mode];
    worldX := x + GDVars.combatMap^.originX;
    worldY := y + GDVars.combatMap^.originY;
    actorKind := GDVars.actor[mode].size;
    for direction := 0 to 5 do
      if CbtMap.FootprintCell(actorKind, direction, dx, dy) then
        if CbtMap.ViewCoordsValid(x + dx, y + dy) then
          CbtMap.DrawTerrainCell(x + dx, y + dy, worldX + dx, worldY + dy)
  end else
    if CbtMap.ViewCoordsValid(x, y) then
      CbtMap.DrawTerrainCell(x, y, worldX, worldY)
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(p: Pointer; mode: Byte): Boolean;
var
  direction: Byte;
  actorIndex: Byte;
  dx: ShortInt;
  dy: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  visibleTiles: array[1..2] of Byte;
begin
  CombatIconVisible := True;
  actorIndex := CbtMap.CombatSlot(p);
  if GDVars.actor[actorIndex].size = 0 then
    CombatIconVisible := False
  else begin
    for direction := 0 to 5 do begin
      if CbtMap.FootprintCell(GDVars.actor[actorIndex].size, direction, dx, dy) then
        if not CbtMap.ViewCoordsValid(GDVars.work.relX[actorIndex] + dx,
                                      GDVars.work.relY[actorIndex] + dy) then begin
          CombatIconVisible := False;
          if mode <> 0 then Exit
        end else begin
          CombatIconVisible := True;
          if mode = 0 then Exit
        end
    end
  end
end;

{ Recenters the 7x7 view on a target cell when it lies farther from the view center than allowed, keeping the view
  inside the arena, then draws the view's terrain and recomputes the creatures' view coordinates.
  @param(x Arena column of the target.)
  @param(y Arena row of the target.)
  @param(radius How far the target may lie from the view center; 255 forces a redraw.)
  @returns(True when the view was redrawn.) }
function BuildViewBuffer(x, y: ShortInt; radius: Byte): Boolean;
var
  useRadius: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixX: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixY: Byte;
  col: Byte;
  row: Byte;
  centerX: ShortInt;
  centerY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bufferIndex: Byte;
begin
  BuildViewBuffer := False;
  centerX := GDVars.combatMap^.originX + 3;
  centerY := GDVars.combatMap^.originY + 3;
  useRadius := radius;
  if radius = 255 then useRadius := 0;
  minX := centerX - useRadius;
  maxX := centerX + useRadius;
  minY := centerY - useRadius;
  maxY := centerY + useRadius;
  if (radius <> 255) and (x >= minX) and (x <= maxX) and (y >= minY) and (y <= maxY) then
    Exit;
  if x < minX then
    while (x < centerX) and (centerX > 3) do Dec(centerX)
  else if x > maxX then
    while (x > centerX) and (centerX < 46) do Inc(centerX);
  if y < minY then
    while (y < centerY) and (centerY > 3) do Dec(centerY)
  else if y > maxY then
    while (y > centerY) and (centerY < 21) do Inc(centerY);
  GDVars.combatMap^.originX := centerX - 3;
  GDVars.combatMap^.originY := centerY - 3;
  centerY := GDVars.combatMap^.originY;
  for row := 0 to 6 do begin
    centerX := GDVars.combatMap^.originX;
    for col := 0 to 6 do begin
      CbtMap.DrawTerrainCell(col, row, centerX, centerY);
      Inc(centerX)
    end;
    Inc(centerY)
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True
end;

procedure ScrollView(x, y: ShortInt; radius, direction: Byte);
var
  actorPtr: Types.PCharacter;
  actorIndex: Byte;
  worldX: ShortInt;
  worldY: ShortInt;
begin
  worldX := x + GDConsts.dirDx[direction];
  worldY := y + GDConsts.dirDy[direction];
  if CbtMap.BuildViewBuffer(worldX, worldY, radius) then begin
    for actorIndex := 1 to GDVars.actorCount do begin
      actorPtr := GDVars.creatureArr[actorIndex];
      if (actorPtr^.inPlay <> 0) and (GDVars.actor[actorIndex].size > 0) and
          CbtMap.CombatIconVisible(actorPtr, 0) then
        MapTiles.DrawIconAnimSprite(GDVars.work.relX[actorIndex], GDVars.work.relY[actorIndex],
                                    actorPtr^.combatAddr^.direction, 0, actorPtr^.icon)
    end
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(worldX - GDVars.combatMap^.originX, worldY - GDVars.combatMap^.originY) then begin
    if worldX > 49 then worldX := 49;
    if worldX < 0 then worldX := 0;
    if worldY > 24 then worldY := 24;
    if worldY < 0 then worldY := 0
  end;
  CbtMap.DrawCursorCell(worldX, worldY);
  Blit.FlushView
end;

procedure SetCreatureFacing(p: Pointer; mode, sub, flag: Byte);
var
  actorIndex: Byte;
begin
  actorIndex := CbtMap.CombatSlot(p);
  if not CbtMap.CombatIconVisible(p, 1) then
    if GDVars.combatGfxOn <> 0 then
      CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 3, C_Dir.CENTER);
  if ((Types.PCharacter(p)^.combatAddr^.direction div 4) <> (mode div 4)) or (sub <> 0) or (flag <> 0) then
    if GDVars.combatGfxOn <> 0 then
      CbtMap.UpdateCombatMapTile(0, 0, actorIndex);
  Types.PCharacter(p)^.combatAddr^.direction := mode;
  if flag = 0 then
    if CbtMap.CombatIconVisible(p, 0) then
      if GDVars.combatGfxOn <> 0 then begin
        MapTiles.DrawIconAnimSprite(GDVars.work.relX[actorIndex], GDVars.work.relY[actorIndex], mode, sub,
                                    Types.PCharacter(p)^.icon);
        Blit.FlushView
      end
end;

function CombatCellX(p: Pointer): ShortInt;
begin
  CombatCellX := GDVars.actor[CbtMap.CombatSlot(p)].x;
end;

function CombatCellY(p: Pointer): ShortInt;
begin
  CombatCellY := GDVars.actor[CbtMap.CombatSlot(p)].y;
end;

function GetIconSize(p: Pointer): Byte;
begin
  GetIconSize := GDVars.actor[CbtMap.CombatSlot(p)].size;
end;

function CombatSlot(p: Pointer): Byte;
var
  found: Boolean;
  i: Byte;
begin
  found := False;
  CombatSlot := 0;
  i := 0;
  repeat
    Inc(i);
    if GDVars.creatureArr[i] = p then found := True;
  until found or (i = GDVars.actorCount);
  if found then CombatSlot := i;
end;

procedure ProbeDirection(p: Pointer; direction: Byte; var occupant, bestTile, terrainId);
var
  adjacent: Byte;
  actorIndex: Byte;
  cellActor: Byte;
  cellTerrain: Byte;
  bestPriority: Byte;
  worldX: ShortInt;
  worldY: ShortInt;
  actorX: ShortInt;
  actorY: ShortInt;
  dx: ShortInt;
  dy: ShortInt;
begin
  ShortInt(occupant) := 0;
  ShortInt(bestTile) := CbtMap.DEFAULT_PROBE_TERRAIN;
  bestPriority := 1;
  ShortInt(terrainId) := 0;
  actorIndex := CbtMap.CombatSlot(p);
  actorX := GDVars.actor[actorIndex].x;
  actorY := GDVars.actor[actorIndex].y;
  for adjacent := 0 to 5 do
    if CbtMap.FootprintCell(GDVars.actor[actorIndex].size, adjacent, dx, dy) then begin
      worldX := actorX + dx + GDConsts.dirDx[direction];
      worldY := actorY + dy + GDConsts.dirDy[direction];
      CbtMap.GetArenaContents(worldX, worldY, cellActor, cellTerrain);
      if Byte(cellActor) = actorIndex then cellActor := 0;
      if Byte(cellActor) > 0 then ShortInt(occupant) := cellActor;
      if cellTerrain in
          [CbtMap.SPECIAL_TERRAIN_FIRST..CbtMap.PATCH_TERRAIN_LAST] then ShortInt(terrainId) := cellTerrain;
      if (cellTerrain = 0) or (ShortInt(bestTile) = 0) then
        ShortInt(bestTile) := 0
      else if GDConsts.terrain[Byte(cellTerrain)].cost >= bestPriority then begin
        bestPriority := GDConsts.terrain[Byte(cellTerrain)].cost;
        ShortInt(bestTile) := cellTerrain
      end
    end
end;

procedure CreatureDowned(p: Pointer);
var
  actorIndex: Byte;
  entry: Byte;
  frame: Byte;
  dx: ShortInt;
  dy: ShortInt;
  actorX: ShortInt;
  actorY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bodyCell: array[0..1] of Byte;
begin
  if GDVars.locState.current <> C_Ifc.IN_COMBAT then begin
    Music.SendSoundCommand(GDConsts.soundIds[3]);
    TextRend.PauseOnly;
    Exit
  end;
  entry := 1;
  while (entry < 9) and (GDVars.downed[entry].cr <> p) do
    Inc(entry);
  if entry < 9 then Exit;
  actorIndex := CbtMap.CombatSlot(p);
  actorX := CbtMap.CombatCellX(p);
  actorY := CbtMap.CombatCellY(p);
  if not CbtMap.CombatIconVisible(p, 1) then
    CbtMap.ScrollView(actorX, actorY, 3, C_Dir.CENTER);
  CbtMap.UpdateCombatMapTile(0, 0, actorIndex);
  Music.SendSoundCommand(GDConsts.soundIds[3]);
  for frame := 0 to 8 do begin
    for entry := 0 to 5 do
      if CbtMap.FootprintCell(GDVars.actor[actorIndex].size, entry, dx, dy) then
        if CbtMap.ViewCoordsValid(GDVars.work.relX[actorIndex] + dx, GDVars.work.relY[actorIndex] + dy) then
          Blit.BlitTileClipped((GDVars.work.relX[actorIndex] + dx) * 3, (GDVars.work.relY[actorIndex] + dy) * 3,
                               0, 5, GDVars.iconSet[CbtMap.CORPSE_ANIMATION_INDEX, frame mod 2],
                               GDVars.viewSurface);
    Blit.FlushView;
    Delay(10)
  end;
  if (Types.PCharacter(p)^.combatAddr^.notPcNpc = 0) and (Types.PCharacter(p)^.status <> C_Status.GONE) then begin
    frame := CbtMap.ResolveTerrain(actorX, actorY);
    Inc(GDVars.downedCount);
    GDVars.downed[GDVars.downedCount].terrain := frame;
    if not (GDVars.combatMap^.cells[actorY, actorX] in [C_Terr.TERRAIN_CLOUDKILL, C_Terr.TERRAIN_STINK_CLOUD]) then
      if Types.PCharacter(p)^.status = C_Status.PETRIFIED then
        GDVars.combatMap^.cells[actorY, actorX] := CbtMap.TERRAIN_STATUE
      else
        GDVars.combatMap^.cells[actorY, actorX] := C_Terr.TERRAIN_CORPSE;
    GDVars.downed[GDVars.downedCount].cr := p;
    GDVars.downed[GDVars.downedCount].x := actorX;
    GDVars.downed[GDVars.downedCount].y := actorY
  end;
  TextRend.PauseOnly;
  CbtMap.UpdateCombatMapTile(0, 0, actorIndex);
  GDVars.actor[CbtMap.CombatSlot(p)].size := 0;
  CbtMap.BuildArenaArrays;
  CbtMap.ScrollView(GDVars.combatMap^.originX + 3, GDVars.combatMap^.originY + 3, 3, C_Dir.CENTER);
  Types.PCharacter(p)^.combatAddr^.initiative := 0;
  Types.PCharacter(p)^.combatAddr^.movement := 0;
  Types.PCharacter(p)^.combatAddr^.guarding := 0
end;

function IsValidCreatureLoc(p: Pointer; x, y: Byte; clearEvent: Boolean): Boolean;
var
  actorIndex: Byte;
  entry: Byte;
  occupant: ShortInt;
  bestTile: ShortInt;
  occupied: Boolean;
  terrainId: ShortInt;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    actorIndex := CbtMap.CombatSlot(p);
    GDVars.actor[actorIndex].size := Types.PCharacter(p)^.iconDimensions and CbtMap.FOOTPRINT_SIZE_MASK;
    GDVars.actor[actorIndex].x := x;
    GDVars.actor[actorIndex].y := y;
    CbtMap.ProbeDirection(p, C_Dir.CENTER, occupant, bestTile, terrainId);
    if (occupant <> 0) or (bestTile = 0) or (GDConsts.terrain[Byte(bestTile)].cost = C_Terr.TERRAIN_IMPASSABLE) then
      GDVars.actor[actorIndex].size := 0
    else begin
      IsValidCreatureLoc := True;
      if clearEvent and (Types.PCharacter(p)^.combatAddr^.notPcNpc = 0) then begin
        for entry := 1 to GDVars.downedCount do
          if GDVars.downed[entry].cr = p then begin
            if GDVars.downed[entry].terrain <> C_Terr.TERRAIN_CORPSE then
              bestTile := GDVars.downed[entry].terrain;
            GameIo.ZeroFill(GDVars.downed[entry], SizeOf(GDVars.downed[entry]))
          end;
        occupied := False;
        for entry := 1 to GDVars.downedCount do
          if (GDVars.downed[entry].cr <> nil) and (GDVars.downed[entry].x = x) and
              (GDVars.downed[entry].y = y) then
            occupied := True;
        if not occupied then GDVars.combatMap^.cells[y, x] := bestTile
      end;
      CbtMap.BuildArenaArrays
    end
  end else
    IsValidCreatureLoc := True
end;

procedure DisplayMapViewCentered(p: Pointer; radius, mode: Byte);
begin
  GDVars.combatMap^.cursorOn := Boolean(mode);
  GDVars.combatMap^.cursorSize := GDVars.actor[CbtMap.CombatSlot(p)].size;
  if GDVars.combatGfxOn <> 0 then
    CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), radius, C_Dir.CENTER);
  GDVars.combatMap^.cursorOn := False;
  GDVars.combatMap^.cursorSize := 1
end;

function ResolveTerrain(x, y: ShortInt): Byte;
var
  tile: Byte;
  entry: Byte;
  { Unused in this version; see the other implementations of this routine. }
  entryTail: Byte;
  node: Types.PCloudNode;
begin
  tile := GDVars.combatMap^.cells[y, x];
  if tile in [C_Terr.TERRAIN_BLADE_BARRIER..C_Terr.TERRAIN_STINK_CLOUD] then begin
    node := GDVars.cloudHead;
    while node <> nil do begin
      for entry := 1 to 9 do
        if node^.live[entry] <> 0 then
          if (node^.x + GDConsts.dirDx[GDConsts.patchDirections[entry]] = x) and (node^.y +
              GDConsts.dirDy[GDConsts.patchDirections[entry]] = y) then
            tile := node^.savedTerrain[entry];
      node := node^.next
    end
  end else if tile = C_Terr.TERRAIN_CORPSE then
    for entry := 1 to GDVars.downedCount do
      if (GDVars.downed[entry].x = ShortInt(x)) and (GDVars.downed[entry].y = ShortInt(y)) then
        tile := GDVars.downed[entry].terrain;
  ResolveTerrain := tile
end;

function DirectionBetween(x2, y2, x1, y1: Integer): Byte;
var
  direction: Byte;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  doneTail: Byte;
  deltaX: Integer;
  deltaY: Integer;
begin
  deltaX := Abs(x1 - x2);
  deltaY := Abs(y1 - y2);
  direction := C_Dir.NORTH;
  done := False;
  while not done do begin
    case direction of
    C_Dir.NORTHEAST: done := (y1 < y2) and (x1 > x2) and ((618 * deltaX) div 256 >= deltaY) and
      ((106 * deltaX) div 256 <= deltaY);
    C_Dir.SOUTHEAST: done := (y1 > y2) and (x1 > x2) and ((618 * deltaX) div 256 >= deltaY) and
      ((106 * deltaX) div 256 <= deltaY);
    C_Dir.SOUTHWEST: done := (y1 > y2) and (x1 < x2) and ((618 * deltaX) div 256 >= deltaY) and
      ((106 * deltaX) div 256 <= deltaY);
    C_Dir.NORTHWEST: done := (y1 < y2) and (x1 < x2) and ((618 * deltaX) div 256 >= deltaY) and
      ((106 * deltaX) div 256 <= deltaY);
    C_Dir.NORTH: done := (y1 <= y2) and ((618 * deltaX) div 256 <= deltaY);
    C_Dir.EAST: done := (x1 >= x2) and ((106 * deltaX) div 256 >= deltaY);
    C_Dir.SOUTH: done := (y1 >= y2) and ((618 * deltaX) div 256 <= deltaY);
    C_Dir.WEST: done := (x1 <= x2) and ((106 * deltaX) div 256 >= deltaY)
    end;
    if not done then Inc(direction)
  end;
  DirectionBetween := direction
end;

function DirectionToward(src, dst: Pointer): Byte;
begin
  DirectionToward := CbtMap.DirectionBetween(CbtMap.CombatCellX(src), CbtMap.CombatCellY(src), CbtMap.CombatCellX(dst),
                                             CbtMap.CombatCellY(dst))
end;

begin
end.
