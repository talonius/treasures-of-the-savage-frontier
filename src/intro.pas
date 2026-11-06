{ Startup logos, title artwork and credits. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Intro;

interface

{ Plays the title sequence: starts the title music and shows title pictures 1, 2 and 3 for up to 25 seconds each, then
  picture 4 (VGA) or 5 for up to 50 seconds, then the credits; a key cuts a picture short but skips none. Ends by
  clearing the screen and restoring the mouse and palette. }
procedure Introduction;

implementation

uses Types, GDVars, C_Video, Blit, TextRend, Music, GameIo, Mouse, GameInit, Portrait;

{ Waits up to a number of seconds or until a key, flushing the keyboard before and after. A clock that runs backwards
  (midnight) also ends the wait.
  @param(timeoutSeconds Seconds to wait.)
  @returns(True when the wait ended early, by a key or by the clock running backwards.) }
function DelayOrKey(timeoutSeconds: Word): Boolean;
var
  startCentiseconds: LongInt;
  deadlineCentiseconds: LongInt;
begin
  GameIo.DrainKeys;
  startCentiseconds := TextRend.GetTicks;
  deadlineCentiseconds := startCentiseconds + 100 * timeoutSeconds;
  repeat
  until GameIo.InputPending or (TextRend.GetTicks >= deadlineCentiseconds) or
      (TextRend.GetTicks < startCentiseconds);
  if TextRend.GetTicks >= deadlineCentiseconds then
    DelayOrKey := False
  else
    DelayOrKey := True;
  GameIo.DrainKeys;
end;

{ Clears the screen, shows the mouse cursor again and resets the palette. }
procedure FinishIntroduction;
begin
  TextRend.ClearScreen;
  Mouse.ShowMouse;
  GameInit.ResetPalette
end;

{ Shows the credits picture, title picture 6, for up to 50 seconds or until a key. }
procedure ShowLastTitle;
begin
  Blit.LoadPic('title', 6, 0, 0, Types.PImage(GDVars.titleImage));
  TextRend.ClearScreen;
  Blit.SetDacPalette(0, SizeOf(GDVars.gamePalette) div SizeOf(GDVars.gamePalette[0]),
                     GDVars.gamePalette);
  Blit.DrawFirstFrame(0, 0, GDVars.titleImage);
  Blit.FreePic(Types.PImage(GDVars.titleImage));
  GDVars.doneSignal := Intro.DelayOrKey(50)
end;

procedure Introduction;
var
  { Unused in this version; see the other implementations of this routine. }
  key: Word;
begin
  GDVars.titleImage := nil;
  Portrait.FreeAnimation;
  Mouse.HideMouse;
  TextRend.ClearScreen;
  Music.StartMusic(1);

  Blit.LoadPic('title', 1, 0, 0, Types.PImage(GDVars.titleImage));
  Blit.SetDacPalette(0, SizeOf(GDVars.gamePalette) div SizeOf(GDVars.gamePalette[0]),
                     GDVars.gamePalette);
  Blit.DrawFirstFrame(0, 0, GDVars.titleImage);
  Blit.FreePic(Types.PImage(GDVars.titleImage));
  GDVars.doneSignal := Intro.DelayOrKey(25);

  Blit.LoadPic('title', 2, 0, 0, Types.PImage(GDVars.titleImage));
  TextRend.ClearScreen;
  Blit.SetDacPalette(0, SizeOf(GDVars.gamePalette) div SizeOf(GDVars.gamePalette[0]),
                     GDVars.gamePalette);
  Blit.DrawFirstFrame(0, 0, GDVars.titleImage);
  Blit.FreePic(Types.PImage(GDVars.titleImage));
  GDVars.doneSignal := Intro.DelayOrKey(25);

  Blit.LoadPic('title', 3, 0, 0, Types.PImage(GDVars.titleImage));
  TextRend.ClearScreen;
  Blit.SetDacPalette(0, SizeOf(GDVars.gamePalette) div SizeOf(GDVars.gamePalette[0]),
                     GDVars.gamePalette);
  Blit.DrawFirstFrame(0, 0, GDVars.titleImage);
  Blit.FreePic(Types.PImage(GDVars.titleImage));
  GDVars.doneSignal := Intro.DelayOrKey(25);

  if GDVars.graphicsClass = C_Video.VM_VGA then
    Blit.LoadPic('title', 4, 0, 0, Types.PImage(GDVars.titleImage))
  else
    Blit.LoadPic('title', 5, 0, 0, Types.PImage(GDVars.titleImage));
  TextRend.ClearScreen;
  Blit.SetDacPalette(0, SizeOf(GDVars.gamePalette) div SizeOf(GDVars.gamePalette[0]),
                     GDVars.gamePalette);
  Blit.DrawFirstFrame(0, 0, GDVars.titleImage);
  Blit.FreePic(Types.PImage(GDVars.titleImage));
  GDVars.doneSignal := Intro.DelayOrKey(50);
  Intro.ShowLastTitle;
  Intro.FinishIntroduction;
  Exit
end;

begin
end.
