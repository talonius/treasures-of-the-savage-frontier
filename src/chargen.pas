{ CharGen owns character creation, modification, training, roster removal, icon customization, starting equipment, and
  mouse/joystick configuration. }
{$O+,F+,S+,A+,I-}
unit CharGen;

interface

{ Runs the character main menu, built from the 13 main-menu items as the roster allows (Train and Change Class while the
  zone's training mask is set): Create, Drop, Modify, Train, Change Class (swapping the paladin's Protection from Evil
  and the ranger's bonus-damage effects for the new class), View, Add, Remove (a player character is saved to its file
  first; a non-player character is dismissed), Load, Save, Begin, Input and Exit (which offers to save an unsaved
  party). Any choice but Save and Exit marks the game unsaved. Begin, with a party or in demo mode, restores the
  interface state the menu was entered from, redraws the game layout, clears the training mask and returns; when the
  roster empties the game state is reset and the menu rebuilt. }
procedure MainMenu;

{ Unlinks the current character from the party roster and frees it. Its predecessor, or else the roster head, becomes
  the current character. A character that is not in the roster is left untouched.
  @param(suppressSizeDec True leaves the party size alone.)
  @param(freeAnim True also frees the character's icon animation.) }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ The icon editor for the current character: show its old and new icons, and change the head and body pictures (Parts),
  the colors of the icon's parts and its size, each change kept with Keep or undone with Exit, until the icon is
  accepted ('Is this icon ok?'). }
procedure CustomizePortrait;

{ Drops the selected character for good after asking twice: deletes its saved files and removes it from the party. }
procedure DropCharacterMenu;

implementation

uses Types, Crt, GDConsts, GDVars, C_Effect, C_Keys, C_Status, C_Stat,
  C_Class, C_Ifc, C_Npc, C_Race, C_Spell, Border, Blit, TextRend, GameIo, Mouse, Joystick, SaveLoad, GameInit, ViewChar,
  Money, FxEngine, CharHlp, ClassCal, MenuCore, MapTiles;

const
  { class values only this unit names }
  CLASS_CLERIC_MAGE = 11;
  CLASS_CLERIC_THIEF = 12;
  CLASS_FIGHTER_MAGE = 13;

procedure InitKnownSpells(characterData: Pointer); forward;

procedure AddCharacterMenu; forward;

function ConHpBonus(characterData: Pointer; classIndex: Byte): ShortInt; forward;

function HpMaximum(characterData: Pointer): Byte; forward;

procedure CalibrateJoystickInWindow; forward;

procedure InitMouseJoystick; forward;

procedure CreateCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

procedure TrainingMenu; forward;

procedure SetDefaultIcon; forward;

procedure CreateStartingItems(characterData: Pointer); forward;

{ Frees a creature record with its combat record, items and effects. Note: a nil creature only prints a warning and is
  then used anyway.
  @param(characterData The creature; nil on return.) }
procedure FreeCreature(var characterData: Types.PCharacter);
var
  itemSlotToFree: Pointer;
  itemCursor: Types.PItem;
  effectToFree: Types.PEffect;
  effectCursor: Types.PEffect;
begin
  if characterData = nil then
    CharHlp.PrintBottomLine('disposing a nil char');
  with characterData^ do begin
    if combatAddr <> nil then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    itemCursor := items;
    while itemCursor <> nil do begin
      itemSlotToFree := Pointer(itemCursor);
      itemCursor := itemCursor^.next;
      GameIo.FreeSlot(itemSlotToFree);
    end;
    effectCursor := effects;
    while effectCursor <> nil do begin
      effectToFree := effectCursor;
      effectCursor := effectCursor^.next;
      FreeMem(effectToFree, SizeOf(Types.TEffect));
    end;
  end;
  FreeMem(characterData, SizeOf(Types.TCharacter));
  characterData := nil;
end;

procedure MainMenu;
var
  i: Byte;
  choice: Byte;
  { Unused in this version; see the other implementations of this routine. }
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  secondExtended: Byte;
  { Unused in this version; see the other implementations of this routine. }
  menuChoice: Byte;
  redraw: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedChoices: array[1..8] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedChoicesTail: Byte;
  n: ShortInt;
  buildMenu: Byte;
  list: Types.PItemRec;
  selNode: Types.PItemRec;
  walk: Types.PItemRec;
  idx: Integer;
  found: Byte;
  { Unused in this version; see the other implementations of this routine. }
  freeTraining: Byte;
  classIndex: Byte;
  eff: Pointer;
begin
  GDVars.partyClickMode := 0;
  GDVars.locState.previous := GDVars.locState.current;
  GDVars.locState.current := C_Ifc.MAIN_MENU;
  buildMenu := 1;
  idx := 0;
  freeTraining := 0;
  while True do begin
    if buildMenu <> 0 then begin
      Border.DrawWindowFrame(1);
      if GDVars.curChar <> nil then begin
        CharHlp.DisplayParty(GDVars.curChar);
        GDConsts.mainMenuItems[1].enabled := 1;
        GDConsts.mainMenuItems[2].enabled := 1;
        GDConsts.mainMenuItems[3].enabled := Byte(GDVars.gameState^.trainMask > 0);
        GDConsts.mainMenuItems[4].enabled := GDConsts.mainMenuItems[3].enabled;
        GDConsts.mainMenuItems[5].enabled := 1;
        GDConsts.mainMenuItems[7].enabled := 1;
        GDConsts.mainMenuItems[8].enabled := 0;
        GDConsts.mainMenuItems[9].enabled := 1;
        GDConsts.mainMenuItems[10].enabled := 1;
        GDConsts.mainMenuItems[11].enabled := 0;
      end else begin
        GDConsts.mainMenuItems[1].enabled := 0;
        GDConsts.mainMenuItems[2].enabled := 0;
        GDConsts.mainMenuItems[3].enabled := 0;
        GDConsts.mainMenuItems[4].enabled := 0;
        GDConsts.mainMenuItems[5].enabled := 0;
        GDConsts.mainMenuItems[7].enabled := 0;
        GDConsts.mainMenuItems[8].enabled := 1;
        GDConsts.mainMenuItems[9].enabled := 0;
        GDConsts.mainMenuItems[10].enabled := 0;
        GDConsts.mainMenuItems[11].enabled := 1;
      end;
      n := 0;
      for i := 0 to 12 do
        if GDConsts.mainMenuItems[i].enabled <> 0 then Inc(n);
      MenuCore.AllocStringList(n, Pointer(list));
      walk := list;
      for i := 0 to 12 do
        if GDConsts.mainMenuItems[i].enabled <> 0 then begin
          walk^.name := GDConsts.mainMenuItems[i].name;
          walk := walk^.next;
        end;
    end;
    redraw := 1;
    MenuCore.ResetMenuSlots(0);
    key := MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.selectMenu, 9, 12, 38, 22, list, False, 0,
                                 Boolean(redraw), idx, Pointer(selNode));
    choice := 0;
    found := 0;
    while (choice < 13) and (found = 0) do begin
      found := Byte(GDConsts.mainMenuItems[choice].name = selNode^.name);
      if found = 0 then Inc(choice);
    end;
    if buildMenu <> 0 then MenuCore.FreeStringList(Pointer(list));
    if (choice <> 9) and (choice <> 12) then GDVars.recentlySaved := 0;
    case choice of
      0: if GDConsts.mainMenuItems[0].enabled <> 0 then CharGen.CreateCharacterMenu;
      1: if GDConsts.mainMenuItems[1].enabled <> 0 then CharGen.DropCharacterMenu;
      2: if GDConsts.mainMenuItems[2].enabled <> 0 then CharGen.ModifyCharacterMenu;
      3: if GDConsts.mainMenuItems[3].enabled <> 0 then CharGen.TrainingMenu;
      4: if GDConsts.mainMenuItems[4].enabled <> 0 then
           if ViewChar.PickCharacterDefault then begin
             classIndex := ClassCal.ChangeClass(GDVars.curChar);
             if classIndex <> C_Class.NO_CLASS then begin
               if CharHlp.HasEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, eff) then
                 FxEngine.RemoveEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, nil);
               if CharHlp.HasEffect(GDVars.curChar, C_Effect.RANGER_BONUS_DAMAGE, eff) then
                 FxEngine.RemoveEffect(GDVars.curChar, C_Effect.RANGER_BONUS_DAMAGE, nil);
               case classIndex of
                 C_Class.PALADIN: FxEngine.AddEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, 0, $FF, False);
                 C_Class.RANGER: FxEngine.AddEffect(GDVars.curChar, C_Effect.RANGER_BONUS_DAMAGE, 0, $FF, False);
               end;
             end;
           end;
      5: if GDConsts.mainMenuItems[5].enabled <> 0 then
           if ViewChar.PickCharacterDefault then ViewChar.ViewCharMenu(Boolean(redraw));
      6: if GDConsts.mainMenuItems[6].enabled <> 0 then CharGen.AddCharacterMenu;
      7: if (GDConsts.mainMenuItems[7].enabled <> 0) and (GDVars.curChar <> nil) then
           if ViewChar.PickCharacterDefault then
             if GDVars.curChar^.npc < C_Npc.NON_PLAYER then begin
               SaveLoad.SaveChar(GDVars.curChar, '');
               CharGen.RemoveCreature(False, True);
             end else
               CharGen.DropCharacterMenu;
      8: if GDConsts.mainMenuItems[8].enabled <> 0 then SaveLoad.LoadGame(#0);
      9: if (GDConsts.mainMenuItems[9].enabled <> 0) and (GDVars.partyHead <> nil) then
           SaveLoad.SaveGame(0, 0);
      10: if GDConsts.mainMenuItems[10].enabled <> 0 then begin
            GDVars.partyClickMode := 1;
            if (GDVars.partyHead <> nil) or (GDVars.inputAbort) then begin
              GDVars.locState.current := GDVars.locState.previous;
              if (GDVars.loadedSavedGameFlag = 0) or (GDVars.resourceCurrentId = 9) then begin
                if (GDVars.locState.current = C_Ifc.AREA_MAP) and (GDVars.gameState^.layoutFlag = 1) then
                  Border.ScreenText
                else
                  Border.DrawExploreFrame;
                CharHlp.DisplayParty(GDVars.curChar);
              end else
                case GDVars.locState.current of
                  C_Ifc.MAIN_MENU, C_Ifc.DUNGEON: begin
                         Border.DrawExploreFrame;
                         CharHlp.DisplayParty(GDVars.curChar);
                       end;
                  C_Ifc.AREA_MAP: Border.ScreenText;
                end;
              MenuCore.ClearBottomLine;
              GDVars.gameState^.trainMask := 0;
              CharHlp.PrintPositionAndTime;
              Exit;
            end;
          end;
      11: if GDConsts.mainMenuItems[11].enabled <> 0 then CharGen.InitMouseJoystick;
      12: if GDConsts.mainMenuItems[12].enabled <> 0 then
            if MenuCore.YesNoMenu(GDConsts.quitToDosPrompt, GDConsts.noChoice) = GDConsts.yesChoice then begin
              if (GDVars.partyHead <> nil) and (GDVars.recentlySaved = 0) then
                if MenuCore.YesNoMenu(GDConsts.quitUnsavedQuery, GDConsts.noChoice) = GDConsts.noChoice then
                  SaveLoad.SaveGame(0, 0)
                else
                  GameIo.ExitGame(0);
              GameIo.ExitGame(0);
            end;
    end;
    if ((choice = 1) or (choice = 7)) and (GDVars.curChar = nil) and (GDVars.partyHead = nil) then begin
      GameInit.ResetGameState;
      GDVars.partyClickMode := 0;
      GDVars.locState.previous := GDVars.locState.current;
      GDVars.locState.current := C_Ifc.MAIN_MENU;
      buildMenu := 1;
      idx := 0;
      freeTraining := 1;
      GDVars.scriptAbortFlag := 1;
    end;
  end;
end;

{ Walks the player through creating a character: race, gender, class, and alignment menus, starting experience and age,
  then ability rolls (the best of six rolls each, adjusted for age and held to the race and class limits) and a first
  training pass for hit points and spells, repeated until the player keeps the result. After a name and icon are chosen
  the character, with its spellbook and starting equipment, is saved to disk if the player wants it. Note: the racial
  ability adjustments test raceIndex, left over from the race menu, rather than race. }
procedure CreateCharacterMenu;
var
  characterData: Types.PCharacter;
  savedCurrentCharacter: Types.PCharacter;
  list: Pointer;
  m: Pointer;
  sel: Integer;
  slot: Byte;
  rollAttemptIndex: Byte;
  rolledStat: Byte;
  key: Char;
  raceIndex: ShortInt;
  genderIndex: ShortInt;
  classIndex: ShortInt;
  statIndex: ShortInt;
  choiceCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conBonuses: array[1..3] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  conBonusesTail: Byte;
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: Byte;
  addExit: Byte;
  redraw: Byte;
  { Unused in this version; see the other implementations of this routine. }
  redrawByte: Byte;
  haveLevelText: Byte;
  line: Types.TStr40;
  savedTrainMask: Byte;
  { Unused in this version; see the other implementations of this routine. }
  savedTrainMaskTail: Byte;
  { Unused in this version; see the other implementations of this routine. }
  workspace: array[1..8] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  startingCoins: Byte;
begin
  GetMem(characterData, SizeOf(Types.TCharacter));
  GameIo.ZeroFill(characterData^, SizeOf(Types.TCharacter));
  with Types.PCharacter(characterData)^ do begin
    for slot := 1 to 6 do
      iconColors[slot] := GDConsts.defIconColors[slot] + (GDConsts.defIconColors[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_Status.OKAY;
    inPlay := 1;
    iconDimensions := 1;
    icon := 10;
  end;
  MenuCore.AllocStringList(7, list);
  Types.PItemRec(list)^.inUse := 1;
  Types.PItemRec(list)^.name := GDConsts.raceHeader;
  for raceIndex := C_Race.ELF to C_Race.HUMAN do begin
    m := MenuCore.FindListMember(raceIndex + 1, list);
    Types.PItemRec(m)^.name := '  ' + GDConsts.raceNames[raceIndex];
  end;
  m := list;
  sel := 1;
  redraw := 1;
  addExit := 1;
  MenuCore.ResetMenuSlots(0);
  repeat
    key := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, list, Boolean(addExit), 0, Boolean(redraw), sel, m);
    if (GDVars.menuReturnedKey and (key = C_Keys.ESCAPE)) or
        ((not GDVars.menuReturnedKey) and (key > #0)) then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(characterData);
      Exit;
    end;
  until key = #0;
  with Types.PCharacter(characterData)^ do begin
    race := sel - 1;
    iconSize := 2;
    case race of
      C_Race.HALFLING: begin
           FxEngine.AddEffect(characterData, C_Effect.CON_SPELL_SAVE_BONUS, 0, $FF, False);
           iconSize := 1;
         end;
      C_Race.DWARF: begin
           FxEngine.AddEffect(characterData, C_Effect.DWARF_GIANT_BONUS, 0, $FF, False);
           FxEngine.AddEffect(characterData, C_Effect.DWARF_THAC0_BONUS, 0, $FF, False);
           FxEngine.AddEffect(characterData, C_Effect.CON_SPELL_SAVE_BONUS, 0, $FF, False);
           iconSize := 1;
         end;
      C_Race.GNOME: begin
           FxEngine.AddEffect(characterData, C_Effect.GNOME_LARGE_MONSTER_BONUS, 0, $FF, False);
           FxEngine.AddEffect(characterData, C_Effect.GNOME_THAC0_BONUS, 0, $FF, False);
           FxEngine.AddEffect(characterData, C_Effect.CON_SPELL_SAVE_BONUS, 0, $FF, False);
           iconSize := 1;
         end;
      C_Race.ELF: FxEngine.AddEffect(characterData, C_Effect.RESIST_SLEEP_CHARM_90, 0, $FF, False);
      C_Race.HALF_ELF: FxEngine.AddEffect(characterData, C_Effect.RESIST_CHARM_30, 0, $FF, False);
    end;
  end;
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  Types.PItemRec(list)^.inUse := 1;
  Types.PItemRec(list)^.name := GDConsts.genderHeader;
  for genderIndex := 0 to 1 do begin
    m := MenuCore.FindListMember(genderIndex + 1, list);
    Types.PItemRec(m)^.name := '  ' + GDConsts.genderNames[genderIndex];
  end;
  m := list;
  sel := 1;
  addExit := 1;
  redraw := 1;
  repeat
    key := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, list, Boolean(addExit), 0, Boolean(redraw), sel, m);
    if (GDVars.menuReturnedKey and (key = C_Keys.ESCAPE)) or
        ((not GDVars.menuReturnedKey) and (key > #0)) then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(characterData);
      Exit;
    end;
  until key = #0;
  Types.PCharacter(characterData)^.gender := sel - 1;
  MenuCore.FreeStringList(list);
  choiceCount := GDConsts.raceClasses[Types.PCharacter(characterData)^.race, 0];
  MenuCore.AllocStringList(choiceCount + 1, list);
  Types.PItemRec(list)^.inUse := 1;
  Types.PItemRec(list)^.name := GDConsts.classHeader;
  for slot := 1 to choiceCount do begin
    m := MenuCore.FindListMember(slot, list);
    Types.PItemRec(m)^.name := '  ' +
      GDConsts.classNameTable[GDConsts.raceClasses[Types.PCharacter(characterData)^.race, slot]];
  end;
  m := list;
  sel := 1;
  addExit := 1;
  redraw := 1;
  repeat
    key := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, list, Boolean(addExit), 0, Boolean(redraw), sel, m);
    if (GDVars.menuReturnedKey and (key = C_Keys.ESCAPE)) or
        ((not GDVars.menuReturnedKey) and (key > #0)) then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(characterData);
      Exit;
    end;
  until key = #0;
  with Types.PCharacter(characterData)^ do begin
    experience := 22600;
    charClass := GDConsts.raceClasses[race, sel];
    hitDice := 1;
    case charClass of
      C_Class.CLERIC..C_Class.FIGHTER: classLevels[charClass] := 1;
      C_Class.MAGE..C_Class.THIEF: classLevels[charClass] := 1;
      C_Class.PALADIN: begin
           Types.PCharacter(characterData)^.poisonCount := 1;
           classLevels[C_Class.PALADIN] := 1;
           FxEngine.AddEffect(characterData, C_Effect.PROTECTION_FROM_EVIL, 0, $FF, False);
         end;
      C_Class.RANGER: begin
           classLevels[C_Class.RANGER] := 1;
           FxEngine.AddEffect(characterData, C_Effect.RANGER_BONUS_DAMAGE, 0, $FF, False);
         end;
      C_Class.CLERIC_FIGHTER: begin
           classLevels[C_Class.CLERIC] := 1;
           classLevels[C_Class.FIGHTER] := 1;
           experience := 11300;
         end;
      C_Class.CLERIC_FIGHTER_MAGE: begin
           classLevels[C_Class.CLERIC] := 1;
           classLevels[C_Class.FIGHTER] := 1;
           classLevels[C_Class.MAGE] := 1;
           experience := 7533;
         end;
      C_Class.CLERIC_RANGER: begin
            classLevels[C_Class.CLERIC] := 1;
            classLevels[C_Class.RANGER] := 1;
            FxEngine.AddEffect(characterData, C_Effect.RANGER_BONUS_DAMAGE, 0, $FF, False);
            experience := 11300;
          end;
      CharGen.CLASS_CLERIC_MAGE: begin
            classLevels[C_Class.CLERIC] := 1;
            classLevels[C_Class.MAGE] := 1;
            experience := 11300;
          end;
      CharGen.CLASS_CLERIC_THIEF: begin
            classLevels[C_Class.CLERIC] := 1;
            classLevels[C_Class.THIEF] := 1;
            experience := 11300;
          end;
      CharGen.CLASS_FIGHTER_MAGE: begin
            classLevels[C_Class.FIGHTER] := 1;
            classLevels[C_Class.MAGE] := 1;
            experience := 11300;
          end;
      C_Class.FIGHTER_THIEF: begin
            classLevels[C_Class.FIGHTER] := 1;
            classLevels[C_Class.THIEF] := 1;
            experience := 11300;
          end;
      C_Class.FIGHTER_MAGE_THIEF: begin
            classLevels[C_Class.FIGHTER] := 1;
            classLevels[C_Class.MAGE] := 1;
            classLevels[C_Class.THIEF] := 1;
            experience := 7533;
          end;
      C_Class.MAGE_THIEF: begin
             classLevels[C_Class.MAGE] := 1;
             classLevels[C_Class.THIEF] := 1;
             experience := 11300;
           end;
    end;
    if classLevels[C_Class.THIEF] > 0 then ClassCal.RecalcThiefSkills(Types.PCharacter(characterData));
    classMask := 0;
    thac0Base := 0;
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then begin
        if GDConsts.thac0Tbl[classIndex, classLevels[classIndex]] > thac0Base then
          thac0Base := GDConsts.thac0Tbl[classIndex, classLevels[classIndex]];
        Inc(classMask, GDConsts.classMaskBit[classIndex]);
      end;
  end;
  ClassCal.RecalcSaves(Types.PCharacter(characterData));
  choiceCount := GDConsts.createClassAlignments[Types.PCharacter(characterData)^.charClass, 0];
  MenuCore.AllocStringList(choiceCount + 1, list);
  Types.PItemRec(list)^.inUse := 1;
  Types.PItemRec(list)^.name := GDConsts.alignmentHeader;
  for slot := 1 to choiceCount do begin
    m := MenuCore.FindListMember(slot, list);
    Types.PItemRec(m)^.name := '  ' +
      GDConsts.alignmentNames[ShortInt(GDConsts.createClassAlignments[Types.PCharacter(characterData)^.charClass,
                                                                      slot])];
  end;
  m := list;
  sel := 1;
  addExit := 1;
  redraw := 1;
  repeat
    key := MenuCore.MenuVertical('', 'Select', 1, 2, 38, 22, list, Boolean(addExit), 0, Boolean(redraw), sel, m);
    if (GDVars.menuReturnedKey and (key = C_Keys.ESCAPE)) or
        ((not GDVars.menuReturnedKey) and (key > #0)) then begin
      MenuCore.FreeStringList(list);
      CharGen.FreeCreature(characterData);
      Exit;
    end;
  until key = #0;
  Types.PCharacter(characterData)^.alignment :=
    GDConsts.createClassAlignments[Types.PCharacter(characterData)^.charClass, sel];
  MenuCore.FreeStringList(list);
  if Types.PCharacter(characterData)^.charClass <= C_Class.THIEF then
    with GDConsts.startAges[Types.PCharacter(characterData)^.race, Types.PCharacter(characterData)^.charClass] do
      Types.PCharacter(characterData)^.age := base + FxEngine.RollDice(dice, sides) + 10
    else
      with Types.PCharacter(characterData)^ do case charClass of
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_FIGHTER_MAGE, CharGen.CLASS_CLERIC_MAGE,
            C_Class.CLERIC_RANGER:
          age := GDConsts.startAges[race, C_Class.CLERIC].base +
            GDConsts.startAges[race, C_Class.CLERIC].sides *
            GDConsts.startAges[race, C_Class.CLERIC].dice;
        CharGen.CLASS_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF, C_Class.MAGE_THIEF:
          age := GDConsts.startAges[race, C_Class.MAGE].base +
            GDConsts.startAges[race, C_Class.MAGE].sides *
            GDConsts.startAges[race, C_Class.MAGE].dice;
        C_Class.FIGHTER_THIEF:
          age := GDConsts.startAges[race, C_Class.FIGHTER].base +
            GDConsts.startAges[race, C_Class.FIGHTER].sides *
            GDConsts.startAges[race, C_Class.FIGHTER].dice;
      end;
  savedCurrentCharacter := GDVars.curChar;
  GDVars.curChar := characterData;
  ViewChar.DisplayChar;
  repeat
  for classIndex := 0 to 6 do
    if GDVars.curChar^.classLevels[classIndex] > 0 then
      GDVars.curChar^.classLevels[classIndex] := 1;
  Types.PCharacter(characterData)^.strExc := 0;
  for statIndex := 0 to 5 do begin
    Types.PCharacter(characterData)^.stats[statIndex].current := 0;
    for rollAttemptIndex := 1 to 6 do begin
      rolledStat := FxEngine.RollDice(3, 6) + 1;
      case raceIndex of
        C_Race.DWARF: case statIndex of
             C_Stat.CONSTITUTION: Inc(rolledStat);
             C_Stat.CHARISMA: Dec(rolledStat);
           end;
        C_Race.ELF: case statIndex of
             C_Stat.DEXTERITY: Inc(rolledStat);
             C_Stat.CONSTITUTION: Dec(rolledStat);
           end;
        C_Race.HALFLING: case statIndex of
             C_Stat.STRENGTH: Dec(rolledStat);
             C_Stat.DEXTERITY: Inc(rolledStat);
           end;
      end;
      if Types.PCharacter(characterData)^.stats[statIndex].current < rolledStat then
        Types.PCharacter(characterData)^.stats[statIndex].current := rolledStat;
    end;
    with Types.PCharacter(characterData)^ do
      case statIndex of
        C_Stat.STRENGTH: begin
             if (stats[statIndex].current > 0) and
                 (GDConsts.ageThresholds[race, 0] < age) then Inc(stats[statIndex].current);
             if (stats[statIndex].current > 0) and
                 (GDConsts.ageThresholds[race, 1] < age) then Dec(stats[statIndex].current);
             if (stats[statIndex].current > 0) and
                 (GDConsts.ageThresholds[race, 2] < age) then Dec(stats[statIndex].current, 2);
             if (stats[statIndex].current > 0) and
                 (GDConsts.ageThresholds[race, 3] < age) then Dec(stats[statIndex].current);
             if stats[statIndex].current < GDConsts.raceLimits[race].strMin[gender] then
               stats[statIndex].current := GDConsts.raceLimits[race].strMin[gender];
             if stats[statIndex].current > GDConsts.raceLimits[race].strMax[gender] then
               stats[statIndex].current := GDConsts.raceLimits[race].strMax[gender];
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
             if stats[C_Stat.STRENGTH].current = 18 then
               if (classLevels[C_Class.FIGHTER] > 0) or (classLevels[C_Class.RANGER] > 0) or
                   (classLevels[C_Class.PALADIN] > 0) then begin
                 strExc := Random(100) + 1;
                 if GDConsts.raceLimits[race].strExcMax[gender] < strExc then
                   strExc := GDConsts.raceLimits[race].strExcMax[gender];
               end;
           end;
        C_Stat.INTELLIGENCE: begin
             if GDConsts.ageThresholds[race, 1] < age then Inc(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 3] < age then Inc(stats[statIndex].current);
             if stats[statIndex].current < GDConsts.raceLimits[race].intMin then
               stats[statIndex].current := GDConsts.raceLimits[race].intMin;
             if stats[statIndex].current > GDConsts.raceLimits[race].intMax then
               stats[statIndex].current := GDConsts.raceLimits[race].intMax;
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
           end;
        C_Stat.WISDOM: begin
             if GDConsts.ageThresholds[race, 0] >= age then Dec(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 1] < age then Inc(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 2] < age then Inc(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 3] < age then Inc(stats[statIndex].current);
             if stats[statIndex].current < GDConsts.raceLimits[race].wisMin then
               stats[statIndex].current := GDConsts.raceLimits[race].wisMin;
             if stats[statIndex].current > GDConsts.raceLimits[race].wisMax then
               stats[statIndex].current := GDConsts.raceLimits[race].wisMax;
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
             if (stats[statIndex].current < 13) and
                 (charClass in
                  [C_Class.CLERIC_FIGHTER..CharGen.CLASS_CLERIC_THIEF]) then stats[statIndex].current := 13;
           end;
        C_Stat.DEXTERITY: begin
             if GDConsts.ageThresholds[race, 2] < age then Dec(stats[statIndex].current, 2);
             if GDConsts.ageThresholds[race, 3] < age then Dec(stats[statIndex].current);
             if stats[statIndex].current < GDConsts.raceLimits[race].dexMin then
               stats[statIndex].current := GDConsts.raceLimits[race].dexMin;
             if stats[statIndex].current > GDConsts.raceLimits[race].dexMax then
               stats[statIndex].current := GDConsts.raceLimits[race].dexMax;
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
           end;
        C_Stat.CONSTITUTION: begin
             if GDConsts.ageThresholds[race, 1] < age then Dec(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 2] < age then Dec(stats[statIndex].current);
             if GDConsts.ageThresholds[race, 3] < age then Dec(stats[statIndex].current);
             if stats[statIndex].current < GDConsts.raceLimits[race].conMin then
               stats[statIndex].current := GDConsts.raceLimits[race].conMin;
             if stats[statIndex].current > GDConsts.raceLimits[race].conMax then
               stats[statIndex].current := GDConsts.raceLimits[race].conMax;
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
           end;
        C_Stat.CHARISMA: begin
             if stats[statIndex].current < GDConsts.raceLimits[race].chaMin then
               stats[statIndex].current := GDConsts.raceLimits[race].chaMin;
             if stats[statIndex].current > GDConsts.raceLimits[race].chaMax then
               stats[statIndex].current := GDConsts.raceLimits[race].chaMax;
             if stats[statIndex].current < GDConsts.classReqs[charClass, statIndex] then
               stats[statIndex].current := GDConsts.classReqs[charClass, statIndex];
           end;
      end;
    Types.PCharacter(characterData)^.stats[statIndex].base := Types.PCharacter(characterData)^.stats[statIndex].current;
    if statIndex =
        C_Stat.STRENGTH then Types.PCharacter(characterData)^.strExcBase := Types.PCharacter(characterData)^.strExc;
    ViewChar.PrintStat(statIndex, False);
  end;
  with Types.PCharacter(characterData)^ do begin
    hpCur := hpMax;
    attackRate[1] := 2;
    unarmedRolls[1] := 1;
    unarmedDice[1] := 2;
    movementBase := 12;
    hpTotal := 0;
    classCount := 0;
    GameIo.ZeroFill(spellSlots, SizeOf(spellSlots));
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then begin
        if classIndex = C_Class.CLERIC then begin
          spellSlots[C_Spell.CLERIC_LIST, 1] := 2;
          ClassCal.RecalcClericSlots(Types.PCharacter(characterData));
          for slot := 1 to 126 do begin
            with GDConsts.spellTable[slot] do
              if (spellBand = C_Spell.CLERIC_LIST) and (spellLevel = 1) then knownSpells[slot] := 1;
          end;
        end;
        Inc(classCount);
      end;
    coins[0] := 200;
    hpMax := 0;
    hpRolled := 0;
    hpCur := 0;
  end;
  ViewChar.AdjustLevelHitPoints(characterData, $FF, classCount, 1);
  savedTrainMask := GDVars.gameState^.trainMask;
  GDVars.gameState^.trainMask := $FF;
  GDVars.modifyDone := 0;
  GDVars.trainMode := 1;
  repeat
    CharGen.TrainingMenu;
  until GDVars.modifyDone <> 0;
  GDVars.gameState^.trainMask := savedTrainMask;
  GDVars.trainMode := 0;
  haveLevelText := 0;
  line := '';
  for classIndex := 0 to 6 do
    if (GDVars.curChar^.classLevels[classIndex] > 0) or
        ((GDVars.curChar^.oldLevels[classIndex] <
          ClassCal.CurrentDualClassLevel(GDVars.curChar)) and
        (GDVars.curChar^.oldLevels[classIndex] > 0)) then begin
      if haveLevelText <> 0 then line := line + '/';
      line :=
        line +
        TextRend.ByteToString(GDVars.curChar^.classLevels[classIndex] +
        GDVars.curChar^.oldLevels[classIndex]);
      haveLevelText := 1;
    end;
  line := line + ' ';
  TextRend.DisplayString(7, 7, White, Black, line);
  ViewChar.PrintCombatStats;
  ViewChar.PrintMoney;
  key := Char(MenuCore.YesNoMenu('Reroll stats? ', GDConsts.yesChoice));
  until key = Char(GDConsts.noChoice);
  ViewChar.DisplayChar;
  repeat
    Types.PCharacter(characterData)^.name := TextRend.ReadString('Character name: ', LightMagenta, Black, 15);
  until (Length(Types.PCharacter(characterData)^.name) <> 0) and
      not (Types.PCharacter(characterData)^.name[1] in ['1'..'9']);
  CharGen.SetDefaultIcon;
  CharGen.CustomizePortrait;
  for statIndex := 0 to 5 do
    Types.PCharacter(characterData)^.stats[statIndex].base := Types.PCharacter(characterData)^.stats[statIndex].current;
  Types.PCharacter(characterData)^.strExcBase := Types.PCharacter(characterData)^.strExc;
  Types.PCharacter(characterData)^.creatureType := 2;
  Types.PCharacter(characterData)^.immunities := 2;
  key := Char(MenuCore.YesNoMenu('Save ' + Types.PCharacter(characterData)^.name + '? ', GDConsts.yesChoice));
  if key = Char(GDConsts.noChoice) then begin
    FreeMem(characterData, SizeOf(Types.TCharacter));
    GDVars.curChar := savedCurrentCharacter;
  end else begin
    CharGen.InitKnownSpells(characterData);
    CharGen.CreateStartingItems(characterData);
    SaveLoad.SaveChar(characterData, '');
    FreeMem(characterData, SizeOf(Types.TCharacter));
    GDVars.curChar := savedCurrentCharacter;
  end;
end;

{ Fills in a magic-user's spellbook: spell 18, then the player picks a third more spells than the character has slots at
  each of levels 1 to 3; higher spells come in fixed groups keyed to the later spellSlots entries, and every magic-user
  spell when the last of those entries is set.
  @param(characterData The character, a Types.PCharacter.) }
procedure InitKnownSpells(characterData: Pointer);
var
  i: Byte;

  { Let the player pick count magic-user spells of level charClass from ViewChar's spell list and mark each known. }
  procedure ChooseAvailability(charClass, count: Byte);
  var
    idx: Integer;
    selected: Byte;
    result: Byte;
  begin
    if count = 0 then Exit;
    begin
      GDVars.curChar := characterData;
      GDVars.spellFilter := charClass;
      GDVars.remainingLevel := count;
      while GDVars.remainingLevel <> 0 do begin
        idx := -1;
        repeat
      result := ViewChar.SpellMenu(8, 4, idx, Boolean(selected));
        until (result > 0) or (selected = 0);
        if result > 0 then
          Types.PCharacter(characterData)^.knownSpells[result] := 1;
        Dec(GDVars.remainingLevel);
      end;
    end;
  end;
begin
  if Types.PCharacter(characterData)^.classLevels[C_Class.MAGE] > 0 then begin
    Types.PCharacter(characterData)^.knownSpells[18] := 1;
    ChooseAvailability(1, (Types.PCharacter(characterData)^.spellSlots[C_Spell.MAGIC_USER_LIST, 1] * 4) div 3);
    ChooseAvailability(2, (Types.PCharacter(characterData)^.spellSlots[C_Spell.MAGIC_USER_LIST, 2] * 4) div 3);
    ChooseAvailability(3, (Types.PCharacter(characterData)^.spellSlots[C_Spell.MAGIC_USER_LIST, 3] * 4) div 3);
    with Types.PCharacter(characterData)^ do begin
      if spellSlots[C_Spell.MAGIC_USER_LIST, 4] > 0 then begin
        knownSpells[82] := 1; knownSpells[84] := 1; knownSpells[88] := 1; knownSpells[81] := 1;
        knownSpells[83] := 1; knownSpells[85] := 1; knownSpells[87] := 1;
      end;
      if spellSlots[C_Spell.MAGIC_USER_LIST, 5] > 0 then begin
        knownSpells[91] := 1; knownSpells[92] := 1; knownSpells[118] := 1; knownSpells[119] := 1;
      end;
      if spellSlots[C_Spell.MAGIC_USER_LIST, 6] > 0 then begin
        knownSpells[113] := 1; knownSpells[114] := 1; knownSpells[112] := 1; knownSpells[111] := 1;
      end;
      if spellSlots[C_Spell.MAGIC_USER_LIST, 7] > 0 then begin
        knownSpells[115] := 1; knownSpells[117] := 1;
      end;
      if spellSlots[C_Spell.MAGIC_USER_LIST, 9] > 0 then
        for i := 1 to 126 do
          with GDConsts.spellTable[i] do
            if spellBand = C_Spell.MAGIC_USER_LIST then
              Types.PCharacter(characterData)^.knownSpells[i] := 1;
    end;
  end;
end;

procedure DropCharacterMenu;
begin
  if ViewChar.PickCharacterDefault then begin
    if GDVars.curChar <> nil then
      with GDVars.curChar^ do begin
        if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', GDConsts.noChoice) = GDConsts.yesChoice) and
            (MenuCore.YesNoMenu('Are you sure? ', GDConsts.noChoice) = GDConsts.yesChoice) then begin
          if inPlay = 0 then
            CharHlp.PrintBottomLine('You dump ' + name + ' out back.')
          else
            CharHlp.PrintBottomLine(name + ' bids you farewell.');
          SaveLoad.DeleteCharacterFiles(GDVars.curChar);
          CharGen.RemoveCreature(False, True);
        end else
          CharHlp.PrintBottomLine(name + ' breathes a sigh of relief.');
      end;
    CharHlp.DisplayParty(GDVars.curChar);
  end;
end;

{ Lets the player adjust a new character's abilities, hit points, and name. Only a character still at its starting
  experience may be modified, unless the third command-line parameter is HALIBUT. Abilities stay within the race and
  class limits and hit points within their allowed range. Cancelling restores the saved values; accepting recomputes
  spell slots, the magic-user spellbook, and the base hit points. }
procedure ModifyCharacterMenu;
var
  savedStats: array[0..5] of Byte;
  savedStr: Byte;
  savedHp: Byte;
  savedName: String[40];
  { Unused in this version; see the other implementations of this routine. }
  nameIdx: Byte;
  classIndex: ShortInt;
  i: ShortInt;
  key: Char;
  rawKey: Char;
  extFlag: Byte;
  field: Byte;
  { Unused in this version; see the other implementations of this routine. }
  editState: array[1..7] of Byte;
  cursorCol: Byte;
  j: Byte;

  { Forgets every magic-user spell so InitKnownSpells can rebuild the spellbook. }
  procedure ClearKnownSpells;
  var spell: Byte;
  begin
    for spell := 1 to 126 do
      if GDConsts.spellTable[spell].spellBand = C_Spell.MAGIC_USER_LIST then
        GDVars.curChar^.knownSpells[spell] := 0;
  end;

  { Redraws the field being edited (ability, name or hit points), highlighted when idx is nonzero. }
  procedure DisplayModifyField(idx: Byte);
  begin
    case field of
      0..5: ViewChar.PrintStat(field, Boolean(idx));
      7: CharHlp.PrintHitPoints(GDVars.curChar, 31, 3, Boolean(idx), False);
      6: begin
         Border.EraseBox(1, 1, Length(GDVars.curChar^.name) + 1, 1);
         if idx <> 0 then begin
           TextRend.DisplayString(1, 1, LightMagenta, Black, GDVars.curChar^.name);
           if GDVars.curChar^.name[cursorCol] = ' ' then
             TextRend.DisplayString(cursorCol, 1, White, Black, '%')
           else
             TextRend.DisplayString(cursorCol, 1, White, Black, GDVars.curChar^.name[cursorCol]);
         end else
           TextRend.DisplayString(1, 1, LightGreen, Black, GDVars.curChar^.name);
         end;
    end;
  end;
begin
  if not ViewChar.PickCharacterDefault then Exit;
  if not ((GDVars.curChar^.experience = 22600) or (GDVars.curChar^.experience = 11300) or
          (GDVars.curChar^.experience = 7533) or (ParamStr(3) = 'HALIBUT')) then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + GDConsts.modifyErrorSuffix, Yellow, Black);
    Exit;
  end;
  GDVars.modifyMouseRow := $FF;
  GDVars.modifyActive := 1;
  ViewChar.DisplayChar;
  for i := 0 to 5 do savedStats[i] := GDVars.curChar^.stats[i].current;
  savedStr := GDVars.curChar^.strExc;
  savedHp := GDVars.curChar^.hpMax;
  savedName := GDVars.curChar^.name;
  cursorCol := 1;
  field := 7;
  DisplayModifyField(0);
  field := 0;
  DisplayModifyField(1);
  with GDVars.curChar^ do
  repeat
    if field = 6 then begin
      extFlag := 0;
      repeat until GameIo.InputPending;
      rawKey := GameIo.ReadGameKey;
      if rawKey in ['1'..'9', '\'] then begin
        if rawKey = '\' then rawKey := '7'
        else rawKey := GDConsts.modifyKeys[Ord(rawKey) - $31];
        extFlag := 1;
      end;
      if rawKey = #0 then begin
        rawKey := GameIo.ReadGameKey;
        extFlag := 1;
      end;
      if rawKey = C_Keys.ESCAPE then rawKey := #0;
      if extFlag = 0 then
        case rawKey of
          C_Keys.BACKSPACE: if cursorCol > 1 then begin
                  for j := cursorCol to Length(GDVars.curChar^.name) do
                    GDVars.curChar^.name[j - 1] := GDVars.curChar^.name[j];
                  Dec(GDVars.curChar^.name[0]);
                  if cursorCol > Length(GDVars.curChar^.name) then
                    cursorCol := Length(GDVars.curChar^.name);
                end;
          ' '..'z': if cursorCol <= 15 then begin
                         GDVars.curChar^.name[cursorCol] := rawKey;
                         Inc(cursorCol);
                         if cursorCol > 15 then cursorCol := 15;
                         if cursorCol > Length(GDVars.curChar^.name) then begin
                           Inc(GDVars.curChar^.name[0]);
                           GDVars.curChar^.name[cursorCol] := ' ';
                         end;
                       end;
        end;
    end else begin
      MenuCore.ResetMenuSlots(3);
      key := MenuCore.MenuHorizontal(GDConsts.modifyQuery, GDConsts.addSubtractKeepMenu, 1, 0);
      extFlag := Ord(GDVars.menuReturnedKey);
      if extFlag <> 0 then rawKey := key;
    end;
    DisplayModifyField(0);
    if extFlag <> 0 then
      case rawKey of
        C_Keys.DELETE_KEY: if (field = 6) and (Length(GDVars.curChar^.name) > 1) then begin
                if cursorCol = Length(GDVars.curChar^.name) then begin
                  Dec(GDVars.curChar^.name[0]); cursorCol := Length(GDVars.curChar^.name)
                end else begin
                  for j := cursorCol to Length(GDVars.curChar^.name) - 1 do
                    GDVars.curChar^.name[j] := GDVars.curChar^.name[j + 1];
                  Dec(GDVars.curChar^.name[0]);
                end;
              end;
        C_Keys.DOWN: begin GDVars.modifyMouseRow := $FF; Inc(field);
                     if field > 7 then field := 0 end;
        C_Keys.UP: begin GDVars.modifyMouseRow := $FF; Dec(field);
                     if field = $FF then field := 7 end;
        C_Keys.HOME: if (GDVars.mouseClicked) and (GDVars.modifyMouseRow <> $FF) then
                field := GDVars.modifyMouseRow;
        C_Keys.ESCAPE: begin
                for i := 0 to 5 do GDVars.curChar^.stats[i].current := savedStats[i];
                GDVars.curChar^.strExc := savedStr;
                GDVars.curChar^.hpMax := savedHp;
                GDVars.curChar^.name := savedName;
                GDVars.curChar^.hpCur := hpMax;
                CharHlp.RecalcStats(GDVars.curChar); GDVars.modifyActive := 0; Exit;
              end;
      end else
      case key of
        #1: if field < 6 then begin
              i := field; Dec(stats[i].current);
              case i of
                C_Stat.STRENGTH: begin
                     if strExc > 0 then begin Dec(strExc); Inc(stats[i].current) end
                     else if stats[i].current < GDConsts.raceLimits[race].strMin[gender] then
                       stats[i].current := GDConsts.raceLimits[race].strMin[gender];
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.STRENGTH] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.STRENGTH];
                   end;
                C_Stat.INTELLIGENCE: begin
                     if stats[i].current < GDConsts.raceLimits[race].intMin then
                       stats[i].current := GDConsts.raceLimits[race].intMin;
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.INTELLIGENCE] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.INTELLIGENCE];
                   end;
                C_Stat.WISDOM: begin
                     if stats[i].current < GDConsts.raceLimits[race].wisMin then
                       stats[i].current := GDConsts.raceLimits[race].wisMin;
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.WISDOM] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.WISDOM];
                     if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
                   end;
                C_Stat.DEXTERITY: begin
                     if stats[i].current < GDConsts.raceLimits[race].dexMin then
                       stats[i].current := GDConsts.raceLimits[race].dexMin;
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.DEXTERITY] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.DEXTERITY];
                   end;
                C_Stat.CONSTITUTION: begin
                     if stats[i].current < GDConsts.raceLimits[race].conMin then
                       stats[i].current := GDConsts.raceLimits[race].conMin;
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.CONSTITUTION] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.CONSTITUTION];
                     if ViewChar.HitPointCap(GDVars.curChar) < hpMax then
                       hpMax := ViewChar.HitPointCap(GDVars.curChar);
                     hpCur := hpMax; field := 6; DisplayModifyField(0); field := 4;
                   end;
                C_Stat.CHARISMA: begin
                     if stats[i].current < GDConsts.raceLimits[race].chaMin then
                       stats[i].current := GDConsts.raceLimits[race].chaMin;
                     if stats[i].current < GDConsts.classReqs[charClass, C_Stat.CHARISMA] then
                       stats[i].current := GDConsts.classReqs[charClass, C_Stat.CHARISMA];
                   end;
              end;
            end else if field = 7 then begin
              Dec(hpMax);
              if CharGen.HpMaximum(GDVars.curChar) > hpMax then hpMax := CharGen.HpMaximum(GDVars.curChar);
              hpCur := hpMax;
            end else if cursorCol = 1 then cursorCol := Length(GDVars.curChar^.name)
            else Dec(cursorCol);
        #0: if field < 6 then begin
              i := field; Inc(stats[i].current);
              case i of
                C_Stat.STRENGTH: if stats[i].current > GDConsts.raceLimits[race].strMax[gender] then begin
                     if stats[i].current > 18 then
                       if (classLevels[C_Class.FIGHTER] > 0) or (classLevels[C_Class.PALADIN] > 0) or
                           (classLevels[C_Class.RANGER] > 0) then
                         if GDConsts.raceLimits[race].strExcMax[gender] > strExc then Inc(strExc);
                     stats[i].current := GDConsts.raceLimits[race].strMax[gender];
                   end;
                C_Stat.INTELLIGENCE: if stats[i].current > GDConsts.raceLimits[race].intMax then
                     stats[i].current := GDConsts.raceLimits[race].intMax;
                C_Stat.WISDOM: begin
                     if stats[i].current > GDConsts.raceLimits[race].wisMax then
                       stats[i].current := GDConsts.raceLimits[race].wisMax;
                     if spellSlots[C_Spell.CLERIC_LIST, 1] > 0 then spellSlots[C_Spell.CLERIC_LIST, 1] := 1;
                   end;
                C_Stat.DEXTERITY: if stats[i].current > GDConsts.raceLimits[race].dexMax then
                     stats[i].current := GDConsts.raceLimits[race].dexMax;
                C_Stat.CONSTITUTION: begin
                     if stats[i].current > GDConsts.raceLimits[race].conMax then
                       stats[i].current := GDConsts.raceLimits[race].conMax;
                     if CharGen.HpMaximum(GDVars.curChar) > hpMax then
                       hpMax := CharGen.HpMaximum(GDVars.curChar);
                     hpCur := hpMax; field := 6; DisplayModifyField(0); field := 4;
                   end;
                C_Stat.CHARISMA: if stats[i].current > GDConsts.raceLimits[race].chaMax then
                     stats[i].current := GDConsts.raceLimits[race].chaMax;
              end;
            end else if field = 7 then begin
              Inc(hpMax);
              if ViewChar.HitPointCap(GDVars.curChar) < hpMax then
                hpMax := ViewChar.HitPointCap(GDVars.curChar);
              hpCur := hpMax;
            end else if cursorCol = Length(GDVars.curChar^.name) then cursorCol := 1
            else Inc(cursorCol);
        #3: begin
              for i := 0 to 5 do GDVars.curChar^.stats[i].current := savedStats[i];
              GDVars.curChar^.strExc := savedStr;
              GDVars.curChar^.hpMax := savedHp;
              GDVars.curChar^.hpCur := hpMax;
              GDVars.curChar^.name := savedName;
              CharHlp.RecalcStats(GDVars.curChar); GDVars.modifyActive := 0; Exit;
            end;
      end;
    CharHlp.RecalcStats(GDVars.curChar);
    ViewChar.PrintCombatStats;
    DisplayModifyField(1);
  until (extFlag = 0) and (key = #2);
  ClassCal.RecalcSpellSlots(GDVars.curChar);
  if GDVars.curChar^.classLevels[C_Class.MAGE] > 0 then begin
    ClearKnownSpells;
    CharGen.InitKnownSpells(GDVars.curChar);
  end;
  with GDVars.curChar^ do begin
    savedHp := 0; j := 0;
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then begin
        if classLevels[classIndex] < GDConsts.hitDiceLevelCap[classIndex] then begin
          if classIndex = C_Class.RANGER then
            Inc(savedHp, CharHlp.ClassConAdj(GDVars.curChar, classIndex) * (classLevels[classIndex] + 1))
          else
            Inc(savedHp, CharHlp.ClassConAdj(GDVars.curChar, classIndex) * classLevels[classIndex]);
        end else
          Inc(savedHp, CharHlp.ClassConAdj(GDVars.curChar, classIndex) * (GDConsts.hitDiceLevelCap[classIndex] - 1));
        Inc(j);
      end;
    savedHp := savedHp div j;
    hpRolled := hpMax - savedHp;
  end;
  for i := 0 to 5 do GDVars.curChar^.stats[i].base := GDVars.curChar^.stats[i].current;
  GDVars.curChar^.strExcBase := GDVars.curChar^.strExc;
  GDVars.modifyActive := 0;
end;

{ Adds saved characters to the party. Asks where to load from, then lists the saved characters and adds each one picked,
  marking it with '*'. A character already in the party is refused, as are a seventh player character, a ninth member,
  and a fourth ranger. }
procedure AddCharacterMenu;
var
  list: Pointer;
  files: Pointer;
  m: Pointer;
  fileNode: Pointer;
  characterData: Types.PCharacter;
  walk: Types.PCharacter;
  idx: Integer;
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  addExit: Byte;
  redraw: Byte;
  nonNpc: Byte;
  rangerCount: Byte;
begin
  rangerCount := 0;
  Border.EraseBox(1, 1, 38, 22);
  MenuCore.ResetMenuSlots(2);
  key := MenuCore.MenuHorizontal(GDConsts.addFromWherePrompt, GDConsts.characterSourceMenu, 0, 0);
  if GDVars.menuReturnedKey and (key = C_Keys.ESCAPE) then key := #2;
  case key of
    #0: GDVars.storageMode := 1;
    #1: GDVars.storageMode := 0;
    #2: Exit;
  end;
  SaveLoad.LoadCharlist(Pointer(list), Pointer(files));
  if list = nil then Exit;
  idx := 0;
  m := list;
  redraw := 1;
  repeat
    MenuCore.ResetMenuSlots(0);
    key := MenuCore.MenuVertical(GDConsts.addCharacterPrompt, GDConsts.addQuery, 1, 2, 38, 22, list,
                                 True, 0,
                                 Boolean(redraw), idx, m);
    if GDVars.menuReturnedKey and (key = C_Keys.ESCAPE) then key := #1;
    if key = #0 then
      if Types.PItemRec(m)^.name[1] <> '*' then begin
        MenuCore.ClearBottomLine;
        GetMem(characterData, SizeOf(Types.TCharacter));
        fileNode := MenuCore.FindListMember(idx, files);
        SaveLoad.LoadChar(Types.PItemRec(fileNode)^.name, characterData, False, True);
        Types.PItemRec(m)^.name := '* ' + Types.PItemRec(m)^.name;
        nonNpc := 0;
        if GDVars.partyHead = nil then begin
          GDVars.gameState^.partySize := 0;
          SaveLoad.AddCharToParty(characterData);
          SaveLoad.LoadCharIconAnim(True);
        end else begin
          walk := GDVars.partyHead;
          rangerCount := 0;
          while (walk <> nil) and (walk^.name <> characterData^.name) do begin
            if walk^.npc < C_Npc.NON_PLAYER then Inc(nonNpc);
            if walk^.classLevels[C_Class.RANGER] > 0 then Inc(rangerCount);
            walk := walk^.next;
          end;
          if (walk = nil) and
              (((characterData^.npc < C_Npc.NON_PLAYER) and (nonNpc < 6)) or
               ((characterData^.npc > $7F) and (GDVars.gameState^.partySize < 8))) and
              ((characterData^.classLevels[C_Class.RANGER] = 0) or (rangerCount < 3)) then begin
            SaveLoad.AddCharToParty(characterData);
            SaveLoad.LoadCharIconAnim(True);
            if characterData^.npc < C_Npc.NON_PLAYER then Inc(nonNpc);
          end else begin
            if (characterData^.classLevels[C_Class.RANGER] > 0) and (rangerCount > 2) then
              CharHlp.PrintBottomLine('too many rangers in party');
            FreeMem(characterData, SizeOf(Types.TCharacter));
          end;
        end;
      end;
  until (key = #1) or (nonNpc > 5) or (GDVars.gameState^.partySize > 7);
  MenuCore.FreeStringList(list);
end;

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PCharacter;
begin
  if GDVars.partyHead = nil then Exit;
  prev := GDVars.partyHead;
  if prev <> GDVars.curChar then begin
    while (prev^.next <> GDVars.curChar) and (prev^.next <> nil) do
      prev := prev^.next;
    if prev^.next <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.icon);
      prev^.next := GDVars.curChar^.next;
      CharGen.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.gameState^.partySize);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.icon);
    GDVars.partyHead := GDVars.curChar^.next;
    prev := GDVars.curChar^.next;
    CharGen.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.gameState^.partySize);
  end;
  if GDVars.curChar = nil then
    GDVars.curChar := GDVars.partyHead;
end;

{ Picks the current character's default icon head from its race, gender, and size, and its icon body from its classes. }
procedure SetDefaultIcon;
begin
  with GDVars.curChar^ do begin
    if race = C_Race.HALFLING then
      iconHeadClass := 3
    else if gender = 1 then begin
      if iconSize = 2 then iconHeadClass := 9 else iconHeadClass := 7;
    end else if iconSize = 2 then
      iconHeadClass := 5
    else
      iconHeadClass := 0;

    if classLevels[C_Class.CLERIC] > 0 then
      iconBodyClass := 23
    else if classLevels[C_Class.RANGER] > 0 then
      iconBodyClass := 1
    else if (classLevels[C_Class.PALADIN] > 0) or (classLevels[C_Class.FIGHTER] > 0) then
      iconBodyClass := 24
    else if classLevels[C_Class.MAGE] > 0 then
      iconBodyClass := 29
    else
      iconBodyClass := 5;
  end;
end;

procedure CustomizePortrait;
var
  { Unused in this version; see the other implementations of this routine. }
  extendedKey: Byte;
  ch: Char;
  savedHead: Byte;
  savedBody: Byte;
  savedIcon: Byte;
  savedOrder: Byte;
  state: Byte;
  iconData: Types.TIconColors;
  partIdx: Byte;
  colorMode: Byte;
  sizeVal: Byte;
  colVal: Byte;
  retState: Byte;
  subKey: Char;
  modeFlag: Byte;
  { Unused in this version; see the other implementations of this routine. }
  modeFlagTail: Types.TStr255;

  { Switch the icon editor to state newState and enable that state's menu items. }
  procedure SetIconMenu(newState: Byte);
  var
    first: Byte;
    i: Byte;
  begin
    state := newState;
    MenuCore.ResetMenuSlots(GDConsts.iconMenuCounts[newState]);
    case newState of
      3: begin
           if colorMode <> 0 then first := 2 else first := 3;
           for i := first to 6 do GDVars.menuSlots[i].optionId := i + 1;
           GDVars.menuSlots[7].optionId := $FF;
         end;
      4: begin
           if GDVars.curChar^.iconSize = 2 then first := 1 else first := 0;
           for i := first to 2 do GDVars.menuSlots[i].optionId := i + 1;
           GDVars.menuSlots[3].optionId := $FF;
         end;
    end;
  end;

  { Redraw the icon editor's preview cell (row, col): clear it and draw the two icon frames. }
  procedure ShowIconFrames(row, col: Byte);
  begin
    Blit.FillPicRect(row * 3, col * 24, 3, 24, 0, Types.TColorMap(GDConsts.fillColorMap),
                     Types.PImage(GDVars.viewSurface));
    MapTiles.DrawIconAnimSprite(row, col, 0, 0, 28);
    MapTiles.DrawIconAnimSprite(row, col, 0, 0, $C);
    Blit.FlushView;
    Blit.FillPicRect((row + 3) * 3, col * $18, 3, $18, 0, Types.TColorMap(GDConsts.fillColorMap),
                     Types.PImage(GDVars.viewSurface));
    MapTiles.DrawIconAnimSprite(row + 3, col, 0, 0, $1C);
    MapTiles.DrawIconAnimSprite(row + 3, col, 0, 1, 12);
    Blit.FlushView;
  end;

  { Copy icon src's pictures and masks to icon dst, recolored for the character when rebuild is set. }
  procedure CopyIconPics(src, dst, rebuild: Byte);
  var
    i: Byte;
    grid1: Types.TColorTable;
    grid2: Types.TColorTable;
    cnt: Word;
  begin
    cnt := GDVars.iconSet[dst, 0]^.frameBytes;
    Move(GDVars.iconSet[src, 0]^.data, GDVars.iconSet[dst, 0]^.data, GDVars.iconSet[dst, 0]^.frameBytes);
    Move(GDVars.iconSet[src, 1]^.data, GDVars.iconSet[dst, 1]^.data, GDVars.iconSet[dst, 1]^.frameBytes);
    if GDVars.iconSet[src, 0]^.mask <> nil then
      Move(GDVars.iconSet[src, 0]^.mask^, GDVars.iconSet[dst, 0]^.mask^, cnt);
    if GDVars.iconSet[src, 1]^.mask <> nil then
      Move(GDVars.iconSet[src, 1]^.mask^, GDVars.iconSet[dst, 1]^.mask^, cnt);
    if rebuild <> 0 then
      with GDVars.curChar^ do begin
        for i := 0 to 15 do begin grid1[i] := i; grid2[i] := i end;
        for i := 1 to 6 do begin
          grid2[GDConsts.defIconColors[i]] := iconColors[i] and $F;
          grid2[GDConsts.defIconColors[i] + 8] := (iconColors[i] and $F0) shr 4;
        end;
        Blit.RemapPic(Types.TColorTable(grid1), Types.TColorTable(grid2), 0, 0, Types.PImage(GDVars.iconSet[dst, 0]));
        Blit.RemapPic(Types.TColorTable(grid1), Types.TColorTable(grid2), 0, 0, Types.PImage(GDVars.iconSet[dst, 1]));
      end;
  end;
begin
  MapTiles.LoadIconAnim('COMSPR', 15, 28);
  Blit.SetDacPalette(64, 32, GDVars.gamePalette);
  Border.DrawWindowFrame(0);
  repeat
    SaveLoad.LoadCharIconAnim(False);
    with GDVars.curChar^ do begin
      SetIconMenu(1);
      iconData := iconColors;
      savedOrder := icon;
      icon := 12;
      SaveLoad.LoadCharIconAnim(False);
      icon := savedOrder;
      savedHead := iconHeadClass;
      savedBody := iconBodyClass;
      savedIcon := iconSize;
      CopyIconPics(icon, 12, 1);
      ShowIconFrames(1, 2);
      TextRend.DisplayString(8, 6, White, Black, GDConsts.iconOldText);
      TextRend.DisplayString(3, 10, White, Black, GDConsts.readyActionText);
      TextRend.DisplayString(8, 12, White, Black, GDConsts.iconNewText);
      TextRend.DisplayString(3, 16, White, Black, GDConsts.readyActionText);
      modeFlag := 0;
      repeat
        ShowIconFrames(1, 4);
        ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.iconMenu[state], 0, 0);
        if not GDVars.menuReturnedKey then
          case state of
            1: begin
                 retState := 1;
                 case ch of
                   #0: SetIconMenu(2);
                   #1: begin colorMode := 0; SetIconMenu(3) end;
                   #2: begin colorMode := 1; SetIconMenu(3) end;
                   #3: SetIconMenu(4);
                   #4: modeFlag := 1;
                 end;
               end;
            2: begin
                 retState := 2;
                 if (ch = #2) or (GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE)) then
                   SetIconMenu(1)
                 else begin
                   subKey := ch;
                   SetIconMenu(5);
                 end;
               end;
            3: begin
                 retState := 3;
                 if GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE) then ch := #7;
                 state := 5;
                 case ch of
                   #0: partIdx := 6;
                   #1: partIdx := 1;
                   #2, #3: partIdx := 4;
                   #4: partIdx := 5;
                   #5: partIdx := 2;
                   #6: partIdx := 3;
                   #7: begin partIdx := 1; state := 1 end;
                 end;
                 SetIconMenu(state);
               end;
            4: begin
                 if GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE) then ch := #3;
                 case ch of
                   #0: begin iconSize := 1; SaveLoad.LoadCharIconAnim(False);
                             SetIconMenu(4) end;
                   #1: begin iconSize := 2; SaveLoad.LoadCharIconAnim(False);
                             SetIconMenu(4) end;
                   #2: begin savedIcon := iconSize; SetIconMenu(1) end;
                   #3: begin iconSize := savedIcon; SetIconMenu(1) end;
                 end;
                 SaveLoad.LoadCharIconAnim(False);
               end;
            5: case retState of
                 2: begin
                      if GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE) then ch := #3;
                      case subKey of
                        #0: begin
                              case ch of
                                #0: if iconHeadClass < 13 then Inc(iconHeadClass) else iconHeadClass := 0;
                                #1: if iconHeadClass > 0 then Dec(iconHeadClass) else iconHeadClass := 13;
                                #2: begin
                                      with GDVars.curChar^ do savedHead := iconHeadClass;
                                      SetIconMenu(retState)
                                    end;
                                #3: begin iconHeadClass := savedHead; SetIconMenu(retState) end;
                              end;
                              SaveLoad.LoadCharIconAnim(False);
                            end;
                        #1: begin
                              case ch of
                                #0: if iconBodyClass < 31 then Inc(iconBodyClass) else iconBodyClass := 0;
                                #1: if iconBodyClass > 0 then Dec(iconBodyClass) else iconBodyClass := 31;
                                #2: begin
                                      with GDVars.curChar^ do savedBody := iconBodyClass;
                                      SetIconMenu(retState)
                                    end;
                                #3: begin iconBodyClass := savedBody; SetIconMenu(retState) end;
                              end;
                              SaveLoad.LoadCharIconAnim(False);
                            end;
                      end;
                    end;
                 3: begin
                      sizeVal := iconColors[partIdx] and $F;
                      colVal := (iconColors[partIdx] and $F0) shr 4;
                      if GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE) then ch := #3;
                      case ch of
                        #0: begin
                              if colorMode <> 0 then colVal := (colVal + 1) mod 16
                              else sizeVal := (sizeVal + 1) mod 16;
                              iconColors[partIdx] := (colVal shl 4) + sizeVal;
                            end;
                        #1: begin
                              if colorMode <> 0 then colVal := (colVal - 1) and $F
                              else sizeVal := (sizeVal - 1) and $F;
                              iconColors[partIdx] := (colVal shl 4) + sizeVal;
                            end;
                        #2: begin iconData := iconColors; SetIconMenu(retState) end;
                        #3: begin iconColors := iconData; SetIconMenu(retState) end;
                      end;
                    end;
               end;
          end;
        CopyIconPics(icon, 12, 1);
      until modeFlag <> 0;
      iconHeadClass := savedHead;
      iconBodyClass := savedBody;
      iconSize := savedIcon;
      iconColors := iconData;
      CopyIconPics(icon, 12, 1);
      CopyIconPics(12, icon, 0);
    end;
    MenuCore.ClearBottomLine;
    MapTiles.FreeIconAnim(12);
  until MenuCore.YesNoMenu(GDConsts.iconOkPrompt, GDConsts.yesChoice) = GDConsts.yesChoice;
  MapTiles.FreeIconAnim(28);
end;

{ Looks up a character's Constitution hit-point bonus for a class in the Constitution bonus table; a fighter, ranger or
  paladin gets 1 more at 17, 2 at 18, 3 at 19..20, 4 at 21..23 and 5 at 24..25.
  @param(characterData The character.)
  @param(classIndex The class.)
  @returns(The bonus per hit die.) }
function ConHpBonus(characterData: Pointer; classIndex: Byte): ShortInt;
var
  bonus: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  classIdx: Byte;
begin
  bonus := 0;
  Inc(bonus, GDConsts.conBonusTable[Types.PCharacter(characterData)^.stats[C_Stat.CONSTITUTION].current]);
  if (classIndex = C_Class.FIGHTER) or (classIndex = C_Class.RANGER) or
      (classIndex = C_Class.PALADIN) then
    case Types.PCharacter(characterData)^.stats[C_Stat.CONSTITUTION].current of
      17: Inc(bonus);
      18: Inc(bonus, 2);
      19, 20: Inc(bonus, 3);
      21..23: Inc(bonus, 4);
      24, 25: Inc(bonus, 5);
    end;
  ConHpBonus := bonus;
end;

{ Returns the lowest hit point maximum the character may be given: one point per level below each class's fixed-gain
  level (one more for a ranger) and the fixed gains above it, plus the constitution bonuses when their total is
  positive, averaged over the character's classes. Note: a character with no class levels divides by zero.
  @param(characterData The character.)
  @returns(The hit point maximum.) }
function HpMaximum(characterData: Pointer): Byte;
var
  classCount: Byte;
  conTotal: Integer;
  total: Integer;
  classIndex: ShortInt;
  over: Byte;
begin
  with Types.PCharacter(characterData)^ do begin
    conTotal := 0;
    classCount := 0;
    total := 0;
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then begin
        if classLevels[classIndex] < GDConsts.hitDiceLevelCap[classIndex] then begin
          Inc(total, classLevels[classIndex]);
          Inc(classCount);
          if classIndex = C_Class.RANGER then Inc(total);
          Inc(conTotal, CharGen.ConHpBonus(characterData, classIndex) * classLevels[classIndex]);
        end else begin
          Inc(classCount);
          over := classLevels[classIndex] - GDConsts.hitDiceLevelCap[classIndex] + 1;
          case classIndex of
            C_Class.CLERIC: Inc(total, over * 2 + 9);
            C_Class.FIGHTER, C_Class.PALADIN: Inc(total, over * 3 + 9);
            C_Class.RANGER: Inc(total, over * 2 + 11);
            C_Class.MAGE: Inc(total, over + 11);
            C_Class.THIEF: Inc(total, over * 2 + 10);
          end;
          Inc(conTotal, CharGen.ConHpBonus(characterData, classIndex) * (GDConsts.hitDiceLevelCap[classIndex] - 1));
        end;
      end;
  end;
  if conTotal > 0 then
    total := (total + conTotal) div classCount
  else
    total := total div classCount;
  HpMaximum := total;
end;

{ Trains GDVars.curChar. Finds the classes that may advance under the racial level limits and have enough experience,
  holds experience below the level after next, and asks for confirmation. Then raises those levels, recalculates the
  class values, lets a magic-user or high ranger pick a new spell, restores dual-class abilities, and rolls the new hit
  points. During character creation it runs without prompts and sets the done flag when nothing is left to train. Note:
  the pass outside creation looks up thresholds with the last class's currentLevel for every class. }
procedure TrainingMenu;
var
  atLimit: Boolean;
  experienceCap: LongInt;
  nextExperienceThreshold: LongInt;
  trainableClassMask: Byte;
  activeClassMask: Byte;
  classCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hpTotal: Integer;
  { Unused in this version; see the other implementations of this routine. }
  avgHp: Integer;
  { Unused in this version; see the other implementations of this routine. }
  hpDelta: Byte;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  conBonusV: Integer;
  row: Byte;
  oldLvl5: Byte;
  { Unused in this version; see the other implementations of this routine. }
  oldLvl4: Byte;
  currentLevel: Byte;
  selResult: Byte;
  sentinel: Integer;
  selIdx: Byte;
  { Unused in this version; see the other implementations of this routine. }
  hasSpells: Byte;
  { Unused in this version; see the other implementations of this routine. }
  selClass: Byte;
  highestClassThreshold: LongInt;
  scanClass: ShortInt;
  bestClass: ShortInt;
  eff: Pointer;
  savedCurChar: Types.PCharacter;
  trainingCost: Word;
begin
  if GDVars.trainMode = 0 then
    if not ViewChar.PickCharacterDefault then Exit;
  if GDVars.curChar^.status <> C_Status.OKAY then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow, Black);
    Exit;
  end;
  trainableClassMask := 0;
  activeClassMask := 0;
  experienceCap := 0;
  with GDVars.curChar^ do begin
    experienceCap := 0;
    for i := 0 to 6 do
      if classLevels[i] > 0 then begin
        Inc(activeClassMask, GDConsts.classBits[i]);
        atLimit := False;
        currentLevel := classLevels[i];
        case race of
          C_Race.DWARF: if i = C_Class.FIGHTER then
               if (currentLevel = 9) or ((currentLevel = 8) and (stats[C_Stat.STRENGTH].current = 17)) or
                   ((currentLevel = 7) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
          C_Race.ELF: begin
               if i = C_Class.FIGHTER then
                 if (currentLevel = 7) or ((currentLevel = 6) and (stats[C_Stat.STRENGTH].current = 17)) or
                     ((currentLevel = 5) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE then
                 if (currentLevel = 11) or ((currentLevel = 9) and (stats[C_Stat.INTELLIGENCE].current < 17)) or
                     ((currentLevel = 10) and (stats[C_Stat.INTELLIGENCE].current = 17)) then atLimit := True;
             end;
          C_Race.GNOME: begin
               if i = C_Class.FIGHTER then
                 if (currentLevel = 6) or
                     ((currentLevel = 5) and (stats[C_Stat.STRENGTH].current < 18)) then atLimit := True;
               if (i = C_Class.CLERIC) and (currentLevel >= 7) then atLimit := True;
             end;
          C_Race.HALF_ELF: if (i = C_Class.CLERIC) and (currentLevel = 5) then atLimit := True
             else begin
               if (i = C_Class.FIGHTER) or (i = C_Class.RANGER) then
                 if (currentLevel = 8) or ((currentLevel = 7) and (stats[C_Stat.STRENGTH].current = 17)) or
                     ((currentLevel = 6) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
               if i = C_Class.MAGE then
                 if (currentLevel = 8) or ((currentLevel = 7) and (stats[C_Stat.INTELLIGENCE].current = 17)) or
                     ((currentLevel = 6) and (stats[C_Stat.INTELLIGENCE].current < 17)) then atLimit := True;
             end;
          C_Race.HALFLING: if i = C_Class.FIGHTER then
               if (currentLevel = 6) or ((currentLevel = 5) and (stats[C_Stat.STRENGTH].current = 17)) or
                   ((currentLevel = 4) and (stats[C_Stat.STRENGTH].current < 17)) then atLimit := True;
        end;
        if currentLevel = 40 then atLimit := True;
        if not atLimit and (GDConsts.trainingLimits[i] > currentLevel) then
          if ClassCal.XpForLevel(GDVars.curChar, Succ(currentLevel), i) <= experience then begin
            Inc(trainableClassMask, GDConsts.classBits[i]);
            nextExperienceThreshold := ClassCal.XpForLevel(GDVars.curChar, Succ(Succ(currentLevel)),
                                                           i);
            for scanClass := 0 to 6 do
              if classLevels[scanClass] > 0 then
                if ClassCal.XpForLevel(GDVars.curChar, Succ(classLevels[scanClass]),
                                       scanClass) > nextExperienceThreshold then
                  nextExperienceThreshold := ClassCal.XpForLevel(GDVars.curChar,
                                                                 Succ(classLevels[scanClass]), scanClass);
            if (experience >= nextExperienceThreshold) and (nextExperienceThreshold > experienceCap) then
              experienceCap := nextExperienceThreshold - 1;
          end;
      end;

    if GDVars.trainMode = 0 then begin
      highestClassThreshold := 0;
      nextExperienceThreshold := 0;
      for i := 0 to 6 do
        if (GDConsts.classBits[i] and trainableClassMask) <> 0 then
          if ClassCal.XpForLevel(GDVars.curChar, Succ(currentLevel), i) >
              highestClassThreshold then begin
            highestClassThreshold := ClassCal.XpForLevel(GDVars.curChar, Succ(currentLevel), i);
            bestClass := i;
          end;
      if highestClassThreshold > 0 then begin
        trainableClassMask := trainableClassMask or GDConsts.classBits[bestClass];
        nextExperienceThreshold := ClassCal.XpForLevel(GDVars.curChar, Succ(Succ(currentLevel)),
                                                       bestClass);
        if (nextExperienceThreshold > 0) and (experience >= nextExperienceThreshold) and
            (nextExperienceThreshold > experienceCap) then
          experienceCap := nextExperienceThreshold - 1;
      end;
    end;
    if (experienceCap > 0) and (GDVars.trainMode = 0) then experience := experienceCap;
    if trainableClassMask = 0 then begin
      GDVars.modifyDone := 1;
      if GDVars.trainMode = 0 then
        TextRend.PrintAndPause('Not Enough Experience', Yellow, Black);
      Exit;
    end;
    if GDVars.trainMode = 0 then begin
      Border.EraseBox(1, 1, 38, 22);
      row := 4;
      CharHlp.DisplayCreatureName(GDVars.curChar, 4, row, False);
      TextRend.DisplayString(Length(name) + 4, row, LightGreen, Black, ' will become:');
      trainingCost := 0;
      for i := 0 to 6 do
        if classLevels[i] > 0 then
          if (GDConsts.classBits[i] and trainableClassMask) > 0 then begin
            Inc(trainingCost, 200);
            Inc(row);
            if row = 5 then
              TextRend.DisplayString(6, row, LightGreen, Black,
                                     '    a level ' + TextRend.ByteToString(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNameTable[i])
            else
              TextRend.DisplayString(6, row, LightGreen, Black,
                                     'and a level ' + TextRend.ByteToString(classLevels[i] + 1) + ' ' +
                                     GDConsts.classNameTable[i]);
          end;
      if MenuCore.YesNoMenu('Pay ' + GDVars.intToStringHook(trainingCost) + ' platinum for training? ',
                            GDConsts.yesChoice) <> GDConsts.yesChoice then Exit;
      savedCurChar := GDVars.curChar;
      while GDVars.curChar^.coins[0] < trainingCost do begin
        Border.EraseBox(1, 1, 38, 22);
        CharHlp.DisplayParty(GDVars.curChar);
        if not ViewChar.PickCharacter('Who pays ' + GDVars.intToStringHook(trainingCost) + ' pt? ') then Exit;
      end;
      Money.DropMoney(GDVars.curChar, trainingCost, 0);
      GDVars.curChar := savedCurChar;
      CharHlp.PrintBottomLine('Congratulations...');
    end;
    classCount := 0;
    oldLvl5 := classLevels[C_Class.MAGE];
    oldLvl4 := classLevels[C_Class.RANGER];
    classMask := 0;
    for i := 0 to 6 do
      if classLevels[i] > 0 then begin
        Inc(classCount);
        if (GDConsts.classBits[i] and trainableClassMask) > 0 then Inc(classLevels[i]);
      end;
    ClassCal.RecalcClassStats(GDVars.curChar);
    if GDVars.trainMode = 0 then begin
      if (classLevels[C_Class.MAGE] > oldLvl5) or (classLevels[C_Class.RANGER] > 8) then begin
        sentinel := -1;
        repeat
          selResult := ViewChar.SpellMenu(4, 4, sentinel, Boolean(selIdx));
        until (selResult > 0) or (selIdx = 0);
        if selResult > 0 then knownSpells[selResult] := 1;
      end;
      if ClassCal.EarlierClassActive(GDVars.curChar) then begin
        if GDVars.curChar^.oldLevels[C_Class.RANGER] > 0 then
          if not CharHlp.HasEffect(GDVars.curChar, C_Effect.RANGER_BONUS_DAMAGE, eff) then
            FxEngine.AddEffect(GDVars.curChar, C_Effect.RANGER_BONUS_DAMAGE, 0, $FF, False);
        if GDVars.curChar^.oldLevels[C_Class.PALADIN] > 0 then
          if not CharHlp.HasEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, eff) then
            FxEngine.AddEffect(GDVars.curChar, C_Effect.PROTECTION_FROM_EVIL, 0, $FF, False);
      end;
    end;
    if hitDice > dualLevel then
      ViewChar.AdjustLevelHitPoints(GDVars.curChar, trainableClassMask, classCount, 1);
    displayHighlight := Byte(CharHlp.CanLevelUp(GDVars.curChar));
  end;
end;

{ Lets the player turn the mouse or joystick on or off, or disable both, calibrating the joystick when it is turned on.
  Each change rewrites the configuration file: line 3 holds the input mode (M, J, or N) and the joystick calibration, or
  zeros, follow the five header lines. Note: the file it rewrites is not treasure.cfg, the one STARTUP and CONTROL
  use. }
procedure InitMouseJoystick;
var
  menuList: Pointer;
  menuNode: Pointer;
  done: Byte;
  menuKey: Char;
  redraw: Byte;
  selectedIndex: Integer;
  mouseButtonState: Integer;
  mouseSampleX: Integer;
  mouseSampleY: Integer;
  menuCursor: Pointer;
  configInput: Text;
  configOutput: Text;
  lineIndex: Byte;
  line: array[1..5] of String;
  items: array[1..3] of Types.TStr40;
begin
  MenuCore.AllocStringList(3, menuList);
  redraw := 1;
  done := 0;
  menuCursor := menuList;
  selectedIndex := 0;
  repeat
    Assign(configInput, 'krynn.cfg');
    Reset(configInput);
    for lineIndex := 1 to 5 do ReadLn(configInput, line[lineIndex]);
    Close(configInput);
    if GDVars.mousePresent then items[1] := 'mouse ON'
    else items[1] := 'mouse OFF';
    if GDVars.joystickPresent then items[2] := 'joystick ON'
    else items[2] := 'joystick OFF';
    items[3] := 'disable both';
    menuNode := menuList;
    for lineIndex := 1 to 3 do begin
      Types.PItemRec(menuNode)^.name := items[lineIndex];
      Types.PItemRec(menuNode)^.inUse := 0;
      menuNode := Types.PItemRec(menuNode)^.next;
    end;
    redraw := 1;
    MenuCore.ResetMenuSlots(0);
    menuKey := MenuCore.MenuVertical(GDConsts.inputQuery, GDConsts.selectMenu, 9, 12, 38, 22, menuList, True, 0,
                                     Boolean(redraw), selectedIndex, menuCursor);
    if menuKey = #0 then
      case selectedIndex of
        0: begin
             GDVars.mousePresent := (not GDVars.mousePresent);
             Assign(configOutput, 'krynn.cfg');
             Rewrite(configOutput);
             if GDVars.mousePresent then begin
               GDVars.partyClickMode := 1;
               GDVars.mouseButtonCount := 0;
               Mouse.InitMouse;
               if GDVars.mousePresent then begin
                 GDVars.cursorMask := @GDConsts.cursorMask19;
                 Mouse.SetMouseCursor(0, 0, GDVars.cursorMask);
                 GDVars.mouseHiRes := True;
                 Mouse.SetMouse(639, 100);
                 Mouse.GetMouse(mouseButtonState, mouseSampleX, mouseSampleY);
                 GDVars.mouseHiRes := ((mouseSampleX >= 321) = False);
                 GDVars.joystickPresent := False;
                 Mouse.ShowMouse;
                 line[3] := 'M';
                 for lineIndex := 1 to 5 do WriteLn(configOutput, line[lineIndex]);
                 for lineIndex := 0 to 13 do WriteLn(configOutput, '0');
                 Close(configOutput);
                 GDVars.mouseX := 160;
                 GDVars.mouseY := 100;
                 GDVars.mouseCurX := 0;
                 GDVars.mouseCurY := 0;
               end;
             end;
             if not GDVars.mousePresent then begin
               line[3] := 'N';
               for lineIndex := 1 to 5 do WriteLn(configOutput, line[lineIndex]);
               for lineIndex := 0 to 13 do WriteLn(configOutput, '0');
               Close(configOutput);
               GDVars.mousePresent := True;
               Mouse.HideMouse;
               GDVars.mousePresent := False;
             end;
           end;
        1: begin
             GDVars.joystickPresent := (not GDVars.joystickPresent);
             Assign(configOutput, 'krynn.cfg');
             Rewrite(configOutput);
             if GDVars.joystickPresent then begin
               CharGen.CalibrateJoystickInWindow;
               if GDVars.joystickPresent then begin
                 line[3] := 'J';
                 for lineIndex := 1 to 5 do WriteLn(configOutput, line[lineIndex]);
                 for lineIndex := 0 to 6 do begin
                   WriteLn(configOutput, GDVars.joystickCalibration[1].x.raw[lineIndex]);
                   WriteLn(configOutput, GDVars.joystickCalibration[1].y.raw[lineIndex]);
                 end;
                 Close(configOutput);
                 if GDVars.joystickPresent then begin
                   Mouse.HideMouse;
                   GDVars.mousePresent := False;
                 end;
               end;
             end;
             if not GDVars.joystickPresent then begin
               line[3] := 'N';
               for lineIndex := 1 to 5 do WriteLn(configOutput, line[lineIndex]);
               for lineIndex := 0 to 13 do WriteLn(configOutput, '0');
               Close(configOutput);
             end;
           end;
        2: begin
             GDVars.joystickPresent := False;
             Mouse.HideMouse;
             GDVars.mousePresent := False;
             Assign(configOutput, 'krynn.cfg');
             Rewrite(configOutput);
             line[3] := 'N';
             for lineIndex := 1 to 5 do WriteLn(configOutput, line[lineIndex]);
             for lineIndex := 0 to 13 do WriteLn(configOutput, '0');
             Close(configOutput);
           end;
      end else
      done := 1;
  until done <> 0;
  MenuCore.FreeStringList(menuList);
end;

{ Gives a new character its starting kit: up to six items from the startingItems row for its class family (fighter
  types, thieves, clerics, then everyone else), each prepended to the inventory, unreadied. Note: a pool slot taken for
  an empty line is not given back, and numberOfItems is set to 3 at the end, whatever the count.
  @param(characterData The character, a Types.PCharacter.) }
procedure CreateStartingItems(characterData: Pointer);
var
  previousInventoryHead: Types.PItem;
  menuNode: Types.PItem;
  equipmentFamily: Byte;
  itemTemplateId: Byte;
  lineIndex: Byte;
begin
    if (Types.PCharacter(characterData)^.classLevels[C_Class.FIGHTER] > 0) or
        (Types.PCharacter(characterData)^.classLevels[C_Class.RANGER] > 0) or
        (Types.PCharacter(characterData)^.classLevels[C_Class.PALADIN] > 0) then
      equipmentFamily := 1
    else if Types.PCharacter(characterData)^.classLevels[C_Class.THIEF] > 0 then
      equipmentFamily := 2
    else if Types.PCharacter(characterData)^.classLevels[C_Class.CLERIC] > 0 then
      equipmentFamily := 3
    else
      equipmentFamily := 4;
    Types.PCharacter(characterData)^.numberOfItems := 0;
    for lineIndex := 1 to 6 do begin
      menuNode := Types.PItem(GameIo.AllocSlot);
      FillChar(menuNode^, SizeOf(menuNode^), 0);
      itemTemplateId := GDConsts.startingItems[equipmentFamily, lineIndex];
      if (itemTemplateId <> 0) and (GDVars.itemDefs^[itemTemplateId].itemType <> $FF) then begin
        Inc(Types.PCharacter(characterData)^.numberOfItems);
        Move(GDVars.itemDefs^[itemTemplateId], menuNode^.itemType, SizeOf(Types.TItemDef));
        menuNode^.next := nil;
        menuNode^.inUse := 0;
        if Types.PCharacter(characterData)^.items = nil then
          Types.PCharacter(characterData)^.items := menuNode
        else begin
          previousInventoryHead := Types.PCharacter(characterData)^.items;
          Types.PCharacter(characterData)^.items := menuNode;
          Types.PCharacter(characterData)^.items^.next := previousInventoryHead;
        end;
        Types.PCharacter(characterData)^.items^.unidMask := Types.PCharacter(characterData)^.items^.unidMask and $F8;
        if ((lineIndex = 5) and (equipmentFamily = 1)) or ((lineIndex = 4) and (equipmentFamily = 4)) then
          Types.PCharacter(characterData)^.items^.quantity := 50;
      end;
    end;
  CharHlp.RecalcStats(characterData);
  Types.PCharacter(characterData)^.numberOfItems := 3;
end;

{ Calibrates joystick 1 in the text window: exits at once when Joystick.ProbeJoystick finds no stick; otherwise the
  center from 20 readings, then the upper-left and lower-right extremes with button 1 down, and boundaries a third and
  two thirds of the way to the center. 20000 polls without a press, or a failed read, abort with "Unable to read
  joystick"; success enables the joystick. Note: the 20 center readings are summed in a Word, which can wrap, and an
  aborted calibration leaves the joystick enabled. }
procedure CalibrateJoystickInWindow;
var
  sumX: Word;
  sumY: Word;
  readSucceeded: Byte;
  x: Word;
  y: Word;
  { Unused in this version; see the other implementations of this routine. }
  reading: Byte;
  sampleCounter: Word;
  buttonState: Byte;
begin
  Joystick.ProbeJoystick;
  if not GDVars.joystickPresent then Exit;
  sumX := 0;
  sumY := 0;
  for sampleCounter := 1 to 20 do begin
    readSucceeded := Byte(Joystick.ReadJoystick(1, x, y, buttonState));
    Inc(sumX, x);
    Inc(sumY, y);
  end;
  GDVars.joystickCalibration[1].x.threshold[3] := sumX div 20;
  GDVars.joystickCalibration[1].y.threshold[3] := sumY div 20;

  repeat
    Border.EraseBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme upper');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'left position and press button #1.');
    sampleCounter := 0;
    repeat
      readSucceeded := Byte(Joystick.ReadJoystick(1, x, y, buttonState));
      Inc(sampleCounter);
    until (sampleCounter > 20000) or ((readSucceeded <> 0) and ((buttonState and 1) <> 0));
    if sampleCounter > 20000 then begin
      Border.EraseBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit;
    end;
    sumX := $FFFF;
    sumY := $FFFF;
    for GDVars.scratchIndex := 1 to 20 do
      if Joystick.ReadJoystick(1, x, y, buttonState) then begin
        if (buttonState and 1) <> 0 then begin
          if x < sumX then sumX := x;
          if y < sumY then sumY := y;
        end;
      end else begin
        Border.EraseBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit;
      end;
  until readSucceeded <> 0;
  GDVars.joystickCalibration[1].x.lo := sumX;
  GDVars.joystickCalibration[1].x.threshold[1] := GDVars.joystickCalibration[1].x.lo +
    (GDVars.joystickCalibration[1].x.threshold[3] - GDVars.joystickCalibration[1].x.lo) div 3;
  GDVars.joystickCalibration[1].x.threshold[2] := GDVars.joystickCalibration[1].x.lo +
    (GDVars.joystickCalibration[1].x.threshold[3] - GDVars.joystickCalibration[1].x.lo) * 2 div 3;
  GDVars.joystickCalibration[1].y.lo := sumY;
  GDVars.joystickCalibration[1].y.threshold[1] := GDVars.joystickCalibration[1].y.lo +
    (GDVars.joystickCalibration[1].y.threshold[3] - GDVars.joystickCalibration[1].y.lo) div 3;
  GDVars.joystickCalibration[1].y.threshold[2] := GDVars.joystickCalibration[1].y.lo +
    (GDVars.joystickCalibration[1].y.threshold[3] - GDVars.joystickCalibration[1].y.lo) * 2 div 3;

  repeat until not Joystick.JoyButton(1, 1);

  repeat
    Border.EraseBox(1, 1, 38, 22);
    TextRend.DisplayString(1, 3, LightMagenta, Black, 'Push JOYSTICK #1 to the extreme lower');
    TextRend.DisplayString(1, 5, LightMagenta, Black, 'right position and press button #1.');
    sampleCounter := 0;
    repeat
      readSucceeded := Byte(Joystick.ReadJoystick(1, x, y, buttonState));
      Inc(sampleCounter);
    until (sampleCounter > 20000) or ((readSucceeded <> 0) and ((buttonState and 1) <> 0));
    if sampleCounter > 20000 then begin
      Border.EraseBox(1, 1, 38, 22);
      TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
      Delay(2000);
      Exit;
    end;
    sumX := 0;
    sumY := 0;
    for GDVars.scratchIndex := 1 to 20 do
      if Joystick.ReadJoystick(1, x, y, buttonState) then begin
        if (buttonState and 1) <> 0 then begin
          if x > sumX then sumX := x;
          if y > sumY then sumY := y;
        end;
      end else begin
        Border.EraseBox(1, 1, 38, 22);
        TextRend.DisplayString(1, 3, LightMagenta, Black, 'Unable to read joystick');
        Delay(2000);
        Exit;
      end;
  until readSucceeded <> 0;
  GDVars.joystickCalibration[1].x.hi := sumX;
  GDVars.joystickCalibration[1].x.threshold[4] := GDVars.joystickCalibration[1].x.threshold[3] +
    (GDVars.joystickCalibration[1].x.hi - GDVars.joystickCalibration[1].x.threshold[3]) div 3;
  GDVars.joystickCalibration[1].x.threshold[5] := GDVars.joystickCalibration[1].x.threshold[3] +
    (GDVars.joystickCalibration[1].x.hi - GDVars.joystickCalibration[1].x.threshold[3]) * 2 div 3;
  GDVars.joystickCalibration[1].y.hi := sumY;
  GDVars.joystickCalibration[1].y.threshold[4] := GDVars.joystickCalibration[1].y.threshold[3] +
    (GDVars.joystickCalibration[1].y.hi - GDVars.joystickCalibration[1].y.threshold[3]) div 3;
  GDVars.joystickCalibration[1].y.threshold[5] := GDVars.joystickCalibration[1].y.threshold[3] +
    (GDVars.joystickCalibration[1].y.hi - GDVars.joystickCalibration[1].y.threshold[3]) * 2 div 3;
  GDVars.joystickPresent := True;
end;

begin
end.
