{ Boot and configuration initialization: the resident start-up code, run by its unit initialization before the overlays
  are used. It opens GAME.OVR (with EMS), finds the overlay drive, reads TREASURE.CFG, sets the video mode, sizes the
  overlay buffer, and reads the input and joystick settings. }
{$F+,S+,V-,I-}
unit GameBoot;

interface

implementation

uses Types, Crt, Dos, Overlay, GDConsts, GDVars, C_Video, C_Sound, Blit, TextRend, DaxIo, GameIo,
  Joystick;

const
  { displayMode values only this unit sets }
  SOUND_MODE_SOUND_BLASTER = 0;
  SOUND_MODE_ADLIB = 2;
  { the video BIOS function that returns the current mode in AL }
  BIOS_GET_VIDEO_MODE = $0F;
  { BIOS video modes }
  VIDEO_MODE_EGA_320X200 = $0D;
  VIDEO_MODE_TANDY_320X200 = $09;
  VIDEO_MODE_VGA_320X200 = $13;
  { the paragraphs HeapEnd is lowered by to make room for the Tandy screen }
  TANDY_HEAP_RESERVE_PARAGRAPHS = 1024;

var
  heapEndRec: Types.TPtrRec absolute HeapEnd;
  overlayReadFunc: Types.TOverlayReadFunc absolute OvrReadBuf;

{ Start up. GameIo.OverlayReadWithBeep becomes the overlay read hook. Run from a floppy, the overlays are read from
  the other floppy drive. TREASURE.CFG's lines are:
  - the sound device (displayMode);
  - the graphics card: E EGA, T Tandy, V VGA;
  - the input device: J joystick, M mouse, N none;
  - two configuration lines;
  - an 'S' flag (editorEnabled);
  - joystick calibration pairs.
  Too little memory for the overlay buffer, or an overlay error, ends the program. }
begin
  CheckBreak := False;
  DaxIo.OverlayPrompt;
  OvrInit('GAME.OVR');
  OvrInitEMS;
  GDVars.savedOvrReadBuf := overlayReadFunc;
  overlayReadFunc := GameIo.OverlayReadWithBeep;

  FSplit(FExpand('*.exe'), GDVars.exeDir, GDVars.exeName, GDVars.exeExt);
  if GDVars.exeDir[1] < 'C' then
  begin
    if GDVars.exeDir[1] = 'A' then
      GDVars.overlayDir := 'B:\'
    else
      GDVars.overlayDir := 'A:\'
  end else
    GDVars.overlayDir := GDVars.exeDir;
  GDVars.overlayDrive := GDVars.overlayDir[1];

  if not DaxIo.FileExists('treasure.cfg') then Halt(1);
  Assign(GDVars.configFile, 'treasure.cfg');
  Reset(GDVars.configFile);
  ReadLn(GDVars.configFile, GDVars.configChar);
  case GDVars.configChar of
    '1': GDVars.displayMode := GameBoot.SOUND_MODE_SOUND_BLASTER;
    '2': GDVars.displayMode := GameBoot.SOUND_MODE_ADLIB;
    '3', '4': GDVars.displayMode := C_Sound.TANDY_VOICES;
    '5': GDVars.displayMode := C_Sound.PC_SPEAKER
  else
    GDVars.displayMode := C_Sound.MUTED
  end;
  ReadLn(GDVars.configFile, GDVars.configChar);

  GDVars.regs.AH := GameBoot.BIOS_GET_VIDEO_MODE;
  Intr($10, Registers(GDVars.regs));
  GDVars.detectedVideoMode := GDVars.regs.AL;
  GDVars.initialVideoMode := GDVars.detectedVideoMode;
  GDVars.memoryNeeded := 350000;

  case GDVars.configChar of
    'E': begin
           GDVars.graphicsClass := C_Video.VM_EGA;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_EGA_320X200);
           GDVars.egaCurPageNum := 0;
           GDVars.egaOtherPageNum := 0;
           TextRend.SetupEgaCurrentPage(GDVars.egaCurPageNum);
           TextRend.SetupEgaOtherPage(GDVars.egaOtherPageNum);
           Dec(GDVars.memoryNeeded, 90000)
         end;
    'T': begin
           GDVars.graphicsClass := C_Video.VM_TANDY;
           GDVars.heapEndTemp := Ptr(heapEndRec.seg - GameBoot.TANDY_HEAP_RESERVE_PARAGRAPHS, heapEndRec.ofs);
           HeapEnd := GDVars.heapEndTemp;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_TANDY_320X200);
           Dec(GDVars.memoryNeeded, 90000)
         end;
    'V': begin
           GDVars.graphicsClass := C_Video.VM_VGA;
           Blit.SetVideoMode(GameBoot.VIDEO_MODE_VGA_320X200)
         end
  end;

  if (MemAvail - GDVars.memoryNeeded) + OvrGetBuf < 54000 then begin
    Blit.RestoreVideoMode;
    Write('Memory low.  Try to free up another ');
    Write(54000 - ((MemAvail - GDVars.memoryNeeded) + OvrGetBuf) + 1000);
    WriteLn(' bytes.');
    GDVars.configReadKey := ReadKey;
    Halt(0)
  end;
  OvrSetBuf((MemAvail - GDVars.memoryNeeded) + OvrGetBuf);
  if OvrResult <> ovrOk then begin
    Blit.RestoreVideoMode;
    WriteLn('Overlay error, program abort!');
    GDVars.configReadKey := ReadKey;
    Halt(0)
  end;

  ReadLn(GDVars.configFile, GDVars.configChar);
  case GDVars.configChar of
    'J': begin GDVars.joystickPresent := True; GDVars.mousePresent := False end;
    'M': begin GDVars.mousePresent := True; GDVars.joystickPresent := False end;
    'N': begin GDVars.mousePresent := False; GDVars.joystickPresent := False end
  end;
  ReadLn(GDVars.configFile, GDVars.configLine1);
  ReadLn(GDVars.configFile, GDVars.configLine2);
  ReadLn(GDVars.configFile, GDVars.configChar);
  GDConsts.editorEnabled := UpCase(GDVars.configChar) = 'S';
  Joystick.ProbeJoystick;
  if GDVars.joystickPresent then begin
    for GDVars.calibrationIndex := 0 to 6 do begin
      ReadLn(GDVars.configFile, GDVars.joystickCalibration[1].x.raw[GDVars.calibrationIndex]);
      ReadLn(GDVars.configFile, GDVars.joystickCalibration[1].y.raw[GDVars.calibrationIndex])
    end
  end;
  Close(GDVars.configFile)
end.
