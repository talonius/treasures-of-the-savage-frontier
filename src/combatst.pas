{ CombatSt -- combat setup: build the combat arena (the dungeon arena from the walls around the party, or the wilderness
  arena with its river, trees and features), place the creatures by the quadrant-spiral search, and enter combat
  (CombatStart). JoinBattle places a creature that joins mid-battle. }
{$O+,F+,S+,R-,V-,B-,I-}
unit CombatSt;

interface

{ Set up the arena and its creatures, announce the battle and switch the interface state to combat. }
procedure CombatStart;

{ Bring a late creature into the battle: place it by its side's battle position and distance, face it, put it in play
  and announce 'joins the battle'; if there is no room it stays off the map.
  @param(p The creature, a Types.PCharacter.) }
procedure JoinBattle(p: Pointer);

implementation

uses Types, Romance, CharGen, CbtActs, CharHlp, MenuCore, FxEngine, Portrait, View3D, CbtMap, MapTiles, Border, Blit,
  TextRend, GameIo, Crt, GDConsts, GDVars, C_Terr, C_Dir, C_Status,
  C_Cond, C_Ifc, C_Npc;

{ Sets one arena cell in the current dungeon cell's skewed six-by-five block, ignoring cells off the 50x25 arena.
  @param(i Column within the block.)
  @param(j Row within the block.)
  @param(t The terrain, stored plus 1.) }
procedure PlotCell(i, j, t: Byte);
var
  x: ShortInt;
  y: ShortInt;
begin
  x := GDVars.dx * 6 + GDVars.dy * 5 + 21 + i;
  y := GDVars.dy * 5 + 10 + j;
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then
    GDVars.combatMap^.cells[y, x] := t + 1;
end;

{ Classifies the edge between a map cell and its neighbor in a direction, from both sides. Off the map it is open on the
  party's row going east or west, otherwise blocked.
  @param(x Map column.)
  @param(y Map row.)
  @param(dir Direction of the neighbor.)
  @returns(0 open, 1 blocked, 3 a wall that can be passed; the two sides' bits combined.) }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  nearKind: Byte;
  farKind: Byte;
  opp: Byte;

  { The wall kind on one side of a square; off the map, east and west on the party's row read open, else solid. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.partyPos.y) and ((pdir = C_Dir.EAST) or (pdir = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  nearKind := GetWallKind(x, y, dir);
  farKind := GetWallKind(x + GDConsts.dirDx[dir], y + GDConsts.dirDy[dir], opp);
  WallBetween := nearKind or farKind;
end;

{ Draw the dungeon arena: for each square in the 13 by 5 window around the party, find its walls and draw its floor,
  west and north walls, and both northern corners. }
procedure BuildDungeonArena;
var
  cellX: ShortInt;
  cellY: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  cellColumn: Byte;

  { Draws the cell's three floor rows and its west wall or door. }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        CombatSt.PlotCell(c, r, 22);
    if GDVars.wallW = 1 then begin
      for r := 2 to 4 do begin
        CombatSt.PlotCell(r - 1, r, 4);
        CombatSt.PlotCell(r, r, 3);
        CombatSt.PlotCell(r + 1, r, 13);
      end;
    end else if GDVars.wallW = 3 then begin
      CombatSt.PlotCell(1, 2, 8);
      CombatSt.PlotCell(5, 4, 0);
    end;
  end;

  { Draws the current cell's north wall band (spots 3..4 on rows 0..1): wall terrain when solid, floor otherwise. }
  procedure DrawNorthWall;
  var
    { Unused in this version; see the other implementations of this routine. }
    column: Integer;
  begin
    if GDVars.wallN = 1 then begin
      CombatSt.PlotCell(3, 0, 5);
      CombatSt.PlotCell(4, 0, 5);
      CombatSt.PlotCell(3, 1, 10);
      CombatSt.PlotCell(4, 1, 10);
    end else begin
      CombatSt.PlotCell(3, 0, 22);
      CombatSt.PlotCell(4, 0, 22);
      CombatSt.PlotCell(3, 1, 22);
      CombatSt.PlotCell(4, 1, 22);
    end;
  end;

  { Fills the cell's northwest corner from its north and west walls and whether the edges beyond the corner are open. }
  procedure FillCornerNorthWest;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = 0) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = 0) then
      open := 1
    else
      open := 0;
    topLeftTile := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.wallN of
             0: case GDVars.wallW of
                  0: topLeftTile := 22;
                  3, 1: if open <> 0 then topLeftTile := 0 else topLeftTile := 13;
                end;
             3, 1: if GDVars.wallW = 0 then begin
                     if open <> 0 then topLeftTile := 15 else topLeftTile := 5;
                   end else begin
                     if open <> 0 then topLeftTile := 18 else topLeftTile := 2;
                   end;
           end;
        2: case GDVars.wallN of
             0: topRightTile := 22;
             3: topRightTile := 17;
             1: topRightTile := 5;
           end;
        3: case GDVars.wallW of
             0: if GDVars.wallN = 0 then
                  bottomLeftTile := 22
                else if open <> 0 then
                  bottomLeftTile := 16
                else
                  bottomLeftTile := 10;
             3: if open <> 0 then bottomLeftTile := 20 else bottomLeftTile := 7;
             1: if open <> 0 then bottomLeftTile := 1 else bottomLeftTile := 3;
           end;
        4: case GDVars.wallW of
             0, 3: case GDVars.wallN of
                     0: bottomRightTile := 22;
                     3: bottomRightTile := 23;
                     1: bottomRightTile := 10;
                   end;
             1: case GDVars.wallN of
                  0: bottomRightTile := 13;
                  3: bottomRightTile := 21;
                  1: bottomRightTile := 6;
                end;
           end;
      end;
    CombatSt.PlotCell(1, 0, topLeftTile);
    CombatSt.PlotCell(2, 0, topRightTile);
    CombatSt.PlotCell(1, 1, bottomLeftTile);
    CombatSt.PlotCell(2, 1, bottomRightTile);
  end;

  { Fills the cell's northeast corner, which spills one spot into the next cell's block. }
  procedure FillCornerNorthEast;
  var
    k: Byte;
    topLeftTile: Byte;
    bottomLeftTile: Byte;
    topRightTile: Byte;
    bottomRightTile: Byte;
    open: Byte;
    kN: Byte;
    kE: Byte;
    { Unused in this version; see the other implementations of this routine. }
    cornerTile: array[0..1] of Byte;
  begin
    kN := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    kE := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (kN = 0) and (kE = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case GDVars.wallN of
             0: if kN = 1 then topLeftTile := 4 else topLeftTile := 22;
             3: topLeftTile := 15;
             1: topLeftTile := 5;
           end;
        2: if GDVars.wallN = 0 then begin
             case kN of
               0: topRightTile := 22;
               3: if (GDVars.wallE = 0) and (kE <> 0) then
                    topRightTile := 24
                  else if GDVars.wallE = 0 then
                    topRightTile := 7
                  else
                    topRightTile := 1;
               1: if GDVars.wallE = 0 then begin
                    if kE <> 0 then topRightTile := 11 else topRightTile := 7;
                  end else
                    topRightTile := 3;
             end;
           end else begin
             if GDVars.wallE <> 0 then
               topRightTile := 9
             else if kE <> 0 then
               topRightTile := 5
             else if open <> 0 then
               topRightTile := 17
             else
               topRightTile := 19;
           end;
        3: case GDVars.wallN of
             0: bottomLeftTile := 22;
             3: bottomLeftTile := 16;
             1: bottomLeftTile := 10;
           end;
        4: if GDVars.wallN = 0 then begin
             if kN = 0 then
               bottomRightTile := 22
             else if GDVars.wallE <> 0 then
               bottomRightTile := 4
             else if kE = 0 then
               bottomRightTile := 8
             else
               bottomRightTile := 12;
           end else begin
             if GDVars.wallE <> 0 then
               bottomRightTile := 14
             else if kE = 0 then
               bottomRightTile := 23
             else
               bottomRightTile := 10;
           end;
      end;
    CombatSt.PlotCell(5, 0, topLeftTile);
    CombatSt.PlotCell(6, 0, topRightTile);
    CombatSt.PlotCell(5, 1, bottomLeftTile);
    CombatSt.PlotCell(6, 1, bottomRightTile);
  end;

begin
  FillChar(GDVars.combatMap^.cells, SizeOf(GDVars.combatMap^.cells), 22);
  for GDVars.dy := -2 to 2 do
    for GDVars.dx := -6 to 6 do begin
      cellX := GDVars.partyPos.x + GDVars.dx;
      cellY := GDVars.partyPos.y + GDVars.dy;
      GDVars.wallW := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      GDVars.wallN := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      GDVars.wallE := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      { never read }
      GDVars.wallS := CombatSt.WallBetween(cellX, cellY, C_Dir.SOUTH);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNorthWest;
      FillCornerNorthEast;
    end;
end;

{ Looks up the class bits of the current terrain type, which steer the wilderness arena generators.
  @returns(The class bits.) }
function TerrainClassOf: Byte;
begin
  TerrainClassOf := GDConsts.terrainClassTbl[GDVars.terrainChar];
end;

{ Lays a diagonal band of river tiles down the arena when the area calls for a river, crossed by fords at random rows;
  the chance of a ford grows with each row that has none. }
procedure PlaceRiver;
var
  fordVal: Byte;
  { Unused in this version; see the other implementations of this routine. }
  startCol: ShortInt;
  col: ShortInt;
  row: ShortInt;

  { Draw a ford across the river at (col, row) and reset the ford chance. }
  procedure PlotFord(col, row: ShortInt);
  begin
    GDVars.combatMap^.cells[row, col] := 58;
    if col < 49 then begin
      GDVars.combatMap^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 58;
      if col + 1 < 49 then
        GDVars.combatMap^.cells[row, col + 2] := FxEngine.RollDice(1, 2) + 58;
      if col + 2 < 49 then
        GDVars.combatMap^.cells[row, col + 3] := 61;
    end;
    fordVal := 1;
  end;

begin
  if GDVars.gameState^.arenaRiver <> 0 then begin
    col := 34 - FxEngine.RollDice(5, 4);
    while (col + 2) mod 7 > 0 do
      Dec(col);
    startCol := col;
    fordVal := 1;
    for row := 0 to 24 do begin
      if col <= 49 then begin
        GDVars.combatMap^.cells[row, col] := 52;
        if col < 49 then begin
          if FxEngine.RollDice(1, 20) <= fordVal then
            PlotFord(col + 1, row)
          else begin
            Inc(fordVal);
            GDVars.combatMap^.cells[row, col + 1] := FxEngine.RollDice(1, 2) + 52;
            if col + 1 < 49 then
              GDVars.combatMap^.cells[row, col + 2] := 55;
            if col + 2 < 49 then
              GDVars.combatMap^.cells[row, col + 3] := 55;
            if col + 3 < 49 then
              GDVars.combatMap^.cells[row, col + 4] := FxEngine.RollDice(1, 2) + 55;
          end;
        end;
        if col + 4 < 49 then
          GDVars.combatMap^.cells[row, col + 5] := 52;
        Inc(col);
      end;
    end;
  end;
end;

{ Unless the terrain class has bit 7 set, replaces some vertical pairs of open-ground cells (tile 37) with features, at
  a chance the class raises or lowers. }
procedure PlaceTrees;
var
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  col: ShortInt;
  row: ShortInt;
  dens: ShortInt;
begin
  if CombatSt.TerrainClassOf and $80 <> 0 then Exit;
  dens := 5;
  if CombatSt.TerrainClassOf and 2 <> 0 then Dec(dens, 3);
  if CombatSt.TerrainClassOf and 4 <> 0 then Dec(dens, 3);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(dens, 2);
  if CombatSt.TerrainClassOf and 8 <> 0 then Inc(dens, 5);
  if dens < 0 then dens := 1;
  for col := 0 to 49 do
    for row := 1 to 24 do
      if GDConsts.terrain[GDVars.combatMap^.cells[row, col]].code = 37 then
        if GDConsts.terrain[GDVars.combatMap^.cells[row - 1, col]].code = 37 then
          if FxEngine.RollDice(1, 100) <= dens then begin
            if FxEngine.RollDice(1, 100) <= dens then
              GDVars.combatMap^.cells[row, col] := FxEngine.RollDice(1, 2) + 41
            else begin
              GDVars.combatMap^.cells[row - 1, col] := FxEngine.RollDice(1, 5) + 31;
              GDVars.combatMap^.cells[row, col] := FxEngine.RollDice(1, 5) + 36;
            end;
          end;
end;

{ Scatters decorative terrain over open ground, the mix chosen by terrain class: five feature kinds by percentage
  chances. Note: the third kind's band is always 1 percent wide, and its chance widens the fourth kind's band instead. }
procedure ScatterFeatures;
var
  col: ShortInt;
  row: ShortInt;
  accum: Integer;

  { Maybe places one of five feature kinds at a cell, by percentage chances; the third band is always 1% wide. }
  procedure ScatterOneCell(col, row: ShortInt; firstChance, secondChance, thirdChance, fourthChance, fifthChance: Byte);
  var
    r: Byte;
  begin
    r := FxEngine.RollDice(1, 100);
    if r <= firstChance then
      GDVars.combatMap^.cells[row, col] := FxEngine.RollDice(1, 2) + 49
    else if r <= firstChance + secondChance then
      GDVars.combatMap^.cells[row, col] := 44
    else if r <= firstChance + secondChance + 1 then
      GDVars.combatMap^.cells[row, col] := FxEngine.RollDice(1, 5) + 44
    else if r <= firstChance + secondChance + thirdChance + fourthChance then
      GDVars.combatMap^.cells[row, col] := 68
    else if r <= firstChance + secondChance + thirdChance + fourthChance + fifthChance then
      GDVars.combatMap^.cells[row, col] := FxEngine.RollDice(1, 6) + 61;
  end;

begin
  accum := 50;
  if CombatSt.TerrainClassOf and $10 <> 0 then Inc(accum, 10);
  if CombatSt.TerrainClassOf and $20 <> 0 then Inc(accum, 30);
  if CombatSt.TerrainClassOf and $40 <> 0 then Inc(accum, 20);
  if CombatSt.TerrainClassOf and 4 <> 0 then Dec(accum, 10);
  if CombatSt.TerrainClassOf and 2 <> 0 then Dec(accum, 20);
  if CombatSt.TerrainClassOf and $80 <> 0 then Dec(accum, 50);
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrain[GDVars.combatMap^.cells[row, col]].code = 37 then
        case accum of
          -30..9: ScatterOneCell(col, row, 0, 0, 0, 30, 15);
          10..29: ScatterOneCell(col, row, 0, 1, 5, 20, 10);
          30..69: ScatterOneCell(col, row, 0, 2, 5, 10, 5);
          70..89: ScatterOneCell(col, row, 10, 2, 10, 10, 1);
          90..110: ScatterOneCell(col, row, 15, 5, 15, 10, 1);
        end;
end;

{ The wilderness arena: river, trees and features, with terrainChar 15. }
procedure BuildWildernessArena;
var
  { Unused in this version; see the other implementations of this routine. }
  mapIndex: array[0..1] of Byte;
begin
  FillChar(GDVars.combatMap^.cells, SizeOf(GDVars.combatMap^.cells), 69);
  GDVars.terrainChar := 15;
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
end;

{ Load the combat tile set (DUNGCOM.DAX or WILDCOM.DAX), then allocate and build the arena. }
procedure LoadCombatTileSet;
var
  { Unused in this version; see the other implementations of this routine. }
  slot: array[0..1] of Byte;
begin
  if (GDVars.gameState^.location <> 0) and (GDVars.gameState^.overMap = 0) then begin
    if GDVars.gameState^.combatWallSet = 0 then
      MapTiles.Load24x24Set('DungCom', Lo(GDVars.wallSetCache[1].wallDefId), 0, 25)
    else
      MapTiles.Load24x24Set('DungCom', GDVars.gameState^.combatWallSet, 0, $19)
  end else
    MapTiles.Load24x24Set('WildCom', 0, 0, 39);
  GetMem(GDVars.combatMap, SizeOf(Types.TCombatMap));
  if GDVars.combatMap = nil then
    GDVars.fatalMessageHook('out of memory');
  GDVars.combatMap^.cursorOn := False;
  GDVars.combatMap^.cursorSize := 1;
  GDVars.combatMap^.noHeight := 0;
  if (GDVars.gameState^.location <> 0) and (GDVars.gameState^.overMap = 0) then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Give every roster creature a zeroed combat record and its facing. }
procedure InitCreatureCombatData;
var
  p: Types.PCharacter;
  count: Byte;
  m: Byte;
begin
  p := GDVars.partyHead;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    if p^.combatAddr = nil then
      GDVars.fatalMessageHook('out of memory');
    GameIo.ZeroFill(p^.combatAddr^, SizeOf(Types.TCombatRec));
    if count > GDVars.gameState^.partySize then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadDir[GDVars.partyPos.facing div 2];
    if p^.side = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    m := p^.npc and C_Npc.MORALE_MASK;
    if (p^.side = 0) and (p^.combatAddr^.notPcNpc = 1) and ((m = 0) or (m > 102)) then
      p^.npc := GDVars.gameState^.partySize + C_Npc.NON_PLAYER;
    p^.combatAddr^.initialized := 1;
    p := p^.next;
  end;
end;

{ Tells whether a placement square lies off the 11x6 grid on both axes.
  @param(qx The square's column.)
  @param(qy The square's row.)
  @returns(True when both coordinates are off the grid.) }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Tries to put a creature on a placement square of its team's grid for one ring. The square must be on the grid and
  free; its arena cell, from the same skewed mapping as the dungeon builder, is stored before the probe, and the cell
  must hold no creature and passable terrain.
  @param(slot The creature's combat slot.)
  @param(qx The square's column.)
  @param(qy The square's row.)
  @param(bqx The grid's base column.)
  @param(bqy The grid's base row.)
  @param(ring The placement ring, 0 to 3.)
  @returns(1 when the creature was placed, which takes the square; 0 otherwise.) }
function TryPlaceAt(slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  { never read }
  adjSpecial: ShortInt;
  crIdx: ShortInt;
  terrIdx: ShortInt;
begin
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (GDVars.quadFree[GDVars.team, ring, qy, qx] = 0) then
    TryPlaceAt := 0
  else begin
    GDVars.actor[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.actor[slot].y := qy + bqy * 5 + 10;
    CbtMap.ProbeDirection(GDVars.creatureArr[slot], C_Dir.CENTER, crIdx, terrIdx, adjSpecial);
    if (Byte(crIdx) = 0) and (Byte(terrIdx) > 0) and
        (GDConsts.terrain[Byte(terrIdx)].cost < C_Terr.TERRAIN_IMPASSABLE) then begin
      TryPlaceAt := 1;
      GDVars.quadFree[GDVars.team, ring, qy, qx] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Walk the quad spiral out from (baseX, baseY) until TryPlaceAt succeeds or every ring is spent.
  @param(slot The combat slot.)
  @param(baseX The base's column.)
  @param(baseY The base's row.)
  @param(placementDir The facing that picks each ring's starting quadrant.)
  @returns(True when a spot was found.) }
function FindPlacement(slot: Byte; baseX, baseY, placementDir: ShortInt): Boolean;
var
  placed: Byte;
  firstPass: Byte;
  giveUp: Byte;
  offGrid: Byte;
  open: Byte;
  state: Byte;
  dir: Byte;
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  baseQX: ShortInt;
  baseQY: ShortInt;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQX := baseX;
  baseQY := baseY;
  repeat
    quad := GDConsts.ringStart[placementDir, ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 2) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 2) mod 4]];
           legX := GDConsts.startQX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.startQY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 1) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirDx[GDConsts.quadDir[(quad + 3) mod 4]];
           stepY := GDConsts.dirDy[GDConsts.quadDir[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= GDVars.teamRows[GDVars.team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (GDVars.team = 0) and Odd(placementDir) and (ring = 0) and (legShift = 1) then begin
          wallX := baseX + GDVars.partyPos.x;
          wallY := baseY + GDVars.partyPos.y;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.ringDirTbl[placementDir, k];
            if (GDVars.locState.current = C_Ifc.AREA_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then
            Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
      placed := 0;
      state := 0;
      while (ring < 3) and (state <> 1) do begin
        Inc(ring);
        wallX := baseX + GDVars.partyPos.x;
        wallY := baseY + GDVars.partyPos.y;
        dir := GDConsts.ringDirTbl[placementDir, ring];
        if (GDVars.locState.current = C_Ifc.AREA_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
          baseQX := baseX + GDConsts.dirDx[dir];
          baseQY := baseY + GDConsts.dirDy[dir];
          legShift := 0;
          state := 1;
        end;
      end;
      if state <> 1 then
        giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(slot, qx, qy, baseQX, baseQY, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Place the roster creatures on the arena; a notPcNpc creature that does not fit is removed. }
procedure PlaceAllCreatures;
var
  prev: Types.PCharacter;
  p: Types.PCharacter;
  slot: Byte;
  d: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
  savedFacing: Byte;
  lastFacingCache: Byte;
  rotIdx: Byte;
  x: ShortInt;
  y: ShortInt;
  dirTmp: Byte;
  rotCount: Byte;
  placedResult: Boolean;

  { Sets both teams' bases, facings and free placement cells for the current facing, unless already set for it. }
  procedure PrepareCombatOccupancy;
  var
    g: Byte;
    x: ShortInt;
    y: ShortInt;
    dist: Byte;
    { Unused in this version; see the other implementations of this routine. }
    plane: array[0..1] of Byte;
  begin
    if (GDVars.gameState^.placementDist = 0) and (GDVars.partyPos.facing <> savedFacing) then
      dist := 1
    else
      dist := GDVars.gameState^.placementDist;
    if GDVars.partyPos.facing = lastFacingCache then Exit;
    lastFacingCache := GDVars.partyPos.facing;
    GDVars.teamDir[0] := GDVars.partyPos.facing div 2;
    GDVars.placeX[1] := GDConsts.dirDx[GDVars.partyPos.facing] * dist + GDVars.placeX[0];
    GDVars.placeY[1] := GDConsts.dirDy[GDVars.partyPos.facing] * dist + GDVars.placeY[0];
    GDVars.teamDir[1] := (GDVars.partyPos.facing + 4) mod 8 div 2;
    for GDVars.team := 0 to 1 do
      for g := 0 to 3 do begin
        if g = 1 then d := 4 else d := GDVars.teamDir[GDVars.team];
        for y := 0 to 5 do
          for x := 0 to 10 do
            if (GDConsts.rowBand[d, y].lo > x) or (GDConsts.rowBand[d, y].hi < x) then
              GDVars.quadFree[GDVars.team, g, y, x] := 0
            else
              GDVars.quadFree[GDVars.team, g, y, x] := 1;
      end;
  end;

begin
  savedFacing := GDVars.partyPos.facing;
  lastFacingCache := $FF;
  rotIdx := 0;
  CharHlp.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  for slot := 1 to 72 do
    GDVars.actor[slot].size := 0;
  FillChar(GDVars.actorGrid, SizeOf(GDVars.actorGrid), 0);
  GDVars.placeX[0] := 0;
  GDVars.placeY[0] := 0;
  GDVars.teamRows[0] := (GDVars.sideTally[0] + 1) div 2;
  rotCount := 0;
  if GDVars.hostileFacingMask and $F = 0 then
    Inc(rotCount)
  else begin
    if GDVars.hostileFacingMask and 1 <> 0 then Inc(rotCount);
    if GDVars.hostileFacingMask and 2 <> 0 then Inc(rotCount);
    if GDVars.hostileFacingMask and 4 <> 0 then Inc(rotCount);
    if GDVars.hostileFacingMask and 8 <> 0 then Inc(rotCount);
  end;
  rotCount := rotCount * 2;
  GDVars.teamRows[1] := (GDVars.sideTally[1] + rotCount - 1) div rotCount;
  PrepareCombatOccupancy;
  slot := 1;
  GDVars.actorCount := 1;
  prev := GDVars.partyHead;
  p := GDVars.partyHead;
  while p <> nil do begin
    GDVars.creatureArr[slot] := p;
    GDVars.team := p^.side;
    GDVars.actor[slot].aux := slot;
    GDVars.actor[slot].size := p^.iconDimensions and 7;
    if GDVars.hostileFacingMask <> 0 then begin
      if p^.side = 0 then
        GDVars.partyPos.facing := savedFacing
      else begin
        repeat
          rotIdx := (rotIdx + 1) and 3;
        until Byte((1 shl rotIdx) and GDVars.hostileFacingMask) <> 0;
        GDVars.partyPos.facing := rotIdx * 2;
      end;
      PrepareCombatOccupancy;
    end;
    dirTmp := GDVars.partyPos.facing;
    if p^.side = 1 then
      dirTmp := (dirTmp + 4) mod 8;
    p^.combatAddr^.direction := GDConsts.quadDir[dirTmp div 2];
    placedResult := CombatSt.FindPlacement(slot, GDVars.placeX[GDVars.team], GDVars.placeY[GDVars.team],
                                           GDVars.teamDir[GDVars.team]);
    if placedResult then begin
      prev := p;
      if p^.inPlay = 0 then begin
        GDVars.actor[slot].size := 0;
        if (p^.combatAddr^.notPcNpc = 0) and (p^.status <> C_Status.GONE) then begin
          x := GDVars.actor[slot].x;
          y := GDVars.actor[slot].y;
          Inc(GDVars.downedCount);
          GDVars.downed[GDVars.downedCount].terrain := CbtMap.ResolveTerrain(x, y);
          GDVars.combatMap^.cells[y, x] := C_Terr.TERRAIN_CORPSE;
          GDVars.downed[GDVars.downedCount].cr := p;
          GDVars.downed[GDVars.downedCount].x := x;
          GDVars.downed[GDVars.downedCount].y := y;
        end;
      end;
      if p^.status in [9, 11..19] then begin
        p^.inPlay := 0;
        GDVars.actor[slot].size := 0;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.actorCount);
      Inc(placedCnt);
    end else begin
      GDVars.actor[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.creatureArr[slot] := nil;
        GDVars.curChar := p;
        CharGen.RemoveCreature(True, False);
        p := prev;
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.actorCount);
      end;
    end;
    p := p^.next;
  end;
  prev^.next := nil;
  GDVars.partyPos.facing := savedFacing;
end;

procedure CombatStart;
var
  spriteFrame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedFlags: array[1..9] of Byte;
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  pTail: Byte;
begin
  GDVars.msgDelayFlag := 0;
  Portrait.FreeAnimation;
  GDVars.palettePresetOn := 0;
  Border.FreePictureBorder;
  if GDVars.vmBand.zone2 <> nil then
    FreeMem(GDVars.vmBand.zone2, SizeOf(Types.TZone2));
  GDVars.vmBand.zone2 := nil;
  Blit.FreePic(GDConsts.extraPictureA);
  Blit.FreePic(GDVars.bigPicture);
  Blit.FreePic(GDVars.backdropImage);
  Blit.FreePic(GDVars.skyImage);
  Blit.FreePic(GDVars.banks[0]);
  Blit.FreePic(GDVars.banks[1]);
  Blit.FreePic(GDVars.banks[2]);
  GDVars.currentSkyId := 0;
  { the backdrop and sky pointers }
  GameIo.ZeroFill(GDVars.backdropImage, 8);
  for spriteFrame := 0 to 21 do
    MapTiles.LoadIconAnim('COMSPR', spriteFrame, spriteFrame + 13);
  Blit.ShadowPaletteEntries(64, 32, GDVars.workPalette);
  Blit.AllocPic(24, 3, 39, 0, GDVars.icon24Bank);
  GDVars.bigPicId := $FF;
  MenuCore.ClearBottomLine;
  case GDVars.gameState^.weather of
    0: TextRend.DisplayString(0, 24, LightGreen, Black, 'Battle in snow! Movement restricted.');
    1: TextRend.DisplayString(0, 24, LightGreen, Black, 'Battle in rain! Movement restricted.');
  else
    TextRend.DisplayString(0, 24, LightGreen, Black, 'A battle begins...');
  end;
  GDVars.quickMagic := 0;
  GDVars.cbRoundCounter := 0;
  GDVars.cbNewFlag := 15;
  GDVars.attackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.cloudHead := nil;
  GDVars.currentItem := nil;
  GameIo.ZeroFill(GDVars.downed, SizeOf(GDVars.downed));
  GDVars.gameState^.allyAttacked := 0;
  CombatSt.LoadCombatTileSet;
  CombatSt.InitCreatureCombatData;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.combatImage);
  GDVars.combatMap^.originX := CbtMap.CombatCellX(Pointer(GDVars.partyHead)) - 3;
  GDVars.combatMap^.originY := CbtMap.CombatCellY(Pointer(GDVars.partyHead)) - 3;
  Border.ClearScreenBlack;
  Blit.SetDacPalette(32, 224, GDVars.workPalette);
  CharHlp.DisplayCombatInterface;
  GameIo.DrainKeys;
  p := GDVars.partyHead;
  while p <> nil do begin
    p^.combatAddr^.turnAttempts := 0;
    FxEngine.TriggerEffectsWithCondition(C_Cond.COMBAT_START, p);
    p := p^.next;
  end;
  Romance.TagRelationshipPair;
  CbtActs.UpdateHostileHpPercent;
  GDVars.arenaClickA := 0;
  GDVars.aimCursorActive := 0;
  GDVars.locState.current := C_Ifc.IN_COMBAT;
  GDVars.isMoveMode := 0;
  p := GDVars.partyHead;
  GDVars.cbTailFlag2 := 0;
  GDVars.cbTailFlag3 := 0;
  GDVars.opMode := 0;
  CharHlp.DebugDumpParty;
end;

procedure JoinBattle(p: Pointer);
var
  dx: ShortInt;
  dy: ShortInt;
  d: ShortInt;
begin
  GDVars.team := Types.PCharacter(p)^.side;
  if GDVars.team = 0 then begin
    dx := GDVars.gameState^.battleX[0] - GDVars.partyPos.x;
    dy := GDVars.gameState^.battleY[0] - GDVars.partyPos.y;
    d := GDVars.gameState^.battleDist[0]
  end else begin
    dx := GDVars.gameState^.battleX[1] - GDVars.partyPos.x;
    dy := GDVars.gameState^.battleY[1] - GDVars.partyPos.y;
    d := GDVars.gameState^.battleDist[1]
  end;
  GDVars.joinSlot := CbtMap.CombatSlot(p);
  GDVars.actor[GDVars.joinSlot].size := Types.PCharacter(p)^.iconDimensions and 7;
  if CombatSt.FindPlacement(GDVars.joinSlot, dx, dy, d) then begin
    Types.PCharacter(p)^.combatAddr^.direction := (d + d) and 6;
    Types.PCharacter(p)^.status := C_Status.OKAY;
    Types.PCharacter(p)^.inPlay := 1;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), 0, 8);
    GDVars.combatPanelDirty := 1;
    CbtMap.DisplayMapViewCentered(p, 3, 1);
    CharHlp.CombatPrintCreatureInfo(p);
    CharHlp.PrintCreatureMessage(p, 'joins the battle', 10, 1);
    CbtMap.DisplayMapViewCentered(p, 3, 0)
  end else
    GDVars.actor[GDVars.joinSlot].size := 0
end;

begin
end.
