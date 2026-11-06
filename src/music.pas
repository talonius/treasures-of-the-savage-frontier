{ Music -- loads the music driver (MUSIC.DAX block 0) and a tune's parameter block (another MUSIC.DAX block), starts and
  stops it through MusDrv, and hands sound effects to SoundDrv. GDVars.residentMode is MUSIC_INSTALLED while the driver
  runs and NO_DRIVER otherwise; nothing sets the SOUND_EFFECTS state that the SoundDrv reset tests look for. }
{$F+,O-,S+,R-,V-,B-,I-}
unit Music;

interface

{ Plays a sound effect: shuts down the music driver if it is installed, then passes the sound to SoundDrv.
  @param(soundId The effect for SoundDrv.SoundCommand.) }
procedure SendSoundCommand(soundId: Word);

{ Shuts down the music driver if it is installed, then calls SoundDrv.StartSound. }
procedure RestoreSoundDriver;

{ Starts the music described by a parameter block of MUSIC.dax. Nothing happens while sound is muted. SoundDrv's driver
  is reset if it is active, and a music driver installed with a different block is shut down; when no driver is
  installed the block is loaded and the driver installed with it. Then the driver is told to start (StartPlayback).
  @param(paramsDaxId The parameter block's entry in MUSIC.dax.) }
procedure StartMusic(paramsDaxId: Word);

{ Shuts down the music driver if it is installed. }
procedure StopMusic;

{ Loads the driver image, entry 0 of MUSIC.dax, into the driver buffer (cleared first) at its first paragraph boundary,
  and marks it loaded. A missing image stops the game with 'unable to load com file'. }
procedure LoadDriverCode;

{ Loads a parameter block of MUSIC.dax into the driver parameter buffer (cleared first) and points the driver's
  parameter pointer at it. Note: a missing block is not reported; the buffer is then left cleared.
  @param(paramsDaxId The block's entry in MUSIC.dax.) }
procedure LoadMusicBank(paramsDaxId: Word);

implementation

uses Types, GDConsts, GDVars, C_Sound, C_Driver, DaxIo, GameIo, ZeroFree, MusDrv, SoundDrv;

procedure SendSoundCommand(soundId: Word);
begin
  if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  SoundDrv.SoundCommand(soundId);
end;

procedure RestoreSoundDriver;
begin
  if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  SoundDrv.StartSound;
end;

procedure StartMusic(paramsDaxId: Word);
begin
  if GDVars.displayMode = C_Sound.MUTED then Exit;
  if GDVars.residentMode = C_Driver.SOUND_EFFECTS then SoundDrv.SoundCommand(GDConsts.resetSoundId);
  if GDVars.loadedParamsDaxId <> paramsDaxId then
    if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
  if GDVars.residentMode = C_Driver.NO_DRIVER then begin
    GDVars.loadedParamsDaxId := paramsDaxId;
    Music.LoadMusicBank(paramsDaxId);
    MusDrv.StartDriver(GDVars.driverLoadAddress, LongInt(GDVars.driverParams));
  end;
  MusDrv.StartPlayback(0);
end;

procedure StopMusic;
begin
  if GDVars.residentMode = C_Driver.MUSIC_INSTALLED then MusDrv.StopHook;
end;

procedure LoadDriverCode;
var
  data: Types.PByteBuffer;
  { Unused in this version; see the other implementations of this routine. }
  driverFile: file;
begin
  data := nil;
  DaxIo.LoadDax('MUSIC', '.dax', 0, GDVars.driverImageSize, data);
  if GDVars.driverImageSize = 0 then begin
    WriteLn('unable to load com file');
    GameIo.ExitGame(0);
  end;
  GameIo.ZeroFill(GDVars.driverImageBuffer^, 13000);
  GDVars.driverLoadAddress := LongInt(GDVars.driverImageBuffer);
  while Lo(GDVars.driverLoadAddress and $F) <> 0 do Inc(GDVars.driverLoadAddress);
  Move(data^, Types.PByteBuffer(GDVars.driverLoadAddress)^, GDVars.driverImageSize);
  ZeroFree.PrefixFree(data, GDVars.driverImageSize);
  GDVars.driverImageLoaded := 1;
end;

procedure LoadMusicBank(paramsDaxId: Word);
var
  data: Types.PByteBuffer;
  { Unused in this version; see the other implementations of this routine. }
  musicFile: file;
  { Unused in this version; see the other implementations of this routine. }
  bytesRead: Word;
begin
  DaxIo.LoadDax('MUSIC', '.dax', paramsDaxId, GDVars.driverParamsSize, data);
  GameIo.ZeroFill(GDVars.driverParamsBuffer^, 6144);
  GDVars.driverParams := GDVars.driverParamsBuffer;
  Move(data^, GDVars.driverParams^, GDVars.driverParamsSize);
  ZeroFree.PrefixFree(data, GDVars.driverParamsSize);
end;

begin
end.
