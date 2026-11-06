{ MapTiles -- the combat-map figures: 24x24 tile sets, the per-slot icon pairs (combat sprites, portraits and monster
  pictures), the monster-icon cache in slots 8..12, and drawing a figure, mirrored for modes above 3. }
{$O+,F+,S+,A+}
unit MapTiles;

interface

{ Loads a picture of 24x24 map tiles and copies the given number of its tiles into the map tile sheet from the given
  slot on, then shadows the tile palette entries and flushes pending keystrokes. A slot past 39 is a fatal error.
  @param(name Base name of the DAX file.)
  @param(blk Picture number within the file.)
  @param(start First tile slot written, 0..39.)
  @param(count Number of tiles copied.) }
procedure Load24x24Set(name: String; blk, start, count: Byte);

{ Frees both frames of an icon animation slot.
  @param(slot The slot.) }
procedure FreeIconAnim(slot: Byte);

{ Loads the two frames of an icon animation, picture blk and blk + 128, with the graphics-busy flag set. For CHEAD and
  CBODY files the last letter of the name is a size letter: it is dropped, and T adds 64 to blk; a head uses one picture
  for both frames. COMSPR, ICON and CPIC (read from CPIC1.DAX) keep their own colors, and CPIC also shadows its palette
  entries once its second frame is loaded; any other name loads from file name + '1' and has its colors remapped through
  GDConsts.colorDrop8.
  @param(name Base name of the DAX file.)
  @param(blk Picture number of the first frame.)
  @param(slot Slot receiving the frames.) }
procedure LoadIconAnim(name: String; blk, slot: Byte);

{ Draws one frame of an icon animation into the view buffer, clipped, at three character cells per map cell, mirrored
  for facings past southeast. A slot or frame out of range, or a frame not loaded, is reported and nothing is drawn.
  @param(x Map column.)
  @param(y Map row.)
  @param(mode Direction the icon faces.)
  @param(sub Frame to draw, 0 or 1.)
  @param(slot Animation slot, 0..42.) }
procedure DrawIconAnimSprite(x, y: ShortInt; mode, sub, slot: Byte);

{ Finds the icon slot holding a monster's combat picture, loading the picture from CPIC into the next free slot when it
  is new. Past slot 12 it reports 'Too many monsters!' and falls back on slot 8.
  @param(key The monster's picture number.)
  @returns(The slot, 8..12.) }
function FindMonsterIcon(key: Byte): Byte;

implementation

uses Types, GDConsts, GDVars, C_Dir, Blit, GameIo;

procedure Load24x24Set(name: String; blk, start, count: Byte);
var
  pic: Types.PImage;
  total: Word;
  offset: Word;
begin
  if start > 39 then
    GDVars.fatalMessageHook('Start range error in Load24x24Set');
  pic := nil;
  Blit.LoadPicFromList(name, blk, 0, 0, pic);
  total := count * pic^.frameBytes;
  offset := start * pic^.frameBytes;
  if GDVars.icon24Bank <> nil then
    Move(pic^.data[0], GDVars.icon24Bank^.data[offset], total);
  Blit.ShadowPaletteEntries(32, 32, GDVars.workPalette);
  Blit.FreePic(pic);
  GameIo.DrainKeys;
end;

procedure FreeIconAnim(slot: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameIndex: array[0..1] of Byte;
begin
  if GDVars.iconSet[slot, 0] <> nil then
    Blit.FreePic(GDVars.iconSet[slot, 0]);
  if GDVars.iconSet[slot, 1] <> nil then
    Blit.FreePic(GDVars.iconSet[slot, 1]);
end;

function FindMonsterIcon(key: Byte): Byte;
var
  i: Byte;
begin
  for i := 8 to GDVars.monsterCount - 1 do
    if GDVars.monsterKeys[i] = key then begin
      FindMonsterIcon := i;
      Exit;
    end;
  if GDVars.monsterCount > 12 then begin
    GDVars.showMessage('Too many monsters!');
    FindMonsterIcon := 8;
  end else begin
    MapTiles.LoadIconAnim('CPIC', key, GDVars.monsterCount);
    FindMonsterIcon := GDVars.monsterCount;
    GDVars.monsterKeys[GDVars.monsterCount] := key;
    Inc(GDVars.monsterCount);
  end;
end;

procedure LoadIconAnim(name: String; blk, slot: Byte);
var
  suffix: String[1];
  { Unused in this version; see the other implementations of this routine. }
  index: array[0..1] of Byte;
begin
  GDConsts.graphicsBusy := 1;
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(blk, $40);
    name := Copy(name, 1, Length(name) - 1);
    Blit.LoadPicFromList(name, blk, 1, 8, GDVars.iconSet[slot, 0]);
    if name = 'CHEAD' then
      Blit.LoadPicFromList(name, blk, 1, 8, GDVars.iconSet[slot, 1])
    else
      Blit.LoadPicFromList(name, blk + $80, 1, 8, GDVars.iconSet[slot, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') or (name = 'CPIC') then begin
    if name = 'CPIC' then
      suffix := '1'
    else
      suffix := '';
    Blit.LoadPicFromList(name + suffix, blk, 1, 8, GDVars.iconSet[slot, 0]);
    Blit.LoadPicFromList(name + suffix, blk + $80, 1, 8, GDVars.iconSet[slot, 1]);
    if (name = 'CPIC') and (GDVars.iconSet[slot, 1] <> nil) then
      Blit.ShadowPaletteEntries(144, 112, GDVars.workPalette);
  end else begin
    suffix := '1';
    Blit.LoadPicFromList(name + suffix, blk, 1, 0, GDVars.iconSet[slot, 0]);
    Blit.RemapPic(GDConsts.colorIdentity, GDConsts.colorDrop8, 0, 0, GDVars.iconSet[slot, 0]);
    Blit.LoadPicFromList(name + suffix, blk + $80, 1, 0, GDVars.iconSet[slot, 1]);
    Blit.RemapPic(GDConsts.colorIdentity, GDConsts.colorDrop8, 0, 0, GDVars.iconSet[slot, 1]);
  end;
  GDConsts.graphicsBusy := 0;
end;

procedure DrawIconAnimSprite(x, y: ShortInt; mode, sub, slot: Byte);
var
  scratch: Types.PImage;
begin
  if not (slot in [0..42]) or not (sub in [0..1]) then begin
    GDVars.showMessage('Strange putfigure');
    Exit;
  end;
  if GDVars.iconSet[slot, sub] = nil then begin
    GDVars.showMessage('No icon in slot ' + GDVars.intToStringHook(slot));
    Exit;
  end;
  with GDVars.iconSet[slot, sub]^ do
    if mode > C_Dir.SOUTHEAST then begin
      Blit.AllocPic(rows, cells, 1, 1, scratch);
      scratch^.colorKey := GDVars.iconSet[slot, sub]^.colorKey;
      Blit.MirrorPic(GDVars.iconSet[slot, sub], scratch);
      Blit.BlitTileClipped(x * 3, y * 3, 0, 1, scratch, GDVars.viewSurface);
      Blit.FreePic(scratch);
    end else
      Blit.BlitTileClipped(x * 3, y * 3, 0, 1, GDVars.iconSet[slot, sub], GDVars.viewSurface);
end;

begin
end.
