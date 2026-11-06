{ Sym8x8 -- the 8x8 tile front end: Load8x8Set loads a tile bank into a slot, and Put8x8Sym draws a tile by its global
  index. }
{$O+,F+,S+,A+}
unit Sym8x8;

interface

{ Loads a symbol set from a picture of its file (BORD for slot 4, 8X8D0 for slot 3, 8X8D1 for the others), transparent
  in light magenta. A slot above 4 does nothing.
  @param(blk Picture number within the file.)
  @param(slot Symbol bank, 0..4.) }
procedure Load8x8Set(blk, slot: Byte);

{ Draws a symbol at a character cell, finding the bank whose range holds it. Symbol 0, a symbol past the last bank and a
  symbol in an unloaded bank draw nothing. Note: a symbol past the last bank reads past the end of GDVars.bankLastTile
  before the bank test.
  @param(x Column, in character cells.)
  @param(y Row, in character cells.)
  @param(tile Global symbol number, which picks its bank.)
  @param(solid True to blit the symbol into the view buffer; False to copy it through bank 3 straight to the screen.)
  @param(flags Bit 0 draws through the symbol's mask.) }
procedure Put8x8Sym(x, y: ShortInt; tile: Word; solid: Boolean; flags: Byte);

implementation

uses
  Types, GDConsts, GDVars, Blit;

type
  { The string Load8x8Set stages a DAX bank name into. }
  TBankName = string[8];

procedure Load8x8Set(blk, slot: Byte);
var
  name: TBankName;
  { Unused in this version; see the other implementations of this routine. }
  nameTail: LongInt;
begin
  if not (slot in [0..4]) then Exit;
  if slot = 4 then
    name := 'bord'
  else if slot = 3 then
    name := '8x8d0'
  else
    name := '8x8d1';
  Blit.LoadPicFromList(name, blk, 1, 13, GDVars.banks[slot]);
end;

procedure Put8x8Sym(x, y: ShortInt; tile: Word; solid: Boolean; flags: Byte);
var
  i: Byte;
begin
  i := 0;
  while GDConsts.bankLastTile[i] < tile do
    Inc(i);
  if (tile = 0) or (i > 4) then Exit;
  if GDVars.banks[i] = nil then Exit;
  Dec(tile, GDConsts.bankFirstTile[i]);
  if solid then
    Blit.BlitTileCell(x, y, Byte(tile), flags, GDVars.banks[i], GDVars.viewSurface)
  else
    with GDVars.banks[i]^ do begin
      if (flags and 1) <> 0 then
        Blit.ShowPicMasked(x, y, GDVars.banks[i], Byte(tile))
      else begin
        Move(data[tile * frameBytes], GDVars.banks[3]^.data[0], frameBytes);
        Blit.DrawFirstFrame(x, y, GDVars.banks[3]);
      end;
    end;
end;

begin
end.
