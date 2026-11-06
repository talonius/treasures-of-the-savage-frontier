{ Call gate to the music driver Music loads from MUSIC.DAX. The entry point, parameter words, selected mode and last
  result are in GDVars; this unit rebases the loaded code pointer to its COM-style entry. }
{$F+,S+,A+}
unit MusDrv;

interface

{ Calls the driver's dispatch entry with a function code and a far argument; returns its status. Codes used: 0 install
  (StartDriver), 1 start (StartPlayback), 3 stop (StopHook).
  @param(func Driver function code.)
  @param(offset Offset of the far argument.)
  @param(segment Segment of the far argument.)
  @returns(The driver's status.) }
function DriverCall(func, offset, segment: Word): Word;

{ Marks the music driver installed and halts unless the image address is a paragraph multiple; turns the address into a
  far entry point whose segment starts 256 bytes below the image, as if the image had been loaded behind a PSP; saves
  the parameter block and sends the initialize event.
  @param(codeAddress Far address of the loaded driver image, as a LongInt.)
  @param(bankAddress The parameter block handed to the driver at install.) }
procedure StartDriver(codeAddress: LongInt; bankAddress: LongInt);

{ Calls driver code 1 when given 0; any other value does nothing.
  @param(skipStart 0 to start playback.) }
procedure StartPlayback(skipStart: Word);

{ When the music driver is installed, marks it idle and sends it the shutdown event. }
procedure StopHook;

implementation

uses GDVars, C_Driver;

const
  DRIVER_EVENT_INITIALIZE = 0;
  DRIVER_EVENT_SHUTDOWN = 3;

function DriverCall(func, offset, segment: Word): Word;
begin
  DriverCall := GDVars.residentHandler(segment, offset, func);
end;

procedure StartDriver(codeAddress: LongInt; bankAddress: LongInt);
begin
  GDVars.residentMode := C_Driver.MUSIC_INSTALLED;
  if Byte(codeAddress and $0000000F) <> 0 then
    Halt(0);
  Inc(codeAddress, (codeAddress and $0000FFF0) shl 12);
  codeAddress := codeAddress and $FFFF0000;
  Inc(codeAddress, $100);
  Dec(codeAddress, $100 shl 12);
  @GDVars.residentHandler := Pointer(codeAddress);
  Move(bankAddress, GDVars.residentHandlerArgs, SizeOf(GDVars.residentHandlerArgs));
  GDVars.driverResult := MusDrv.DriverCall(MusDrv.DRIVER_EVENT_INITIALIZE, GDVars.residentHandlerArgs[0],
                             GDVars.residentHandlerArgs[1]);
end;

procedure StartPlayback(skipStart: Word);
begin
  if skipStart <> 0 then Exit;
  GDVars.driverResult := MusDrv.DriverCall(1, 0, 0);
end;

procedure StopHook;
begin
  if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then begin
    GDVars.residentMode := C_Driver.NO_DRIVER;
    GDVars.driverResult := MusDrv.DriverCall(MusDrv.DRIVER_EVENT_SHUTDOWN, 0, 0);
  end;
end;

begin
end.
