{ INT $33 mouse services and drag-to-keypad input. Register scratch and mouse flags are in GDVars; horizontal
  coordinates follow GDVars.mouseHiRes. }
{$F+,O+,S+,A+}
unit Mouse;

interface

{ Resets the mouse driver through INT 33h; when a driver answers, marks the mouse present and records the button count,
  otherwise marks it absent. }
procedure InitMouse;

{ Shows the mouse cursor. Does nothing without a mouse. }
procedure ShowMouse;

{ Hides the mouse cursor. Does nothing without a mouse. }
procedure HideMouse;

{ Reads the mouse buttons and position, halving the column unless the mouse's scale flag is set. Does nothing without a
  mouse.
  @param(buttons Receives the button state.)
  @param(x Receives the column.)
  @param(y Receives the row.) }
procedure GetMouse(var buttons, x, y: Integer);

{ Moves the mouse cursor, doubling the column unless the mouse's scale flag is set. Does nothing without a mouse.
  @param(x Column.)
  @param(y Row.) }
procedure SetMouse(x, y: Integer);

{ Sets the graphics cursor shape and hot spot. Does nothing without a mouse.
  @param(hotX Hot spot column within the cursor.)
  @param(hotY Hot spot row within the cursor.)
  @param(shape Screen and cursor masks of the shape.) }
procedure SetMouseCursor(hotX, hotY: Integer; shape: Pointer);

{ Resets the mouse driver's software state. Does nothing without a mouse. }
procedure ResetMouse;

{ Classifies a mouse move into one of eight 45-degree sectors and returns the matching keypad key. The slopes 618/256
  and 106/256 stand for tan 67.5 and tan 22.5 degrees; the sectors are tried clockwise from up, so a move with no motion
  counts as up. Note: the horizontal change times 618 overflows an Integer for moves wider than 53 units, which can give
  the wrong direction.
  @param(oldX Starting column.)
  @param(oldY Starting row.)
  @param(newX Ending column.)
  @param(newY Ending row.)
  @returns(The scan code of the arrow, Home, End, Page Up or Page Down key for that direction.) }
function MouseDirection(oldX, oldY, newX, newY: Integer): Char;

implementation

uses Dos, GDVars, C_Dir, C_Keys;

const
  { the mouse driver's functions, staged in AX }
  { detects and resets the driver: AX returns $FFFF when one is present, BX its buttons }
  RESET_DRIVER = 0;
  { shows the cursor }
  SHOW_CURSOR = 1;
  { hides the cursor }
  HIDE_CURSOR = 2;
  { returns the buttons in BX, x in CX and y in DX }
  GET_STATE = 3;
  { moves the cursor to x in CX, y in DX }
  SET_POSITION = 4;
  { sets the cursor shape: hot spot in BX and CX, masks at ES:DX }
  SET_CURSOR = 9;
  { the driver's software reset }
  SOFT_RESET = $21;

procedure InitMouse;
begin
  GDVars.regs.AX := Mouse.RESET_DRIVER;
  Intr($33, Registers(GDVars.regs));
  if GDVars.regs.AX = $FFFF then begin
    GDVars.mouseButtonCount := GDVars.regs.BL;
    GDVars.mousePresent := True;
  end else
    GDVars.mousePresent := False;
end;

procedure ShowMouse;
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.SHOW_CURSOR;
  Intr($33, Registers(GDVars.regs));
end;

procedure HideMouse;
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.HIDE_CURSOR;
  Intr($33, Registers(GDVars.regs));
end;

procedure GetMouse(var buttons, x, y: Integer);
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.GET_STATE;
  Intr($33, Registers(GDVars.regs));
  buttons := GDVars.regs.BX;
  x := GDVars.regs.CX;
  if not GDVars.mouseHiRes then x := x div 2;
  y := GDVars.regs.DX;
end;

procedure SetMouse(x, y: Integer);
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.SET_POSITION;
  if not GDVars.mouseHiRes then x := x * 2;
  GDVars.regs.CX := x;
  GDVars.regs.DX := y;
  Intr($33, Registers(GDVars.regs));
end;

procedure SetMouseCursor(hotX, hotY: Integer; shape: Pointer);
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.SET_CURSOR;
  GDVars.regs.BX := hotX;
  GDVars.regs.CX := hotY;
  GDVars.regs.ES := Seg(shape^);
  GDVars.regs.DX := Ofs(shape^);
  Intr($33, Registers(GDVars.regs));
end;

procedure ResetMouse;
begin
  if not GDVars.mousePresent then Exit;
  GDVars.regs.AX := Mouse.SOFT_RESET;
  Intr($33, Registers(GDVars.regs));
end;

function MouseDirection(oldX, oldY, newX, newY: Integer): Char;
var
  directionIndex: Byte;
  directionFound: Boolean;
  scanCode: Char;
  deltaX: Integer;
  deltaY: Integer;
begin
  { Integer products discard their high word before signed division. }
  deltaX := Abs(newX - oldX);
  deltaY := Abs(newY - oldY);
  directionIndex := C_Dir.NORTH;
  directionFound := False;
  while not directionFound do begin
    case directionIndex of
      C_Dir.NORTH: begin
           directionFound := (newY <= oldY) and ((618 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.UP
         end;
      C_Dir.EAST: begin
           directionFound := (newX >= oldX) and ((106 * deltaX) div 256 >= deltaY);
           scanCode := C_Keys.RIGHT
         end;
      C_Dir.SOUTH: begin
           directionFound := (newY >= oldY) and ((618 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.DOWN
         end;
      C_Dir.WEST: begin
           directionFound := (newX <= oldX) and ((106 * deltaX) div 256 >= deltaY);
           scanCode := C_Keys.LEFT
         end;
      C_Dir.NORTHEAST: begin
           directionFound := (newY < oldY) and (newX > oldX) and ((618 * deltaX) div 256 >= deltaY) and
             ((106 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.PAGE_UP
         end;
      C_Dir.SOUTHEAST: begin
           directionFound := (newY > oldY) and (newX > oldX) and ((618 * deltaX) div 256 >= deltaY) and
             ((106 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.PAGE_DOWN
         end;
      C_Dir.SOUTHWEST: begin
           directionFound := (newY > oldY) and (newX < oldX) and ((618 * deltaX) div 256 >= deltaY) and
             ((106 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.END_KEY
         end;
      C_Dir.NORTHWEST: begin
           directionFound := (newY < oldY) and (newX < oldX) and ((618 * deltaX) div 256 >= deltaY) and
             ((106 * deltaX) div 256 <= deltaY);
           scanCode := C_Keys.HOME
         end
    end;
    if not directionFound then Inc(directionIndex)
  end;
  MouseDirection := scanCode
end;

begin
end.
