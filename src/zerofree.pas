{ Clears a heap block before releasing it; owns no persistent state. }
{$S+}
unit ZeroFree;

interface

{ Zero-fills a heap block through GameIo.ZeroFill, then releases it with FreeMem.
  @param(p The block to free.)
  @param(n Its size in bytes.) }
procedure PrefixFree(p: Pointer; n: Word);

implementation

uses GameIo;

procedure PrefixFree(p: Pointer; n: Word);
begin
  GameIo.ZeroFill(p^, n);
  FreeMem(p, n);
end;

begin
end.
