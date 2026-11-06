{ Stages ZOUNDS sound requests for the resident INT $66 KERN driver. GDVars holds the sound table, staging pointer and
  command buffer: soundTable, stagingBuffer and driverCommand. }
{$F+,O-,S+,R-,V-,B-,I-,A+}
unit SoundDrv;

interface

{ Plays a sound effect, after the driver finishes the one before: copies the loaded sound into the staging buffer and
  sends the driver the play command. Nothing happens without a driver or while sound is muted.
  @param(soundId The effect, 2..12; other ids play nothing.) }
procedure SoundCommand(soundId: Word);

{ Does nothing. DaxIo calls it at the end of disk access when the sound driver is in use, and Music after shutting down
  the music driver. }
procedure StartSound;

implementation

uses Types, GDVars, C_Sound;

{$L SOUNDDRV.OBJ}
{ Hand the driver a command block.
  @param(commandOffset The block's offset in the data segment.) }
procedure DriverDispatch(commandOffset: Word); external;

{ Return whether the driver is still playing.
  @returns(True while it plays.) }
function DriverBusy: Boolean; external;

{ Return whether the sound driver is installed, by its "KERN" signature.
  @returns(True when it is.) }
function DriverPresent: Boolean; external;

procedure SoundCommand(soundId: Word);
var
  bufferPtrCopy: Pointer;
begin
  if GDVars.displayMode <> C_Sound.MUTED then
    if (soundId > 1) and (soundId < 13) then
      if SoundDrv.DriverPresent then begin
        while SoundDrv.DriverBusy do ;
        FillChar(GDVars.driverCommand, SizeOf(GDVars.driverCommand), 0);
        FillChar(GDVars.stagingBuffer^, 9000, 0);
        GDVars.driverCommand.sampleRate := 9000;
        GDVars.driverCommand.size := LongInt(GDVars.soundTable[soundId - 1].size);
        Move(GDVars.soundTable[soundId - 1].data^, GDVars.stagingBuffer^,
                    GDVars.soundTable[soundId - 1].size);
        bufferPtrCopy := GDVars.stagingBuffer;
        Move(bufferPtrCopy, GDVars.driverCommand, SizeOf(bufferPtrCopy));
        SoundDrv.DriverDispatch(Ofs(GDVars.driverCommand));
      end;
end;

procedure StartSound;
begin
end;

begin
end.
