{ Global variables: every variable in the data segment, grouped in sections by the subsystem that owns them and kept in
  address order. A new section starts wherever the data needs a word boundary. }
unit GDVars;

interface

uses Types;

{ The title menu, the copy-protection loop and the script interpreter's run state. }
var
  { the key the title menu returned }
  menuResult: Char;
  { FixMain's loop over the four copy-protection flags }
  checkIndex: Byte;
  { unused }
  checkIndexTail: array[0..1] of Byte;
  { the title picture, loaded, shown and freed by Intro }
  titleImage: Types.PImage;
  { set to stop CallEclScript's loop }
  loopRunning: Byte;
  { set when a script has moved the party to a new area; cleared before the next area script runs }
  areaExitFlag: Boolean;
  { set when the script loop must put pendingCharHalves back as the current character }
  pendingCharSwap: Boolean;

{ The script's saved character and the copy-protection challenge. }
var
  { the character pendingCharSwap restores, by its offset and segment }
  pendingCharHalves: Types.TPtrRec;
  { the decoded word the check asks for }
  correctWord4: String;
  { the player's answer }
  enteredWord4: String;
  { tries so far; the check allows three }
  attemptCount4: Byte;
  { unused }
  attemptCount4Tail: Byte;
  { journal page asked, 1..21 }
  pageIndex4: Byte;
  { word slot on that page, 1..3 }
  wordIndex4: Byte;
  { unused }
  wordIndex4Tail: Byte;

{ The end of a fight, and the shop's menu. }
var
  { there were monsters to defeat }
  monstersKilled: Boolean;
  { set when a party member ran from the fight }
  partyFled: Boolean;
  { the defeated monsters left coins }
  treasureHasMoney: Boolean;
  { the defeated monsters left items }
  treasureHasItems: Boolean;
  { MenuVertical's redraw flag for the shop and treasure menus }
  menuNeedsRedraw: Boolean;

{ The combat AI's movement. }
var
  { AiMoveStep's last direction tried; 8 = none }
  lastMoveDir: Byte;
  { AiMoveStep's oscillation counter }
  stuckCount: Byte;
  { only ever cleared, by AiMoveAttack }
  stuckCountTail: Byte;

{ Combat set-up: placing the two teams on the arena and drawing its walls. }
var
  { [team, ring, qy, qx], 1 = free }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { each team's base square column, relative to the party }
  placeX: array[0..1] of ShortInt;
  { each team's base square row, relative to the party }
  placeY: array[0..1] of ShortInt;
  { each team's placement tries on the first pass of a ring }
  teamRows: array[0..1] of ShortInt;
  { each team's facing, as a quarter turn 0..3 }
  teamDir: array[0..1] of ShortInt;
  { BuildDungeonArena's loop variables, at unit level; PlotCell reads them directly }
  dx: ShortInt;
  { the row of the dungeon square being drawn, relative to the party }
  dy: ShortInt;
  { that square's north wall: 0 open, 1 solid, 3 any other wall }
  wallN: Byte;
  { its west wall, coded the same way }
  wallW: Byte;
  { its east wall }
  wallE: Byte;
  { written, never read }
  wallS: Byte;
  { the team being placed }
  team: ShortInt;
  { JoinBattle's slot }
  joinSlot: Byte;
  { the terrainClassTbl index for the ground under the party }
  terrainChar: Byte;
  { unused }
  terrainCharTail: array[0..5] of Byte;

{ The map editor: the map number. }
var
  { the map being edited, 0..99 }
  mapNumber: Byte;

{ The map editor: wall sets. }
var
  { its three wall sets }
  wallSet: array[1..3] of Byte;

{ The map and item editors' cursor. }
var
  { +1 or -1, the step the edit keys apply }
  direction: Integer;
  { the item field the editor cursor is on, 0..14 }
  itemField14Local: Byte;

{ Start-up: the screen-row tables and the ITEMS file. }
var
  { video row being tabulated, 0..199 }
  rowIndex: Byte;
  { unused }
  rowIndexTail: Byte;
  { set when GameInit opened ITEMS }
  itemsFileOpen: Boolean;

{ Start-up: the mouse probe and the ITEMS file. }
var
  { unused }
  cursorOpenTail: array[0..43] of Byte;
  { the buttons GameInit reads once at start-up }
  mouseButtons: Integer;
  { the mouse's column then; a column past 320 means the driver counts in high resolution }
  probeMouseX: Integer;
  { and its row }
  probeMouseY: Integer;
  { ITEMS, the base-item table GameInit reads }
  itemsFile: file;
  { unused }
  cursorFileTail: Byte;

{ Start-up row tables; the character sheet, the spell selector and the menu animation. }
var
  { rowIndex's offset: +40 a row, or +10 per four }
  rowOffset: Word;
  { the character the sheet shows, and the one it trades with }
  globals: Types.TOvr19Globals;
  { per party member: nonzero while its timed effects still need aging }
  effectFlags: array[1..72] of Byte;
  { the spell selector's list: the menu lines, then per spell line its count, its spell id and the scroll it is on }
  selectorVars: record
    spellList: Types.PItemRec;
    spellCounts: array[0..141] of Byte;
    spellIds: array[0..141] of Byte;
    scrollPtrs: array[0..48] of Pointer;
    scrollSlots: array[0..48] of Byte;
    scrollCount: Byte
  end;
  { a strength spell's working value: [0] the strength, [1] its exceptional percentage }
  spellTempsView: array[0..1] of Byte;
  { the weight of what a character carries, totalled by CharHlp }
  equippedWeight: Word;
  { the tick each menu animation last stepped; [0] times the picture's frames }
  animationTicks: array[0..4] of LongInt;
  { CPIC key of the icon loaded in iconSet slot 8..12 }
  monsterKeys: array[8..12] of Byte;

{ Boot: the configuration file, the memory check and the game's directories. }
var
  { the key that dismisses a start-up error }
  configReadKey: Char;
  { unused }
  configReadKeyTail: Byte;
  { HeapEnd lowered on a Tandy, to keep its video memory free }
  heapEndTemp: Pointer;
  { unused }
  heapEndTempTail: Byte;
  { the line of treasure.cfg being read }
  configChar: Char;
  { unused }
  configCharTail: array[0..1] of Byte;
  { treasure.cfg, which STARTUP wrote }
  configFile: Text;
  { unused }
  configFileTail: array[0..128] of Byte;
  { the joystick calibration line being read from the cfg }
  calibrationIndex: Byte;
  { unused }
  calibrationIndexTail: array[0..81] of Byte;
  { the game's file name, from FSplit }
  exeName: String[8];
  { unused }
  exeNameTail: Byte;
  { and its extension }
  exeExt: String[4];
  { unused }
  exeExtTail: array[0..82] of Byte;
  { the memory kept back from the overlay buffer; less on EGA and Tandy }
  memoryNeeded: LongInt;
  { the colors last written to the DAC, so only changed runs are written again }
  dacPalette: Types.TPalette;
  { the directory the game runs from; OpenWithRetry swaps it with overlayDir when a file is missing }
  exeDir: String[79];
  { the other place to look for files: the other floppy drive, or exeDir on a hard disk }
  overlayDir: String[79];
  { overlayDir's drive letter, named in the insert-disk prompt }
  overlayDrive: Char;

{ The music driver's result; the game state, script VM and location; the run's flags. }
var
  { the music driver's last result }
  driverResult: Word;
  { unread }
  driverResultTail: array[0..3] of Byte;
  { the game state a save holds }
  gameState: Types.PGameState;
  { the ECL VM's zone pointers, run addresses and instruction pointer }
  vmBand: Types.TVmBand;
  { where the party is: wilderness, dungeon, camp, combat and so on }
  locState: Types.TLocState;
  { set when a key or click cut a demo or a wait short }
  inputAbort: Boolean;
  { nonzero while the party panel is on show }
  partyShown: Byte;
  { set once a game has been started or loaded }
  loadComplete: Byte;
  { SaveLoad sets it after a load; EclMenu tests it }
  loadedSavedGameFlag: Byte;
  { rest steps since GameTime's last interruption roll }
  restTicks: Word;
  { set when the party is defeated; MapView then draws nothing }
  partyDefeated: Boolean;
  { set when a fight ends; DisplayMessageWindow then paces each character }
  msgDelayFlag: Byte;
  { set once the game is running, so HeapErr saves before it stops }
  gameUp: Byte;

{ Video: the BIOS registers, the EGA pages and the video modes. }
var
  { register block for the BIOS and DOS calls }
  regs: Types.TRegisters;
  { the EGA page segments drawn to and shown }
  egaPages: Types.TEgaPages;
  { the EGA page drawn to }
  egaOtherPageNum: Byte;
  { the EGA page shown }
  egaCurPageNum: Byte;
  { the video mode the BIOS reported at start-up }
  detectedVideoMode: Byte;
  { the mode RestoreVideoMode puts back }
  initialVideoMode: Byte;
  { EGA, Tandy or VGA, from treasure.cfg }
  graphicsClass: Byte;

{ Video: the view surface, the dirty spans and the row tables. }
var
  { the off-screen picture the view is composed in }
  viewSurface: Types.PImage;
  { the picture BlitTileClipped draws into }
  savedPic: Types.PImage;
  { unused }
  savedPicTail: array[0..15] of Byte;
  { The view's deferred spans, one slot per view scanline 0..167; the writers do not check a row against the bounds.
    Nonzero when the scanline must be flushed. }
  spanActive: array[0..167] of Byte;
  { Screen columns, scaled for the graphics mode. }
  spanLow: array[0..167] of Word;
  { First image-data offsets; reset to $FFFF. }
  spanHigh: array[0..167] of Word;
  { Inclusive last image-data offsets; reset to zero. }
  spanExtra: array[0..167] of Word;
  { unused }
  spanExtraTail: array[0..671] of Byte;
  { each screen row's offset in an EGA page }
  egaRowOffset: array[0..199] of Word;
  { each screen row's segment in Tandy video memory }
  tandyRowSegment: array[0..199] of Word;
  { set to 1 by GameInit, never read }
  clipFlag: Byte;

{ Sound: the sound mode and the music driver image. }
var
  { the sound hardware from treasure.cfg; MUTED when sound is off }
  displayMode: Byte;
  { the sound mode the sound toggle puts back }
  savedDisplayMode: Byte;
  { the music toggle; off stops the resident driver }
  residentToggle: Boolean;
  { unused }
  residentToggleTail: array[0..8] of Byte;
  { where the driver image sits in driverImageBuffer, rounded up to a paragraph }
  driverLoadAddress: LongInt;
  { the driver image's size in MUSIC.DAX }
  driverImageSize: Word;
  { the loaded tune data the driver plays }
  driverParams: Pointer;
  { its size }
  driverParamsSize: Word;
  { residentMode while DaxIo has the sound effects stopped for disk access }
  savedResidentMode: Byte;
  { which resident driver is installed: none, music or sound effects }
  residentMode: Byte;
  { set once the driver image is in memory }
  driverImageLoaded: Byte;

{ Sound: the music driver's buffers. }
var
  { 13000 bytes for the driver image }
  driverImageBuffer: Types.PByteBuffer;
  { 6144 bytes for the tune data }
  driverParamsBuffer: Types.PByteBuffer;
  { the MUSIC.DAX block in driverParamsBuffer; $FF for none }
  loadedParamsDaxId: Byte;

{ The music driver's entry; the save directories; the item, party, text, picture, combat, treasure, effect, 3-D view and
  picture-animation state. }
var
  { the loaded driver's entry point }
  residentHandler: Types.TResidentHandler;
  { the bank address handed to the driver when it starts }
  residentHandlerArgs: array[0..1] of Word;
  { the directory of Gateway characters (.guy), from treasure.cfg }
  configLine2: String;
  { the directory of saved games and characters (.pc), from treasure.cfg }
  configLine1: String;
  { nonzero stops the insert-disk prompt when a DAX file is missing }
  suppressDiskPrompt: Byte;
  { set by a save, cleared by anything worth saving; quitting asks only when it is clear }
  recentlySaved: Byte;
  { the base item types from ITEMS, by item type }
  baseItems: array[0..128] of Types.TBaseItem;
  { the target of the last spell cast outside combat, offered first next time }
  lastSpellTarget: Types.PCharacter;
  { the party member the panel shows highlighted }
  highlightedCharacter: Types.PCharacter;
  { the character acting or shown }
  curChar: Types.PCharacter;
  { the first party member }
  partyHead: Types.PCharacter;
  { the party member last clicked on the panel }
  alternateChar: Types.PCharacter;
  { the item MakeAttack last added to treasureItems; its walk stops there }
  currentItem: Types.PItem;
  { 1 once the party has aged; Combat clears it }
  agingFlag: Byte;
  { unused }
  agingFlagTail: Byte;
  { the item templates of ITEM0.DAX }
  itemDefs: Types.PItemDefs;
  { the file DaxIo erases }
  ioScratchFile: file;
  { the bytes read from ITEMS }
  itemsBytesRead: Word;
  { 1416 bytes GameInit takes for the font; never read }
  gameFontPtr: Pointer;
  { unused }
  gameFontPtrTail: array[0..7] of Byte;
  { the text cursor's column }
  curCol: Byte;
  { the text cursor's row }
  curRow: Byte;
  { unused }
  curRowTail: array[0..2] of Byte;
  { the text window's left column, top row, right column and bottom row }
  viewBounds: array[0..3] of Byte;
  { unused }
  viewBoundsTail: array[0..12] of Byte;
  { the tile banks the 8x8 symbols are drawn from }
  banks: array[0..4] of Types.PImage;
  { the cursor tile composed for the automap }
  secondaryViewBank: Types.PImage;
  { the combat map's 24-pixel terrain tiles }
  icon24Bank: Types.PImage;
  { the combat icons, by icon slot and frame }
  iconSet: array[0..42, 0..1] of Types.PImage;
  { the combatants on the arena }
  actorCount: Byte;
  { unused }
  actorCountTail: Byte;
  { each combatant's arena cell, by combat slot }
  actor: array[1..72] of Types.TActor;
  { each combatant's cell relative to the arena view }
  work: Types.TOvr35Work;
  { CbtMap: [y, x]: index of the actor on that cell, 0 = none }
  actorGrid: array[0..24, 0..49] of Byte;
  { CbtMap: the combat creatures, by creature index }
  creatureArr: array[1..72] of Types.PCharacter;
  { the fallen combatants and the cells they lie on }
  downed: array[1..8] of Types.TDownedRec;
  { how many of them there are }
  downedCount: Byte;
  { unused }
  downedCountTail: Byte;
  { the combat arena }
  combatMap: Types.PCombatMap;
  { how many rankedTargets entries are in use }
  targetCount: Byte;
  { unused }
  targetCountTail: Byte;
  { Pathing.BuildTargetList's results, targetCount entries in rank order }
  rankedTargets: array[1..72] of Types.TCombatTarget;
  { the party's pooled platinum, gems and jewelry }
  pooledMoney: array[0..2] of LongInt;
  { the treasure on the ground: items left by a fight or dropped in a shop }
  treasureItems: Types.PItem;
  { the combatants still standing on each side }
  sideTally: array[0..1] of Byte;
  { the effect names, bord.dax block 9 }
  effectNames: Types.PEffectNames;
  { the saving throw being rolled; effect handlers adjust it }
  saveRoll: Byte;
  { FxEngine: effect being applied; a handler clears it to block it }
  pendingEffectId: Byte;
  { the kind of damage being dealt, as bits the resistance handlers test: 1 fire, 2 cold, 4 electricity, 8 magic, $10
    gaze, $20 breath }
  effectMask: Byte;
  { scratch for the attack-rate and initiative handlers }
  fxScratchB: Byte;
  { scratch for the movement handlers }
  fxScratchA: Byte;
  { the spell id being resolved; 0 for a weapon }
  opMode: Byte;
  { the dice RollDice last rolled }
  diceCount: Byte;
  { unused }
  diceCountTail: Byte;
  { damage about to be dealt; handlers may reduce or cancel it }
  pendingDamage: Integer;
  { set by a target or attacker veto effect to forbid the attack }
  attackVetoed: ShortInt;
  { set while a spell's effects are being applied outside combat }
  effectBusy: Byte;
  { set while an attack or spell is resolving in combat }
  effectInProgress: Byte;
  { set when a spell has changed the character the sheet shows }
  viewCharRedraw: Byte;
  { the attack roll being resolved; effect handlers adjust it }
  attackRoll: ShortInt;
  { unused }
  attackRollTail: Byte;
  { the hits landed in each attack phase during the current swing }
  attackHits: array[1..2] of Byte;
  { the size of an effect: morale, or how much a spell changes }
  effectMagnitude: Byte;
  { unused }
  effectMagnitudeTail: Byte;
  { the target of the creature whose effect is being run }
  effectTarget: Types.PCharacter;
  { the kind of saving throw being rolled }
  saveType: ShortInt;
  { 1 when the saving throw succeeded }
  saveResult: Byte;
  { cleared before an attack; never read }
  initiativeSeed: Byte;
  { set when the attack roll is high enough for a vorpal weapon to behead }
  beheadOk: Boolean;
  { the effect handlers, by effect id }
  effectHandlers: array[1..160] of Types.TEffectHandler;
  { the wall definitions of the loaded wall sets, 2340 bytes }
  wallDefs: Pointer;
  { the dungeon map: walls, doors and events by cell }
  geoMap: Types.PGeoMap;
  { the 3-D view's sky, horizon and ground colors }
  viewColors: array[0..3] of Byte;
  { set while the automap is on show in place of the 3-D view }
  automapShown: Boolean;
  { unused }
  automapShownTail: Byte;
  { where the party stands and faces }
  partyPos: Types.TPartyPos;
  { unused }
  eventAtCellTail: Byte;
  { the wall sets loaded into the three symbol slots }
  wallSetCache: array[1..3] of Types.TWallSetCacheSlot;
  { cleared by GameInit, never read }
  skyPtrA: Pointer;
  { cleared by GameInit, never read }
  skyPtrB: Pointer;
  { cleared by GameInit, never read }
  skyPtrC: Pointer;
  { set while palettePreset cycles the picture's colors }
  palettePresetOn: Byte;
  { set when the 3-D view supplied the cycle data, so the next picture keeps it }
  overMapCycle: Byte;
  { the displayed picture's palette-cycle chunks }
  palettePreset: array[1..4] of Types.TChunk3;
  { Byte 1 is set when the picture has cycle data }
  savedCycleChunk32: Types.TChunk3;

{ Pictures: the saved palette-cycle chunk. }
var
  { the last picture's cycle chunk, kept for the 3-D view }
  savedCycleChunk: Types.TChunk3;

{ Pictures: the loaded picture's frames and animation; menu state. }
var
  { the cycle chunk read with the picture }
  picCycleChunk3: Types.TChunk3;
  { set when the picture came from a sprite archive rather than a VGA picture file }
  spriteArchive: Boolean;
  { each frame's delay, in tenths of a second; 99 holds the frame }
  menuAnimDelays: array[0..8] of Byte;
  { each frame's size in the picture file }
  frameSizes: array[0..8] of Word;
  { the frame stored whole; the others are differences from it }
  keyFrameIndex: Byte;
  { the frame the animation loops back to }
  firstFrameIndex: Byte;
  { the last frame }
  lastFrameIndex: Byte;
  { the frame on show }
  curFrameIndex: Byte;
  { unused }
  mouseCounterCurTail: Byte;
  { the VGA frames and the picture they are composed in }
  vgaState: Types.TVgaState;
  { the EGA and Tandy frames }
  imageFrames: Types.TPicTable;
  { cleared by GameInit, never read }
  animFrames: array[0..65] of Byte;
  { the archive the loaded picture came from }
  resourceCurrentName: String[8];
  { unused }
  resourceCurrentNameTail: Byte;
  { the archive of the picture shown before camp, put back after it }
  resourceSavedName: String[8];
  { the loaded picture's block; 9 is the camp picture }
  resourceCurrentId: Byte;
  { the block of the picture shown before camp; $FF for none }
  resourceSavedId: Byte;
  { unused }
  resourceSavedIdTail: Byte;
  { the big picture on show }
  bigPicture: Types.PImage;
  { its id; $FF forces the next one to load }
  bigPicId: Byte;
  { unused }
  bigPicIdTail: Byte;
  { nonzero while the party panel picks a character for a menu rather than changing curChar }
  selectionMode: Byte;
  { unused }
  selectionModeTail: Byte;
  { the character the panel has picked for the menu }
  menuSelection: Types.PCharacter;
  { the first list line the vertical menu shows }
  vertTop: Integer;
  { MenuCore: the highlighted option of the horizontal menu, from 1 }
  horizChoice: Byte;
  { MenuCore: the menu returned a key code, not a slot index }
  menuReturnedKey: Boolean;
  { set while the mouse is over the menu }
  menuMouseActive: Boolean;
  { unused }
  menuMouseActiveTail: Byte;
  { MenuHorizontal picks menuAutoChoice after this many ticks }
  menuAutoDelay: LongInt;
  { What MenuHorizontal returns once the delay runs out }
  menuAutoChoice: Char;
  { unused }
  menuAutoChoiceTail: Byte;
  { the screen row of each vertical menu line, $FF past the last }
  menuHotRows: array[1..25] of Byte;
  { the first column of the menu's clickable hotkeys; 127 when there are none }
  menuKeyColLo: ShortInt;
  { and the last; -128 when there are none }
  menuKeyColHi: ShortInt;
  { the party panel's clickable area: its left column }
  partyPanelLeft: Byte;
  { its right column }
  partyPanelRight: Byte;
  { its top row }
  partyPanelTop: Byte;
  { its bottom row }
  partyPanelBottom: Byte;
  { the character-modify field the mouse picked; $FF for none }
  modifyMouseRow: Byte;
  { set to $FF before a menu; never read }
  menuCursorIndex: Byte;
  { unused }
  menuCursorIndexTail: Byte;
  { the menu's options, by slot }
  menuSlots: array[0..19] of Types.TMenuSlot;
  { the menu text color }
  menuTextColor: Byte;
  { the color of a menu's prompt }
  queryColor: Byte;
  { the color of its hotkeys }
  highlightColor: Byte;
  { unused }
  highlightColorTail: Byte;
  { the scroll the spell selector picked a spell from }
  selectedItem: Types.PItem;
  { that spell's slot on the scroll }
  scribeSpellIndex: Byte;

{ Spell casting: the targets and the spell routines. }
var
  { the spell routines and the target picker for combat or camp }
  spellFns: Types.TSpellFns;
  { how many spellTargets entries are in use }
  castTargetCount: Byte;
  { unused }
  castTargetCountTail: Byte;
  { the spell's targets }
  spellTargets: array[1..72] of Types.PCharacter;
  { the spell's target cell: its column }
  targetCoordX: ShortInt;
  { and its row }
  targetCoordY: ShortInt;
  { the clouds on the arena }
  cloudHead: Types.PCloudNode;
  { set while a spell is cast from an item }
  usingItem: Byte;

{ The shop's pooled-money flag. }
var
  { set while money is pooled in a shop }
  poolHasMoney: Boolean;

{ Rest and the clock; interface flags; combat rounds, initiative, the script VM and the encounter. }
var
  { nonzero while Camp's fix rests the party }
  fixBusy: Byte;
  { unused }
  fixBusyTail: Byte;
  { the rest time set on the rest menu }
  restClock: Types.TClock;
  { each party member's ticks until it memorizes its next spell }
  prepTimer: array[1..8] of Byte;
  { the day's rest ticks; 288 heal a day's worth }
  healTicks: Word;
  { set while GameTime rests without the border drawn }
  noBorder: Byte;
  { unused }
  noBorderTail: Byte;
  { set when the view must be redrawn when the script returns }
  pendingRefresh: Byte;
  { unused }
  overrideFlagLead: Byte;
  { nonzero sends every effect to handler 127 }
  overrideFlag: Byte;
  { unused }
  overrideFlagTail: array[0..1] of Byte;
  { where characters are added from: 0 Gateway characters, 1 this game's }
  storageMode: ShortInt;
  { set to leave the character modify loop }
  modifyDone: Byte;
  { unused }
  modifyDoneTail: Byte;
  { set while a character is being modified }
  modifyActive: Byte;
  { set while a character is being trained rather than created }
  trainMode: Byte;
  { 1: the spell menus redraw the memorize display }
  memorizeRedraw: Byte;
  { unused }
  memorizeRedrawTail: Byte;
  { Camp: the magic-user bonus-slot value the slot display clears }
  magicBonusSlots: Byte;
  { unused }
  magicBonusSlotsTail: Byte;
  { set when the player chose to attack an ally; never read }
  allyFlag: Byte;
  { the combat round }
  cbRoundCounter: Byte;
  { the round at which a fight with no attacks made ends }
  cbNewFlag: Byte;
  { unused }
  cbNewFlagTail: Byte;
  { creatureArr indexes in the order targets are tried }
  targetOrder: array[1..72] of Byte;
  { the attacks made in each phase of the current swing }
  attacksMade: array[1..2] of Byte;
  { CombatAi: the percentage UpdateHostileHpPercent writes }
  hostileHpPct: Byte;
  { quick magic: nonzero lets the party's quick-fighters cast spells }
  quickMagic: Byte;
  { set when an action ended the combatant's turn }
  doneSignal: Boolean;
  { unused }
  doneSignalTail: array[0..4] of Byte;
  { the combat icon picture composed for the combatant being drawn }
  combatImage: Types.PImage;
  { unused }
  combatImageTail: Byte;
  { CbtActs: the aim cursor's arena cell while it runs }
  aimCursorX: ShortInt;
  { and its row }
  aimCursorY: ShortInt;
  { MenuCore: 1 while CbtActs's manual aim cursor runs }
  aimCursorActive: Byte;
  { CombatSt: which of four facings successive hostiles are placed at }
  hostileFacingMask: Byte;
  { set while a click on the arena counts as a move }
  arenaClickA: Byte;
  { the creature the target walk looks for; never set }
  specialTarget: Types.PCharacter;
  { set while CombatAi's current attacker has its target in weapon range and in sight }
  targetInReach: Byte;
  { set when the combat panel must be redrawn }
  combatPanelDirty: Byte;
  { nonzero while combat is drawn: moves scroll the arena and redraw tiles }
  combatGfxOn: Byte;
  { unused }
  gfxValueTail: Byte;
  { the combatants in initiative order }
  initQueue: array[1..72] of Types.PCharacter;
  { how many initQueue entries are in use }
  initQueueCount: Byte;
  { unused }
  initQueueCountTail: Byte;
  { set to $DB by GameInit, never read }
  wallColorSel: Byte;
  { set to $E8 by GameInit, never read }
  ceilFloorColorSel: Byte;
  { unused }
  ceilFloorColorSelTail: array[0..5] of Byte;
  { the GOSUB return stack }
  eclStack: Types.PGosubNode;
  { the COMPARE results: equal, not equal, less, greater, less or equal, greater or equal }
  compareFlags: array[1..6] of Byte;
  { the opcode before the current one }
  lastOpcode: Byte;
  { the current opcode }
  curOpcode: Byte;
  { unused }
  curOpcodeTail: Byte;
  { the monster sprite the script shows }
  monsterSprId: Byte;
  { its picture }
  monsterPicId: Byte;
  { the icon slots in use; monster icons load from slot 8 }
  monsterCount: Byte;
  { unused }
  monsterCountTail: array[0..129] of Byte;
  { each decoded operand's type }
  varTypes: array[1..64] of Byte;
  { its high byte }
  varHi: array[1..64] of Byte;
  { its low byte }
  varLo: array[1..64] of Byte;
  { set when the aim cursor or a menu picked a target }
  targetSelected: Boolean;
  { a global loop counter shared by Camp, MenuCore and others }
  scratchIndex: ShortInt;
  { the ECL string operands: EclMenu stores the k-th in slot k }
  gbStrings: array[1..5] of String[255];
  { unused }
  gbStringsTail: array[0..248] of Byte;
  { unused }
  castCurX: ShortInt;
  { unused }
  castCurY: ShortInt;
  { unused }
  castCurYTail: array[0..145] of Byte;

{ The encounter: monster display, experience, script flags and the scene; the automap password; mouse and joystick;
  palettes; the vault; the item pool; the sound table; the installed hooks. }
var
  { unused }
  monsterFlagsLead: array[0..3441] of Byte;
  { which of the monster's pictures are shown }
  monsterFlags: Types.TMonFlags;
  { unused }
  monsterFlagsTail: array[0..7] of Byte;
  { set while the shop, temple and vault menus share the screen with the picture }
  splitFrameGate: Byte;
  { unused }
  splitFrameGateTail: Byte;
  { the creatures left unanimated, which do not share experience }
  nonAnimCount: Byte;
  { unused }
  nonAnimCountTail: Byte;
  { each character's experience share }
  expShare: LongInt;
  { the victory flag }
  combatWon: Boolean;
  { unused }
  combatWonTail: Byte;
  { the area script loaded; 0 and 80 do not wrap at the map edge }
  environmentId: Byte;
  { the search flag, kept while a script runs }
  combatSideByte: Byte;
  { set when a script ends with a hard exit }
  hardExitFlag: Byte;
  { set when a script message waits for a key before the next }
  msgLineFlag: Byte;
  { set while a script picture is on show }
  eclPicShown: Boolean;
  { unused }
  eclPicShownTail: Byte;
  { set when a sprite is shown }
  sprShown: Byte;
  { set once the bottom text lines have been cleared }
  bottomCleared: Byte;
  { the script picture's width and whether it must be redrawn }
  picState: Types.TPicState;
  { [0] the walls must be redrawn, [1] the picture must be redrawn }
  wallDirty: array[0..1] of Byte;
  { cleared by GameInit, never read }
  inEncounterMenu: Byte;
  { unused }
  inEncounterMenuTail: Byte;
  { set while a combat message is shown }
  combatMsgFlag: Byte;
  { set when the map must be redrawn before the next picture }
  mapDirtyFlag: Byte;
  { cleared by GameInit, never read }
  clickInputMode: Byte;
  { nonzero while clicks on the view move the party }
  isMoveMode: Byte;
  { CombatAi: the encounter's undead (levelUndead <> 0), counted by EclVm's setup }
  undeadCount: Byte;
  { cleared by GameInit, never read }
  monstersLoaded: Byte;
  { set to stop the script loop }
  scriptAbortFlag: Byte;
  { the monsters LOAD MONSTER has added, capped at 63 }
  cloneCount2: Byte;
  { unused }
  cloneCount2Tail: array[0..5] of Byte;
  { the overlay manager's read routine, which OverlayReadWithBeep calls }
  savedOvrReadBuf: Types.TOverlayReadFunc;
  { unused }
  savedOvrReadBufTail: array[0..1] of Byte;
  { the cursor picture the automap's cursor is composed from }
  scratchViewBank: Types.PImage;
  { the word on the command line that shows the automap; ModeInit copies it from itemNameParts }
  automapPassword: String[20];
  { unused }
  automapPasswordTail: Byte;
  { the copy-protection results, one per check }
  journalFlags4: array[1..4] of Byte;
  { set when the title menu chose the demo }
  alternateStart: Byte;
  { unused }
  alternateStartTail: Byte;
  { set when the mouse driver counts columns in screen pixels }
  mouseHiRes: Boolean;
  { the party-click mode }
  partyClickMode: Byte;
  { a mouse is in use }
  mousePresent: Boolean;
  { set when the last input was a click }
  mouseClicked: Boolean;
  { the buttons the driver reported }
  mouseButtonCount: Byte;
  { unused }
  mouseButtonCountTail: Byte;
  { the mouse's column }
  mouseX: Integer;
  { the mouse's row }
  mouseY: Integer;
  { cleared when the mouse is set up; never read }
  mouseCurX: Integer;
  { cleared when the mouse is set up; never read }
  mouseCurY: Integer;
  { the mouse cursor's screen and cursor masks }
  cursorMask: Pointer;
  { the stick's calibration readings }
  joystickCalibration: array[1..2] of Types.TJoyCal;
  { a joystick is in use }
  joystickPresent: Boolean;
  { unused }
  joystickPresentTail: Byte;
  { the stick's center column }
  joystickCenterX: Integer;
  { the stick's center row }
  joystickCenterY: Integer;
  { set when the automap must be redrawn }
  automapDirty: Byte;
  { set once the backdrop's colors are in backdropPalette }
  backdropPaletteSelected: Byte;
  { the sky drawn last }
  previousSkyId: Byte;
  { the sky to draw }
  currentSkyId: Byte;
  { the 3-D view's backdrop picture }
  backdropImage: Types.PImage;
  { its sky picture }
  skyImage: Types.PImage;
  { colors 144..175 as they were before the backdrop's }
  paletteScratch: Types.TPalette;
  { the backdrop's colors 144..175 }
  backdropPalette: Types.TPalette;
  { Portrait's palette A }
  paletteA: Types.TPalette;
  { the palette combat set-up saves and puts back }
  workPalette: Types.TPalette;
  { the colors on screen }
  activePalette: Types.TPalette;
  { the colors the pictures load }
  gamePalette: Types.TPalette;
  { maps an EGA picture's color nibbles to palette slots }
  gfxNibbleTable: array[0..255] of Byte;
  { set when the palette must be written before the next picture }
  palettePending: Byte;
  { unused }
  palettePendingTail: array[0..4] of Byte;
  { set when the vault has changed and must be saved }
  vaultDirty: Byte;
  { the save letter the vault belongs to }
  pendingSaveLetter: Char;
  { the last item read into the vault list }
  lastVaultItem: Types.PItem;
  { the fixed item records handed out when an item is created }
  itemPool: array[1..138] of Types.TItem;
  { the loaded sound effects, by sound id }
  soundTable: array[1..11] of Types.TSoundEntry;
  { 9000 bytes the sound effect is copied into for the driver }
  stagingBuffer: Types.PByteBuffer;
  { unused }
  stagingBufferTail: array[0..3] of Byte;
  { the command SoundDrv clears and hands the driver }
  driverCommand: Types.TSoundDriverCommand;
  { prints a message on the bottom line }
  bottomMessageHook: Types.TMessageProc;
  { prints a message }
  showMessage: Types.TMessageProc;
  { turns a number into text }
  intToStringHook: Types.TIntToStringFunc;
  { the border layouts, BORD.DAX tile streams }
  borderLayout: Types.PByteBuffer;
  { erases a box of text cells }
  clearRectHook: Types.TBoxProc;
  { clears a box of cells to the backdrop }
  clearRectCoreHook: Types.TBoxProc;
  { loads a picture from a DAX list }
  bankLoader: Types.TBankLoader;
  { prints spaces; never called }
  printSpacesHook: Types.TPrintSpacesProc;
  { draws a string; never called }
  displayStringHook: Types.TDisplayStringProc;
  { prints a message and waits for a key }
  pauseHook: Types.TDisplayPauseProc;
  { draws a recolored glyph of a picture }
  maskedRender: Types.TMaskedRender;
  { prints a message if one is due; never called }
  conditionalMessageHook: Types.TMessageProc;
  { EclVm installs FinishNewEcl here }
  finishHook: Types.TNoArg;
  { set when a crystal has been smashed and the smash shown }
  cbTailFlag3: Byte;
  { nonzero while the crystal effects must not smash a crystal; CombatSt clears it }
  cbTailFlag2: Byte;
  { the party member on the party's side of the romance }
  relationA: Types.PCharacter;
  { the one on the NPC's side }
  relationB: Types.PCharacter;
  { prints a fatal message and stops }
  fatalMessageHook: Types.TMessageProc;
  { the first symbol of each wall-set slot }
  symbolOffset: array[1..3] of Word;
  { the spell-level chooser Camp installs for the spell menus }
  chooseSpellLevelHook: Pointer;
  { the spells still to pick when a new magic-user fills its spellbook }
  remainingLevel: Byte;
  { the spell level they are picked from }
  spellFilter: Byte;
  { frees the animated picture }
  freeAnimationHook: Types.TNoArg;
  { set by any text output; ECL program 5 waits for a key only when nothing printed }
  program5Flag: Byte;

implementation

end.
