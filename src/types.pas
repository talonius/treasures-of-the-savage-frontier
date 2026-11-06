{ The types the storage and its readers share: GDConsts and GDVars are typed with them, so they sit below both in the
  uses chain. Each group is headed by the units that use it. The unit has no code and no storage. }
{$A-}
unit Types;

interface

type
  { Used by most units }
  TStr40 = String[40];
  TStr255 = String[255];
  TStr80 = String[80];

  { Used by Camp, CbtActs, CharGen, CharHlp, EclVm, EffHndlr, FxEngine, GameIo, GameTime, Magic, PostCbt, Romance and
    SaveLoad }
  { One effect on a creature, in its list: the effect id, the minutes left, a strength whose meaning is the effect's
    own, whether its handler runs when it is removed, and the next effect. }
  PEffect = ^TEffect;
  TEffect = record
    id: Byte;
    duration: Word;
    strength: Byte;
    onRemove: Byte;
    next: PEffect;
  end;

  { Used by GDVars and the units that read items }
  { An item's three name parts, by name-part id. }
  TNameIds = array[1..3] of Byte;
  { One item definition, as the item-definition table holds it and as an item carries it from itemType on: the item
    type, its name parts, its attack and saving-throw bonuses, whether it is readied, which name parts are not yet
    identified (low three bits), whether it is cursed, its weight, quantity and value, then either its charges, effect
    and special power or, on a scroll, its three spells. }
  TItemDef = record
    itemType: Byte;
    nameIds: TNameIds;
    plus: ShortInt;
    saveBonus: ShortInt;
    equipped: Byte;
    unidMask: Byte;
    cursed: Byte;
    weight: Word;
    quantity: Byte;
    value: Word;
    case Integer of
      0: (charges: Byte; effect: Byte; special: Byte);
      1: (spells: array[1..3] of Byte);
  end;
  PItemDefs = ^TItemDefs;
  TItemDefs = array[1..254] of TItemDef;
  { One item, in a character's list, the treasure or the item pool: its name, the menu's heading flag, the next item,
    then its definition's fields. A pool entry is free while its itemType is 0. }
  PItem = ^TItem;
  TItem = record
    name: String[40];
    inUse: Byte;
    next: PItem;
    itemType: Byte;
    nameIds: TNameIds;
    plus: ShortInt;
    saveBonus: ShortInt;
    equipped: Byte;
    unidMask: Byte;
    cursed: Byte;
    weight: Word;
    quantity: Byte;
    value: Word;
    case Integer of
      0: (charges: Byte; effect: Byte; special: Byte);
      1: (spells: array[1..3] of Byte);
  end;
  { One menu line, as the menu lists hold it: the start of an item record, so a list of items is a menu list too. inUse
    is nonzero on a heading line. }
  PItemRec = ^TItemRec;
  TItemRec = record
    name: TStr40;
    inUse: Byte;
    next: PItemRec;
  end;

  { Used by GDConsts, GDVars and the units that read characters }
  { One ability score's base and current value. }
  TStatPair = record
    base: Byte;
    current: Byte;
  end;
  { The six head colors and body colors of a character's combat icon. }
  TIconColors = array[1..6] of Byte;
  PCharacter = ^TCharacter;
  { A creature's combat state, which its combatAddr points at while combat runs. }
  PCombatRec = ^TCombatRec;
  TCombatRec = record
    spellCast: Byte;
    castAllowed: Byte;
    itemUseAllowed: Byte;
    initiative: ShortInt;
    attackPhase: Byte;
    movement: Byte;
    guarding: Byte;
    madeAttack: Byte;
    direction: Byte;
    { the creature it is engaged with }
    other: PCharacter;
    overkill: Byte;
    flankCount: Byte;
    { turned by a cleric }
    turned: Byte;
    turnAttempts: Byte;
    flankSpread: Byte;
    { 1: not a party member or a party NPC }
    notPcNpc: Byte;
    fleeing: Byte;
    aiStance: Byte;
    initialized: Byte;
  end;
  { A character or monster: a party member, a party NPC, or a creature in combat. The memorized spells and the known
    spells are by spell id; the spell slots are by casting band (cleric, druid, magic-user) and spell level. }
  TCharacter = record
    name: String[15];
    stats: array[0..5] of TStatPair;
    strExc: Byte;
    strExcBase: Byte;
    memorized: array[0..140] of Byte;
    { the hours of spell preparation left }
    spellPrep: ShortInt;
    thac0Base: Byte;
    race: ShortInt;
    charClass: ShortInt;
    { the paladin's cures of disease left }
    poisonCount: Byte;
    age: Word;
    hpMax: Byte;
    knownSpells: array[1..126] of Byte;
    { the low bits are the footprint size }
    iconDimensions: Byte;
    saves: array[0..4] of Byte;
    movementBase: Byte;
    hitDice: Byte;
    dualLevel: Byte;
    levelUndead: ShortInt;
    skills: array[1..8] of Byte;
    effects: PEffect;
    { a party NPC's morale and loyalty; above $7F: an NPC }
    npc: Byte;
    npcTail: array[0..2] of Byte;
    coins: array[0..2] of Word;
    classLevels: array[0..6] of Byte;
    { the levels of the class a dual-classed human left }
    oldLevels: array[0..6] of Byte;
    { the levels before any were drained }
    classLevelCap: array[0..6] of Byte;
    gender: ShortInt;
    alignment: Byte;
    attackRate: array[1..2] of Byte;
    unarmedRolls: array[1..2] of Byte;
    unarmedDice: array[1..2] of Byte;
    unarmedMod: array[1..2] of ShortInt;
    acBase: Byte;
    creatureId: Byte;
    experience: LongInt;
    { the experience and hit points before a level was drained }
    savedExperience: LongInt;
    savedHpMax: Byte;
    { the class bits an item's class mask must share }
    classMask: Byte;
    hpRolled: Byte;
    spellSlots: array[0..2, 1..9] of Byte;
    { the experience a monster is worth }
    xpAward: Word;
    iconHeadClass: Byte;
    iconBodyClass: Byte;
    { the combat icon's slot among the icon animations }
    icon: Byte;
    iconSize: Byte;
    iconColors: TIconColors;
    creatureType: Byte;
    immunities: Byte;
    numberOfItems: Byte;
    items: PItem;
    { the readied items, by equipment slot }
    equipped: array[0..12] of PItem;
    handsEquipped: Byte;
    saveBonus: ShortInt;
    encumbrance: Word;
    next: PCharacter;
    combatAddr: PCombatRec;
    spellResistance: Byte;
    { nonzero: the roster highlights the character, who can train }
    displayHighlight: Byte;
    status: ShortInt;
    inPlay: Byte;
    side: ShortInt;
    quickfight: Byte;
    thac0Cur: Byte;
    { the current armor class from the front (0) and from behind (1) }
    acCur: array[0..1] of Byte;
    curAttacks: array[1..2] of Byte;
    curRolls: array[1..2] of Byte;
    curDice: array[1..2] of Byte;
    curMod: array[1..2] of ShortInt;
    hpCur: Byte;
    movementCur: Byte;
  end;

  { Used by GDVars, CbtMap, Combat, FxEngine and Magic }
  { A cloud spell's cells, in the list GDVars.cloudHead heads; Magic.SpellStinkingCloud builds one. }
  PCloudNode = ^TCloudNode;
  TCloudNode = record
    owner: Pointer;
    next: PCloudNode;
    { the terrain under each cell, put back on expiry }
    savedTerrain: array[1..9] of Byte;
    live: array[1..9] of Byte;
    x: ShortInt;
    y: ShortInt;
    { FxEngine.CountDownAreaEffects counts it down; -1: dispelled }
    ttl: ShortInt;
    { the caster's level, which a dispel rolls against }
    lvl: Byte;
    { the cloud's terrain, $1B..$1D }
    terrain: Byte
  end;

  { Used by GDVars, EclMenu and EclVm }
  { The two flags EclMenu.DisplayMonster reports about the monster it drew. }
  TMonFlags = array[0..1] of Boolean;

  { Used by Pathing, CharHlp and Magic }
  { The path request Pathing.PathFind seeds and Pathing.NextPathStep walks. }
  TPathReq = record
    { start }
    x1: Integer;
    y1: Integer;
    { target }
    x2: Integer;
    y2: Integer;
    { Bresenham error accumulator }
    err: Integer;
    adx: Integer;
    ady: Integer;
    { the walking cursor }
    cx: Integer;
    cy: Integer;
    stepX: Integer;
    stepY: Integer;
    { cost so far: +2 straight, +3 diagonal }
    dist: Byte;
    { the last step's direction, from GDConsts.stepDir }
    dir: Byte;
  end;

  { Used by GDVars }
  { The party's square on the area map and its facing, with the wall ahead of it and the event at its square: cleared
    and saved as one block. }
  TPartyPos = record
    x: ShortInt;
    y: ShortInt;
    facing: Byte;
    wallAhead: Byte;
    eventAtCell: Byte;
  end;

  { Used by GDVars, Camp, CharHlp, EffHndlr and Magic }
  { The effect names, by effect id, loaded from BORD.DAX block 9. }
  TEffectName = String[37];
  TEffectNames = array[1..160] of TEffectName;
  PEffectNames = ^TEffectNames;

  { Used by GDVars, GameInit and View3D }
  { One 16 x 16 plane of the area map. }
  TGeoPlane = array[0..15, 0..15] of Byte;
  { The area map: the walls on each square's sides, its events and its barriers. }
  TGeoMap = record
    { N = high nibble, E = low }
    wallsNE: TGeoPlane;
    { S = high nibble, W = low }
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    { 2 bits per facing, W S E N from bit 7 }
    barriers: TGeoPlane;
  end;
  PGeoMap = ^TGeoMap;

  { Used by GDConsts, GDVars, Blit, Border, Camp, CharGen, CharHlp, CombatSt, DaxIo, EclMenu, EclVm, GameInit, Intro,
    MapTiles, Music, Portrait, Romance, SaveLoad, VgaFrame, View3D and ViewChar }
  { One combat-map slot: a creature's cell, its slot index and its footprint size. }
  TActor = record
    x: ShortInt;
    y: ShortInt;
    { the slot's own index, set by CombatSt }
    aux: Byte;
    { footprint size; 0 = not on the combat map }
    size: Byte;
  end;
  { A downed creature and its cell. }
  TDownedRec = record
    cr: Pointer;
    x: ShortInt;
    y: ShortInt;
    { the terrain under the corpse }
    terrain: Byte;
  end;
  PByteBuffer = ^TByteBuffer;
  TByteBuffer = array[0..65534] of Byte;
  { A packed color map: a display color for each of 16 colors, two to a byte, the even color in the high nibble. }
  TColorMap = array[0..7] of Byte;
  { A picture or a bank of picture frames: its header, then the pixel data. }
  PImage = ^TImage;
  TImage = record
    { Scanlines and horizontal eight-pixel cells. }
    rows: Word;
    cells: Word;
    { Display position in eight-pixel cells. }
    displayX: Word;
    displayY: Word;
    { Frames sharing this header. }
    count: Word;
    { Carried from picture to picture; only a CGA display would read it. }
    colorMap: TColorMap;
    frameBytes: Word;
    allocSize: Word;
    colorKey: Byte;
    { Separate EGA/Tandy mask bytes, without an image header. }
    mask: PByteBuffer;
    { Variable payload starts here. R- consumers can index beyond this one-byte view; allocSize and frameBytes, rather
      than SizeOf(TImage), determine its extent. }
    data: array[0..0] of Byte
  end;
  TColorTable = array[0..15] of Byte;
  TMessageProc = procedure(s: String);
  TBankLoader = procedure(name: String; blk, hasMask, transpColor: Byte;
                          var slot: PImage);
  TMaskedRender = procedure(x, y: Integer; bank: Pointer;
                            idx, planeMask, special: Byte);
  TBoxProc = procedure(ulCol, ulRow, lrCol, lrRow: ShortInt);
  TSoundEntry = record
    size: Word;
    data: PByteBuffer;
  end;
  { GBVM bank 2 (EclMenu.GbvmZone), the ECL script: an untyped GetMem block. }
  TZone2 = array[$8000..$B6B0] of Byte;
  PZone2 = ^TZone2;
  TLocState = record current: Byte; previous: Byte end;
  PGameState = ^TGameState;
  TVmBand = record
    { the loaded ECL script, a block GameInit allocates }
    zone2: PZone2;
    { the ECL script's entry points }
    vmRun: array[1..5] of Word;
    eclIp: Word
  end;
  { Bank 0 read as the game's state: GameInit allocates its $400 bytes and SaveLoad saves them whole. gbvm addresses a
    byte as the ECL scripts do, from 1. }
  TGameState = record
    case Integer of
      0: (
        enemyToHitAdj: ShortInt;
        antiMagic: Byte;
        { ResolveMovement takes no step at $FF }
        movementState: Byte;
        movementStateTail: array[$003..$004] of Byte;
        minuteOnes: Byte;
        minuteTens: Byte;
        hour: Byte;
        hourTail: array[$008..$00D] of Byte;
        turnPenalty: Byte;
        turnPenaltyTail: array[$00F..$010] of Byte;
        gameDelay: Byte;
        currentMap: Byte;
        { 1: the healer opens next; still 1 while it runs }
        healerRequest: Byte;
        monstersDefeated: Byte;
        { the script the area restarts with; 0: the default }
        areaScriptId: Byte;
        savedX: Byte;
        savedY: Byte;
        searchFlags: Byte;
        mapHidden: Byte;
        moraleAdj: Byte;
        partyMoveAdj: Byte;
        reviveFlag: Byte;
        noCombatItems: Byte;
        mirrorDuel: Byte;
        partySize: Byte;
        leaveMap: Byte;
        location: Byte;
        locationTail: Byte;
        layoutFlag: Byte;
        cursorX: Byte;
        cursorY: Byte;
        gameLevel: Byte;
        priceScale: Byte;
        { left by the ECL DIVIDE }
        divRemainder: Byte;
        divRemainderTail: Byte;
        { rest steps between interruption rolls; 0: none }
        restPeriod: Byte;
        { the chance each roll interrupts the rest }
        interruptPct: Byte;
        interruptPctTail: Byte;
        initPenaltyMask: Byte;
        partyToHitAdj: ShortInt;
        trainMask: Byte;
        { 1: the vault (Vault.PoolVault) opens next }
        vaultRequest: Byte;
        vaultRequestTail: Byte;
        arenaRiver: Byte;
        arenaRiverTail: array[$033..$034] of Byte;
        allyAttacked: Byte;
        placementDist: Byte;
        { SETUP MONSTER's distance; placementDist is held to it }
        placementLimit: Byte;
        { message text color: set by a %0..%F escape }
        printColor: Byte;
        pictureIndex: Byte;
        pictureIndexTail: Byte;
        crystals: Byte;
        { nonzero: effects 127..129 award a crystal }
        crystalsActive: Byte;
        { the crystal last awarded: 0 red, 1 green, 2 blue }
        lastCrystal: Byte;
        crown: Byte;
        overMap: Byte;
        inBoat: Byte;
        overMapId: Byte;
        facingHidden: Byte;
        { nonzero: LOAD MONSTER, status 0 -> min(10 + it, 19), out of play }
        monsterLoadStatus: Byte;
        { by side }
        battleX: array[0..1] of Byte;
        battleY: array[0..1] of Byte;
        battleDist: array[0..1] of Byte;
        lastSpell: Byte;
        npcLoveBand: Byte;
        partyLoveBand: Byte;
        resourceId: Byte;
        pictureId: Byte;
        layoutPic: Byte;
        layoutPicTail: Byte;
        combatWallSet: Byte;
        weather: Byte;
        field53: Byte;
        backdropId: Byte;
        field55: Byte;
        skyLevel: Byte;
        skyLevelTail: array[$057..$0C4] of Byte;
        loadedMap: Byte;
        loadedMapTail: array[$0C6..$103] of Byte;
        npcNumber: Byte;
        partyLove: Byte;
        npcLove: Byte;
        npcLoveTail: array[$107..$125] of Byte;
        luckFlags: array[1..11] of Byte;
        luckFlagsTail: array[$131..$1F6] of Byte;
        luckFallback: Byte;
        luckFallbackTail: array[$1F8..$25A] of Byte;
        luckState: Byte;
        luckStateTail: array[$25C..$2C8] of Byte;
        moveLocked: Byte;
        moveLockedTail: array[$2CA..$3FF] of Byte);
      1: (
        gbvm: array[1..$400] of Byte)
  end;

  { Used by GDVars, CbtMap and CharHlp }
  TOvr35Work = record
    relX: array[1..72] of ShortInt;
    relY: array[1..72] of ShortInt;
  end;

  { Used by GDVars, GameInit, Portrait and VgaFrame }
  TPicTable = array[0..8] of PImage;
  TVgaState = record
    frames: TPicTable;
    displayImage: PImage
  end;

  { Used by GDVars and TextRend }
  TEgaPages = record
    currentPage: Word;
    otherPage: Word
  end;

  { Used by GDVars, Combat and CombatSt }
  { The combat arena: the view's upper-left corner in arena cells, the cursor (on or off) and its footprint size, the
    flag that lets a line walk ignore heights, and the 50 x 25 terrain cells. }
  PCombatMap = ^TCombatMap;
  TCombatMap = record
    originXLead: array[0..1] of Byte;
    originX: ShortInt;
    originY: ShortInt;
    cursorOn: Boolean;
    cursorSize: Byte;
    noHeight: Byte;
    cells: array[0..24, 0..49] of Byte;
  end;

  { Used by GDVars, CharGen, GameBoot and Joystick }
  { One joystick axis's calibration: the low stop, the five zone thresholds (3 is the center) and the high stop; or the
    same seven words as the config file stores them (CharGen writes them as raw). }
  TJoyAxis = record
    case Byte of
      0: (lo: Word;
          threshold: array[1..5] of Word;
          hi: Word);
      1: (raw: array[0..6] of Word);
  end;
  { One joystick's calibration. }
  TJoyCal = record
    x: TJoyAxis;
    y: TJoyAxis;
  end;

  { Used by GDVars, GameBoot and GameIo }
  { Turbo Pascal's overlay read hook (System.OvrReadBuf): read an overlay of size bytes, 0 on success. }
  TOverlayReadFunc = function(size: Word): Integer;

  { Used by GDConsts, GDVars and the units that cycle the palette }
  { Three palette bytes: a palette-cycle chunk, or the over-map palette span View3D saves. }
  TChunk3 = array[0..2] of Byte;

  { Used by GDConsts, CbtActs, CbtMap, CombatAi, CombatSt, Combat, Magic and Pathing }
  { One combat terrain row: the movement cost multiplier ($FF impassable), the clearance a line walk starts with, the
    height it is compared against (Pathing), and the tile drawn for it (CbtMap). }
  TTerrain = record
    cost: Byte;
    clear: Byte;
    block: Byte;
    code: Byte;
  end;

  { Used by GDVars, CbtActs, CharHlp, EffHndlr, FxEngine, Magic and Pathing }
  { One entry of the approach list Pathing.BuildTargetList builds: the actor's index, its doubled walk distance and the
    facing towards it. }
  TCombatTarget = record
    entity: Byte;
    cost: Byte;
    facing: Byte;
  end;

  { Used by GDConsts and the units that read spells }
  { One row of the spell table: the casting band (0 cleric, 1 druid, 2 magic-user) and the spell level, range and
    duration (a base plus so much per level), the area (its low nibble the area kind) and targeting, the saving throw,
    the effect, when it may be cast (0 camp only), the casting time, and the combat AI's priority, offensive flag and
    radius. }
  TSlotRule = record
    spellBand: Byte;
    spellLevel: Byte;
    rangeBase: Byte;
    rangePerLevel: Byte;
    durBase: Byte;
    durPerLevel: Byte;
    area: Byte;
    targeting: Byte;
    saveEffect: Byte;
    saveType: Byte;
    effectId: Byte;
    whenCast: Byte;
    castTime: Byte;
    aiPriority: Byte;
    offensive: Byte;
    aiRadius: Byte;
  end;

  { Used by GDVars, CbtActs and CombatAi }
  { One base-item row: an item type's equip slot, hands, damage against large and smaller targets, rate of fire, armor
    class, weapon class, range, the classes that may use it and its property bits. }
  TBaseItem = record
    slot: Byte;
    hands: Byte;
    dmgLgRolls: Byte;
    dmgLgDice: Byte;
    dmgLgMod: ShortInt;
    rateOfFire: Byte;
    acDescr: Byte;
    wpnClass: Byte;
    { unused }
    wpnClassTail: Byte;
    dmgSmRolls: Byte;
    dmgSmDice: Byte;
    dmgSmMod: ShortInt;
    range: Byte;
    classMask: Byte;
    props: Byte;
    { unused }
    propsTail: Byte;
  end;

  { Used by GDConsts }
  { One race's ability-score limits; each strength pair is by gender. }
  TRaceLimits = record
    strMin: array[0..1] of Byte;
    strMax: array[0..1] of Byte;
    strExcMax: array[0..1] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;

  { Used by GDConsts }
  { One starting age: base years plus dice rolls of a die with sides faces. }
  TStartAge = record
    base: Word;
    dice: Byte;
    sides: Byte;
  end;

  { Used by GDConsts }
  { One class's levels: the experience needed for levels 2 through 11, then the spell slots by character level and spell
    level. }
  TClassLevelTable = record
    xp: array[2..11] of LongInt;
    spellSlots: array[1..29] of array[1..9] of Byte;
  end;

  { Used by GDVars, SaveLoad, View3D and the script handlers }
  { One cached wall set: the WALLDEF id loaded in the slot and the 8x8 symbol slot stamped for it. }
  TWallSetCacheSlot = record
    case Integer of
      0: (wallDefId: Integer;
          symbolSlot: Integer);
      { slot 1 on the overland map: the over-map picture's position }
      1: (overMapX: Word;
          overMapY: Word);
  end;

  { Used by GDConsts, GDVars, FixMain, Blit, CharGen, CombatSt, GameInit, Intro, Portrait, SaveLoad and View3D }
  { Graphics types that describe allocated buffers, with no owned storage. }
  TRGB = array[0..2] of Byte;
  TPalette = array[0..255] of TRGB;

  { Used by GDConsts, GDVars, Camp and GameTime }
  { a clock, by component: the game clock, the rest time and the clock scales }
  TClock = array[0..6] of Word;

  { Used by GDVars and EclMenu }
  TPicState = record width: Byte; dirty: Byte end;

  { Used by GDVars }
  { The pause-message hook: show msg in the colors fg and bg and wait for a key. }
  TDisplayPauseProc = procedure(fg, bg: Byte; msg: TStr40);
  TPrintSpacesProc = procedure(col, row, color, count: Byte);
  TDisplayStringProc = procedure(col, row, fg, bg: Byte; source: String);

  { Used by GDConsts and CbtMap: one icon cell's offset from a combatant's cell }
  TIconDelta = record
    dx: ShortInt;
    dy: ShortInt;
  end;

  { Used by GDVars, MenuCore and the menus that register options: one menu slot, the option it offers and its hotkey. }
  TMenuSlot = record
    optionId: Byte;
    keyCode: Byte;
  end;

  { Used by GDVars, EclMenu and EclVm }
  { One return address on the ECL gosub stack GDVars.eclStack heads. }
  PGosubNode = ^TGosubNode;
  TGosubNode = record
    ip: Word;
    next: PGosubNode;
  end;

  { Used by Combat and CombatAi }
  PShortInt = ^ShortInt;

  { Used by GDVars, EclVm, GameBoot and View3D }
  { A far pointer's two words. }
  TPtrRec = record
    ofs: Word;
    seg: Word;
  end;

  { Used by GDVars and the units that cast spells or install hooks }
  TNoArg = procedure;
  { The target hook a cast calls to pick its targets: NoncombatCastTargetMenu, or CbtActs.SelectCombatTargets in
    combat. }
  TSelectTarget = procedure(spell, ai: Byte; var selected: Boolean);
  { The spell dispatch table: the target hook, then each spell's routine by spell id. }
  TSpellFns = record
    selectTarget: TSelectTarget;
    spells: array[1..126] of TNoArg;
  end;

  { Used by GDConsts and CharGen: one main-menu line and whether it is offered. }
  TMenuItem = record
    name: String[40];
    enabled: Byte;
  end;

  { Used by GDVars and SoundDrv }
  { The command block SoundDrv hands the sound driver: the effect's buffer and byte count, four bytes it clears and
    nothing reads, and the playback rate. }
  TSoundDriverCommand = record
    data: Pointer;
    size: Word;
    reserved: LongInt;
    sampleRate: Word;
  end;

  { Used by GDVars }
  TResidentHandler = function(a, b, c: Word): Word;
  TEffectHandler = procedure(var cr: Pointer; p: Pointer; removed: Boolean);
  TIntToStringFunc = function(n: LongInt): String;

type
  { Used by GDConsts }
  { One placement row band: columns lo..hi are free. }
  TBandRec = record
    lo: ShortInt;
    hi: ShortInt;
  end;
  TJournalEntry4 = record
    heading: String[30];
    pageNumber: Byte;
    wordNumber: array[1..3] of Byte;
    encodedWord: array[1..3] of String[20];
  end;
  TGeoNameAnchor = record
    initialized: Byte;
    newWall: Byte;
    header: Word;
    name: String[5];
    loadName: String[5];
    { indexed by the 2-bit barrier type }
    wallNames: array[0..3] of String[20];
  end;
  { the 3D view-slot geometry table: start/cols/rows give each slot's rectangle in the 156-cell slice (start is the
    running sum of cols*rows); xCol/yRow give each slot's view position. }
  TVsTbl = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  { Used by GDVars }
  TOvr19Globals = record
    tempCr1: PCharacter;
    tempCr2: PCharacter
  end;
  { The register block for software interrupts, laid out as Dos.Registers so storage can hold one without using Dos;
    callers pass it to Intr as a Registers. }
  TRegisters = record
    case Integer of
      0: (ax: Word;
          bx: Word;
          cx: Word;
          dx: Word;
          bp: Word;
          si: Word;
          di: Word;
          ds: Word;
          es: Word;
          flags: Word);
      1: (al: Byte;
          ah: Byte;
          bl: Byte;
          bh: Byte;
          cl: Byte;
          ch: Byte;
          dl: Byte;
          dh: Byte);
  end;

implementation

end.
