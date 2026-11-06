{ VGA-frame preparation service: a Pascal front end over two assembly leaves in VGAFRAME.OBJ. }
{$F+,O-,S+,R-,V-,B-,I-}
unit VgaFrame;

interface

{ Decodes a frame into the display picture's data; does nothing while no frames are loaded.
  @param(picIdx The frame: the key frame is copied as it is, any other is expanded and XORed with it.) }
procedure PrepareVgaFrame(picIdx: Byte);

{ Expands a run-length-coded frame into dst.
  @param(src The run-length code.)
  @param(dst Receives the expanded frame.)
  @param(encodedBytes The length of the code at src.) }
procedure ExpandRleFrame(src, dst: Pointer; encodedBytes: Word);

{ Stores src xor key into dst, byte by byte; dst may be src.
  @param(src The bytes to combine.)
  @param(dst Receives the result.)
  @param(key The bytes `src` is XORed with.)
  @param(count The byte count; 0 processes 65536 bytes.) }
procedure XorFrame(src, dst, key: Pointer; count: Word);

implementation

uses Types, ZeroFree, DaxIo, GDVars;

{$L VGAFRAME.OBJ}

procedure ExpandRleFrame; external;

procedure XorFrame; external;

procedure PrepareVgaFrame(picIdx: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  frameSize: Pointer;
  work: Pointer;

{$F-}
  { Expands the current frame's code into the work buffer, then XORs it with the key frame into the display picture. }
  procedure DecodeDelta;
  begin
    VgaFrame.ExpandRleFrame(GDVars.vgaState.frames[picIdx], work, GDVars.frameSizes[picIdx]);
    VgaFrame.XorFrame(work, @Types.PImage(GDVars.vgaState.displayImage)^.data,
                      GDVars.vgaState.frames[GDVars.keyFrameIndex], 7744)
  end;
{$F+}

begin
  if GDVars.vgaState.frames[0] = nil then Exit;
  DaxIo.SafeGetMem(work, 7744);
  if picIdx <> GDVars.keyFrameIndex then
    DecodeDelta
  else
    Move(Types.PByteBuffer(GDVars.vgaState.frames[picIdx])^, Types.PImage(GDVars.vgaState.displayImage)^.data,
         7744);
  ZeroFree.PrefixFree(work, 7744)
end;

end.
