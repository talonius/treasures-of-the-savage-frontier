{ Graphics-bank loading, image conversion and composition for EGA, Tandy and VGA. The Pascal routines allocate and free
  images, mirror and remap pixels, capture and display frames, and flush deferred spans. The unit's initialization fills
  the active palette with $FF, so the first DAC write of each entry goes through.

  GRAPHICS.OBJ supplies near-call image, rectangle and palette routines; graphics.asm contains their implementations. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Blit;

interface

uses Types, GDConsts, GDVars, C_Video, Dos, ZeroFree, DaxIo, GameIo, Mouse;

type
  { An 8-pixel chunk as stored in a picture: one byte per pixel. }
  TChunk = array[0..7] of Byte;

{ Returns the transparency mask of an 8-pixel chunk.
  @param(transpColor The color that is transparent.)
  @param(chunk The chunk's eight pixels, one byte each.)
  @returns(A bit set for each pixel equal to transpColor, bit 7 for chunk[0] down to bit 0 for chunk[7].) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns to the mode that was current before the last SetVideoMode call. That call saves the mode it replaces, so two
  calls in a row toggle between two modes. }
procedure RestoreVideoMode;

{ Decodes a DAX image payload into an image record; LoadPic calls it. The header gives the size in rows and cells, the
  display position, the frame count and the palette range; on VGA the palette goes into GDVars.gamePalette, and its
  nibble map into GDVars.gfxNibbleTable. A palette-cycle chunk follows, kept in GDVars.picCycleChunk3. The pixels are
  then expanded by ExpandPicFrames. Note: colorMapScratch is never written, so pic^.colorMap receives whatever the stack
  held.
  @param(data The loaded payload.)
  @param(hasMask Bit 0 asks for a mask, as AllocPic's flag.)
  @param(transpColor The transparent color key.)
  @param(needsAlloc Nonzero allocates a fresh image (EGA and Tandy need a different layout from the payload's); 0 makes
    the payload block itself the image record, with loadedSize as its size.)
  @param(loadedSize The payload block's size.)
  @param(pic Receives the image.) }
procedure PreparePic(var data: Types.PByteBuffer; hasMask, transpColor, needsAlloc: Byte; loadedSize: Word;
                     var pic: Types.PImage);

{ Frees any picture already held, loads a record of a .dax archive and builds the picture from it; outside the 256-color
  mode the loaded buffer is then freed. The keyboard is flushed after a successful load only.
  @param(name The archive's name.)
  @param(fileId The record.)
  @param(hasMask Asks for a transparency mask, outside the 256-color mode.)
  @param(transpColor The transparent color.)
  @param(pic Receives the picture.) }
procedure LoadPic(name: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);

{ Load block fileId into pic from the first archive in the comma-separated list names that holds it. If none does,
  report the block missing from the last archive tried and, unless graphicsBusy is set, start again from the first.
  @param(names The archive base names, separated by commas.)
  @param(fileId The image's record.)
  @param(hasMask Bit 0 asks for a mask, as AllocPic's flag.)
  @param(transpColor The transparent color key.)
  @param(pic Receives the image.) }
procedure LoadPicFromList(names: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);

{ Converts a one-byte-per-pixel payload into an image's pixel data in the active class's layout, frame by frame,
  building the transparency mask from the key color when the image has one. An image with no rows or cells is left
  alone. Note: Tandy's mask pass runs over everything converted so far rather than just the current frame, which repeats
  work but gives the same result.
  @param(imgData The payload.)
  @param(srcOff The offset of the first pixel in imgData; left just past the data consumed.)
  @param(hasMask Unused.)
  @param(transpColor The key color the mask covers.)
  @param(pic The image, already allocated at its size.) }
procedure ExpandPicFrames(imgData: Types.PByteBuffer; var srcOff: Word; hasMask, transpColor: Byte;
                          pic: Types.PImage);

{ Draws a frame of gfx at a cell position of dest with no clipping. Bit 0 of flag asks for a transparent draw, which
  uses the image's mask, or in VGA its key color; an image without a mask draws plain in the other classes.
  @param(screenX The cell column.)
  @param(screenY The scanline row.)
  @param(tileIdx The frame.)
  @param(flag Bit 0 draws transparently.)
  @param(gfx The image drawn.)
  @param(dest The image drawn into.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Pointer);

{ Shows the first frame of an image through ShowPic.
  @param(screenX The left cell column.)
  @param(screenY The top cell row.)
  @param(pic The image.) }
procedure DrawFirstFrame(screenX, screenY: Integer; pic: Pointer);

{ Draw frame frame of pic at cell (screenX, screenY) through its mask (VGA: skipping the color key); rows from 25 down
  use the 9-pixel text-row spacing.
  @param(screenX The left cell column.)
  @param(screenY The top cell row.)
  @param(pic The image.)
  @param(frame The frame.) }
procedure ShowPicMasked(screenX, screenY: Integer; pic: Pointer; frame: Byte);

{ Draws a frame of gfx at a cell position of dest, clipped to dest; nothing is drawn when gfx is nil or lies wholly off
  the left or top edge. The clipped blitters interpret flag themselves and save what they cover into GDVars.savedPic.
  @param(screenX The cell column.)
  @param(screenY The scanline row.)
  @param(tileIdx The frame.)
  @param(flag Bit 0 draws through the mask or key color; bit 2 first saves the covered pixels.)
  @param(gfx The image drawn.)
  @param(dest The image drawn into.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImage);

{ Copies the first frame of an image into another with every row reversed left to right, with its color map. In EGA a
  byte holds 8 one-bit pixels, so each plane byte's bits are reversed as well; in Tandy a byte holds two pixels, so its
  nibbles swap; in the 256-color mode a byte is one pixel. The mask is mirrored the same way; the 256-color mode has
  none.
  @param(src The image mirrored; nothing happens if nil.)
  @param(dst Receives the mirror image, already allocated at the source's size; nothing happens if nil.) }
procedure MirrorPic(src, dst: Types.PImage);

{ Copies a cell-aligned rectangle of the screen, pic^.rows scanlines by pic^.cells cells, into pic's pixel data in the
  active class's layout. EGA reads each plane in turn through the Graphics Controller's read-map select and restores
  read map 0 and mode 0 afterwards.
  @param(col The rectangle's left cell column.)
  @param(row Its top cell row.)
  @param(pic Receives the pixels; its size gives the rectangle's.) }
procedure GrabPic(col, row: Integer; pic: Types.PImage);

{ Puts one frame of an image's pixel data onto the screen; the inverse of GrabPic. EGA writes each plane in turn through
  the Sequencer's map mask and re-enables all four planes afterwards.
  @param(screenX The left cell column.)
  @param(screenY The top cell row.)
  @param(pic The image.)
  @param(frame The frame.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImage; frame: Byte);

{ Copies every dirty scanline run of the view surface to the screen, with the mouse cursor hidden, and resets the span
  tables. The view surface's slot 0 is screen scanline 8. EGA stages each plane of each run in a hidden page and then
  latch-copies the staged runs to the displayed page; Tandy and the 256-color mode copy each run straight to video
  memory. }
procedure FlushView;

{ VGA only: clear every dirty row span on the screen to color 0. }
procedure BlankDirtySpans;

{ Recolors an image. For each of the 16 color-map entries whose source and destination colors differ, every pixel of the
  source color becomes the destination color. EGA builds an 8-pixel match mask per cell by XOR-folding the four planes,
  Tandy tests the high and low nibble of each byte separately, and the 256-color mode is a plain compare and store. The
  work is done in a scratch copy which is copied back and freed at the end. Note: the 256-color mode's key test reads
  the scratch image's key color, which allocation leaves 0, rather than the picture's, so it is color 0 that is never
  recolored.
  @param(fromColors The colors to replace.)
  @param(toColors Their replacements.)
  @param(frame The frame to recolor. Note: a negative frame selects every frame for the first pass only; every later
    pass finds it zeroed, so only the first frame is recolored and copied back.)
  @param(isDithered Set to change only a random subset of the matching pixels, in EGA and Tandy; the 256-color mode has
    no dither.)
  @param(pic The image.) }
procedure RemapPic(fromColors, toColors: Types.TColorTable; frame: Integer; isDithered: Byte; pic: Types.PImage);

{ Allocates a zero-filled image in the active display class's layout: the record and all frames as one block of
  totalSize + 27 bytes, 8 bytes per cell in VGA and 4 otherwise, with the size fields filled in. Running out of memory
  is fatal.
  @param(height The rows.)
  @param(width The width in cells.)
  @param(count The frames.)
  @param(flag Bit 0 asks for a separate zero-filled mask of totalSize bytes as well, never allocated for VGA.)
  @param(pic Receives the image.) }
procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImage);

{ Frees an image's mask, if it has one (one frame's bytes times the frame count), then the record block, and sets the
  pointer to nil; a nil pointer is left alone.
  @param(bank The image.) }
procedure FreePic(var bank: Types.PImage);

{ Fills a rectangle of an image with a solid color, clipping it to the picture, and raises each touched row's span so
  FlushView copies it to the screen. Note: with a negative top edge the fill starts at the top and covers one row more
  than is visible, and is not clipped against the surface height.
  @param(x The rectangle's left cell column; may be negative.)
  @param(y Its top scanline; may be negative.)
  @param(width Its width in cells.)
  @param(height Its height in scanlines.)
  @param(color The fill color.)
  @param(colorMap Unused.)
  @param(pic The image filled; nothing happens if nil.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImage);

{ Copies entries of GDVars.gamePalette into the same entries of another palette; it acts only in VGA.
  @param(startIdx The first entry.)
  @param(count The number of entries.)
  @param(dest Receives the entries.) }
procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest);

{ Copies palette entries into the same entries of another palette; it acts only in VGA.
  @param(first The first entry.)
  @param(count The number of entries.)
  @param(src The palette copied from.)
  @param(dst The palette copied into.) }
procedure CopyPaletteEntries(first: Byte; count: Word; src, dst: Pointer);

{ VGA only: program count palette entries from startIdx, writing only the runs that differ from the active palette, on
  retrace, and record them as active.
  @param(startIdx The first entry.)
  @param(count The number of entries.)
  @param(src The palette.) }
procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette);

{ Renders a region through the current graphics class's GRAPHICS.OBJ routine.
  @param(x The destination column.)
  @param(y The destination row.)
  @param(frame The frame.)
  @param(sourceSeg The source image's segment.)
  @param(sourceOfs The source image's offset.)
  @param(destSeg The destination image's segment.)
  @param(destOfs The destination image's offset.)
  @param(sourceX The first source column.)
  @param(sourceY The first source row.)
  @param(copyWidth The width copied, in cells.)
  @param(copyHeight The height copied, in cells.) }
procedure RenderRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                       copyWidth, copyHeight: Byte);

{ Plots one pixel on video page 0 through BIOS INT 10h function 0Ch; a pixel outside the view (columns 8..199, rows
  8..87) is not drawn.
  @param(x Pixel column.)
  @param(y Pixel row.)
  @param(color Color to plot.) }
procedure PlotViewPixel(x, y: Integer; color: Byte);

{ Copies a tile of an icon into a frame of the moving combat icon, mirrored when asked, together with its mask, when it
  has one, and its key color. Mirroring goes through a scratch image of 24 rows by 3 cells, the combat icon size, which
  has a mask outside the 256-color mode. Note: the key color always comes from the icon's own image, even in the
  mirrored case.
  @param(kind The icon animation row.)
  @param(tileIdx The icon's tile.)
  @param(frame The frame of the moving icon filled.)
  @param(isMirrored Set to mirror the tile.) }
procedure CopyIconTile(kind, tileIdx, frame, isMirrored: Byte);

{ Builds the moving combat icon's four frames from an icon's tiles 0 and 1: tile 0, tile 0 mirrored, tile 1 mirrored and
  tile 1, so the second half of the cycle walks the other way.
  @param(kind The icon animation row.) }
procedure BuildIconFrames(kind: Byte);

{ Draw a copyWidth by copyHeight cell part of pic's given frame, from (sourceX, sourceY), at cell (screenX, screenY).
  @param(screenX The destination column.)
  @param(screenY The destination row.)
  @param(pic The image.)
  @param(frame The frame.)
  @param(sourceX The first source column.)
  @param(sourceY The first source row.)
  @param(copyWidth The width copied, in cells.)
  @param(copyHeight The height copied, in cells.) }
procedure DrawFramePart(screenX, screenY: Integer; pic: Pointer; frame, sourceX, sourceY, copyWidth, copyHeight: Byte);

{ Draw pic's given frame through its mask at cell (screenX, screenY), recolored: EGA writes the frame's bytes to the
  planes set in color and zero to the other planes under the mask (in effect data and color per plane), Tandy ANDs each
  pixel with color, and VGA draws color $0F pixels in color, skips color $0D and copies the rest. Rows from 25 down use
  the 9-pixel text-row spacing. With color $0F and bgColor 0 it first draws the frame through ShowPicMasked, then still
  runs its own pass.
  @param(screenX The left cell column.)
  @param(screenY The top cell row.)
  @param(pic The image.)
  @param(frame The frame.)
  @param(color The recolor value.)
  @param(bgColor The background color; 0 with color $0F draws the frame through ShowPicMasked first.) }
procedure ShowPicRecolored(screenX, screenY: Integer; pic: Pointer; frame, color, bgColor: Byte);

implementation

{$F-}
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitClippedEga(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImage); forward;

procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitClippedTandy(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                           dest: Types.PImage); forward;

procedure BlitCellVga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitCellVgaKeyed(screenX, screenY: Integer; transpColor, tileIdx: Byte; gfx, dest: Types.PImage); forward;

procedure BlitClippedVga(under: Types.PImage; screenX, screenY: Integer; transpColor, tileIdx, flag: Byte; gfx,
                         dest: Types.PImage); forward;

procedure ProgramPaletteOnRetrace(palette: Pointer; startIdx, count: Word); forward;

procedure RenderEgaRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                          copyWidth, copyHeight: Word); forward;

procedure RenderTandyRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                            copyWidth, copyHeight: Word); forward;

procedure RenderVgaRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                          copyWidth, copyHeight: Word); forward;

procedure BlitVgaRecolored(x, y, rowBytes, rows: Word; transpColor, color: Byte; data: Pointer); forward;
{$F+}

function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
var
  mask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  transpHigh: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  bit := $80;
  for i := 0 to 7 do begin
    if chunk[i] = transpColor then Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

procedure SetVideoMode(mode: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  oldMode: Word;
begin
  GDVars.detectedVideoMode := GDVars.initialVideoMode;
  GDVars.regs.AH := 0;
  GDVars.regs.AL := mode;
  Intr($10, Registers(GDVars.regs));
  GDVars.initialVideoMode := mode
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GDVars.detectedVideoMode)
end;

procedure PreparePic(var data: Types.PByteBuffer; hasMask, transpColor, needsAlloc: Byte; loadedSize: Word;
                     var pic: Types.PImage);
var
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  j: Byte;
  picHeight: Byte;
  picWidth: Byte;
  picOriginX: Word;
  picOriginY: Word;
  paletteCount: Word;
  firstPaletteSlot: Byte;
  picCount: Word;
  colorMapScratch: Types.TColorMap;
  readOfs: Word;
  { Unused in this version; see the other implementations of this routine. }
  colorTables: array[1..514] of Byte;
  frameSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  chunk: array[1..8] of Byte;
begin
  Move(data^[0], picHeight, SizeOf(picHeight));
  Move(data^[1], picWidth, SizeOf(picWidth));
  Move(data^[2], picOriginX, SizeOf(picOriginX));
  Move(data^[4], picOriginY, SizeOf(picOriginY));
  Move(data^[6], picCount, SizeOf(picCount));
  Move(data^[8], firstPaletteSlot, SizeOf(firstPaletteSlot));
  paletteCount := data^[9] + 1;
  if GDVars.graphicsClass = C_Video.VM_VGA then
    Move(data^[10], GDVars.gamePalette[firstPaletteSlot], paletteCount * 3);
  readOfs := paletteCount * 3 + 10;
  for i := 0 to 15 do GDVars.gfxNibbleTable[i] := i;
  for i := 0 to (paletteCount div 2) - 1 do begin
    GDVars.gfxNibbleTable[Word(firstPaletteSlot) + Word(i) * 2] := data^[readOfs] shr 4;
    GDVars.gfxNibbleTable[Word(firstPaletteSlot) + Word(i) * 2 + 1] := data^[readOfs] and $0F;
    Inc(readOfs)
  end;
  FillChar(GDVars.picCycleChunk3, SizeOf(GDVars.picCycleChunk3), 0);
  if data^[readOfs] = 1 then Move(data^[readOfs + 1], GDVars.picCycleChunk3, SizeOf(GDVars.picCycleChunk3));
  Inc(readOfs, 4);
  if (firstPaletteSlot = 32) and (paletteCount = 112) then Inc(readOfs, $1C);
  if needsAlloc <> 0 then
    Blit.AllocPic(picHeight, picWidth, picCount, hasMask, pic)
  else begin
    frameSize := Word(picHeight) * Word(picWidth) * 8;
    pic := Types.PImage(data);
    Types.PImage(pic)^.rows := picHeight;
    Types.PImage(pic)^.cells := picWidth;
    Types.PImage(pic)^.frameBytes := frameSize;
    Types.PImage(pic)^.count := picCount;
    Types.PImage(pic)^.mask := nil;
    Types.PImage(pic)^.allocSize := loadedSize
  end;
  with Types.PImage(pic)^ do begin
    displayX := picOriginX;
    displayY := picOriginY;
    colorKey := transpColor;
    colorMap := colorMapScratch
  end;
  Blit.ExpandPicFrames(data, readOfs, hasMask, transpColor, pic)
end;

procedure LoadPic(name: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);
var
  dataSize: Word;
  data: Types.PByteBuffer;
begin
  if pic <> nil then Blit.FreePic(pic);
  DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
  if dataSize = 0 then Exit;
  Blit.PreparePic(data, hasMask, transpColor, Ord(GDVars.graphicsClass <> C_Video.VM_VGA), dataSize, pic);
  if GDVars.graphicsClass <> C_Video.VM_VGA then ZeroFree.PrefixFree(data, dataSize);
  GameIo.DrainKeys
end;

procedure LoadPicFromList(names: String; fileId, hasMask, transpColor: Byte; var pic: Types.PImage);
var
  archiveName: String;
  index: Byte;
begin
  repeat
    index := 1;
    repeat
      archiveName := '';
      while (index <= Length(names)) and (names[index] <> ',') do
      begin
        archiveName := archiveName + names[index];
        Inc(index)
      end;
      if (index <= Length(names)) and (names[index] = ',') then Inc(index);
      Blit.LoadPic(archiveName, fileId, hasMask, transpColor, pic);
      if pic <> nil then Exit;
    until index > Length(names);
    GDVars.showMessage('no #' + GDVars.intToStringHook(fileId) + ' in ' + archiveName + '.dax');
  until GDConsts.graphicsBusy <> 0;
end;

procedure ExpandPicFrames(imgData: Types.PByteBuffer; var srcOff: Word; hasMask, transpColor: Byte;
                          pic: Types.PImage);
var
  chunk: TChunk;
  frame: Word;
  col: Word;
  row: Word;
  dstOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  maskOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  mask: Byte;
  k: Byte;
  { Unused in this version; see the other implementations of this routine. }
  j: Byte;
  bit: Byte;
  plane: Byte;
  color: Byte;
  { Unused in this version; see the other implementations of this routine. }
  vgaPalette: array[1..770] of Byte;
begin
  if pic = nil then Exit;
  with Types.PImage(pic)^ do begin
    if (rows = 0) or (cells = 0) then Exit;
    dstOff := 0;
    maskOff := 0;
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
        begin
          for frame := 1 to count do
            for row := 0 to rows - 1 do
              for col := 0 to cells - 1 do begin
                Move(imgData^[srcOff], chunk, SizeOf(chunk));
                if mask <> nil then
                  FillChar(mask^[dstOff], 4, Blit.ComputeMask(transpColor, chunk));
                bit := $80;
                for k := 0 to 7 do begin
                  color := GDVars.gfxNibbleTable[chunk[k]];
                  for plane := 0 to 3 do
                    if (GDConsts.egaPlaneBit[plane] and color) > 0 then
                      data[dstOff + plane] := data[dstOff + plane] or bit;
                  bit := bit shr 1
                end;
                if mask <> nil then
                  for plane := 0 to 3 do
                    data[dstOff + plane] := data[dstOff + plane] and not mask^[dstOff];
                Inc(dstOff, 4);
                Inc(srcOff, SizeOf(chunk))
              end
        end;
      C_Video.VM_TANDY:
        begin
          for frame := 1 to count do begin
            for col := 0 to frameBytes - 1 do begin
              data[dstOff] := (GDVars.gfxNibbleTable[imgData^[srcOff]] shl 4) +
                  GDVars.gfxNibbleTable[imgData^[srcOff + 1]];
              Inc(dstOff);
              Inc(srcOff, 2)
            end
          end;
          if mask <> nil then
            for col := 0 to dstOff - 1 do begin
              if (data[col] shr 4) = transpColor then
                mask^[col] := $F0;
              if (data[col] and $0F) = transpColor then
                Inc(mask^[col], $0F);
              data[col] := data[col] and not mask^[col]
            end
        end;
      C_Video.VM_VGA:
        begin
          for frame := 1 to count do begin
            Move(imgData^[srcOff], data[dstOff], frameBytes);
            Inc(dstOff, frameBytes);
            Inc(srcOff, frameBytes)
          end
        end
    end
  end
end;

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  leftSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rightSkip: Integer;
  { Unused in this version; see the other implementations of this routine. }
  rowBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  srcOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  destOff: Word;
  { Unused in this version; see the other implementations of this routine. }
  lastRow: Word;
  { Unused in this version; see the other implementations of this routine. }
  y: Word;
  useMask: Boolean;
begin
  useMask := ((flag and 1) <> 0) and ((Types.PImage(gfx)^.mask <> nil) or (GDVars.graphicsClass = C_Video.VM_VGA));
  case GDVars.graphicsClass of
    C_Video.VM_EGA: if useMask then
         Blit.BlitCellEgaMasked(screenX, screenY, tileIdx, Types.PImage(gfx), Types.PImage(dest))
       else
         Blit.BlitCellEga(screenX, screenY, tileIdx, Types.PImage(gfx), Types.PImage(dest));
    C_Video.VM_TANDY: if useMask then
         Blit.BlitCellTandyMasked(screenX, screenY, tileIdx, Types.PImage(gfx), Types.PImage(dest))
       else
         Blit.BlitCellTandy(screenX, screenY, tileIdx, Types.PImage(gfx), Types.PImage(dest));
    C_Video.VM_VGA: if useMask then
         Blit.BlitCellVgaKeyed(screenX, screenY, Types.PImage(gfx)^.colorKey, tileIdx, Types.PImage(gfx),
                               Types.PImage(dest))
       else
         Blit.BlitCellVga(screenX, screenY, tileIdx, Types.PImage(gfx), Types.PImage(dest))
  end
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImage);
begin
  if (gfx = nil) or (LongInt(-screenX) >= Types.PImage(gfx)^.cells) or
      (LongInt(-screenY * 8) >= Types.PImage(gfx)^.rows) then Exit;
  case GDVars.graphicsClass of
    C_Video.VM_EGA: Blit.BlitClippedEga(GDVars.savedPic, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Video.VM_TANDY: Blit.BlitClippedTandy(GDVars.savedPic, screenX, screenY, tileIdx, flag, gfx, dest);
    C_Video.VM_VGA: Blit.BlitClippedVga(GDVars.savedPic, screenX, screenY, Types.PImage(gfx)^.colorKey,
                                        tileIdx, flag, gfx, dest)
  end
end;

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte;
var mirrored: Byte;
begin
  mirrored := value shl 7;
  Inc(mirrored, (value and 2) shl 5);
  Inc(mirrored, (value and 4) shl 3);
  Inc(mirrored, (value and 8) shl 1);
  Inc(mirrored, (value and $10) shr 1);
  Inc(mirrored, (value and $20) shr 3);
  Inc(mirrored, (value and $40) shr 5);
  Inc(mirrored, (value and $80) shr 7);
  MirrorBits := mirrored
end;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte;
var mirrored: Byte;
begin
  mirrored := value shl 4;
  Inc(mirrored, (value and $F0) shr 4);
  MirrorNibbles := mirrored
end;

procedure MirrorPic(src, dst: Types.PImage);
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cell: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  with Types.PImage(src)^ do begin
    Move(colorMap, Types.PImage(dst)^.colorMap, SizeOf(colorMap));
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
        begin
          rowBytes := cells * 4;
          srcOff := rowBytes - 4;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to cells do begin
              for plane := 0 to 3 do begin
                Types.PImage(dst)^.data[dstOff + plane] := Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
                if mask <> nil then
                  Types.PImage(dst)^.mask^[dstOff +
                                           plane] := Blit.MirrorBits(mask^[srcOff - dstOff + rowStart + plane])
              end;
              Inc(dstOff, 4)
            end;
            Inc(srcOff, rowBytes)
          end
        end;
      C_Video.VM_TANDY:
        begin
          rowBytes := cells * 4;
          srcOff := rowBytes - 1;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to rowBytes do begin
              Types.PImage(dst)^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff + rowStart]);
              if mask <> nil then
                Types.PImage(dst)^.mask^[dstOff] := Blit.MirrorNibbles(mask^[srcOff - dstOff + rowStart]);
              Inc(dstOff)
            end;
            Inc(srcOff, rowBytes)
          end
        end;
      C_Video.VM_VGA:
        begin
          rowBytes := cells * 8;
          srcOff := rowBytes - 1;
          dstOff := 0;
          for row := 1 to rows do begin
            rowStart := dstOff;
            for col := 1 to rowBytes do begin
              Types.PImage(dst)^.data[dstOff] := data[srcOff - dstOff + rowStart];
              Inc(dstOff)
            end;
            Inc(srcOff, rowBytes)
          end
        end
    end
  end
end;

procedure GrabPic(col, row: Integer; pic: Types.PImage);
var
  c: Integer;
  r: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  screenOff: Word;
  rowBytes: Word;
  dataOffset: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with Types.PImage(pic)^ do
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
        begin
          dataOffset := 0;
          firstRow := row * 8;
          lastRow := firstRow + rows - 1;
          colOff := col;
          colEnd := colOff + cells - 1;
          Port[$3CE] := 5;
          Port[$3CF] := 0;
          Port[$3CE] := 4;
          for r := firstRow to lastRow do
            for c := colOff to colEnd do
              for plane := 0 to 3 do begin
                Port[$3CF] := plane;
                Types.PImage(pic)^.data[dataOffset] := Mem[$A000:GDVars.egaRowOffset[r] + c];
                Inc(dataOffset)
              end;
          Port[$3CF] := 0;
          Port[$3CE] := 5;
          Port[$3CF] := 0
        end;
      C_Video.VM_VGA:
        begin
          screenOff := row * 8 * 320 + col * 8;
          dataOffset := 0;
          rowBytes := cells * 8;
          firstRow := row * 8;
          lastRow := firstRow + rows - 1;
          for r := firstRow to lastRow do begin
            Move(Types.PByteBuffer(LongInt(Ptr($A000, 0)) + screenOff)^[0], Types.PImage(pic)^.data[dataOffset],
                 rowBytes);
            Inc(dataOffset, rowBytes);
            Inc(screenOff, 320)
          end
        end;
      C_Video.VM_TANDY:
        begin
          rowBytes := cells * 4;
          dataOffset := 0;
          firstRow := row * 8;
          lastRow := firstRow + rows - 1;
          colOff := col * 4;
          for r := firstRow to lastRow do begin
            Move(Mem[GDVars.tandyRowSegment[r]:colOff], Types.PImage(pic)^.data[dataOffset], rowBytes);
            Inc(dataOffset, rowBytes)
          end
        end
    end
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImage; frame: Byte);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  if frame = 0 then srcOff := 0
  else srcOff := Word(frame) * Types.PImage(pic)^.frameBytes;
  with Types.PImage(pic)^ do
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
        begin
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX;
          colEnd := colOff + cells - 1;
          Port[$3C4] := 2;
          for row := firstRow to lastRow do
            for col := colOff to colEnd do
              for plane := 0 to 3 do begin
                Port[$3C5] := GDConsts.egaPlaneBit[plane];
                Mem[$A000:GDVars.egaRowOffset[row] + col] := Types.PImage(pic)^.data[srcOff];
                Inc(srcOff)
              end;
          Port[$3C5] := $0F
        end;
      C_Video.VM_TANDY:
        begin
          rowBytes := cells * 4;
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX * 4;
          for row := firstRow to lastRow do begin
            Move(Types.PImage(pic)^.data[srcOff], Mem[GDVars.tandyRowSegment[row]:colOff], rowBytes);
            Inc(srcOff, rowBytes)
          end
        end;
      C_Video.VM_VGA:
        begin
          rowBytes := cells * 8;
          firstRow := screenY * 8;
          lastRow := firstRow + rows - 1;
          colOff := screenX * 8;
          for row := firstRow to lastRow do begin
            Move(Types.PImage(pic)^.data[srcOff], Mem[$A000:colOff + row * 320], rowBytes);
            Inc(srcOff, rowBytes)
          end
        end
    end
end;

procedure DrawFirstFrame(screenX, screenY: Integer; pic: Pointer);
begin
  Blit.ShowPic(screenX, screenY, Types.PImage(pic), 0)
end;

procedure FlushView;
var
  row: Word;
  srcOff: Word;
  dstOff: Word;
  dstBase: Word;
  { Unused in this version; see the other implementations of this routine. }
  plane: Word;
begin
  Mouse.HideMouse;
  case GDVars.graphicsClass of
    C_Video.VM_EGA:
      begin
        Port[$3C4] := 2;
        for row := 0 to 167 do
          if GDVars.spanActive[row] <> 0 then begin
            dstBase := GDVars.egaRowOffset[row + 8] + GDVars.spanLow[row] + 1;
            Port[$3C5] := GDConsts.egaPlaneBit[0];
            srcOff := GDVars.spanHigh[row];
            dstOff := dstBase;
            repeat
              Mem[$A200:dstOff] := Types.PImage(GDVars.viewSurface)^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff)
            until srcOff > GDVars.spanExtra[row];
            Port[$3C5] := GDConsts.egaPlaneBit[1];
            srcOff := GDVars.spanHigh[row] + 1;
            dstOff := dstBase;
            repeat
              Mem[$A200:dstOff] := Types.PImage(GDVars.viewSurface)^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff)
            until srcOff > GDVars.spanExtra[row];
            Port[$3C5] := GDConsts.egaPlaneBit[2];
            srcOff := GDVars.spanHigh[row] + 2;
            dstOff := dstBase;
            repeat
              Mem[$A200:dstOff] := Types.PImage(GDVars.viewSurface)^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff)
            until srcOff > GDVars.spanExtra[row];
            Port[$3C5] := GDConsts.egaPlaneBit[3];
            srcOff := GDVars.spanHigh[row] + 3;
            dstOff := dstBase;
            repeat
              Mem[$A200:dstOff] := Types.PImage(GDVars.viewSurface)^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff)
            until srcOff > GDVars.spanExtra[row]
          end;
        Port[$3C5] := $0F;
        dstOff := GDVars.egaRowOffset[8] + 1;
        Port[$3CE] := 5;
        Port[$3CF] := 1;
        for row := 0 to 167 do begin
          if GDVars.spanActive[row] <> 0 then
            Move(Mem[$A200:dstOff + GDVars.spanLow[row]], Mem[$A000:dstOff + GDVars.spanLow[row]],
                 (GDVars.spanExtra[row] - GDVars.spanHigh[row]) div 4 + 1);
          Inc(dstOff, 40)
        end;
        Port[$3CF] := 0
      end;
    C_Video.VM_TANDY:
      for row := 0 to 167 do
        if GDVars.spanActive[row] <> 0 then
          Move(Types.PImage(GDVars.viewSurface)^.data[GDVars.spanHigh[row]],
               Mem[GDVars.tandyRowSegment[row + 8]:GDVars.spanLow[row] + 4],
               GDVars.spanExtra[row] - GDVars.spanHigh[row] + 1);
    C_Video.VM_VGA:
      for row := 0 to 167 do
        if GDVars.spanActive[row] <> 0 then
          Move(Types.PImage(GDVars.viewSurface)^.data[GDVars.spanHigh[row]],
               Pointer(LongInt($A000) shl 16 + (row + 8) * 320 + GDVars.spanLow[row] + 8)^,
               GDVars.spanExtra[row] - GDVars.spanHigh[row] + 1)
  end;
  GameIo.ZeroFill(GDVars.spanActive, SizeOf(GDVars.spanActive));
  FillChar(GDVars.spanHigh, SizeOf(GDVars.spanHigh), $FF);
  GameIo.ZeroFill(GDVars.spanExtra, SizeOf(GDVars.spanExtra));
  Mouse.ShowMouse
end;

procedure BlankDirtySpans;
var rowIdx: Word;
begin
  if GDVars.graphicsClass <> C_Video.VM_VGA then Exit;
  Mouse.HideMouse;
  for rowIdx := 0 to $A7 do
    if GDVars.spanActive[rowIdx] <> 0 then
      FillChar(Pointer(LongInt($A000) shl 16 + (rowIdx + 8) * $140 + GDVars.spanLow[rowIdx] + 8)^,
               GDVars.spanExtra[rowIdx] - GDVars.spanHigh[rowIdx] + 1, 0);
  Mouse.ShowMouse
end;

procedure RemapPic(fromColors, toColors: Types.TColorTable; frame: Integer; isDithered: Byte; pic: Types.PImage);
var
  srcOff: Word;
  dstOff: Word;
  nFrames: Byte;
  col: Word;
  row: Word;
  match: Byte;
  planeMask: array[0..3] of Byte;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  cellByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  pixPos: Byte;
  rowBytes: Word;
  fromHigh: Byte;
  toHigh: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImage;
begin
  if pic = nil then Exit;
  with Types.PImage(pic)^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := count
    end else nFrames := 1;
    srcOff := frame * frameBytes
  end;
  dstOff := 0;
  Blit.AllocPic(Types.PImage(pic)^.rows, Types.PImage(pic)^.cells, nFrames, 0, scratchPic);
  Types.PImage(scratchPic)^.colorMap := Types.PImage(pic)^.colorMap;
  Move(Types.PImage(pic)^.data[srcOff], Types.PImage(scratchPic)^.data[dstOff],
       Types.PImage(scratchPic)^.frameBytes * Types.PImage(scratchPic)^.count);
  for pairIdx := 0 to 15 do begin
    with Types.PImage(pic)^ do begin
      if frame < 0 then begin
        frame := 0;
        nFrames := count
      end else nFrames := 1;
      srcOff := frame * frameBytes
    end;
    dstOff := 0;
    if fromColors[pairIdx] <> toColors[pairIdx] then
      with Types.PImage(scratchPic)^ do
        case GDVars.graphicsClass of
          C_Video.VM_EGA:
          begin
            for plane := 0 to 3 do
              if (fromColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                planeMask[plane] := 0
              else planeMask[plane] := $FF;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to cells do begin
                  if isDithered <> 0 then
                    match := Random(256) and Random(256)
                  else match := $FF;
                  for plane := 0 to 3 do
                    match := (Types.PImage(pic)^.data[plane + srcOff] xor planeMask[plane]) and match;
                  for plane := 0 to 3 do
                    if (toColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                      data[plane + dstOff] := data[plane + dstOff] or match
                    else
                      data[plane + dstOff] := data[plane + dstOff] and not match;
                  Inc(srcOff, 4);
                  Inc(dstOff, 4)
                end
          end;
          C_Video.VM_TANDY:
          begin
            rowBytes := cells * 4;
            fromHigh := fromColors[pairIdx] shl 4;
            toHigh := toColors[pairIdx] shl 4;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to rowBytes do begin
                  if Types.PImage(pic)^.data[srcOff] and $F0 = fromHigh then
                    if (isDithered = 0) or ((isDithered <> 0) and (Random(4) = 0)) then
                      data[dstOff] := data[dstOff] and $0F or toHigh;
                  if Types.PImage(pic)^.data[srcOff] and $0F = fromColors[pairIdx] then
                    if (isDithered = 0) or ((isDithered <> 0) and (Random(4) = 0)) then
                      data[dstOff] := data[dstOff] and $F0 or toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff)
                end
          end;
          C_Video.VM_VGA:
          begin
            rowBytes := cells * 8;
            for GDVars.scratchIndex := frame to nFrames + frame - 1 do
              for row := 1 to rows do
                for col := 1 to rowBytes do begin
                  if (Types.PImage(pic)^.data[srcOff] = fromColors[pairIdx]) and
                      (fromColors[pairIdx] <> colorKey) then
                    data[dstOff] := toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff)
                end
          end
        end
  end;
  with Types.PImage(pic)^ do
    Move(Types.PImage(scratchPic)^.data, data[frame * frameBytes], nFrames * frameBytes);
  Blit.FreePic(scratchPic)
end;

procedure AllocPic(height, width, count: Word; flag: Byte; var pic: Types.PImage);
var
  frameSize: Word;
  totalSize: Word;
  cellSize: Byte;
begin
  case GDVars.graphicsClass of
    C_Video.VM_VGA: cellSize := 8
    else cellSize := 4
  end;
  frameSize := height * width * cellSize;
  totalSize := frameSize * count;
  DaxIo.SafeGetMem(Pointer(pic), totalSize + 27);
  GameIo.ZeroFill(pic^, totalSize + 27);
  Types.PImage(pic)^.rows := height;
  Types.PImage(pic)^.cells := width;
  Types.PImage(pic)^.frameBytes := frameSize;
  Types.PImage(pic)^.count := count;
  Types.PImage(pic)^.allocSize := totalSize + $1B;
  if ((flag and 1) > 0) and (GDVars.graphicsClass <> C_Video.VM_VGA) then begin
    DaxIo.SafeGetMem(Pointer(Types.PImage(pic)^.mask), totalSize);
    GameIo.ZeroFill(Types.PImage(pic)^.mask^, totalSize)
  end
end;

procedure FreePic(var bank: Types.PImage);
begin
  if bank = nil then Exit;
  with Types.PImage(bank)^ do begin
    if mask <> nil then ZeroFree.PrefixFree(mask, frameBytes * count);
    ZeroFree.PrefixFree(bank, allocSize)
  end;
  bank := nil
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImage);
var
  cellSize: Word;
  clipLeft: Word;
  clipRight: Word;
  clampedX: Word;
  rightMargin: Word;
  runLen: Word;
  lastRow: Word;
  dstOff: Word;
  row: Word;
  planeMask: array[0..3] of Byte;
  absRow: Word;
  screenOfs: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  if x < 0 then begin
    clipLeft := Abs(x);
    clampedX := 0
  end else begin
    clipLeft := 0;
    clampedX := x
  end;
  if Types.PImage(pic)^.cells < x + width then begin
    clipRight := x + width - Types.PImage(pic)^.cells;
    rightMargin := 0
  end else begin
    clipRight := 0;
    rightMargin := Types.PImage(pic)^.cells - (x + width)
  end;
  if y < 0 then begin
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y)
  end else begin
    absRow := y;
    dstOff := absRow * Types.PImage(pic)^.cells;
    lastRow := height - 1;
    if Types.PImage(pic)^.rows < y + height then
      lastRow := Types.PImage(pic)^.rows - 1 - y
    else lastRow := height - 1
  end;
  case GDVars.graphicsClass of
    C_Video.VM_TANDY, C_Video.VM_VGA:
    begin
      case GDVars.graphicsClass of
        C_Video.VM_TANDY: cellSize := 4;
        C_Video.VM_VGA: cellSize := 8
      end;
      runLen := (width - clipLeft - clipRight) * cellSize;
      clampedX := clampedX * cellSize;
      rightMargin := rightMargin * cellSize;
      dstOff := dstOff * cellSize;
      screenOfs := clampedX;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanHigh[absRow] > dstOff then begin
          GDVars.spanLow[absRow] := screenOfs;
          GDVars.spanHigh[absRow] := dstOff
        end;
        case GDVars.graphicsClass of
          C_Video.VM_TANDY: FillChar(Types.PImage(pic)^.data[dstOff], runLen,
                                     GDConsts.packedColorFill[color]);
          C_Video.VM_VGA: FillChar(Types.PImage(pic)^.data[dstOff], runLen, color)
        end;
        Inc(dstOff, runLen);
        if dstOff - 1 > GDVars.spanExtra[absRow] then
          GDVars.spanExtra[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow)
      end
    end;
    C_Video.VM_EGA:
    begin
      screenOfs := clampedX;
      runLen := width - clipLeft - clipRight;
      clampedX := clampedX * 4;
      rightMargin := rightMargin * 4;
      dstOff := dstOff * 4;
      GameIo.ZeroFill(planeMask, SizeOf(planeMask));
      for plane := 0 to 3 do
        if (GDConsts.egaPlaneBit[plane] and color) > 0 then
          planeMask[plane] := $FF;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanHigh[absRow] > dstOff then begin
          GDVars.spanLow[absRow] := screenOfs;
          GDVars.spanHigh[absRow] := dstOff
        end;
        for GDVars.scratchIndex := 1 to runLen do begin
          Move(planeMask, Types.PImage(pic)^.data[dstOff], SizeOf(planeMask));
          Inc(dstOff, 4)
        end;
        if dstOff - 1 > GDVars.spanExtra[absRow] then
          GDVars.spanExtra[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow)
      end
    end
  end
end;

procedure ShadowPaletteEntries(startIdx: Byte; count: Word; var dest);
begin
  if GDVars.graphicsClass <> C_Video.VM_VGA then Exit;
  Move(GDVars.gamePalette[startIdx], Types.PByteBuffer(@dest)^[Word(startIdx) * 3], count * 3)
end;

procedure CopyPaletteEntries(first: Byte; count: Word; src, dst: Pointer);
begin
  if GDVars.graphicsClass <> C_Video.VM_VGA then Exit;
  Move(Types.PByteBuffer(src)^[Word(first) * 3], Types.PByteBuffer(dst)^[Word(first) * 3], count * 3)
end;

procedure SetDacPalette(startIdx, count: Word; src: Types.TPalette);
var
  runLength: Word;
begin
  if GDVars.graphicsClass <> C_Video.VM_VGA then Exit;
  repeat
    while (count <> 0) and (src[startIdx, 0] = GDVars.dacPalette[startIdx, 0]) and
        (src[startIdx, 1] = GDVars.dacPalette[startIdx, 1]) and
        (src[startIdx, 2] = GDVars.dacPalette[startIdx, 2]) do begin
      Inc(startIdx);
      Dec(count)
    end;
    if count = 0 then Exit;
    runLength := 0;
    while (runLength < count) and
        ((src[startIdx + runLength, 0] <> GDVars.dacPalette[startIdx + runLength, 0]) or
         (src[startIdx + runLength, 1] <> GDVars.dacPalette[startIdx + runLength, 1]) or
         (src[startIdx + runLength, 2] <> GDVars.dacPalette[startIdx + runLength, 2])) do
      Inc(runLength);
    Blit.ProgramPaletteOnRetrace(@src[startIdx, 0], startIdx, runLength);
    Move(src[startIdx, 0], GDVars.dacPalette[startIdx, 0], runLength * 3);
    Inc(startIdx, runLength);
    Dec(count, runLength)
  until count = 0
end;

procedure RenderRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                       copyWidth, copyHeight: Byte);
begin
  case GDVars.graphicsClass of
    C_Video.VM_TANDY: Blit.RenderTandyRegion(x, y, frame, sourceSeg, sourceOfs, destSeg, destOfs, sourceX, sourceY,
                                             copyWidth, copyHeight);
    C_Video.VM_EGA: Blit.RenderEgaRegion(x, y, frame, sourceSeg, sourceOfs, destSeg, destOfs, sourceX, sourceY,
                                         copyWidth, copyHeight);
    C_Video.VM_VGA: Blit.RenderVgaRegion(x, y, frame, sourceSeg, sourceOfs, destSeg, destOfs, sourceX, sourceY,
                                         copyWidth, copyHeight)
  end
end;

procedure PlotViewPixel(x, y: Integer; color: Byte);
begin
  if (x < 8) or (x > 199) or (y < 8) or (y > 87) then Exit;
  GDVars.regs.AH := $0C;
  GDVars.regs.AL := color;
  GDVars.regs.BH := 0;
  GDVars.regs.CX := x;
  GDVars.regs.DX := y;
  Intr($10, Registers(GDVars.regs))
end;

procedure CopyIconTile(kind, tileIdx, frame, isMirrored: Byte);
var
  tmp: Types.PImage;
  frameSize: Word;
  frameOfs: Word;
begin
  frameSize := Types.PImage(GDVars.combatImage)^.frameBytes;
  frameOfs := frame * frameSize;
  if isMirrored <> 0 then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.iconSet[kind, tileIdx], tmp);
    Move(Types.PImage(tmp)^.data, Types.PImage(GDVars.combatImage)^.data[frameOfs], frameSize);
    Types.PImage(GDVars.combatImage)^.colorKey := Types.PImage(GDVars.iconSet[kind, tileIdx])^.colorKey;
    if Types.PImage(tmp)^.mask <> nil then
      Move(Types.PImage(tmp)^.mask^, Types.PImage(GDVars.combatImage)^.mask^[frameOfs], frameSize);
    Blit.FreePic(tmp)
  end else begin
    Move(Types.PImage(GDVars.iconSet[kind, tileIdx])^.data, Types.PImage(GDVars.combatImage)^.data[frameOfs],
         frameSize);
    Types.PImage(GDVars.combatImage)^.colorKey := Types.PImage(GDVars.iconSet[kind, tileIdx])^.colorKey;
    if Types.PImage(GDVars.iconSet[kind, tileIdx])^.mask <> nil then
      Move(Types.PImage(GDVars.iconSet[kind, tileIdx])^.mask^,
           Types.PImage(GDVars.combatImage)^.mask^[frameOfs], frameSize)
  end
end;

procedure BuildIconFrames(kind: Byte);
begin
  Blit.CopyIconTile(kind, 0, 0, 0);
  Blit.CopyIconTile(kind, 0, 1, 1);
  Blit.CopyIconTile(kind, 1, 2, 1);
  Blit.CopyIconTile(kind, 1, 3, 0)
end;

procedure ShowPicMasked(screenX, screenY: Integer; pic: Pointer; frame: Byte);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  screenByte: Byte;
  transpColor: Byte;
begin
  if pic = nil then Exit;
  if (Types.PImage(pic)^.rows = 0) or (Types.PImage(pic)^.cells = 0) then Exit;
  if (GDVars.graphicsClass <> C_Video.VM_VGA) and (Types.PImage(pic)^.mask = nil) then Exit;
  transpColor := Types.PImage(pic)^.colorKey;
  srcOff := frame * Types.PImage(pic)^.frameBytes;
  with Types.PImage(pic)^ do
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
      begin
        if screenY <= $18 then firstRow := screenY * 8
        else firstRow := (screenY - $19) * 9 + $8A;
        colOff := screenX;
        lastRow := firstRow + rows - 1;
        colOff := screenX;
        colEnd := colOff + cells - 1;
        Port[$3CE] := 8;
        Port[$3C4] := 2;
        for row := firstRow to lastRow do
          for col := colOff to colEnd do begin
            Port[$3CF] := Types.PImage(pic)^.mask^[srcOff] xor $FF;
            screenByte := Mem[$A000:GDVars.egaRowOffset[row] + col];
            for plane := 0 to 3 do begin
              Port[$3C5] := GDConsts.egaPlaneBit[plane];
              Mem[$A000:GDVars.egaRowOffset[row] + col] := Types.PImage(pic)^.data[srcOff];
              Inc(srcOff)
            end
          end;
        Port[$3CF] := $FF;
        Port[$3C5] := $0F
      end;
      C_Video.VM_TANDY:
      begin
        rowBytes := cells * 4;
        if screenY <= $18 then firstRow := screenY * 8
        else firstRow := (screenY - $19) * 9 + $8A;
        lastRow := firstRow + rows - 1;
        colOff := screenX * 4;
        colEnd := colOff + rowBytes - 1;
        for row := firstRow to lastRow do
          for col := colOff to colEnd do begin
            Mem[GDVars.tandyRowSegment[row]:col] := (Mem[GDVars.tandyRowSegment[row]:col] and
                                                 Types.PImage(pic)^.mask^[srcOff]) or
                                                   Types.PImage(pic)^.data[srcOff];
            Inc(srcOff)
          end
      end;
      C_Video.VM_VGA:
      begin
        rowBytes := cells * 8;
        if screenY <= $18 then firstRow := screenY * 8
        else firstRow := (screenY - $19) * 9 + $8A;
        lastRow := firstRow + rows - 1;
        colOff := screenX * 8;
        colEnd := colOff + rowBytes - 1;
        for row := firstRow to lastRow do
          for col := colOff to colEnd do begin
            if Types.PImage(pic)^.data[srcOff] <> transpColor then
              Mem[$A000:row * $140 + col] := Types.PImage(pic)^.data[srcOff];
            Inc(srcOff)
          end
      end
    end
end;

procedure DrawFramePart(screenX, screenY: Integer; pic: Pointer; frame, sourceX, sourceY, copyWidth, copyHeight: Byte);
var
  col: Integer;
  row: Integer;
  xStart: Word;
  yStart: Word;
  xEnd: Word;
  yEnd: Word;
  rowStride: Word;
  rowBytes: Word;
  dataOffset: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with Types.PImage(pic)^ do
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
      begin
        rowStride := cells shl 2;
        rowBytes := copyWidth shl 2;
        dataOffset := frame * Types.PImage(pic)^.frameBytes + (sourceY shl 3) * rowStride + sourceX * 4;
        yStart := screenY shl 3;
        yEnd := yStart + (copyHeight shl 3) - 1;
        xStart := screenX;
        xEnd := xStart + copyWidth - 1;
        Port[$3C4] := 2;
        for row := yStart to yEnd do begin
          for col := xStart to xEnd do
            for plane := 0 to 3 do begin
              Port[$3C5] := GDConsts.egaPlaneBit[plane];
              Mem[$A000:GDVars.egaRowOffset[row] + col] := Types.PImage(pic)^.data[dataOffset];
              Inc(dataOffset)
            end;
          Inc(dataOffset, rowStride - rowBytes)
        end;
        Port[$3C5] := $0F
      end;
      C_Video.VM_TANDY:
      begin
        rowStride := cells shl 2;
        dataOffset := frame * Types.PImage(pic)^.frameBytes + (sourceY shl 3) * rowStride + (sourceX shl 2);
        rowBytes := copyWidth shl 2;
        yStart := screenY shl 3;
        yEnd := yStart + (copyHeight shl 3) - 1;
        xStart := screenX shl 2;
        for row := yStart to yEnd do begin
          Move(Types.PImage(pic)^.data[dataOffset], Mem[GDVars.tandyRowSegment[row]:xStart], rowBytes);
          Inc(dataOffset, rowStride)
        end
      end;
      C_Video.VM_VGA:
      begin
        rowStride := cells shl 3;
        dataOffset := frame * Types.PImage(pic)^.frameBytes + (sourceY shl 3) * rowStride + (sourceX shl 3);
        rowBytes := copyWidth shl 3;
        yStart := screenY shl 3;
        yEnd := yStart + (copyHeight shl 3) - 1;
        xStart := screenX shl 3;
        for row := yStart to yEnd do begin
          Move(Types.PImage(pic)^.data[dataOffset], Mem[$A000:xStart + row * $140], rowBytes);
          Inc(dataOffset, rowStride)
        end
      end
    end
end;

procedure ShowPicRecolored(screenX, screenY: Integer; pic: Pointer; frame, color, bgColor: Byte);
var
  packedMask: Byte;
  col: Integer;
  row: Integer;
  xStart: Word;
  yStart: Word;
  xEnd: Word;
  yEnd: Word;
  rowStride: Word;
  dataOffset: Word;
  plane: Byte;
  { Unused in this version; see the other implementations of this routine. }
  screenByte: Byte;
  { Unused in this version; see the other implementations of this routine. }
  transparentColor: Byte;
  planeEnabled: array[0..3] of Boolean;
begin
  if pic = nil then Exit;
  if (Types.PImage(pic)^.rows = 0) or (Types.PImage(pic)^.cells = 0) then Exit;
  if (GDVars.graphicsClass <> C_Video.VM_VGA) and (Types.PImage(pic)^.mask = nil) then Exit;
  if (color = $0F) and (bgColor = 0) then
    Blit.ShowPicMasked(screenX, screenY, pic, frame);
  transparentColor := Types.PImage(pic)^.colorKey;
  dataOffset := frame * Types.PImage(pic)^.frameBytes;
  with Types.PImage(pic)^ do
    case GDVars.graphicsClass of
      C_Video.VM_EGA:
      begin
        if screenY <= $18 then yStart := screenY * 8
        else yStart := (screenY - $19) * 9 + $8A;
        yEnd := yStart + rows - 1;
        xStart := screenX;
        xEnd := xStart + cells - 1;
        Port[$3CE] := 8;
        Port[$3C4] := 2;
        FillChar(planeEnabled, SizeOf(planeEnabled), 0);
        planeEnabled[0] := (color and 1) <> 0;
        planeEnabled[1] := (color and 2) <> 0;
        planeEnabled[2] := (color and 4) <> 0;
        planeEnabled[3] := (color and 8) <> 0;
        for row := yStart to yEnd do
          for col := xStart to xEnd do begin
            Port[$3CF] := Types.PImage(pic)^.mask^[dataOffset] xor $FF;
            screenByte := Mem[$A000:GDVars.egaRowOffset[row] + col];
            for plane := 0 to 3 do begin
              Port[$3C5] := GDConsts.egaPlaneBit[plane];
              if planeEnabled[plane] then
                Mem[$A000:GDVars.egaRowOffset[row] + col] := Types.PImage(pic)^.data[dataOffset]
              else
                Mem[$A000:GDVars.egaRowOffset[row] + col] := 0;
              Inc(dataOffset)
            end
          end;
        Port[$3CF] := $FF;
        Port[$3C5] := $0F
      end;
      C_Video.VM_TANDY:
      begin
        rowStride := cells * 4;
        if screenY <= $18 then yStart := screenY * 8
        else yStart := (screenY - $19) * 9 + $8A;
        yEnd := yStart + rows - 1;
        xStart := screenX * 4;
        xEnd := xStart + rowStride - 1;
        packedMask := (color shl 4) or (color and $0F);
        for row := yStart to yEnd do
          for col := xStart to xEnd do begin
            Mem[GDVars.tandyRowSegment[row]:col] := (Mem[GDVars.tandyRowSegment[row]:col] and
                                                 Types.PImage(pic)^.mask^[dataOffset]) or
                                                   (Types.PImage(pic)^.data[dataOffset] and packedMask);
            Inc(dataOffset)
          end
      end;
      C_Video.VM_VGA:
      begin
        if screenY <= $18 then
          Blit.BlitVgaRecolored(screenX shl 3, screenY shl 3, cells shl 3, rows, $0D, color,
                                @Types.PImage(pic)^.data[dataOffset])
        else
          Blit.BlitVgaRecolored(screenX shl 3, (screenY - $19) * 9 + $8A, cells shl 3, rows, $0D, color,
                           @Types.PImage(pic)^.data[dataOffset])
      end
    end
end;

{$F-}
{$L GRAPHICS.OBJ}
{ Draws a frame of a graphic opaque into an EGA buffer (four plane bytes per cell) at a character-cell position,
  unclipped, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into an EGA
  buffer (four plane bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellEgaMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic into an EGA buffer (four plane bytes per cell) at a character-cell position, clipped
  against the edges of dest, opaque or masked as flag asks, and marks the touched scanlines dirty for FlushView. A frame
  lying entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of
  step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedEga(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                         dest: Types.PImage); external;

{ Draws a frame of a graphic opaque into a Tandy buffer (four bytes per cell) at a character-cell position, unclipped,
  and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandy(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic through its transparency mask, keeping the background where the mask is set, into a Tandy
  buffer (four bytes per cell) at a character-cell position, unclipped, and marks the touched scanlines dirty for
  FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellTandyMasked(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic into a Tandy buffer (four bytes per cell) at a character-cell position, clipped against the
  edges of dest, opaque or masked as flag asks, and marks the touched scanlines dirty for FlushView. A frame lying
  entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing masked with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects masked drawing; bit 2 saves the covered bytes when drawing masked.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedTandy(under: Types.PImage; screenX, screenY: Integer; tileIdx, flag: Byte; gfx,
                           dest: Types.PImage); external;

{ Draws a frame of a graphic opaque into a VGA buffer (eight bytes per cell) at a character-cell position, unclipped,
  and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVga(screenX, screenY: Integer; tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic into a VGA buffer (eight bytes per cell) at a character-cell position, unclipped, keeping
  the background where a pixel is transpColor, and marks the touched scanlines dirty for FlushView.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(transpColor The color left out.)
  @param(tileIdx Frame within gfx to draw.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitCellVgaKeyed(screenX, screenY: Integer; transpColor, tileIdx: Byte; gfx, dest: Types.PImage); external;

{ Draws a frame of a graphic into a VGA buffer (eight bytes per cell) at a character-cell position, clipped against the
  edges of dest, opaque or keyed on transpColor as flag asks, and marks the touched scanlines dirty for FlushView. A
  frame lying entirely off dest is skipped. Note: an opaque frame cut at the left or right edge is drawn with its rows
  out of step.
  @param(under Save-under buffer, which receives the covered bytes when drawing keyed with bit 2 of flag set.)
  @param(screenX Left edge, in character columns; may be negative.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative.)
  @param(transpColor The color left out when drawing keyed.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 selects keyed drawing; bit 2 saves the covered bytes when drawing keyed.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into.) }
procedure BlitClippedVga(under: Types.PImage; screenX, screenY: Integer; transpColor, tileIdx, flag: Byte; gfx,
                         dest: Types.PImage); external;

{ Waits for vertical retrace and then loads DAC entries.
  @param(palette The first entry's color.)
  @param(startIdx The first DAC entry.)
  @param(count The number of entries.) }
procedure ProgramPaletteOnRetrace(palette: Pointer; startIdx, count: Word); external;

{ Copies a region of an EGA image into another, in GRAPHICS.OBJ.
  @param(x The destination column.)
  @param(y The destination row.)
  @param(frame The frame.)
  @param(sourceSeg The source image's segment.)
  @param(sourceOfs The source image's offset.)
  @param(destSeg The destination image's segment.)
  @param(destOfs The destination image's offset.)
  @param(sourceX The first source column.)
  @param(sourceY The first source row.)
  @param(copyWidth The width copied, in cells.)
  @param(copyHeight The height copied, in cells.) }
procedure RenderEgaRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                          copyWidth, copyHeight: Word); external;

{ Copies a region of a Tandy image into another, in GRAPHICS.OBJ.
  @param(x The destination column.)
  @param(y The destination row.)
  @param(frame The frame.)
  @param(sourceSeg The source image's segment.)
  @param(sourceOfs The source image's offset.)
  @param(destSeg The destination image's segment.)
  @param(destOfs The destination image's offset.)
  @param(sourceX The first source column.)
  @param(sourceY The first source row.)
  @param(copyWidth The width copied, in cells.)
  @param(copyHeight The height copied, in cells.) }
procedure RenderTandyRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                            copyWidth, copyHeight: Word); external;

{ Copies a region of a VGA image into another, in GRAPHICS.OBJ.
  @param(x The destination column.)
  @param(y The destination row.)
  @param(frame The frame.)
  @param(sourceSeg The source image's segment.)
  @param(sourceOfs The source image's offset.)
  @param(destSeg The destination image's segment.)
  @param(destOfs The destination image's offset.)
  @param(sourceX The first source column.)
  @param(sourceY The first source row.)
  @param(copyWidth The width copied, in cells.)
  @param(copyHeight The height copied, in cells.) }
procedure RenderVgaRegion(x, y: Word; frame: Byte; sourceSeg, sourceOfs, destSeg, destOfs: Word; sourceX, sourceY,
                          copyWidth, copyHeight: Word); external;

{ Draws VGA pixel rows straight to the screen, recolored: pixels of color $0F take color, pixels of the key color are
  skipped and the rest are copied; in GRAPHICS.OBJ.
  @param(x The pixel column.)
  @param(y The pixel row.)
  @param(rowBytes The bytes per row.)
  @param(rows The rows.)
  @param(transpColor The key color.)
  @param(color The color that replaces $0F.)
  @param(data The first pixel.) }
procedure BlitVgaRecolored(x, y, rowBytes, rows: Word; transpColor, color: Byte; data: Pointer); external;
{$F+}

begin
  GDVars.bankLoader := Blit.LoadPicFromList;
  GDVars.maskedRender := Blit.ShowPicRecolored;
  FillChar(GDVars.dacPalette, SizeOf(GDVars.dacPalette), $FF)
end.
