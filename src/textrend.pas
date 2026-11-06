{ TextRend -- video, font, text, and prompt layer. }
{$F+,O+,S+,A+,I-,R-,V-,B-}
unit TextRend;

interface

uses Types, Crt, Dos, GDConsts, GDVars, C_Video, C_Keys, GameIo, Mouse;

{ Resets the EGA Graphics Controller and Sequencer to their defaults: no set/reset, no rotate, write mode 0, all bits
  and all planes enabled. }
procedure ResetEgaGc;

{ Shows an EGA page (video BIOS function 5) and records its segment as the current page.
  @param(page The page to show.) }
procedure SetupEgaCurrentPage(page: Byte);

{ Records an EGA page's segment as the other page.
  @param(page The page.) }
procedure SetupEgaOtherPage(page: Byte);

{ Fills a character-cell rectangle of an EGA page with one color in write mode 2, then restores write mode 0 and points
  the other page back at the page number saved for it.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(page The EGA page to fill.)
  @param(color The fill color.) }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

{ Loads the game font, picture 8 of BORD.DAX, into GDConsts.gameFont through GDVars.bankLoader. }
procedure LoadGameFont;

{ Draws a character several times at a cell through the BIOS, in the BIOS font.
  @param(col The column.)
  @param(row The row.)
  @param(color The color attribute.)
  @param(count The number of copies.)
  @param(ch The character.) }
procedure BiosChar(col, row, color, count, ch: Byte);

{ Draws a character several times, advancing one column each time: through the BIOS while no game font is loaded,
  otherwise as its upper-cased glyph, folded into the 64-glyph font, through GDVars.maskedRender.
  @param(col The first column.)
  @param(row The row.)
  @param(fg The foreground color.)
  @param(bg The background color.)
  @param(count The number of copies.)
  @param(ch The character.)
  @param(isASCII Unused.) }
procedure RenderChar(col, row, fg, bg, count, ch, isASCII: Byte);

{ Paints cells of solid color: a nonzero color draws glyph 31 in that color on that color, color 0 clears the cells
  through GDVars.clearRectCoreHook. Cells off the 40x25 screen, or a count of 0, draw nothing.
  @param(col The first column.)
  @param(row The row.)
  @param(color The color.)
  @param(count The number of cells.) }
procedure PrintSpaces(col, row, color, count: Byte);

{ Writes a string from a cell, one character per cell, with the mouse cursor hidden; characters off the screen are not
  drawn. Note: a column above 39 or a row above 39 exits early and leaves the mouse hidden.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayString(col, row, fg, bg: Byte; source: String);

{ Writes a string from a cell, clearing each cell before drawing its character, with the mouse cursor hidden. An empty
  string, a column above 39 or a row above 39 draws nothing.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayStringClear(col, row, fg, bg: Byte; source: String);

{ Writes a string from a cell through DisplayString, first clearing its cells through GDVars.clearRectHook when the
  background is black. An empty string draws nothing.
  @param(col The first character's column.)
  @param(row The row.)
  @param(fg The text color.)
  @param(bg The background color.)
  @param(source The text.) }
procedure DisplayText(col, row, fg, bg: Byte; source: String);

{ Prints a paragraph word-wrapped inside a rectangle of cells. Printing continues from the global cursor if it lies
  inside the rectangle, otherwise from the top left. A '%' and a hex digit set the color (and the game state's print
  color), #10 starts a new line and #12 a new page. When the text overflows the bottom row the player is asked to press
  a key, the rectangle is cleared, and printing continues from the top. Note: a rectangle past row 29 or an empty
  paragraph exits with the mouse cursor still hidden.
  @param(ulCol Left column.)
  @param(ulRow Top row.)
  @param(lrCol Right column.)
  @param(lrRow Bottom row.)
  @param(fg The foreground color.)
  @param(bg The background color.)
  @param(clearFirst True wipes the rectangle and starts at the top left.)
  @param(source The paragraph.) }
procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);

{ Reads a line on the status row under a prompt, echoing as it goes. Backspace deletes, the numeric keypad types digits,
  a leading space is refused, and Enter or Esc ends the line, as does the input-abort flag. Note: the keypad-5 arm tests
  scancode $20 (Alt-D) instead of $4C, so keypad 5 does not type '5' and Alt-D does.
  @param(query The prompt.)
  @param(fg The prompt's foreground color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most characters accepted.)
  @returns(The line, trailing spaces trimmed and upper-cased.) }
function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;

{ Reads a non-negative number through ReadString, prompting again until the entry is all digits and converts cleanly.
  Note: the upper-bound test can never be true; the sign test does the work.
  @param(query The prompt.)
  @param(fg The prompt's foreground color.)
  @param(bg The prompt's background color.)
  @param(maxLen The most digits accepted.)
  @returns(The number; 0 for an empty entry.) }
function ReadNumber(query: Types.TStr40; fg, bg, maxLen: Byte): LongInt;

{ Shows a message on the status row and waits for Enter or Esc, then, with a mouse present, for all buttons to be
  released.
  @param(fg The foreground color.)
  @param(bg The background color.)
  @param(msg The message.) }
procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);

{ Reads the time of day.
  @returns(The time since midnight in hundredths of a second.) }
function GetTicks: LongInt;

{ Clears the whole screen in the current display mode: both EGA pages, the VGA frame, or all four Tandy banks. }
procedure ClearScreen;

{ Shows a message on the bottom row for the game-speed pause (PauseOnly), then clears the row.
  @param(msg The message.)
  @param(fg The text color.)
  @param(bg The background color.) }
procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);

{ Waits for the game-speed setting times 100 milliseconds. }
procedure PauseOnly;

{ Drains any keys already pressed, waits for the player with the continue prompt on the status line, then clears the
  line. }
procedure PauseContinue;

{ Shows the loading banner on the cleared status row. }
procedure DisplayLoading;

{ Clears the whole status row. }
procedure ClearStatusLine;

{ Formats a byte in decimal.
  @param(value The number.)
  @returns(Its digits.) }
function ByteToString(value: Byte): String;

{ Right-aligns a string in a field by adding spaces on the left.
  @param(s The string, padded in place.)
  @param(width The field width.) }
procedure RightAlignString(var s: Types.TStr40; width: Byte);

{ Show msg in white on the cleared bottom line.
  @param(msg The message.) }
procedure DisplayStatusLine(msg: String);

{ Shows a debug message on the bottom line in the BIOS font, waits for a key and clears the line. Nothing happens unless
  the editor is enabled and Scroll Lock is on.
  @param(msg The message.) }
procedure ConditionalMessage(msg: String);

{ Shows a message in white on the bottom line, waits for a key and clears the line.
  @param(msg The message.) }
procedure DisplayMessageAndWait(msg: String);

{ Converts a number to decimal text.
  @param(value The number.)
  @returns(The text.) }
function LongToString(value: LongInt): String;

{ Shows a message through GDVars.showMessage, then ends the game with exit code 100.
  @param(msg The message.) }
procedure ExitWithMessage(msg: String);

implementation

const
  { the Ins key's extended scan code }
  KEY_INS = #82;

type
  TTandyRow = array[0..159] of Byte;

var
  vgaScreen: array[0..63999] of Byte absolute $A000:$0000;
  tandyFirstBank: array[0..49] of TTandyRow absolute $B800:$0000;
  tandySecondBank: array[0..49] of TTandyRow absolute $BA00:$0000;
  tandyThirdBank: array[0..49] of TTandyRow absolute $BC00:$0000;
  tandyFourthBank: array[0..49] of TTandyRow absolute $BE00:$0000;
  keyboardShiftFlags: Byte absolute $0000:$0417;

procedure ResetEgaGc;
begin
  Port[$3CE] := 0; Port[$3CF] := 0;
  Port[$3CE] := 1; Port[$3CF] := 0;
  Port[$3CE] := 2; Port[$3CF] := 0;
  Port[$3CE] := 3; Port[$3CF] := 0;
  Port[$3CE] := 4; Port[$3CF] := 0;
  Port[$3CE] := 5; Port[$3CF] := 0;
  Port[$3CE] := 7; Port[$3CF] := $0F;
  Port[$3CE] := 8; Port[$3CF] := $FF;
  Port[$3C4] := 2; Port[$3C5] := $0F
end;

procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.regs.AH := 5;
  GDVars.regs.AL := page;
  Intr($10, Registers(GDVars.regs));
  GDVars.egaPages.currentPage := $A000 + (Word(page) shl 9)
end;

procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaPages.otherPage := $A000 + (Word(page) shl 9)
end;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  dstOff: Word;
  rowCount: Word;
  i: Word;
begin
  savedPage := GDVars.egaOtherPageNum;
  dstOff := Word(ulRow) * 40 * 8 + ulCol;
  rowCount := (lrRow - ulRow + 1) * 8 - 1;
  TextRend.SetupEgaOtherPage(page);
  TextRend.ResetEgaGc;
  Port[$3CE] := 5;
  Port[$3CF] := 2;
  for i := 0 to rowCount do begin
    FillChar(Mem[GDVars.egaPages.otherPage:dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40)
  end;
  Port[$3CE] := 5;
  Port[$3CF] := 0;
  GDVars.egaOtherPageNum := savedPage;
  TextRend.SetupEgaOtherPage(GDVars.egaOtherPageNum)
end;

procedure LoadGameFont;
var
  { Unused in this version; see the other implementations of this routine. }
  fontData: array[0..6] of Byte;
begin
  GDVars.bankLoader('bord', 8, 1, 13, GDConsts.gameFont)
end;

procedure BiosChar(col, row, color, count, ch: Byte);
begin
  GDVars.regs.AH := 2;
  GDVars.regs.BH := 0;
  GDVars.regs.DH := row;
  GDVars.regs.DL := col;
  Intr($10, Registers(GDVars.regs));
  GDVars.regs.AH := 9;
  GDVars.regs.AL := ch;
  GDVars.regs.BH := 0;
  GDVars.regs.BL := color;
  GDVars.regs.CX := count;
  Intr($10, Registers(GDVars.regs))
end;

procedure RenderChar(col, row, fg, bg, count, ch, isASCII: Byte);
var
  i: Byte;
  charIdx: Byte;
begin
  if GDConsts.gameFont = nil then
    TextRend.BiosChar(col, row, fg, count, ch)
  else begin
    charIdx := Ord(UpCase(Chr(ch))) and $3F;
    for i := 1 to count do begin
      GDVars.maskedRender(col, row, GDConsts.gameFont, charIdx, fg, bg);
      Inc(col)
    end
  end
end;

procedure PrintSpaces(col, row, color, count: Byte);
begin
  if (count = 0) or (col < 0) or (col > 39) or (row < 0) or (row > 24) then Exit;
  Mouse.HideMouse;
  if color <> 0 then
    TextRend.RenderChar(col, row, color, color, count, $1F, 1)
  else
    GDVars.clearRectCoreHook(col, row, col + count - 1, row);
  Mouse.ShowMouse
end;

procedure DisplayString(col, row, fg, bg: Byte; source: String);
var
  n: Byte;
  i: Byte;
begin
  Mouse.HideMouse;
  if (col > 39) or (row > 39) then Exit;
  n := Length(source);
  for i := 1 to n do begin
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1);
    Inc(col)
  end;
  Mouse.ShowMouse
end;

procedure DisplayStringClear(col, row, fg, bg: Byte; source: String);
var
  i: Byte;
  n: Byte;
begin
  if (Length(source) = 0) or (col > $27) or (row > $27) then Exit;
  Mouse.HideMouse;
  n := Length(source);
  for i := 1 to n do begin
    GDVars.clearRectCoreHook(col, row, col, row);
    TextRend.RenderChar(col, row, fg, bg, 1, Ord(source[i]), 1);
    Inc(col)
  end;
  Mouse.ShowMouse
end;

procedure DisplayText(col, row, fg, bg: Byte; source: String);
begin
  if Length(source) = 0 then Exit;
  if bg = 0 then
    GDVars.clearRectHook(col, row, col + Length(source) - 1, row);
  TextRend.DisplayString(col, row, fg, bg, source)
end;

procedure DisplayMessageWindow(ulCol, ulRow, lrCol, lrRow, fg, bg: Byte; clearFirst: Boolean; source: String);
var
  len: Byte;
  width: Byte;
  idx: Byte;
  lineEnd: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lineStart: Byte;

  { At source[idx], take a '%' color code and skip it; False when there is none. }
  function ParseColor: Boolean;
  begin
    if (idx + 1 <= len) and (source[idx] = '%') and (source[idx + 1] in ['0'..'9', 'A'..'F']) then
    begin
      if source[idx + 1] in ['A'..'F'] then
        GDVars.gameState^.printColor := Ord(source[idx + 1]) - Ord('A') + 10
      else
        GDVars.gameState^.printColor := Ord(source[idx + 1]) - Ord('0');
      fg := GDVars.gameState^.printColor;
      Inc(idx, 2);
      ParseColor := True
    end else
      ParseColor := False
  end;

  { Print source[idx..lineEnd] at the cursor, taking color codes on the way. }
  procedure PrintCharInWindow;
  begin
    while idx <= lineEnd do begin
      if not ParseColor then begin
        TextRend.RenderChar(GDVars.curCol, GDVars.curRow, fg, bg, 1, Ord(source[idx]), 1);
        Inc(idx);
        Inc(GDVars.curCol)
      end
    end
  end;

  { Skip the spaces at source[idx]. }
  procedure SkipSpaces;
  begin
    while (idx <= len) and (source[idx] = ' ') do Inc(idx)
  end;

  { Wait for a key, then clear the window and put the text cursor at its top left. }
  procedure PageWindow;
  begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow;
    TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
    GDVars.clearRectCoreHook(ulCol, ulRow, lrCol, lrRow)
  end;

  { Set lineEnd to the last character of the word at idx, with its trailing space, within the width. }
  procedure FindLineEnd;
  begin
    lineEnd := idx;
    while (idx - lineEnd + 1 < width) and (lineEnd <= len) and (source[lineEnd] <> ' ') and
        not (source[lineEnd] in [#10, #12]) do Inc(lineEnd);
    if (lineEnd <= len) and (source[lineEnd] = ' ') then Inc(lineEnd);
    Dec(lineEnd)
  end;

begin
  Mouse.HideMouse;
  if (ulCol > 39) or (ulRow > $1D) or (lrCol > 39) or (lrRow > $1D) then Exit;
  if (GDVars.curCol < ulCol) or (GDVars.curCol > lrCol) or (GDVars.curRow < ulRow) or
      (GDVars.curRow > lrRow) then begin
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow
  end;
  if clearFirst then begin
    GDVars.clearRectCoreHook(ulCol, ulRow, lrCol, lrRow);
    GDVars.curCol := ulCol;
    GDVars.curRow := ulRow
  end;
  idx := 1;
  len := Length(source);
  if len = 0 then Exit;
  width := lrCol - ulCol + 1;
  repeat
    if ParseColor then begin
    end else if source[idx] = #10 then begin
      Inc(idx);
      GDVars.curCol := ulCol;
      Inc(GDVars.curRow);
      if (GDVars.curRow > lrRow) and (idx <= len) then PageWindow
    end else if source[idx] = #12 then begin
      Inc(idx);
      PageWindow
    end else begin
      FindLineEnd;
      if lineEnd - idx + GDVars.curCol >= lrCol then begin
        if (GDVars.curCol <= lrCol) and (lineEnd - idx + GDVars.curCol = lrCol + 1) and
            (source[lineEnd] = ' ') then Dec(lineEnd);
        if lineEnd - idx + GDVars.curCol = lrCol then begin
          PrintCharInWindow;
          GDVars.curCol := ulCol;
          Inc(GDVars.curRow);
          SkipSpaces
        end else begin
          GDVars.curCol := ulCol;
          Inc(GDVars.curRow);
          SkipSpaces;
          if (GDVars.curRow > lrRow) and (idx < len) then PageWindow;
          PrintCharInWindow
        end
      end else
        PrintCharInWindow
    end
  until idx > len;
  if GDVars.curCol > lrCol then begin
    GDVars.curCol := ulCol;
    Inc(GDVars.curRow)
  end;
  Mouse.ShowMouse
end;

function ReadString(query: Types.TStr40; fg, bg, maxLen: Byte): Types.TStr40;
var
  col: Byte;
  len: Byte;
  reply: String;
  key: Char;
begin
  GDVars.program5Flag := 1;
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, fg, bg, query);
  col := Length(query);
  reply := '';
  repeat
    TextRend.DisplayText(col + 1, 24, White, Black, #31);
    key := ReadKey;
    if key = #0 then begin
      key := ReadKey;
      case key of
        C_Keys.HOME: key := '7';
        C_Keys.UP: key := '8';
        C_Keys.PAGE_UP: key := '9';
        C_Keys.LEFT: key := '4';
        #32: key := '5';
        C_Keys.RIGHT: key := '6';
        C_Keys.END_KEY: key := '1';
        C_Keys.DOWN: key := '2';
        C_Keys.PAGE_DOWN: key := '3';
        TextRend.KEY_INS: key := '0'
      else
        key := #0
      end
    end;
    len := Length(reply);
    case key of
      ' ':
        if (len <> 0) and (len < maxLen) then begin
          reply := reply + ' ';
          Inc(col);
          TextRend.DisplayText(col, 24, White, Black, ' ')
        end;
      '!'..'z':
        if len < maxLen then begin
          reply := reply + key;
          Inc(col);
          TextRend.DisplayText(col, 24, White, Black, key)
        end;
      C_Keys.BACKSPACE:
        if len > 0 then begin
          reply := Copy(reply, 1, len - 1);
          TextRend.PrintSpaces(col, 24, Black, 2);
          Dec(col)
        end
    end
  until (key = C_Keys.ENTER) or (key = C_Keys.ESCAPE) or (GDVars.inputAbort);
  TextRend.PrintSpaces(0, 24, Black, 40);
  len := Length(reply);
  while reply[len] = ' ' do Dec(len);
  reply := Copy(reply, 1, len);
  for col := 1 to len do reply[col] := UpCase(reply[col]);
  ReadString := reply
end;

function ReadNumber(query: Types.TStr40; fg, bg, maxLen: Byte): LongInt;
var
  valid: Boolean;
  num: LongInt;
  valueText: string[10];
  code: Integer;
begin
  repeat
    valueText := TextRend.ReadString(query, fg, bg, maxLen);
    num := 0;
    code := 0;
    valid := True;
    if Length(valueText) > 0 then begin
      GDVars.scratchIndex := 1;
      while (GDVars.scratchIndex <= Length(valueText)) and valid do begin
        valid := valueText[GDVars.scratchIndex] in ['0'..'9'];
        Inc(GDVars.scratchIndex)
      end;
      if valid then begin
        Val(valueText, num, code);
        if code = 0 then
          if (num > $7FFFFFFF) or (num < 0) then code := 1
      end else
        code := 1
    end
  until code = 0;
  ReadNumber := num
end;

procedure DisplayAndPause(fg, bg: Byte; msg: Types.TStr40);
var
  key: Char;
  buttons: Integer;
  x: Integer;
  y: Integer;
begin
  GDVars.program5Flag := 1;
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  repeat
    key := GameIo.ReadGameKey
  until key in [C_Keys.ENTER, C_Keys.ESCAPE];
  if GDVars.mouseClicked then
    repeat
      Mouse.GetMouse(buttons, x, y)
    until buttons = 0
end;

function GetTicks: LongInt;
var
  h: Word;
  m: Word;
  s: Word;
  hundredths: Word;
begin
  GetTime(h, m, s, hundredths);
  GetTicks := LongInt(h) * 360000 + LongInt(m) * 6000 + LongInt(s) * 100 + hundredths
end;

procedure ClearScreen;
begin
  case GDVars.graphicsClass of
    C_Video.VM_EGA:
      begin
        TextRend.FillRectEga(0, 0, 39, 24, 0, Black);
        TextRend.FillRectEga(0, 0, 39, 24, 1, Black)
      end;
    C_Video.VM_VGA:
      GameIo.ZeroFill(vgaScreen, SizeOf(vgaScreen));
    C_Video.VM_TANDY:
      begin
        GameIo.ZeroFill(tandyFirstBank, SizeOf(tandyFirstBank));
        GameIo.ZeroFill(tandySecondBank, SizeOf(tandySecondBank));
        GameIo.ZeroFill(tandyThirdBank, SizeOf(tandyThirdBank));
        GameIo.ZeroFill(tandyFourthBank, SizeOf(tandyFourthBank))
      end
  end
end;

procedure PrintAndPause(msg: Types.TStr40; fg, bg: Byte);
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, fg, bg, msg);
  TextRend.PauseOnly;
  TextRend.PrintSpaces(0, 24, Black, 40)
end;

procedure PauseOnly;
begin
  Delay(GDVars.gameState^.gameDelay * 100)
end;

procedure PauseContinue;
begin
  GameIo.DrainKeys;
  TextRend.DisplayAndPause(White, Black, GDConsts.pressButtonPrompt);
  GDVars.clearRectHook(0, 24, $27, $18)
end;

procedure DisplayLoading;
begin
  GDVars.clearRectHook(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait')
end;

procedure ClearStatusLine;
begin
  GDVars.clearRectHook(0, 24, 39, 24)
end;

function ByteToString(value: Byte): String;
var
  s: String;
begin
  Str(value:0, s);
  ByteToString := s
end;

procedure RightAlignString(var s: Types.TStr40; width: Byte);
begin
  while Length(s) < width do s := ' ' + s
end;

procedure DisplayStatusLine(msg: String);
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, White, Black, msg)
end;

procedure ConditionalMessage(msg: String);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  savedFont: Pointer;
begin
  if (not GDConsts.editorEnabled) or ((keyboardShiftFlags and $10) = 0) then Exit;
  savedFont := GDConsts.gameFont;
  GDConsts.gameFont := nil;
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, White, Black, msg);
  GDVars.program5Flag := 1;
  key := GameIo.ReadGameKey;
  TextRend.PrintSpaces(0, 24, Black, 40);
  GDConsts.gameFont := savedFont
end;

procedure DisplayMessageAndWait(msg: String);
var
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, White, Black, msg);
  GDVars.program5Flag := 1;
  key := GameIo.ReadGameKey;
  TextRend.PrintSpaces(0, 24, Black, 40)
end;

function LongToString(value: LongInt): String;
var
  s: String;
begin
  Str(value:0, s);
  LongToString := s
end;

procedure ExitWithMessage(msg: String);
begin
  GDVars.showMessage(msg);
  GameIo.ExitGame(100)
end;

{ Install this unit's routines in the shared message and display hooks. }
begin
  GDVars.fatalMessageHook := TextRend.ExitWithMessage;
  GDVars.bottomMessageHook := TextRend.DisplayStatusLine;
  GDVars.showMessage := TextRend.DisplayMessageAndWait;
  GDVars.conditionalMessageHook := TextRend.ConditionalMessage;
  GDVars.intToStringHook := TextRend.LongToString;
  GDVars.printSpacesHook := TextRend.PrintSpaces;
  GDVars.displayStringHook := TextRend.DisplayString;
  GDVars.pauseHook := TextRend.DisplayAndPause

end.
