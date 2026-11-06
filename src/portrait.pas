{ Portrait -- the picture overlay. It loads an animated picture (a PIC portrait or a SPRIT 3-D sprite) from its DAX
  archive into frames, draws a frame or a sprite, frees them, loads and draws the area's big picture (BIGPIC1.DAX), and
  cycles a palette range. The initializer installs FreeAnimation as GDVars.freeAnimationHook. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Portrait;

interface

type TResourceName = String[8];

{ Shows a frame of the loaded animation at a character cell with the mouse cursor hidden, doing nothing when that frame
  is not loaded. A VGA frame other than a sprite is first decoded into the display image.
  @param(col Character column.)
  @param(row Character row.)
  @param(ignoredAnimate Overwritten with False, so the frame always goes straight to the screen rather than through the
    view buffer.)
  @param(frameIndex The frame; not range-checked.) }
procedure DisplayImageBuf(col, row: Integer; ignoredAnimate: Boolean; frameIndex: Byte);

{ Loads picture resourceId of archiveName ('PIC' or 'SPRIT'; archives archiveName + '1' and + '1a') into frames; nothing
  happens for resourceId 255. When it is already the loaded one, only its palette is programmed again. It frees the
  previous frames, reads the header (size, display position, last frame, the palette slice and its nibble map, the cycle
  chunk, the key frame and the frame sizes) and builds the frames: on VGA a PIC keeps its run-length frames and expands
  only the key frame into a full one; otherwise every frame is expanded, XORed with the key frame and built for the
  current graphics class, and SPRIT frames swap color 0 with the transparent color 13. For a PIC whose id is
  gameState^.resourceId it also loads block gameState^.pictureId into a scratch picture and frees it at once. Last it
  programs the palette (entries 176.. for SPRIT; for a PIC it clears the portrait box and programs entries 32..) and
  arms cycling unless the archive is SPRIT. A missing block shows 'PIC not found'; with the editor and debug flags set
  it shows 'seq <name> <id>'.
  @param(archiveName Base name of the DAX file, without the disk digit.)
  @param(resourceId Picture number within the file; 255 loads nothing.)
  @param(transparentColor Passed to AllocPic as its flag (bit 0 asks for a mask) and to ExpandPicFrames.) }
procedure LoadAnimation(archiveName: TResourceName; resourceId, transparentColor: Byte);

{ Frees the loaded animation's frames (on VGA, a PIC's encoded frames and the display image), clears the frame table,
  and forgets which animation is loaded, so the next LoadAnimation reloads. }
procedure FreeAnimation;

{ Draws the sprite frame for a distance clipped into the view buffer, at the frame's own origin, and flushes the view to
  the screen; a missing frame draws nothing. A distance outside 1..3 is a fatal error, reported in text mode.
  @param(distance 1 near, 2 middle, 3 far.) }
procedure Show3DSprite(distance: Byte);

{ Frees any animation and the extra pictures, then loads a big picture from BIGPIC1.DAX and arms its palette cycling
  (picture 242 gets the special preset), unless it is already loaded, in which case only the cycling and its palette are
  restored. A new picture shows the loading message, redraws the base frame unless it is picture 244, and clears the
  bottom line.
  @param(pictureId Picture number.) }
procedure LoadBigPic(pictureId: Byte);

{ Shows the big picture at its own display position, with the mouse cursor hidden. }
procedure DisplayBigPic;

{ Rotates a color range of the current preset by one entry into GDVars.gamePalette, then shadows and programs the range
  from the source palette: GDVars.activePalette while the cycle index is set, else GDVars.paletteA. MenuCore's input
  loop calls this on each range's delay. Note: a range with a zero color count underflows the palette indices and the
  Move extent.
  @param(rangeIndex The range within GDVars.palettePreset.) }
procedure CyclePaletteRange(rangeIndex: Byte);

implementation

uses Types, Crt, GDConsts, GDVars, C_Video, Blit, Mouse, ZeroFree, GameIo,
  TextRend, Border, DaxIo, VgaFrame;

const
  { the key color of a decoded frame }
  DEFAULT_TRANSPARENT_COLOR = 13;
  { the resource id of no picture }
  NO_RESOURCE_ID = 255;

var
  frameKinds: array[0..30] of Byte absolute GDVars.menuAnimDelays;

{ Arms palette cycling when the loaded picture has cycle data (GDVars.savedCycleChunk32[1] nonzero): cycling on, the
  cycle index 0 and the preset cleared, then its first chunk taken from savedCycleChunk32. Otherwise cycling stays
  off. }
procedure InitPaletteState;
begin
  GDVars.palettePresetOn := 0;
  if not Boolean(GDVars.savedCycleChunk32[1]) then Exit;
  GDVars.palettePresetOn := 1;
  GDVars.overMapCycle := 0;
  FillChar(GDVars.palettePreset, SizeOf(GDVars.palettePreset), 0);
  GDVars.palettePreset[1] := GDVars.savedCycleChunk32;
end;

procedure DisplayImageBuf(col, row: Integer; ignoredAnimate: Boolean; frameIndex: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameName: array[1..14] of Byte;
begin
  if ((GDVars.graphicsClass = C_Video.VM_VGA) and (GDVars.vgaState.frames[frameIndex] = nil)) or
      (((GDVars.graphicsClass <> C_Video.VM_VGA) or GDVars.spriteArchive) and
       (GDVars.imageFrames[frameIndex] = nil)) then Exit;
  if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then
    VgaFrame.PrepareVgaFrame(frameIndex);
  ignoredAnimate := False;
  if ignoredAnimate then begin
    if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, GDVars.vgaState.displayImage, GDVars.viewSurface)
    else
      Blit.BlitTileClipped(col - 1, row - 1, 0, 0, GDVars.imageFrames[frameIndex], GDVars.viewSurface);
    Blit.FlushView;
  end else begin
    Mouse.HideMouse;
    if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then
      Blit.DrawFirstFrame(col, row, GDVars.vgaState.displayImage)
    else
      Blit.DrawFirstFrame(col, row, GDVars.imageFrames[frameIndex]);
    Mouse.ShowMouse
  end
end;

procedure LoadAnimation(archiveName: TResourceName; resourceId, transparentColor: Byte);
var
  imageX: Word;
  imageY: Word;
  frameNumber: Integer;
  pixelOffset: Word;
  lastLoadedFrame: Byte;
  paletteFirst: Byte;
  paletteCount: Byte;
  xorFrame: Types.PByteBuffer;
  workBuffer: Types.PByteBuffer;
  resourceData: Types.PByteBuffer;
  decodedBytes: Word;
  imageHeight: Word;
  imageWidth: Word;
  { Unused in this version; see the other implementations of this routine. }
  frameSize: Word;
  resourceSize: Word;
  frameDataOffset: Word;
  dataOffset: Word;
  archiveSuffix: String[1];
  workBufferSize: Word;
  scratchPicture: Types.PImage;
begin
  if resourceId = Portrait.NO_RESOURCE_ID then Exit;
  GDVars.palettePresetOn := 0;
  if (archiveName = GDVars.resourceCurrentName) and (resourceId = GDVars.resourceCurrentId) then begin
    if GDVars.spriteArchive then begin
      Blit.SetDacPalette(176, 80, GDVars.paletteA)
    end else begin
      Border.BlankBox(3, 3, 13, 13);
      Blit.SetDacPalette(32, 224, GDVars.paletteA)
    end;
    if archiveName <> 'SPRIT' then Portrait.InitPaletteState;
    Exit
  end;
  if GDVars.bigPicture <> nil then Blit.FreePic(GDVars.bigPicture);
  TextRend.DisplayLoading;
  if (GDConsts.editorEnabled) and (GDConsts.debugToggle) then begin
    GDVars.bottomMessageHook('seq ' + archiveName + ' ' + GDVars.intToStringHook(resourceId))
  end;
  Portrait.FreeAnimation;
  GameIo.ZeroFill(frameKinds, SizeOf(frameKinds));
  GDVars.resourceCurrentName := archiveName;
  GDVars.spriteArchive := UpCase(archiveName[1]) = 'S';
  GDVars.resourceCurrentId := resourceId;
  archiveSuffix := '1';
  DaxIo.LoadDaxFromList(archiveName + archiveSuffix + ',' + archiveName + archiveSuffix + 'a', '.dax', resourceId,
                 resourceSize, resourceData, 1);
  if resourceSize = 0 then begin
    TextRend.DisplayAndPause(Yellow, Black, 'PIC not found');
    Exit
  end;
  dataOffset := 0;
  Move(resourceData^[dataOffset], imageHeight, SizeOf(imageHeight)); Inc(dataOffset, SizeOf(imageHeight));
  Move(resourceData^[dataOffset], imageWidth, SizeOf(imageWidth)); Inc(dataOffset, SizeOf(imageWidth));
  Move(resourceData^[dataOffset], imageX, SizeOf(imageX)); Inc(dataOffset, SizeOf(imageX));
  Move(resourceData^[dataOffset], imageY, SizeOf(imageY)); Inc(dataOffset, SizeOf(imageY));
  Move(resourceData^[dataOffset], lastLoadedFrame, SizeOf(lastLoadedFrame)); Inc(dataOffset);
  if lastLoadedFrame > 8 then lastLoadedFrame := 8;
  GDVars.lastFrameIndex := lastLoadedFrame;
  Move(resourceData^[dataOffset], paletteFirst, SizeOf(paletteFirst)); Inc(dataOffset);
  Move(resourceData^[dataOffset], paletteCount, SizeOf(paletteCount)); Inc(dataOffset);
  Move(resourceData^[dataOffset], GDVars.gamePalette[paletteFirst], paletteCount * 3);
  Inc(dataOffset, paletteCount * 3);
  for frameNumber := 0 to (paletteCount shr 1) - 1 do begin
    GDVars.gfxNibbleTable[paletteFirst + frameNumber * 2] := resourceData^[dataOffset] shr 4;
    GDVars.gfxNibbleTable[paletteFirst + frameNumber * 2 + 1] := resourceData^[dataOffset] and $0F;
    Inc(dataOffset)
  end;
  FillChar(GDVars.picCycleChunk3, SizeOf(GDVars.picCycleChunk3), 0);
  if resourceData^[dataOffset] = 1 then
    Move(resourceData^[dataOffset + 1], GDVars.picCycleChunk3, SizeOf(GDVars.picCycleChunk3));
  Inc(dataOffset, 4);
  Move(resourceData^[dataOffset], GDVars.keyFrameIndex, SizeOf(GDVars.keyFrameIndex)); Inc(dataOffset);
  Move(resourceData^[dataOffset], GDVars.firstFrameIndex, SizeOf(GDVars.firstFrameIndex)); Inc(dataOffset);
  for frameNumber := 0 to lastLoadedFrame do begin
    Move(resourceData^[dataOffset], GDVars.frameSizes[frameNumber], SizeOf(GDVars.frameSizes[frameNumber]));
    Move(resourceData^[dataOffset + 2], frameKinds[frameNumber], SizeOf(frameKinds[frameNumber]));
    Inc(dataOffset, 3)
  end;
  if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then begin
    Blit.AllocPic(imageHeight, imageWidth, 1, transparentColor, GDVars.vgaState.displayImage);
    Types.PImage(GDVars.vgaState.displayImage)^.colorKey := Portrait.DEFAULT_TRANSPARENT_COLOR;
    Types.PImage(GDVars.vgaState.displayImage)^.displayX := imageX;
    Types.PImage(GDVars.vgaState.displayImage)^.displayY := imageY
  end;
  workBufferSize := 7744;
  for frameNumber := 0 to lastLoadedFrame do
    if GDVars.frameSizes[frameNumber] > workBufferSize then
      workBufferSize := GDVars.frameSizes[frameNumber];
  DaxIo.SafeGetMem(Pointer(workBuffer), workBufferSize);
  if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then begin
    for frameNumber := 0 to lastLoadedFrame do begin
      if frameNumber = GDVars.keyFrameIndex then begin
        DaxIo.SafeGetMem(Pointer(GDVars.vgaState.frames[frameNumber]), 7744);
        Move(resourceData^[dataOffset], workBuffer^, GDVars.frameSizes[frameNumber]);
        VgaFrame.ExpandRleFrame(workBuffer, GDVars.vgaState.frames[frameNumber], GDVars.frameSizes[frameNumber])
      end else begin
        DaxIo.SafeGetMem(Pointer(GDVars.vgaState.frames[frameNumber]), GDVars.frameSizes[frameNumber]);
        Move(resourceData^[dataOffset], GDVars.vgaState.frames[frameNumber]^, GDVars.frameSizes[frameNumber])
      end;
      Inc(dataOffset, GDVars.frameSizes[frameNumber])
    end
  end else begin
    DaxIo.SafeGetMem(Pointer(xorFrame), 7744);
    frameDataOffset := dataOffset;
    frameNumber := 0;
    while frameNumber < GDVars.keyFrameIndex do begin
      Inc(dataOffset, GDVars.frameSizes[frameNumber]);
      Inc(frameNumber)
    end;
    VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], xorFrame, GDVars.frameSizes[GDVars.keyFrameIndex]);
    dataOffset := frameDataOffset;
    for frameNumber := 0 to lastLoadedFrame do begin
      Blit.AllocPic(imageHeight, imageWidth, 1, transparentColor, GDVars.imageFrames[frameNumber]);
      Types.PImage(GDVars.imageFrames[frameNumber])^.displayX := imageX;
      Types.PImage(GDVars.imageFrames[frameNumber])^.displayY := imageY;
      Types.PImage(GDVars.imageFrames[frameNumber])^.colorKey := Portrait.DEFAULT_TRANSPARENT_COLOR;
      if frameNumber <> GDVars.keyFrameIndex then begin
        VgaFrame.ExpandRleFrame(@resourceData^[dataOffset], workBuffer, GDVars.frameSizes[frameNumber]);
        VgaFrame.XorFrame(workBuffer, workBuffer, xorFrame, 7744);
        if GDVars.spriteArchive then
          for pixelOffset := 0 to 7743 do
            case workBuffer^[pixelOffset] of
              0: workBuffer^[pixelOffset] := Portrait.DEFAULT_TRANSPARENT_COLOR;
              Portrait.DEFAULT_TRANSPARENT_COLOR: workBuffer^[pixelOffset] := 0
            end;
        decodedBytes := 0;
        Blit.ExpandPicFrames(workBuffer, decodedBytes, transparentColor, Portrait.DEFAULT_TRANSPARENT_COLOR,
                        GDVars.imageFrames[frameNumber])
      end;
      Inc(dataOffset, GDVars.frameSizes[frameNumber])
    end;
    if GDVars.spriteArchive then
      for pixelOffset := 0 to 7743 do
        case xorFrame^[pixelOffset] of
          0: xorFrame^[pixelOffset] := Portrait.DEFAULT_TRANSPARENT_COLOR;
          Portrait.DEFAULT_TRANSPARENT_COLOR: xorFrame^[pixelOffset] := 0
        end;
    decodedBytes := 0;
    Blit.ExpandPicFrames(xorFrame, decodedBytes, transparentColor, Portrait.DEFAULT_TRANSPARENT_COLOR,
                    GDVars.imageFrames[GDVars.keyFrameIndex]);
  ZeroFree.PrefixFree(xorFrame, 7744)
  end;
  ZeroFree.PrefixFree(resourceData, resourceSize);
  ZeroFree.PrefixFree(workBuffer, workBufferSize);
  if UpCase(archiveName[1]) = 'P' then
    if GDVars.gameState^.resourceId = resourceId then begin
      scratchPicture := nil;
      Blit.LoadPicFromList(archiveName + archiveSuffix + ',' + archiveName + archiveSuffix + 'a',
                           GDVars.gameState^.pictureId, 0,
                      13, scratchPicture);
      Blit.FreePic(scratchPicture)
    end;
  if GDVars.spriteArchive then begin
    Blit.ShadowPaletteEntries(176, 80, GDVars.paletteA);
    Blit.SetDacPalette(176, 80, GDVars.paletteA)
  end else begin
    Border.BlankBox(3, 3, 13, 13);
    Blit.ShadowPaletteEntries(32, 224, GDVars.paletteA);
    Blit.SetDacPalette(32, 224, GDVars.paletteA)
  end;
  GDVars.savedCycleChunk32 := GDVars.picCycleChunk3;
  if archiveName <> 'SPRIT' then Portrait.InitPaletteState
end;

procedure FreeAnimation;
begin
  if (GDVars.graphicsClass = C_Video.VM_VGA) and not GDVars.spriteArchive then begin
    for GDVars.scratchIndex := 0 to GDVars.lastFrameIndex do
      if GDVars.vgaState.frames[GDVars.scratchIndex] <> nil then
        if GDVars.scratchIndex = GDVars.keyFrameIndex then
          ZeroFree.PrefixFree(GDVars.vgaState.frames[GDVars.scratchIndex], 7744)
        else
          ZeroFree.PrefixFree(GDVars.vgaState.frames[GDVars.scratchIndex],
                              GDVars.frameSizes[GDVars.scratchIndex]);
    Blit.FreePic(GDVars.vgaState.displayImage);
    GameIo.ZeroFill(GDVars.vgaState.frames, 66)
  end else begin
    for GDVars.scratchIndex := 0 to GDVars.lastFrameIndex do
      Blit.FreePic(GDVars.imageFrames[GDVars.scratchIndex]);
    GameIo.ZeroFill(GDVars.imageFrames, SizeOf(GDVars.imageFrames))
  end;
  GDVars.resourceCurrentName[0] := #0;
  GDVars.resourceCurrentId := Portrait.NO_RESOURCE_ID
end;

procedure Show3DSprite(distance: Byte);
begin
  if (distance < 1) or (distance > 3) then
    GDVars.fatalMessageHook('Illegal range in Show3DSprite.');
  if GDVars.imageFrames[distance - 1] = nil then Exit;
  Blit.BlitTileClipped(2, 2, 0, 1, GDVars.imageFrames[distance - 1], GDVars.viewSurface);
  Blit.FlushView
end;

{ Arms palette cycling with the three fixed cycle chunks GDConsts.specialChunk0..2, big picture 242's. }
procedure LoadSpecialPreset;
begin
  GDVars.palettePresetOn := 1;
  GDVars.overMapCycle := 0;
  FillChar(GDVars.palettePreset, SizeOf(GDVars.palettePreset), 0);
  GDVars.palettePreset[1] := GDConsts.specialChunk0;
  GDVars.palettePreset[2] := GDConsts.specialChunk1;
  GDVars.palettePreset[3] := GDConsts.specialChunk2
end;

procedure LoadBigPic(pictureId: Byte);
begin
  Portrait.FreeAnimation;
  Blit.FreePic(GDConsts.extraPictureA);
  Blit.FreePic(GDVars.backdropImage);
  Blit.FreePic(GDVars.skyImage);
  Blit.FreePic(GDVars.banks[0]);
  Blit.FreePic(GDVars.banks[1]);
  Blit.FreePic(GDVars.banks[2]);
  if (GDVars.bigPicId = pictureId) and (GDVars.bigPicture <> nil) then begin
    Portrait.InitPaletteState;
    Blit.SetDacPalette(32, 224, GDVars.paletteA)
  end else begin
    TextRend.DisplayLoading;
    Blit.LoadPic('bigpic1', pictureId, 0, 0, GDVars.bigPicture);
    GDVars.savedCycleChunk32 := GDVars.picCycleChunk3;
    Portrait.InitPaletteState;
    if pictureId = 242 then Portrait.LoadSpecialPreset;
    GDVars.bigPicId := pictureId;
    Blit.ShadowPaletteEntries(32, 224, GDVars.paletteA);
    if GDVars.bigPicId <> 244 then Border.ScreenText;
    Blit.SetDacPalette(32, 224, GDVars.gamePalette);
    TextRend.ClearStatusLine
  end
end;

procedure DisplayBigPic;
begin
  Mouse.HideMouse;
  Blit.DrawFirstFrame(Types.PImage(GDVars.bigPicture)^.displayX + 1, Types.PImage(GDVars.bigPicture)^.displayY + 1,
                      GDVars.bigPicture);
  Mouse.ShowMouse
end;

procedure CyclePaletteRange(rangeIndex: Byte);
var
  firstColor: Byte;
  colorCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  colorIndex: Word;
begin
  firstColor := GDVars.palettePreset[rangeIndex][0];
  colorCount := GDVars.palettePreset[rangeIndex][1];
  if GDVars.overMapCycle <> 0 then begin
    Move(GDVars.activePalette[firstColor], GDVars.gamePalette[firstColor + 1], (colorCount - 1) * 3);
    Move(GDVars.activePalette[firstColor + colorCount - 1], GDVars.gamePalette[firstColor], SizeOf(Types.TRGB));
    Blit.ShadowPaletteEntries(firstColor, colorCount, GDVars.activePalette);
    Blit.SetDacPalette(firstColor, colorCount, GDVars.activePalette)
  end else begin
    Move(GDVars.paletteA[firstColor], GDVars.gamePalette[firstColor + 1], (colorCount - 1) * 3);
    Move(GDVars.paletteA[firstColor + colorCount - 1], GDVars.gamePalette[firstColor], SizeOf(Types.TRGB));
    Blit.ShadowPaletteEntries(firstColor, colorCount, GDVars.paletteA);
    Blit.SetDacPalette(firstColor, colorCount, GDVars.paletteA)
  end
end;

begin
  GDVars.freeAnimationHook := Portrait.FreeAnimation
end.
