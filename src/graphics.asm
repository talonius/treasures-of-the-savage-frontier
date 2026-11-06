; Three-format image compositing and direct EGA/VGA output for Blit.
; Region/frame entries stage image bytes and dirty spans for Blit.FlushView to flush.
; Palette entries and the final two blitters access hardware directly.
; DS enters as DGROUP; BP accesses use SS even while LDS selects image buffers.
; Near Pascal entries consume word-sized argument slots and preserve DS.
; Row loops enter before LOOP; a zero row count wraps the 16-bit counter.

ImageRows EQU 00h ; Types.TImage.rows is a scanline count
ImageCells EQU 02h ; Types.TImage.cells is the number of eight-pixel cells
ImageFrameBytes EQU 12h ; Types.TImage.frameBytes
ImageMaskPtr EQU 17h ; Types.TImage.mask; far pointer
ImageMaskSegment EQU 19h ; high word of Types.TImage.mask
ImageData EQU 1Bh ; pixel payload follows the packed image header
SpanActiveBase EQU 7E66h ; GDVars.spanActive; byte flags
SpanScreenOfsBase EQU 7F0Eh ; GDVars.spanLow; word screen columns
SpanFirstOfsBase EQU 805Eh ; GDVars.spanHigh; word first data offsets
SpanLastOfsBase EQU 81AEh ; GDVars.spanExtra; word inclusive last offsets
VgaSegment EQU 0A000h
VgaRowBytes EQU 320
EgaRowBytes EQU 40
InputStatusPort EQU 3DAh
PaletteIndexPort EQU 3C8h
GraphicsIndexPort EQU 3CEh
SequencerIndexPort EQU 3C4h
VerticalRetraceBit EQU 08h
BitMaskRegister EQU 08h
MapMaskRegister EQU 02h
AllBits EQU 0FFh
RecolorPixel EQU 0Fh
SignedClipBoundary EQU 8000h ; the unsigned test includes the most-negative Integer
UseMaskFlag EQU 01h
SavePixelsFlag EQU 04h
FourByteCellShift EQU 2
CellPixelShift EQU 3
EgaPlane0Mask EQU 01h
EgaPlane1Mask EQU 02h
EgaPlane2Mask EQU 04h
EgaPlane3Mask EQU 08h
MaskPtr EQU 04h ; local far mask pointer; low word
MaskSegment EQU 02h ; local far mask pointer; high word
ScreenColumn EQU 06h ; hardware column contribution, format-scaled
SpanRow EQU 08h ; scanline slot before word-table scaling
RowCount EQU 0Ah ; number of scanlines to copy
DestinationOffset EQU 0Ch ; destination data cursor
SourceOffset EQU 0Eh ; source frame/data cursor
RowBytes EQU 10h ; bytes copied per scanline
DestinationSkip EQU 12h ; destination right margin; scaled before copy
DestinationLeft EQU 14h ; destination left margin; scaled before copy
SourceSkip EQU 16h ; source row tail; scaled before copy
SourceLeft EQU 18h ; source left margin; scaled before copy
SaveDestination EQU 1Ah ; byte flag for saving overwritten pixels
SaveOffset EQU 1Ch ; saved-image data cursor for four-byte formats
VgaSaveOffset EQU 1Eh ; saved-image data cursor for byte pixels
TransparentColor EQU 1Ch ; byte color key; shares another format's local slot
RenderRows EQU 04h
RenderCells EQU 06h
RenderSourceY EQU 08h
RenderSourceX EQU 0Ah
RenderDestination EQU 0Ch
RenderSource EQU 10h
RenderFrame EQU 14h
RenderY EQU 16h
RenderX EQU 18h
BlitDestination EQU 04h
BlitSource EQU 08h
BlitFrame EQU 0Ch
BlitY EQU 0Eh
BlitX EQU 10h
BlitKey EQU 0Eh
KeyedY EQU 10h
KeyedX EQU 12h
ClipFlags EQU 0Ch
ClipFrame EQU 0Eh
ClipY EQU 10h
ClipX EQU 12h
ClipSave EQU 14h
ClipKey EQU 10h
ClipVgaY EQU 12h
ClipVgaX EQU 14h
ClipVgaSave EQU 16h
PaletteCount EQU 04h
PaletteStart EQU 06h
PaletteSource EQU 08h
ScreenSource EQU 04h
ScreenReplacement EQU 08h
ScreenKey EQU 0Ah
ScreenRows EQU 0Ch
ScreenRowBytes EQU 0Eh
ScreenY EQU 10h
ScreenX EQU 12h
EgaPlanesSource EQU 04h
EgaMaskSource EQU 08h

CODE SEGMENT BYTE PUBLIC 'CODE'
 ASSUME CS:CODE

 PUBLIC RenderEgaRegion
 PUBLIC BlitCellEga
 PUBLIC BlitCellEgaMasked
 PUBLIC BlitClippedEga
 PUBLIC RenderTandyRegion
 PUBLIC BlitCellTandy
 PUBLIC BlitCellTandyMasked
 PUBLIC BlitClippedTandy
 PUBLIC BlitCellVga
 PUBLIC BlitCellVgaKeyed
 PUBLIC BlitClippedVga
 PUBLIC RenderVgaRegion
 PUBLIC ProgramPaletteOnRetrace
 PUBLIC ProgramPaletteImmediate ; No Pascal unit declares it external.
 PUBLIC BlitVgaRecolored
 PUBLIC BlitEgaPlanesMasked ; No Pascal unit declares it external.

; Copy a cell-aligned rectangle using four interleaved EGA plane bytes per cell.
RenderEgaRegion:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + RenderDestination]
 mov ax, word ptr [bp + RenderY]
 mov cl, FourByteCellShift ; Four bytes per EGA or packed-nibble cell.
 shl ax, cl
 shl ax, 1
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 shl ax, cl
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + RenderX]
 mov word ptr [bp - ScreenColumn], ax
 shl ax, cl
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderX]
 shl ax, cl
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp + RenderCells]
 shl ax, cl
 mov word ptr [bp - RowBytes], ax
 les di, [bp + RenderSource]
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bh, bh
 mov bl, byte ptr [bp + RenderFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceY]
 shl ax, cl
 shl ax, 1
 mov bx, word ptr es:[di + ImageCells]
 shl bx, cl
 mul bx
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceX]
 shl ax, cl
 mov word ptr [bp - SourceLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderSourceX]
 shl ax, cl
 mov word ptr [bp - SourceSkip], ax
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp + RenderRows]
 shl cx, 1
 shl cx, 1
 shl cx, 1
 mov byte ptr [bp - SaveDestination], 0
RenderEgaRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1 ; Convert the scanline index to a word-table index.
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 ja short RenderEgaCopy ; Equal first offsets refresh the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
RenderEgaCopy:
 push ds
 lds si, [bp + RenderSource]
 les di, [bp + RenderDestination]
 add si, ImageData
 add si, word ptr [bp - SourceOffset]
 add di, ImageData
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
 rep movsb
 pop cx
 pop ds
 mov ax, word ptr [bp - RowBytes]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jb short RenderEgaNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
RenderEgaNextRow:
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 shr bx, 1 ; Recover the scanline index before advancing.
 inc bx
 loop short RenderEgaRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h

; Copy a complete EGA frame; coordinates are cells and eight-scanline rows.
BlitCellEga:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + BlitDestination]
 mov ax, word ptr [bp + BlitY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call CopyFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 0Eh

; Compose a complete EGA frame with its bit-preservation mask.
BlitCellEgaMasked:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + BlitDestination]
 mov ax, word ptr [bp + BlitY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 mov ax, word ptr es:[di + ImageMaskPtr]
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr es:[di + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call ComposeFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 0Eh

; Clip EGA bounds; the masked path can save destination bytes before composition.
BlitClippedEga:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 push ds
 lds si, [bp + BlitSource]
 les di, [bp + BlitDestination]
 mov ax, word ptr [si + ImageMaskPtr]
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr [si + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 mov ax, word ptr [bp + ClipX]
 cmp ax, SignedClipBoundary ; The unsigned clipping test keeps its boundary case.
 jbe short ClipEgaLeftInside
 mov word ptr [bp - SourceLeft], ax
 neg word ptr [bp - SourceLeft]
 mov word ptr [bp - DestinationLeft], 0
 jmp short ClipEgaRight
 nop
ClipEgaLeftInside:
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - DestinationLeft], ax
ClipEgaRight:
 add ax, word ptr [si + ImageCells]
 cmp word ptr es:[di + ImageCells], ax
 jae short ClipEgaRightInside
 sub ax, word ptr es:[di + ImageCells]
 mov word ptr [bp - SourceSkip], ax
 mov word ptr [bp - DestinationSkip], 0
 jmp short ClipEgaTop
 nop
ClipEgaRightInside:
 mov word ptr [bp - SourceSkip], 0
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + ClipX]
 sub ax, word ptr [si + ImageCells]
 mov word ptr [bp - DestinationSkip], ax
ClipEgaTop:
 mov ax, word ptr [bp + ClipY]
 cmp ax, SignedClipBoundary
 jbe short ClipEgaTopInside
 neg ax
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov bx, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], bx
 sub word ptr [bp - RowCount], ax
 mov bx, word ptr [si + ImageCells]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov word ptr [bp - DestinationOffset], 0
 mov word ptr [bp - SpanRow], 0
 jmp short ClipEgaValidate
 nop
ClipEgaTopInside:
 mov word ptr [bp - SourceOffset], 0
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SpanRow]
 add ax, word ptr [si + ImageRows]
 cmp ax, word ptr es:[di + ImageRows]
 jbe short ClipEgaFullHeight
 mov ax, word ptr es:[di + ImageRows]
 sub ax, word ptr [bp - SpanRow]
 mov word ptr [bp - RowCount], ax
 jmp short ClipEgaValidate
 nop
ClipEgaFullHeight:
 mov ax, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], ax
ClipEgaValidate:
 mov ax, word ptr [si + ImageCells]
 cmp ax, word ptr [bp - SourceLeft]
 jb short ClipEgaReject
 cmp ax, word ptr [bp - SourceSkip]
 jb short ClipEgaReject
 mov ax, word ptr [bp - SourceOffset]
 cmp ax, word ptr [si + ImageFrameBytes]
 ja short ClipEgaReject
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr es:[di + ImageFrameBytes]
 ja short ClipEgaReject
 mov ax, word ptr [bp - RowCount]
 cmp ax, word ptr [si + ImageRows]
 ja short ClipEgaReject
 jmp short ClipEgaScale
 nop
ClipEgaReject:
 pop ds
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h
ClipEgaScale:
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr [bp - DestinationLeft]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr [si + ImageCells]
 sub ax, word ptr [bp - SourceLeft]
 sub ax, word ptr [bp - SourceSkip]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov ax, word ptr [bp - SourceOffset]
 mov word ptr [bp - SaveOffset], ax ; Saving starts at the vertical crop, before the source frame is added.
 mov ax, word ptr [si + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + ClipFrame]
 mul bx
 add word ptr [bp - SourceOffset], ax
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 pop ds
 test byte ptr [bp + ClipFlags], UseMaskFlag ; Bit 0 selects masked composition.
 jne short ClipEgaMasked
 call CopyFourByteRow ; The opaque path does not skip clipped source columns.
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h
ClipEgaMasked:
 mov byte ptr [bp - SaveDestination], 0
 test byte ptr [bp + ClipFlags], SavePixelsFlag ; Bit 2 saves destination bytes before composition.
 je short ClipEgaCompose
 mov byte ptr [bp - SaveDestination], 1
ClipEgaCompose:
 call ComposeFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h

; Copy a cell-aligned rectangle using four packed-nibble bytes per cell.
RenderTandyRegion:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + RenderDestination]
 mov ax, word ptr [bp + RenderY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov ax, word ptr [bp + RenderX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 mov ax, word ptr [bp + RenderCells]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr [bp + RenderRows]
 mov word ptr [bp - RowCount], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 les di, [bp + RenderSource]
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + RenderFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceY]
 shl ax, cl
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 shl ax, 1
 shl ax, 1
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceX]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - SourceLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderSourceX]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - SourceSkip], ax
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 shl cx, 1
 shl cx, 1
 shl cx, 1
 mov byte ptr [bp - SaveDestination], 0
RenderTandyRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1 ; Convert the scanline index to a word-table index.
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 ja short RenderTandyCopy ; Equal first offsets refresh the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
RenderTandyCopy:
 push ds
 lds si, [bp + RenderSource]
 les di, [bp + RenderDestination]
 add si, ImageData
 add si, word ptr [bp - SourceOffset]
 add di, ImageData
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
 rep movsb
 pop cx
 pop ds
 mov ax, word ptr [bp - RowBytes]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jb short RenderTandyNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
RenderTandyNextRow:
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 shr bx, 1 ; Recover the scanline index before advancing.
 inc bx
 loop short RenderTandyRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h

; Copy a complete packed-nibble frame into an image buffer.
BlitCellTandy:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + BlitDestination]
 mov ax, word ptr [bp + BlitY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call CopyFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 0Eh

; Compose a complete packed-nibble frame with its bit-preservation mask.
BlitCellTandyMasked:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 les di, [bp + BlitDestination]
 mov ax, word ptr [bp + BlitY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 mov ax, word ptr es:[di + ImageMaskPtr]
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr es:[di + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call ComposeFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 0Eh

; Clip packed-nibble bounds before copying or mask composition.
BlitClippedTandy:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 push ds
 lds si, [bp + BlitSource]
 les di, [bp + BlitDestination]
 mov ax, word ptr [si + ImageMaskPtr]
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr [si + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 mov ax, word ptr [bp + ClipX]
 cmp ax, SignedClipBoundary ; The unsigned clipping test keeps its boundary case.
 jbe short ClipTandyLeftInside
 mov word ptr [bp - SourceLeft], ax
 neg word ptr [bp - SourceLeft]
 mov word ptr [bp - DestinationLeft], 0
 jmp short ClipTandyRight
 nop
ClipTandyLeftInside:
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - DestinationLeft], ax
ClipTandyRight:
 add ax, word ptr [si + ImageCells]
 cmp word ptr es:[di + ImageCells], ax
 jae short ClipTandyRightInside
 sub ax, word ptr es:[di + ImageCells]
 mov word ptr [bp - SourceSkip], ax
 mov word ptr [bp - DestinationSkip], 0
 jmp short ClipTandyTop
 nop
ClipTandyRightInside:
 mov word ptr [bp - SourceSkip], 0
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + ClipX]
 sub ax, word ptr [si + ImageCells]
 mov word ptr [bp - DestinationSkip], ax
ClipTandyTop:
 mov ax, word ptr [bp + ClipY]
 cmp ax, SignedClipBoundary
 jbe short ClipTandyTopInside
 neg ax
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov bx, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], bx
 sub word ptr [bp - RowCount], ax
 mov bx, word ptr [si + ImageCells]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov word ptr [bp - DestinationOffset], 0
 mov word ptr [bp - SpanRow], 0
 jmp short ClipTandyValidate
 nop
ClipTandyTopInside:
 mov word ptr [bp - SourceOffset], 0
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SpanRow]
 add ax, word ptr [si + ImageRows]
 cmp ax, word ptr es:[di + ImageRows]
 jbe short ClipTandyFullHeight
 mov ax, word ptr es:[di + ImageRows]
 sub ax, word ptr [bp - SpanRow]
 mov word ptr [bp - RowCount], ax
 jmp short ClipTandyValidate
 nop
ClipTandyFullHeight:
 mov ax, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], ax
ClipTandyValidate:
 mov ax, word ptr [si + ImageCells]
 cmp ax, word ptr [bp - SourceLeft]
 jb short ClipTandyReject
 cmp ax, word ptr [bp - SourceSkip]
 jb short ClipTandyReject
 mov ax, word ptr [bp - SourceOffset]
 cmp ax, word ptr [si + ImageFrameBytes]
 ja short ClipTandyReject
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr es:[di + ImageFrameBytes]
 ja short ClipTandyReject
 mov ax, word ptr [bp - RowCount]
 cmp ax, word ptr [si + ImageRows]
 ja short ClipTandyReject
 jmp short ClipTandyScale
 nop
ClipTandyReject:
 pop ds
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h
ClipTandyScale:
 mov ax, word ptr [bp - DestinationLeft]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - DestinationLeft], ax
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr [si + ImageCells]
 sub ax, word ptr [bp - SourceLeft]
 sub ax, word ptr [bp - SourceSkip]
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov ax, word ptr [bp - SourceOffset]
 mov word ptr [bp - SaveOffset], ax ; Saving starts at the vertical crop, before the source frame is added.
 mov ax, word ptr [si + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + ClipFrame]
 mul bx
 add word ptr [bp - SourceOffset], ax
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 pop ds
 test byte ptr [bp + ClipFlags], UseMaskFlag ; Bit 0 selects masked composition.
 jne short ClipTandyMasked
 call CopyFourByteRow ; The opaque path does not skip clipped source columns.
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h
ClipTandyMasked:
 mov byte ptr [bp - SaveDestination], 0
 test byte ptr [bp + ClipFlags], SavePixelsFlag ; Bit 2 saves destination bytes before composition.
 je short ClipTandyCompose
 mov byte ptr [bp - SaveDestination], 1
ClipTandyCompose:
 call ComposeFourByteRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 14h
CopyFourByteRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1 ; Convert the scanline index to a word-table index.
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 ja short CopyFourBytePixels ; Equal first offsets refresh the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
CopyFourBytePixels:
 push ds
 lds si, [bp + BlitSource]
 les di, [bp + BlitDestination]
 add si, ImageData
 add si, word ptr [bp - SourceOffset]
 add di, ImageData
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
 rep movsb
 pop cx
 pop ds
 mov ax, word ptr [bp - RowBytes]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jb short CopyFourByteNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
CopyFourByteNextRow:
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 shr bx, 1 ; Recover the scanline index before advancing.
 inc bx
 loop short CopyFourByteRow
 ret
ComposeFourByteRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 jae short ComposeFourBytePixels ; Equal first offsets retain the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
ComposeFourBytePixels:
 push ds
 les di, [bp + BlitDestination]
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
ComposeFourBytePixel:
 cmp byte ptr [bp - SaveDestination], 0
 je short ComposeFourByteSource
 lds si, [bp + ClipSave]
 add si, word ptr [bp - SaveOffset]
 mov al, byte ptr es:[di + ImageData] ; Read the destination byte before saving it.
 mov byte ptr [si + ImageData], al ; DS selects the saved-image buffer.
ComposeFourByteSource:
 lds si, [bp - MaskPtr] ; DS:SI selects the raw transparency-mask buffer.
 add si, word ptr [bp - SourceOffset]
 mov ah, byte ptr [si] ; Read the bit-preservation mask; no image header here.
 lds si, [bp + BlitSource]
 add si, word ptr [bp - SourceOffset]
 mov al, byte ptr [si + ImageData]
 and byte ptr es:[di + ImageData], ah ; Preserve destination bits selected by the source mask.
 or byte ptr es:[di + ImageData], al ; Source data already has transparent bits cleared.
 inc word ptr [bp - SourceOffset]
 inc word ptr [bp - SaveOffset] ; The cursor advances even when saving is disabled.
 inc word ptr [bp - DestinationOffset]
 inc di
 loop short ComposeFourBytePixel
 pop cx
 pop ds
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jbe short ComposeFourByteNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
ComposeFourByteNextRow:
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - SaveOffset], ax ; Save rows skip the right crop but do not add the left crop.
 shr bx, 1
 inc bx
 dec cx
 je short ComposeFourByteDone
 jmp ComposeFourByteRow
ComposeFourByteDone:
 ret

; Copy a complete byte-pixel frame into an image buffer.
BlitCellVga:
 push bp
 mov bp, sp
 sub sp, 1Ch
 sub sp, 1Ch
 push ss
 push ds
 cld
 les di, [bp + BlitDestination]
 mov ax, word ptr [bp + BlitY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + BlitX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call CopyBytePixelRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 0Eh

; Compose a complete byte-pixel frame by color key.
BlitCellVgaKeyed:
 push bp
 mov bp, sp
 sub sp, 1Eh
 sub sp, 1Eh
 push ss
 push ds
 les di, [bp + BlitDestination]
 mov ah, byte ptr [bp + BlitKey]
 mov byte ptr [bp - TransparentColor], ah
 mov ax, word ptr [bp + KeyedY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + KeyedX]
 mov word ptr [bp - DestinationLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 les di, [bp + BlitSource]
 sub ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + KeyedX]
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp - DestinationLeft]
 mov word ptr [bp - ScreenColumn], ax
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 shl word ptr [bp - ScreenColumn], 1
 mov ax, word ptr es:[di + ImageCells]
 shl ax, 1
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 mov ax, word ptr es:[di + ImageRows]
 mov word ptr [bp - RowCount], ax
 mov ax, word ptr es:[di + ImageMaskPtr] ; The setup loads the mask pointer; keyed copying uses the color key.
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr es:[di + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationLeft], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + BlitFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - SourceSkip], 0
 call ComposeBytePixelRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 10h

; Clip byte-pixel bounds before copying or color-key composition.
BlitClippedVga:
 push bp
 mov bp, sp
 sub sp, 1Eh
 sub sp, 1Eh
 push ss
 push ds
 cld
 push ds
 lds si, [bp + BlitSource]
 les di, [bp + BlitDestination]
 mov ax, word ptr [si + ImageMaskPtr] ; The setup loads the mask pointer; keyed copying uses the color key.
 mov word ptr [bp - MaskPtr], ax
 mov ax, word ptr [si + ImageMaskSegment]
 mov word ptr [bp - MaskSegment], ax
 mov ah, byte ptr [bp + ClipKey]
 mov byte ptr [bp - TransparentColor], ah
 mov ax, word ptr [bp + ClipVgaX]
 cmp ax, SignedClipBoundary ; The unsigned clipping test keeps its boundary case.
 jbe short ClipVgaLeftInside
 mov word ptr [bp - SourceLeft], ax
 neg word ptr [bp - SourceLeft]
 mov word ptr [bp - DestinationLeft], 0
 jmp short ClipVgaRight
 nop
ClipVgaLeftInside:
 mov word ptr [bp - SourceLeft], 0
 mov word ptr [bp - DestinationLeft], ax
ClipVgaRight:
 add ax, word ptr [si + ImageCells]
 cmp word ptr es:[di + ImageCells], ax
 jae short ClipVgaRightInside
 sub ax, word ptr es:[di + ImageCells]
 mov word ptr [bp - SourceSkip], ax
 mov word ptr [bp - DestinationSkip], 0
 jmp short ClipVgaTop
 nop
ClipVgaRightInside:
 mov word ptr [bp - SourceSkip], 0
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + ClipVgaX]
 sub ax, word ptr [si + ImageCells]
 mov word ptr [bp - DestinationSkip], ax
ClipVgaTop:
 mov ax, word ptr [bp + ClipVgaY]
 cmp ax, SignedClipBoundary
 jbe short ClipVgaTopInside
 neg ax
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov bx, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], bx
 sub word ptr [bp - RowCount], ax
 mov bx, word ptr [si + ImageCells]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov word ptr [bp - DestinationOffset], 0
 mov word ptr [bp - SpanRow], 0
 jmp short ClipVgaValidate
 nop
ClipVgaTopInside:
 mov word ptr [bp - SourceOffset], 0
 mov cx, CellPixelShift ; Scale character rows to scanlines.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SpanRow]
 add ax, word ptr [si + ImageRows]
 cmp ax, word ptr es:[di + ImageRows]
 jbe short ClipVgaFullHeight
 mov ax, word ptr es:[di + ImageRows]
 sub ax, word ptr [bp - SpanRow]
 mov word ptr [bp - RowCount], ax
 jmp short ClipVgaValidate
 nop
ClipVgaFullHeight:
 mov ax, word ptr [si + ImageRows]
 mov word ptr [bp - RowCount], ax
ClipVgaValidate:
 mov ax, word ptr [si + ImageCells]
 cmp ax, word ptr [bp - SourceLeft]
 jb short ClipVgaReject
 cmp ax, word ptr [bp - SourceSkip]
 jb short ClipVgaReject
 mov ax, word ptr [bp - SourceOffset]
 cmp ax, word ptr [si + ImageFrameBytes]
 ja short ClipVgaReject
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr es:[di + ImageFrameBytes]
 ja short ClipVgaReject
 mov ax, word ptr [bp - RowCount]
 cmp ax, word ptr [si + ImageRows]
 ja short ClipVgaReject
 jmp short ClipVgaScale
 nop
ClipVgaReject:
 pop ds
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h
ClipVgaScale:
 mov ax, word ptr [bp - DestinationLeft]
 shl ax, 1
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - DestinationLeft], ax
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr [si + ImageCells]
 sub ax, word ptr [bp - SourceLeft]
 sub ax, word ptr [bp - SourceSkip]
 shl ax, 1
 shl ax, 1
 shl ax, 1
 mov word ptr [bp - RowBytes], ax
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceLeft], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - SourceSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - DestinationSkip], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - SourceOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 shl word ptr [bp - DestinationOffset], 1
 mov ax, word ptr [bp - SourceOffset]
 mov word ptr [bp - VgaSaveOffset], ax ; Saving starts at the vertical crop, before the source frame is added.
 mov ax, word ptr [si + ImageFrameBytes]
 xor bx, bx
 mov bl, byte ptr [bp + ClipFrame]
 mul bx
 add word ptr [bp - SourceOffset], ax
 mov bx, word ptr [bp - SpanRow]
 mov cx, word ptr [bp - RowCount]
 mov byte ptr [bp - SaveDestination], 0
 pop ds
 test byte ptr [bp + ClipFlags], UseMaskFlag ; Bit 0 selects color-key composition in this format.
 jne short ClipVgaKeyed
 mov word ptr [bp - SourceLeft], 0 ; The opaque path discards horizontal source clipping.
 mov word ptr [bp - SourceSkip], 0
 call CopyBytePixelRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h
ClipVgaKeyed:
 mov byte ptr [bp - SaveDestination], 0
 test byte ptr [bp + ClipFlags], SavePixelsFlag ; Bit 2 saves destination bytes before composition.
 je short ClipVgaCompose
 mov byte ptr [bp - SaveDestination], 1
ClipVgaCompose:
 call ComposeBytePixelRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h
CopyBytePixelRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1 ; Convert the scanline index to a word-table index.
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 ja short CopyBytePixels ; Equal first offsets refresh the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
CopyBytePixels:
 push ds
 lds si, [bp + BlitSource]
 les di, [bp + BlitDestination]
 add si, ImageData
 add si, word ptr [bp - SourceOffset]
 add di, ImageData
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
 rep movsb
 pop cx
 pop ds
 mov ax, word ptr [bp - RowBytes]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jb short CopyByteNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
CopyByteNextRow:
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 shr bx, 1 ; Recover the scanline index before advancing.
 inc bx
 loop short CopyBytePixelRow
 ret
ComposeBytePixelRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 jae short ComposeBytePixels ; Equal first offsets retain the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
ComposeBytePixels:
 push ds
 les di, [bp + BlitDestination]
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
ComposeBytePixel:
 cmp byte ptr [bp - SaveDestination], 0
 je short ComposeByteSource
 lds si, [bp + ClipVgaSave]
 add si, word ptr [bp - VgaSaveOffset]
 mov al, byte ptr es:[di + ImageData] ; Read the destination byte before saving it.
 mov byte ptr [si + ImageData], al ; DS selects the saved-image buffer.
ComposeByteSource:
 lds si, [bp + BlitSource]
 add si, word ptr [bp - SourceOffset]
 mov al, byte ptr [si + ImageData]
 cmp al, byte ptr [bp - TransparentColor] ; Color-key pixels leave the destination unchanged.
 je short ComposeByteAdvance
 mov byte ptr es:[di + ImageData], al
ComposeByteAdvance:
 inc word ptr [bp - SourceOffset]
 inc word ptr [bp - VgaSaveOffset] ; The cursor advances even when saving is disabled.
 inc word ptr [bp - DestinationOffset]
 inc di
 loop short ComposeBytePixel
 pop cx
 pop ds
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jbe short ComposeByteNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
ComposeByteNextRow:
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - VgaSaveOffset], ax ; Save rows skip the right crop but do not add the left crop.
 shr bx, 1
 inc bx
 dec cx
 je short ComposeByteDone
 jmp ComposeBytePixelRow
ComposeByteDone:
 ret

; Copy a cell-aligned rectangle using eight byte pixels per cell.
RenderVgaRegion:
 push bp
 mov bp, sp
 sub sp, 1Eh
 sub sp, 1Eh
 push ss
 push ds
 cld
 mov ax, word ptr [bp + RenderY]
 mov cl, CellPixelShift ; Eight pixels per cell or scanlines per character row.
 shl ax, cl
 mov word ptr [bp - SpanRow], ax
 les di, [bp + RenderDestination]
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 shl ax, cl
 mov word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp + RenderX]
 shl ax, cl
 mov word ptr [bp - DestinationLeft], ax
 mov word ptr [bp - ScreenColumn], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderX]
 shl ax, cl
 mov word ptr [bp - DestinationSkip], ax
 mov ax, word ptr [bp + RenderCells]
 shl ax, cl
 mov word ptr [bp - RowBytes], ax
 les di, [bp + RenderSource]
 mov ax, word ptr es:[di + ImageFrameBytes]
 xor bh, bh
 mov bl, byte ptr [bp + RenderFrame]
 mul bx
 mov word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceY]
 shl ax, cl
 mov bx, word ptr es:[di + ImageCells]
 mul bx
 shl ax, cl
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp + RenderSourceX]
 shl ax, cl
 mov word ptr [bp - SourceLeft], ax
 mov ax, word ptr es:[di + ImageCells]
 sub ax, word ptr [bp + RenderCells]
 sub ax, word ptr [bp + RenderSourceX]
 shl ax, cl
 mov word ptr [bp - SourceSkip], ax
 mov bx, word ptr [bp - SpanRow]
 mov ax, word ptr [bp + RenderRows]
 shl ax, cl
 mov cx, ax
 mov byte ptr [bp - SaveDestination], 0
RenderVgaRow:
 mov byte ptr [bx + SpanActiveBase], 1 ; DS is DGROUP here; mark this scanline dirty.
 shl bx, 1 ; Convert the scanline index to a word-table index.
 mov ax, word ptr [bp - SourceLeft]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationLeft]
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 cmp ax, word ptr [bx + SpanFirstOfsBase]
 ja short RenderVgaCopy ; Equal first offsets refresh the screen column.
 mov word ptr [bx + SpanFirstOfsBase], ax ; Record the earliest destination data byte.
 mov ax, word ptr [bp - ScreenColumn]
 mov word ptr [bx + SpanScreenOfsBase], ax ; Keep its corresponding hardware column.
RenderVgaCopy:
 push ds
 lds si, [bp + RenderSource]
 les di, [bp + RenderDestination]
 add si, ImageData
 add si, word ptr [bp - SourceOffset]
 add di, ImageData
 add di, word ptr [bp - DestinationOffset]
 push cx
 mov cx, word ptr [bp - RowBytes]
 rep movsb
 pop cx
 pop ds
 mov ax, word ptr [bp - RowBytes]
 add word ptr [bp - SourceOffset], ax
 add word ptr [bp - DestinationOffset], ax
 mov ax, word ptr [bp - DestinationOffset]
 dec ax
 cmp ax, word ptr [bx + SpanLastOfsBase]
 jb short RenderVgaNextRow
 mov word ptr [bx + SpanLastOfsBase], ax ; Record the inclusive final destination byte.
RenderVgaNextRow:
 mov ax, word ptr [bp - SourceSkip]
 add word ptr [bp - SourceOffset], ax
 mov ax, word ptr [bp - DestinationSkip]
 add word ptr [bp - DestinationOffset], ax
 shr bx, 1 ; Recover the scanline index before advancing.
 inc bx
 loop short RenderVgaRow
 pop ds
 pop ss
 mov sp, bp
 pop bp
 ret 16h

; Program RGB DAC triples after the next vertical retrace starts.
ProgramPaletteOnRetrace:
 push bp
 mov bp, sp
 push ss
 push ds
 cli ; Exclude interrupt activity during palette programming.
 mov dx, InputStatusPort
WaitRetraceEnd:
 in al, dx
 test al, VerticalRetraceBit ; Wait for the current retrace to end, then a new one.
 jne short WaitRetraceEnd
WaitRetraceStart:
 in al, dx
 test al, VerticalRetraceBit
 je short WaitRetraceStart
 mov dx, PaletteIndexPort ; Select the first DAC palette index; next port is DAC data.
 mov ax, word ptr [bp + PaletteStart]
 out dx, al
 inc dx
 mov cx, word ptr [bp + PaletteCount]
 lds si, [bp + PaletteSource]
 cld
PaletteRetraceEntry:
 lodsb
 out dx, al
 lodsb
 out dx, al
 lodsb
 out dx, al
 loop short PaletteRetraceEntry
 sti ; Return with interrupts enabled, without restoring the prior IF.
 pop ds
 pop ss
 pop bp
 ret 8

; Program RGB DAC triples without waiting for retrace.
ProgramPaletteImmediate:
 push bp
 mov bp, sp
 push ss
 push ds
 cli ; Exclude interrupt activity during palette programming.
 mov dx, PaletteIndexPort ; Select the first DAC palette index; next port is DAC data.
 mov ax, word ptr [bp + PaletteStart]
 out dx, al
 inc dx
 mov cx, word ptr [bp + PaletteCount]
 lds si, [bp + PaletteSource]
 cld
PaletteImmediateEntry:
 lodsb
 out dx, al
 lodsb
 out dx, al
 lodsb
 out dx, al
 loop short PaletteImmediateEntry
 sti ; Return with interrupts enabled, without restoring the prior IF.
 pop ds
 pop ss
 pop bp
 ret 8

; Copy byte pixels to VGA, skipping the key and recoloring the marker.
BlitVgaRecolored:
 push bp
 mov bp, sp
 push ds
 lds si, [bp + ScreenSource]
 ; Point ES:DI at pixel (x, y) of the 320-byte-wide VGA screen.
 mov ax, VgaSegment
 mov es, ax
 mov ax, VgaRowBytes
 mul word ptr [bp + ScreenY]
 add ax, word ptr [bp + ScreenX]
 mov di, ax
 mov bx, VgaRowBytes ; Compute the destination row tail after the copied bytes.
 sub bx, word ptr [bp + ScreenRowBytes]
 mov cx, word ptr [bp + ScreenRows]
RecoloredVgaRow:
 push cx
 mov cx, word ptr [bp + ScreenRowBytes]
 cld
RecoloredVgaPixel:
 lodsb
 cmp al, byte ptr [bp + ScreenKey]
 je short RecoloredVgaSkip
 cmp al, RecolorPixel ; The source marker color is replaced by the requested color.
 jne short RecoloredVgaStore
 mov al, byte ptr [bp + ScreenReplacement]
RecoloredVgaStore:
 stosb
 loop short RecoloredVgaPixel
 jmp short RecoloredVgaNextRow
 nop
RecoloredVgaSkip:
 inc di
 loop short RecoloredVgaPixel
RecoloredVgaNextRow:
 add di, bx
 pop cx
 loop short RecoloredVgaRow
 pop ds
 pop bp
 ret 10h

; Copy raw four-plane cells; forward traversal requires clear DF and compatible EGA write state.
BlitEgaPlanesMasked:
 push bp
 mov bp, sp
 push ds
 ; Point ES:DI at byte column x of scanline y on the planar EGA screen.
 mov ax, VgaSegment
 mov es, ax
 mov ax, EgaRowBytes
 mul word ptr [bp + ScreenY]
 add ax, word ptr [bp + ScreenX]
 mov di, ax
 lds si, [bp + EgaPlanesSource]
 mov bx, si ; Park the plane-stream offset while DS selects the mask stream.
 lds si, [bp + EgaMaskSource]
 mov cx, word ptr [bp + ScreenRows]
MaskedEgaRow:
 push cx
 mov cx, word ptr [bp + ScreenRowBytes]
MaskedEgaCell:
 ; Let the writes change only the pixels the mask byte marks opaque.
 mov dx, GraphicsIndexPort
 mov al, BitMaskRegister
 out dx, al
 inc dx
 lodsb
 xor al, AllBits ; Invert transparent bits into writable EGA pixel bits.
 out dx, al
 mov al, byte ptr es:[di] ; Load the four EGA plane latches before masked writes.
 ; Switch DS:SI from the mask stream to the plane stream, parking the mask offset in BX.
 push bx
 mov bx, si
 lds si, [bp + EgaPlanesSource]
 pop si
 ; Write the cell's four plane bytes, enabling one plane at a time through the map mask.
 mov dx, SequencerIndexPort
 mov al, MapMaskRegister
 out dx, al
 inc dx
 mov al, EgaPlane0Mask
 out dx, al
 dec dx
 lodsb
 mov byte ptr es:[di], al
 mov al, MapMaskRegister
 out dx, al
 inc dx
 mov al, EgaPlane1Mask
 out dx, al
 dec dx
 lodsb
 mov byte ptr es:[di], al
 mov al, MapMaskRegister
 out dx, al
 inc dx
 mov al, EgaPlane2Mask
 out dx, al
 dec dx
 lodsb
 mov byte ptr es:[di], al
 mov al, MapMaskRegister
 out dx, al
 inc dx
 mov al, EgaPlane3Mask ; The exit leaves plane 3 enabled and the last bit mask selected.
 out dx, al
 movsb ; Plane 3's write also steps to the next cell.
 ; Switch DS:SI back to the mask stream, parking the plane offset in BX.
 push bx
 mov bx, si
 lds si, [bp + EgaMaskSource]
 pop si
 loop short MaskedEgaCell
 mov ax, EgaRowBytes
 sub ax, word ptr [bp + ScreenRowBytes]
 add di, ax
 pop cx
 loop short MaskedEgaRow
 pop ds
 pop bp
 ret 10h
CODE ENDS
END
