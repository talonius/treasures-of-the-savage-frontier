{ Menu key values. Enter, Escape and Backspace are ASCII; the arrow, Home, End, Page Up, Page Down and Delete keys are
  BIOS extended scan codes, returned with menuReturnedKey set. }
unit C_Keys;

interface

const
  BACKSPACE = #8;
  ENTER = #13;
  ESCAPE = #27;
  HOME = #71;
  UP = #72;
  PAGE_UP = #73;
  LEFT = #75;
  RIGHT = #77;
  END_KEY = #79;
  DOWN = #80;
  PAGE_DOWN = #81;
  DELETE_KEY = #83;
  { scan codes of the Alt keys combat answers }
  ALT_X = #45;
  ALT_M = #50;

implementation

end.
