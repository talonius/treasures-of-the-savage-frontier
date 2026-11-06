{ GeoEdit -- the developers' map editor, reached only while GDConsts.editorEnabled is set. It edits the current 16x16
  map's walls, wall blocks, events and indoor flags at the party's square and facing, and loads and saves maps as \GEO\
  files. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit GeoEdit;

interface

{ The editor, which does nothing unless GDConsts.editorEnabled is set: shows the wall, new wall, barrier name, event and
  indoor flag ahead of the party, and applies the chosen command (set or step the wall, replace walls, step the event or
  barrier, toggle indoors, flip the direction, Clr, the map menu, move forward, or leave). }
procedure GeoEditor;

implementation

uses Types, Crt, GDConsts, GDVars, C_Keys, Border, TextRend, CharHlp, MenuCore, MapView,
  View3D;

{ Formats a number in decimal.
  @param(value The number.)
  @returns(Its digits.) }
function GeoByteStr(value: Byte): String;
var
  s: String;
begin
  Str(value:0, s);
  GeoByteStr := s;
end;

{ Write the map to \GEO\GEOnn, nn the editor's map number, after the file's header; I/O errors are ignored. }
procedure SaveMapFile;
var
  f: File;
  { Unused in this version; see the other implementations of this routine. }
  err: Byte;
  result: Word;
begin
  GDConsts.geoNameAnchor.name[5] := Chr(GDVars.mapNumber mod 10 + Ord('0'));
  GDConsts.geoNameAnchor.name[4] := Chr(GDVars.mapNumber div 10 + Ord('0'));
  Assign(f, '\geo\' + GDConsts.geoNameAnchor.name);
  Rewrite(f, 1);
  BlockWrite(f, GDConsts.geoNameAnchor.header, SizeOf(GDConsts.geoNameAnchor.header));
  BlockWrite(f, GDVars.geoMap^, SizeOf(GDVars.geoMap^), result);
  Close(f);
  err := IOResult;
end;

{ Read the map from \GEO\GEOnn, nn the editor's map number, past the file's header; I/O errors are ignored. }
procedure LoadMapFile;
var
  f: File;
  { Unused in this version; see the other implementations of this routine. }
  err: Byte;
  result: Word;
begin
  GDConsts.geoNameAnchor.loadName[5] := Chr(GDVars.mapNumber mod 10 + Ord('0'));
  GDConsts.geoNameAnchor.loadName[4] := Chr(GDVars.mapNumber div 10 + Ord('0'));
  Assign(f, '\geo\' + GDConsts.geoNameAnchor.loadName);
  Reset(f, 1);
  Seek(f, SizeOf(GDConsts.geoNameAnchor.header));
  BlockRead(f, GDVars.geoMap^, SizeOf(GDVars.geoMap^), result);
  Close(f);
  err := IOResult;
end;

{ Sets the 2-bit field of a cell's barrier byte that starts at bit field (0, 2, 4 or 6). Outside the view's coordinates
  the edit is made only while an override flag is set, and never off the map.
  @param(y The map column.)
  @param(x The map row.)
  @param(field The side's first bit: 0, 2, 4 or 6.)
  @param(value The barrier, 0..3.) }
procedure SetMapField(y, x: ShortInt; field, value: Byte);
begin
  if not View3D.Valid3DCoords(y, x) and (GDVars.environmentId = 0) then Exit;
  if (y > 15) or (y < 0) or (x > 15) or (x < 0) then Exit;
  value := value and 3;
  case field of
    6: GDVars.geoMap^.barriers[x, y] := (GDVars.geoMap^.barriers[x, y] and $3F) or (value shl 6);
    4: GDVars.geoMap^.barriers[x, y] := (GDVars.geoMap^.barriers[x, y] and $CF) or (value shl 4);
    2: GDVars.geoMap^.barriers[x, y] := (GDVars.geoMap^.barriers[x, y] and $F3) or (value shl 2);
    0: GDVars.geoMap^.barriers[x, y] := (GDVars.geoMap^.barriers[x, y] and $FC) or value;
  end;
end;

{ Sets the wall on side field (0, 2, 4 or 6) of a cell, a nibble of wallsNE or wallsSW, under SetMapField's conditions.
  @param(y The map column.)
  @param(x The map row.)
  @param(field The side: 0, 2, 4 or 6.)
  @param(value The wall type, 0..15.) }
procedure SetWallField(y, x: ShortInt; field, value: Byte);
begin
  if not View3D.Valid3DCoords(y, x) and (GDVars.environmentId = 0) then Exit;
  if (y > 15) or (y < 0) or (x > 15) or (x < 0) then Exit;
  value := value and $0F;
  case field of
    0: GDVars.geoMap^.wallsNE[x, y] := (GDVars.geoMap^.wallsNE[x, y] and $0F) or (value shl 4);
    2: GDVars.geoMap^.wallsNE[x, y] := (GDVars.geoMap^.wallsNE[x, y] and $F0) or value;
    4: GDVars.geoMap^.wallsSW[x, y] := (GDVars.geoMap^.wallsSW[x, y] and $0F) or (value shl 4);
    6: GDVars.geoMap^.wallsSW[x, y] := (GDVars.geoMap^.wallsSW[x, y] and $F0) or value;
  end;
end;

{ Sets a cell's event byte under SetMapField's conditions.
  @param(y The map column.)
  @param(x The map row.)
  @param(value The event byte.) }
procedure SetMapEvent(y, x: ShortInt; value: Byte);
begin
  if not View3D.Valid3DCoords(y, x) and (GDVars.environmentId = 0) then Exit;
  if (y > 15) or (y < 0) or (x > 15) or (x < 0) then Exit;
  GDVars.geoMap^.events[x, y] := value;
end;

{ The editor's map menu: step the map number (0..99) or a wall set, flip the step direction, load the wall sets, load or
  save the map, toggle overland and dungeon, toggle the display, or leave. }
procedure MapOptions;
var
  i: Byte;
  c: Char;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
begin
  repeat
    Border.EraseBox(1, 18, 38, 22);
    TextRend.DisplayString(20, 18, LightGreen, Black, 'map=' + GeoEdit.GeoByteStr(GDVars.mapNumber));
    for i := 1 to 3 do
      TextRend.DisplayString(1, i + $11, LightGreen, Black,
                             'wall' + GeoEdit.GeoByteStr(i) + '=' + GeoEdit.GeoByteStr(GDVars.wallSet[i]));
    if GDVars.direction = 1 then
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=inc')
    else
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=dec');
    if GDVars.gameState^.location = 0 then
      TextRend.DisplayString(20, 22, LightGreen, Black, 'Overland')
    else
      TextRend.DisplayString(20, 22, LightGreen, Black, 'Dungeon ');
    MenuCore.ResetMenuSlots(19);
    c := MenuCore.MenuHorizontal('', 'Map 1 2 3 Dir Walls Lo Sa Out Ind Ex', 1, 0);
    if GDVars.menuReturnedKey then begin
      if c = C_Keys.DELETE_KEY then begin
        Border.EraseBox(1, 17, 38, 22);
        Exit;
      end;
    end else
      case c of
        #0: begin
          GDVars.mapNumber := GDVars.mapNumber + GDVars.direction;
          if GDVars.mapNumber = 100 then GDVars.mapNumber := 0;
          if GDVars.mapNumber = $FF then GDVars.mapNumber := 99;
        end;
        #1, #2, #3:
          GDVars.wallSet[Ord(c) - Ord(#1) + 1] := GDVars.wallSet[Ord(c) - Ord(#1) + 1] + GDVars.direction;
        #4: if GDVars.direction = 1 then
              GDVars.direction := -1
            else
              GDVars.direction := 1;
        #5: begin
          GDConsts.graphicsBusy := 1;
          for i := 1 to 3 do
            if (GDVars.wallSet[i] <> $FF) and (GDVars.wallSet[i] <> 0) then
              View3D.LoadWallSet(GDVars.wallSet[i], i - 1);
          GDConsts.graphicsBusy := 0;
          MapView.DisplayMapView;
        end;
        #6: begin
          GDConsts.graphicsBusy := 1;
          GeoEdit.LoadMapFile;
          GDConsts.graphicsBusy := 0;
          MapView.DisplayMapView;
        end;
        #7: GeoEdit.SaveMapFile;
        #8: begin
          if GDVars.gameState^.location = 0 then GDVars.gameState^.location := 1
          else GDVars.gameState^.location := 0;
          MapView.DisplayMapView;
        end;
        #9: begin
          GDVars.automapShown := True;
          GDConsts.displayToggle := Ord(GDConsts.displayToggle = 0);
          MapView.DisplayMapView;
        end;
        #10: begin
          Border.EraseBox(1, 17, 38, 22);
          Exit;
        end;
      end;
  until False;
end;

{ Copies a cell to the eight cells around it: its event and, on the overland, its wallsNE byte, which is stored without
  SetMapEvent's checks, so at the map's edge it lands outside the plane; in a dungeon the copies keep only the indoor
  flag and lose their walls and barriers.
  @param(y The map column.)
  @param(x The map row.) }
procedure CopyCellArea(y, x: ShortInt);
var
  yy: ShortInt;
  xx: ShortInt;
  field: Byte;
begin
  if GDVars.gameState^.location = 0 then begin
    for yy := y - 1 to y + 1 do
      for xx := x - 1 to x + 1 do begin
        GeoEdit.SetMapEvent(yy, xx, View3D.GetMapEvent(y, x));
        GDVars.geoMap^.wallsNE[xx, yy] := GDVars.geoMap^.wallsNE[x, y];
      end;
  end else begin
    for yy := y - 1 to y + 1 do
      for xx := x - 1 to x + 1 do begin
        GeoEdit.SetMapEvent(yy, xx, View3D.GetMapEvent(y, x) and $80);
        field := 0;
        while field <= 6 do begin
          GeoEdit.SetMapField(yy, xx, field, 0);
          GeoEdit.SetWallField(yy, xx, field, 0);
          field := field + 2;
        end;
      end;
  end;
end;

{ The R command: every wall of type oldValue on the map becomes newValue.
  @param(oldValue The wall type replaced.)
  @param(newValue Its replacement.) }
procedure ReplaceWall(oldValue, newValue: Byte);
var
  y: ShortInt;
  x: ShortInt;
  field: Byte;
begin
  for y := 0 to 15 do
    for x := 0 to 15 do begin
      field := 0;
      while field < 8 do begin
        if View3D.GetWallType(y, x, field) = oldValue then
          GeoEdit.SetWallField(y, x, field, newValue);
        Inc(field, 2);
      end;
    end;
end;

procedure GeoEditor;
var
  wall: Byte;
  eventValue: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
  c: Char;
begin
  if not GDConsts.editorEnabled then Exit;
  if GDConsts.geoNameAnchor.initialized = 0 then
    GDVars.mapNumber := GDVars.gameState^.loadedMap;
  GDConsts.geoNameAnchor.initialized := 1;
  TextRend.DisplayString(1, 17, LightGreen, Black, 'Geo Editor');
  if GDVars.direction <> -1 then GDVars.direction := 1;
  GDVars.wallSet[1] := Lo(GDVars.wallSetCache[1].wallDefId);
  GDVars.wallSet[2] := Lo(GDVars.wallSetCache[2].wallDefId);
  GDVars.wallSet[3] := Lo(GDVars.wallSetCache[3].wallDefId);
  repeat
    Border.EraseBox(1, 18, 38, 22);
    if GDVars.gameState^.location = 0 then
      TextRend.DisplayString(1, 18, LightGreen, Black,
                             'wall=' +
                             GeoEdit.GeoByteStr(GDVars.geoMap^.wallsNE[GDVars.partyPos.y, GDVars.partyPos.x]))
    else
      TextRend.DisplayString(1, 18, LightGreen, Black,
                             'wall=' +
                             GeoEdit.GeoByteStr(View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                                   GDVars.partyPos.facing)) + ' nw=' +
        GeoEdit.GeoByteStr(GDConsts.geoNameAnchor.newWall));
    TextRend.DisplayString(1, 19, LightGreen, Black,
                           'block=' +
                           GDConsts.geoNameAnchor.wallNames[View3D.GetBarrierType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                                    GDVars.partyPos.facing)]);
    TextRend.DisplayString(1, 20, LightGreen, Black,
                           'special=' +
                           GeoEdit.GeoByteStr(View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y) and $7F));
    if (View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y) and $80) = 0 then
      TextRend.DisplayString(1, 21, LightGreen, Black, 'location=outdoors')
    else
      TextRend.DisplayString(1, 21, LightGreen, Black, 'location=inside');
    if GDVars.direction = 1 then
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=inc')
    else
      TextRend.DisplayString(1, 22, LightGreen, Black, 'dir=dec');
    MenuCore.ResetMenuSlots(19);
    c := MenuCore.MenuHorizontal('', 'Wll Nw Rp Spc Blk Loc Dir Clr Fil Mov Ex', 1, 0);
    if GDVars.menuReturnedKey then begin
      if c = C_Keys.DELETE_KEY then begin
        Border.EraseBox(1, 17, 38, 22);
        Exit;
      end;
    end else
      case c of
        #0: begin
          if GDVars.gameState^.location <> 0 then begin
            GDConsts.geoNameAnchor.newWall := GDConsts.geoNameAnchor.newWall and $0F;
            wall := View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
            if GDConsts.geoNameAnchor.newWall = wall then
              GDConsts.geoNameAnchor.newWall := (wall + GDVars.direction) and $0F;
            GeoEdit.SetWallField(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing,
                                 GDConsts.geoNameAnchor.newWall);
          end else
            Inc(GDVars.geoMap^.wallsNE[GDVars.partyPos.y, GDVars.partyPos.x], GDVars.direction);
          MapView.DisplayMapView;
        end;
        #1: GDConsts.geoNameAnchor.newWall := (GDConsts.geoNameAnchor.newWall + GDVars.direction) and $0F;
        #2: begin
          GeoEdit.ReplaceWall(View3D.GetWallType(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing),
                              GDConsts.geoNameAnchor.newWall);
          MapView.DisplayMapView;
        end;
        #3: begin
          eventValue := View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y);
          eventValue := (eventValue and $80) + ((eventValue + GDVars.direction) and $7F);
          GeoEdit.SetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y, eventValue);
        end;
        #4: GeoEdit.SetMapField(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing,
                                View3D.GetBarrierType(GDVars.partyPos.x, GDVars.partyPos.y,
                                                      GDVars.partyPos.facing) + GDVars.direction);
        #5: begin
          GeoEdit.SetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y,
                              View3D.GetMapEvent(GDVars.partyPos.x, GDVars.partyPos.y) xor $80);
          MapView.DisplayMapView;
        end;
        #6: if GDVars.direction = 1 then GDVars.direction := -1
            else GDVars.direction := 1;
        #7: begin
          GeoEdit.CopyCellArea(GDVars.partyPos.x, GDVars.partyPos.y);
          MapView.DisplayMapView;
        end;
        #8: begin
          GeoEdit.MapOptions;
          MapView.DisplayMapView;
        end;
        #9: begin
          Inc(GDVars.partyPos.x, GDConsts.dirDx[GDVars.partyPos.facing]);
          Inc(GDVars.partyPos.y, GDConsts.dirDy[GDVars.partyPos.facing]);
          GDVars.partyPos.x := GDVars.partyPos.x and $0F;
          GDVars.partyPos.y := GDVars.partyPos.y and $0F;
          CharHlp.PrintPositionAndTime;
          MapView.DisplayMapView;
        end;
        #10: begin
          Border.EraseBox(1, 17, 38, 22);
          Exit;
        end;
      end;
  until False;
end;

begin
  GDConsts.geoNameAnchor.newWall := 0;
end.
