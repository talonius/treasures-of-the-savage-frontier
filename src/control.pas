{ Reads STARTUP's sound/video settings, runs GAME through restart exits and restores the original video mode. Owns
  configuration, register and command scratch. Note: the INTRO and FINAL viewer command lines are built and then
  overwritten unused, and the vectors are swapped twice in a row before the first run. }

{$A+,I+}
{$M 2048,0,0}
program Control;

uses Dos;

const
  { video BIOS functions, passed in AH }
  BIOS_GET_VIDEO_MODE = $0F;
  BIOS_SET_VIDEO_MODE = 0;
  { BIOS video modes }
  VIDEO_MODE_EGA_320X200 = $0D;
  VIDEO_MODE_TANDY_320X200 = $09;
  VIDEO_MODE_VGA_320X200 = $13;
  { VACE's video-mode argument }
  VACE_MODE_EGA = 2;
  VACE_MODE_TANDY = 3;
  VACE_MODE_VGA = 4;

var
  cfg: Text;
  { VACE's music switch: '0' for the silent sound choice, else '1' }
  musicArg: Char;
  cfgChar: Char;
  regs: Dos.Registers;
  { The VACE viewer's video-mode argument. }
  vaceVideoMode: Integer;
  savedMode: Byte;
  cmdLine: string[40];
  isDone: Boolean;

begin
  System.Assign(cfg, 'treasure.cfg');
  System.Reset(cfg);
  System.Readln(cfg, cfgChar);
  if cfgChar = '6' then
    musicArg := '0'
  else
    musicArg := '1';
  System.Readln(cfg, cfgChar);
  System.Close(cfg);
  regs.AH := BIOS_GET_VIDEO_MODE;
  Dos.Intr($10, regs);
  savedMode := regs.AL;
  regs.AH := BIOS_SET_VIDEO_MODE;
  { An unrecognized graphics choice has no fallback assignment. }
  case cfgChar of
    'E': begin regs.AL := VIDEO_MODE_EGA_320X200; vaceVideoMode := VACE_MODE_EGA; end;
    'T': begin regs.AL := VIDEO_MODE_TANDY_320X200; vaceVideoMode := VACE_MODE_TANDY; end;
    'V': begin regs.AL := VIDEO_MODE_VGA_320X200; vaceVideoMode := VACE_MODE_VGA; end;
  end;
  Dos.Intr($10, regs);
  System.Str(vaceVideoMode, cmdLine);
  cmdLine := cmdLine + ' INTRO 1 ' + musicArg;
  Dos.SwapVectors;
  Dos.SwapVectors;
  cmdLine := '0 ' + System.ParamStr(1) + ' ' + System.ParamStr(2);
  repeat
    Dos.SwapVectors;
    Dos.Exec('game.exe', cmdLine);
    Dos.SwapVectors;
    if Dos.DosExitCode = 23 then begin
      System.Str(vaceVideoMode, cmdLine);
      cmdLine := cmdLine + ' FINAL 1 ' + musicArg;
      isDone := False;
      cmdLine := '1 ' + System.ParamStr(1) + ' ' + System.ParamStr(2);
    end else
      isDone := True;
  until isDone;
  regs.AH := BIOS_SET_VIDEO_MODE;
  regs.AL := savedMode;
  Dos.Intr($10, regs);
  System.Halt;
end.
