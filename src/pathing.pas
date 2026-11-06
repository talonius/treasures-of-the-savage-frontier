{ Pathing -- the combat pathfinder: a Bresenham line walker, a directional cone test, a movement-cost probe, and the
  builder and sorter of the candidate-target list. }
{$O+,F+,S+,A+}
unit Pathing;

interface

uses Types, CbtMap, GDConsts, GDVars, C_Dir;

{ Gives the sign of a number.
  @param(n The number.)
  @returns(-1, 0 or 1.) }
function SignOf(n: Integer): Integer;

{ Starts a line walk from its start point to its end point: sets the current point, the deltas, the step signs, and zero
  error and distance.
  @param(req The walk, with its start and end points set.) }
procedure PathFind(var req: Types.TPathReq);

{ Takes one Bresenham step along a line walk, adding 2 to the doubled distance for a straight step and 3 for a diagonal,
  and records the step's direction.
  @param(req The walk, started by PathFind.)
  @returns(False, without moving, once the end point is reached.) }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ Tells whether a direction leads from one arena cell toward another: the target must lie in the 90-degree cone around
  the cell one step away in that direction. A target on the start cell or on the cell one step away always counts.
  @param(x1 Arena column of the start cell.)
  @param(y1 Arena row of the start cell.)
  @param(x2 Arena column of the target cell.)
  @param(y2 Arena row of the target cell.)
  @param(dir The direction, 0 to 7; 8 or 255 for any direction, which always counts.)
  @returns(True when the direction leads toward the target; False when a cell lies outside the arena. Note: a direction
    from 9 to 254 matches no case and leaves the result unset.) }
function IsDirToward(x1, y1, x2, y2: ShortInt; dir: Byte): Boolean;

{ Walks the line of sight from a source cell to a target cell through the arena. A second walk carries the eye height
  level along the line from the source cell, and the trace stops where a cell's obstacle stands taller than that, unless
  the arena has no heights, or where the range runs out. Note: the coordinates are not range-checked before indexing the
  map.
  @param(px Source column.)
  @param(py Source row.)
  @param(tx In: target column. Out: the stopping column when the walk stops short.)
  @param(ty In: target row. Out: the stopping row when the walk stops short.)
  @param(cost In: the range in cells. Out: the doubled distance walked.)
  @returns(True when the target was reached.) }
function WalkLine(px, py: ShortInt; var tx, ty: ShortInt; var cost: Word): Boolean;

{ Fills the ranked target list with each combatant in the arena that a cell of a body of the given size at the given
  cell can see within range and in the facing wedge. For each combatant the closest such pair of footprint cells counts,
  with its doubled distance and a direction toward it (the facing itself when it is 0 to 7, else the first direction
  whose wedge holds the best pair). The list is then sorted nearest first.
  @param(bx Column of the body.)
  @param(by Row of the body.)
  @param(budget The range in cells.)
  @param(dir The direction, 0 to 7, or 8 or more for any.)
  @param(kind The body's size.) }
procedure BuildTargetList(bx, by: ShortInt; budget: Word; dir, kind: Byte);

implementation

function SignOf(n: Integer): Integer;
begin
  if n < 0 then SignOf := -1
  else if n > 0 then SignOf := 1
  else SignOf := 0;
end;

{ Sorts the target list nearest first; on equal distance a lower direction goes first unless it is diagonal and the
  other is not. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  dirJ: Byte;
  dirI: Byte;
  tmp: Types.TCombatTarget;
begin
  if GDVars.targetCount > 1 then
    for i := 1 to GDVars.targetCount - 1 do
      for j := i + 1 to GDVars.targetCount do begin
        dirI := GDVars.rankedTargets[i].facing;
        dirJ := GDVars.rankedTargets[j].facing;
        if (GDVars.rankedTargets[j].cost < GDVars.rankedTargets[i].cost) or
            ((GDVars.rankedTargets[j].cost = GDVars.rankedTargets[i].cost) and (dirJ < dirI) and
             ((dirJ mod 2) <= (dirI mod 2))) then begin
          tmp := GDVars.rankedTargets[i];
          GDVars.rankedTargets[i] := GDVars.rankedTargets[j];
          GDVars.rankedTargets[j] := tmp;
        end;
      end;
end;

procedure PathFind(var req: Types.TPathReq);
begin
  with req do begin
    cx := x1;
    cy := y1;
    adx := Abs(x2 - x1);
    ady := Abs(y2 - y1);
    stepX := Pathing.SignOf(x2 - x1);
    stepY := Pathing.SignOf(y2 - y1);
    err := 0;
    dist := 0;
  end;
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
var
  sx: ShortInt;
  sy: ShortInt;
begin
  NextPathStep := False;
  sx := 1;
  sy := 1;
  with req do begin
    if adx >= ady then begin
      if cx <> x2 then begin
        Inc(cx, stepX);
        sx := stepX + 1;
        Inc(err, ady);
        Inc(err, ady);
        Inc(dist);
        Inc(dist);
        if err >= adx then begin
          Dec(err, adx);
          Dec(err, adx);
          Inc(cy, stepY);
          sy := stepY + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end else begin
      if cy <> y2 then begin
        Inc(cy, stepY);
        sy := stepY + 1;
        Inc(err, adx);
        Inc(err, adx);
        Inc(dist);
        Inc(dist);
        if err >= ady then begin
          Dec(err, ady);
          Dec(err, ady);
          Inc(cx, stepX);
          sx := stepX + 1;
          Inc(dist);
        end;
        NextPathStep := True;
      end;
    end;
    dir := GDConsts.stepDir[sy, sx];
  end;
end;

function WalkLine(px, py: ShortInt; var tx, ty: ShortInt; var cost: Word): Boolean;
var
  reqA: Types.TPathReq;
  reqB: Types.TPathReq;
  done: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ignored: Boolean;
  limit: Word;
begin
  limit := cost * 2 + 1;
  reqA.x1 := px;
  reqA.y1 := py;
  reqA.x2 := tx;
  reqA.y2 := ty;
  Pathing.PathFind(reqA);
  reqB.x1 := 0;
  reqB.y1 := GDConsts.terrain[GDVars.combatMap^.cells[py, px]].clear;
  if reqA.adx > reqA.ady then
    reqB.x2 := reqA.adx
  else
    reqB.x2 := reqA.ady;
  reqB.y2 := GDConsts.terrain[GDVars.combatMap^.cells[py, px]].clear;
  Pathing.PathFind(reqB);
  done := False;
  repeat
    if ((GDVars.combatMap^.noHeight = 0) and
        (GDConsts.terrain[GDVars.combatMap^.cells[reqA.cy, reqA.cx]].block > reqB.cy)) or
        (reqA.dist > limit) then begin
      tx := reqA.cx;
      ty := reqA.cy;
      cost := reqA.dist;
      WalkLine := False;
      Exit;
    end;
    ignored := Pathing.NextPathStep(reqB);
    done := not Pathing.NextPathStep(reqA);
  until done;
  cost := reqA.dist;
  WalkLine := True;
end;

function IsDirToward(x1, y1, x2, y2: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x1 < 0) or (x1 > 49) or (y1 < 0) or (y1 > 24) or (x2 < 0) or (x2 > 49) or (y2 < 0) or (y2 > 24) then
    IsDirToward := False
  else begin
    if dir = $FF then dir := C_Dir.CENTER;
    nx := x1 + GDConsts.dirDx[dir];
    ny := y1 + GDConsts.dirDy[dir];
    if ((x1 = x2) and (y1 = y2)) or ((nx = x2) and (ny = y2)) then
      IsDirToward := True
    else
      case dir of
        C_Dir.NORTH: IsDirToward := ((x2 >= nx) and (y2 <= nx - x2 + ny)) or ((x2 <= nx) and (y2 <= x2 - nx + ny));
        C_Dir.NORTHEAST: IsDirToward := ((x2 >= nx) and (y2 <= nx - x2 + ny)) or
          ((x2 >= nx + ny - y2) and (y2 <= ny));
        C_Dir.EAST: IsDirToward := ((x2 >= nx + ny - y2) and (y2 <= ny)) or ((x2 >= nx + y2 - ny) and (y2 >= ny));
        C_Dir.SOUTHEAST: IsDirToward := ((x2 >= nx + y2 - ny) and (y2 >= ny)) or
          ((x2 >= nx) and (y2 >= x2 - nx + ny));
        C_Dir.SOUTH: IsDirToward := ((x2 >= nx) and (y2 >= x2 - nx + ny)) or ((x2 <= nx) and (y2 >= nx - x2 + ny));
        C_Dir.SOUTHWEST: IsDirToward := ((x2 <= nx) and (y2 >= nx - x2 + ny)) or
          ((x2 <= nx + ny - y2) and (y2 >= ny));
        C_Dir.WEST: IsDirToward := ((x2 <= nx + ny - y2) and (y2 >= ny)) or ((x2 <= nx + y2 - ny) and (y2 <= ny));
        C_Dir.NORTHWEST: IsDirToward := ((x2 <= nx + y2 - ny) and (y2 <= ny)) or
          ((x2 <= nx) and (y2 <= x2 - nx + ny));
        C_Dir.CENTER: IsDirToward := True;
      end;
  end;
end;

procedure BuildTargetList(bx, by: ShortInt; budget: Word; dir, kind: Byte);
var
  k: Byte;
  d: Byte;
  i: Byte;
  j: Byte;
  bi: Byte;
  bj: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  vx: ShortInt;
  vy: ShortInt;
  selfX: array[0..5] of ShortInt;
  selfY: array[0..5] of ShortInt;
  othX: array[0..5] of ShortInt;
  othY: array[0..5] of ShortInt;
  c: Word;
  best: Word;
begin
  for i := 0 to 5 do
    if CbtMap.FootprintCell(kind, i, vx, vy) then begin
      selfX[i] := bx + vx;
      selfY[i] := by + vy;
    end else
      selfX[i] := -1;
  GDVars.targetCount := 0;
  for k := 1 to GDVars.actorCount do
    if GDVars.actor[k].size > 0 then begin
      found := False;
      best := 255;
      for j := 0 to 5 do
        if CbtMap.FootprintCell(GDVars.actor[k].size, j, vx, vy) then begin
          othX[j] := GDVars.actor[k].x + vx;
          othY[j] := GDVars.actor[k].y + vy;
        end else
          othX[j] := -1;
      for j := 0 to 5 do
        if othX[j] >= 0 then
          for i := 0 to 5 do
            if selfX[i] >= 0 then
              if Pathing.IsDirToward(selfX[i], selfY[i], othX[j], othY[j], dir) then begin
                tx := othX[j];
                ty := othY[j];
                c := budget;
                if Pathing.WalkLine(selfX[i], selfY[i], tx, ty, c) then begin
                  found := True;
                  if c < best then begin
                    best := c;
                    bi := i;
                    bj := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.rankedTargets[GDVars.targetCount].entity := k;
        GDVars.rankedTargets[GDVars.targetCount].cost := best;
        d := C_Dir.NORTH;
        if dir < C_Dir.CENTER then
          d := dir
        else
          while not Pathing.IsDirToward(selfX[bi], selfY[bi], othX[bj], othY[bj], d) do
            Inc(d);
        GDVars.rankedTargets[GDVars.targetCount].facing := d;
      end;
    end;
  Pathing.SortTargets;
end;

begin
end.
