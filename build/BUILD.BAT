@echo off
rem Build all four shipped files from Pascal and TASM sources.
rem build.sh runs this in E:\src and creates E:\obj and E:\build\logs.
rem D: TP 6.0; E: version tree; F: TASM; G: EXEPACK; H: TP 5.5.
rem Keep PATH at D:\; other tools use drive-qualified commands.
rem TPC.CFG supplies switches; /E sends products to obj, /O finds objects.

rem Remove stale units, linked objects and outputs before building.
rem Guard DEL on a clean tree; REN requires an absent GAME.OVR.
if exist *.TPU del *.TPU
if exist *.OBJ del *.OBJ
if exist ..\obj\*.TPU del ..\obj\*.TPU
if exist ..\obj\SOUNDDRV.OBJ del ..\obj\SOUNDDRV.OBJ
if exist ..\obj\JOYSTICK.OBJ del ..\obj\JOYSTICK.OBJ
if exist ..\obj\GRAPHICS.OBJ del ..\obj\GRAPHICS.OBJ
if exist ..\obj\ZEROFILL.OBJ del ..\obj\ZEROFILL.OBJ
if exist ..\obj\VGAFRAME.OBJ del ..\obj\VGAFRAME.OBJ
if exist ..\obj\FIXMAIN.EXE del ..\obj\FIXMAIN.EXE
if exist ..\obj\FIXMAIN.OVR del ..\obj\FIXMAIN.OVR
if exist ..\obj\FIXMAIN.MAP del ..\obj\FIXMAIN.MAP
if exist ..\obj\GAME.EXE del ..\obj\GAME.EXE
if exist ..\obj\GAME.OVR del ..\obj\GAME.OVR
if exist ..\obj\CONTROL.EXE del ..\obj\CONTROL.EXE
if exist ..\obj\CONTROL.MAP del ..\obj\CONTROL.MAP
if exist ..\obj\STARTUP.EXE del ..\obj\STARTUP.EXE
if exist ..\obj\STARTUP.MAP del ..\obj\STARTUP.MAP
f:\tasm sounddrv,..\obj\sounddrv > e:\build\logs\TASM.OUT
f:\tasm joystick,..\obj\joystick >> e:\build\logs\TASM.OUT
f:\tasm graphics,..\obj\graphics >> e:\build\logs\TASM.OUT
f:\tasm zerofill,..\obj\zerofill >> e:\build\logs\TASM.OUT
f:\tasm vgaframe,..\obj\vgaframe >> e:\build\logs\TASM.OUT
path d:\
tpc fixmain.pas /B /E..\obj /O..\obj > e:\build\logs\TPC.OUT
g:\exepack ..\obj\FIXMAIN.EXE ..\obj\GAME.EXE > e:\build\logs\PACK.OUT
ren ..\obj\FIXMAIN.OVR GAME.OVR
rem Clear TP 6.0 units before compiling utilities with TP 5.5.
if exist ..\obj\*.TPU del ..\obj\*.TPU
h:\tpc control.pas /M /E..\obj /O..\obj >> e:\build\logs\TPC.OUT
h:\tpc startup.pas /M /E..\obj /O..\obj >> e:\build\logs\TPC.OUT
