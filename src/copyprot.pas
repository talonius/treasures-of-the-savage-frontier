{ The journal check, the game's copy protection. It asks for a word from the printed journal by page, word number and
  heading. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit CopyProt;

interface

{ Asks for a journal word from a random page and word slot, with a fresh question after each wrong answer, at most three
  times. Each stage sets one of the protection flags, which are cleared on entry.
  @returns(True when the last answer typed was right.) }
function CopyProtection: Boolean;

implementation

uses Crt, GDConsts, GDVars, Border, TextRend, GameIo, CharHlp;

{ Decodes a journal word as stored: character i is i minus the stored byte, upper-cased.
  @param(source The encoded word.)
  @returns(The plain word.) }
function DecodeWord4(source: String): String;
var
  acc: String;
  i: Byte;
  wordLen: Byte;
begin
  wordLen := Length(source);
  acc := '';
  for i := 1 to wordLen do
    acc := acc + UpCase(Chr(i - Ord(source[i])));
  DecodeWord4 := acc
end;

function CopyProtection: Boolean;
begin
  GameIo.ZeroFill(GDVars.journalFlags4, SizeOf(GDVars.journalFlags4));
  Border.DrawWindowFrame(1);
  GDVars.attemptCount4 := 0;
  repeat
    Inc(GDVars.attemptCount4);
    GDVars.correctWord4 := '';
    GDVars.journalFlags4[1] := 1;
    GDVars.pageIndex4 := Random(21) + 1;
    with GDConsts.journalTable[GDVars.pageIndex4] do begin
      repeat
        GDVars.wordIndex4 := Random(3) + 1
      until wordNumber[GDVars.wordIndex4] <> $FF;
      GDVars.correctWord4 := CopyProt.DecodeWord4(encodedWord[GDVars.wordIndex4]);

      TextRend.DisplayString(3, 2, LightGreen, Black, ' journal, page ');
      TextRend.DisplayStringClear(17, 2, LightMagenta, Black, ' (' + CharHlp.Uint8Str(pageNumber) + ')         ');
      TextRend.DisplayString(3, 4, LightGreen, Black, ' what is word # ');
      TextRend.DisplayStringClear(19, 4, LightMagenta, Black,
                                  CharHlp.Uint8Str(wordNumber[GDVars.wordIndex4]) + '     ');
      TextRend.DisplayString(3, 6, LightGreen, Black, ' after the heading ');
      Border.EraseBox(4, 8, 38, 8);
      TextRend.DisplayStringClear(4, 8, LightMagenta, Black, CopyProt.DecodeWord4(heading))
    end;
    GDVars.enteredWord4 := TextRend.ReadString('Enter ', Yellow, Black, 20);
    GDVars.journalFlags4[2] := 1
  until (GDVars.attemptCount4 = 3) or (GDVars.enteredWord4 = GDVars.correctWord4);
  GDVars.journalFlags4[3] := 1;
  if GDVars.enteredWord4 = GDVars.correctWord4 then
    CopyProtection := True
  else
    CopyProtection := False;
  GDVars.journalFlags4[4] := 1
end;

begin
end.
