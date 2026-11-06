{ The main program. }
{$M 16384,0,655360}
{$F+,O+,S+}
program FixMain;

uses
  Types, Overlay,
  Dos,
  Crt,
  GDConsts, GDVars,
  ModeInit,
  Joystick,
  Mouse,
  SoundDrv,
  MusDrv,
  GameIo,
  DaxIo,
  Music,
  TextRend,
  Blit,
  GameBoot,
  Border,
  Sym8x8,
  MapTiles,
  CbtMap,
  Pathing,
  EmptyC,
  View3D,
  Portrait,
  MapView,
  MenuCore,
  ClassCal,
  MapCurs,
  CharHlp,
  FxEngine,
  Magic,
  Money,
  GameTime,
  ViewChar,
  CbtActs,
  EffHndlr,
  Camp,
  GameInit,
  CharGen,
  SaveLoad,
  Romance,
  DevMenu,
  GeoEdit,
  Explore,
  CombatSt,
  CombatAi,
  Combat,
  EclMenu,
  Shop,
  PostCbt,
  Temple,
  CopyProt,
  Vault,
  Restart,
  EclVm,
  Intro,
  HeapErr,
  C_Ifc;

{$O Sym8x8}
{$O MapTiles}
{$O CbtMap}
{$O Pathing}
{$O View3D}
{$O Portrait}
{$O MapView}
{$O MenuCore}
{$O ClassCal}
{$O MapCurs}
{$O CharHlp}
{$O FxEngine}
{$O Magic}
{$O Money}
{$O GameTime}
{$O ViewChar}
{$O CbtActs}
{$O EffHndlr}
{$O GameInit}
{$O CharGen}
{$O SaveLoad}
{$O Romance}
{$O Camp}
{$O DevMenu}
{$O GeoEdit}
{$O Explore}
{$O CombatSt}
{$O CombatAi}
{$O Combat}
{$O EclMenu}
{$O Shop}
{$O PostCbt}
{$O Temple}
{$O CopyProt}
{$O Vault}
{$O Restart}
{$O EclVm}
{$O Intro}

{ Start up (GameInit.InitializeGame) and load the music driver. Without the parameter '1', show the introduction (unless
  GDConsts.editorEnabled) and the title menu, whose Demo choice, or no key within 3 seconds, starts the demo; with '1',
  load a game through SaveLoad.LoadGame(#1) and redraw its screen. Then loop forever: outside the demo and a '1' start,
  the main menu (CharGen.MainMenu), the journal check and its four stage flags, aborting on a failure, and the screen
  layout; then the scripts run until the party is defeated (EclVm.GameLoop) and the game state is reset
  (GameInit.ResetGameState). A demo replays the introduction and the title menu (5 seconds) between runs. }
begin
  GameInit.InitializeGame;
  Music.LoadDriverCode;
  if ParamStr(1) <> '1' then
  begin
    GDVars.gameUp := 0;
    if not GDConsts.editorEnabled then
      Intro.Introduction;
    CharHlp.ClearEncounterState;
    GDVars.menuAutoDelay := 3000;
    GDVars.menuAutoChoice := #1;
    MenuCore.ResetMenuSlots(1);
    GDVars.menuResult := MenuCore.MenuHorizontal(GDConsts.titleText, GDConsts.playDemoMenu, 0, 0);
    Blit.SetDacPalette(16, 16, GDVars.activePalette);
    GDVars.menuAutoDelay := 0;
    GDVars.menuAutoChoice := #1;
    GDVars.alternateStart := 0
  end else begin
    GDVars.alternateStart := 1;
    SaveLoad.LoadGame(#1);
    GDVars.locState.current := GDVars.locState.previous;
    CharHlp.DisplayNoncombatInterface
  end;
  if GDVars.menuResult = #1 then
    GDVars.inputAbort := True;
  repeat
    Music.StopMusic;
    Blit.SetDacPalette(16, 16, GDVars.activePalette);
    if GDVars.inputAbort then
      GDVars.gameState^.gameDelay := 9
    else
      GDVars.gameUp := 1;
    if (not GDVars.inputAbort) and (GDVars.alternateStart = 0) then begin
      CharGen.MainMenu;
      if CopyProt.CopyProtection <> True then
        GameIo.ExitGame(0);
      for GDVars.checkIndex := 1 to 4 do
        if GDVars.journalFlags4[GDVars.checkIndex] = 0 then
          GameIo.ExitGame(0);
      if (GDVars.locState.current = C_Ifc.AREA_MAP) and (GDVars.gameState^.layoutFlag = 1) then
        Border.ScreenText
      else
        Border.DrawExploreFrame;
      CharHlp.DisplayParty(GDVars.curChar)
    end;
    View3D.SetView3DColors(GDVars.viewColors[0], GDVars.viewColors[1], GDVars.viewColors[2],
                           GDVars.viewColors[3]);
    EclVm.GameLoop;
    GameInit.ResetGameState;
    if GDVars.inputAbort then begin
      Music.SendSoundCommand(GDConsts.resetSoundId);
      Intro.Introduction;
      Music.RestoreSoundDriver;
      GameIo.DrainKeys;
      GDVars.menuAutoDelay := 5000;
      GDVars.menuAutoChoice := #1;
      MenuCore.ResetMenuSlots(1);
      GDVars.menuResult := MenuCore.MenuHorizontal(GDConsts.titleText, GDConsts.playDemoMenu, 0, 0);
      GDVars.menuAutoDelay := 0;
      GDVars.menuAutoChoice := #0;
      GDVars.inputAbort := (GDVars.menuResult = #1);
      Music.SendSoundCommand(GDConsts.soundOffId)
    end
  until False
end.
