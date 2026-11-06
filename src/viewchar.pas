{ ViewChar -- the character sheet, item use, treasure and money exchange, and the spell-selection menus. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit ViewChar;

interface

{ Draw the character sheet for GDVars.curChar (kept in GDVars.globals.tempCr1): name with ' <NPC>' for npc $80..$B2,
  status, gender, age, alignment, race and class, then level and experience, the six abilities (PrintStat), the money
  panel (PrintMoney), the combat panel (PrintCombatStats) and the items readied in slots 0 and 2. A human with an old
  class below the current class's level shows as dual-class: 'class/old class' and 'level/old level'; a multi-class
  character shows each class's level joined by '/'. }
procedure DisplayChar;

{ Recalculates the current character's stats and shows its hit points, armor class, encumbrance, THAC0, movement and
  damage dice on the character sheet. }
procedure PrintCombatStats;

{ Draws one of the current character's abilities on its row of the character sheet, in light magenta while modifying and
  light green otherwise. Strength 18 with exceptional strength adds '(NN)', with 100 shown as '(00)'; a '*' marks a
  current value (or exceptional strength) that differs from its base.
  @param(statIdx The ability, 0 to 5.)
  @param(modifying True draws it in the modify color.) }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

{ Redraws the money panel of the character sheet, one line per coin type the character holds. }
procedure PrintMoney;

{ The View screen: draw the sheet (DisplayChar) and run the 'Items Spells Trade Deposit Drop Lay Cure Exit' menu until
  Exit or Escape, or until rawDone is set. Items (UseItemMenu) is offered with items; Spells (SpellMenu) with memorized
  spells; Trade (TradeTreasureMenu) with money, outside combat, for a non-NPC or one out of play or in status 1; Deposit
  at the vault (a non-NPC only) or Drop elsewhere (both DropMoneyMenu(1)) with money; Lay and Cure when CanHeal and
  CanCure allow. The sheet is redrawn after Items, Spells and Trade.
  @param(rawDone A Boolean, set when an action ends the character's turn.) }
procedure ViewCharMenu(var rawDone);

{ The Items menu for GDVars.curChar, 'Ready Use Trade Deposit Drop Halve Join Sell Id', over the item list, until Exit
  or Escape, rawDone, or no items left. Ready toggles readiness (ToggleReadyItem). Use, offered in play without
  anti-magic in locations 2..4 or in combat when the combat record allows, needs a readied scroll or effect item
  (UseItem); outside combat it never ends the menu. Trade passes the item to a party member (ItemTradeMenu). Deposit, at
  the vault for a non-NPC, moves a copy to the end of the vault list. Drop, away from the vault, asks 'Lose it? ' and
  frees the item. Halve (under 16 items) splits a stack, Join merges matching stacks (JoinItem), and Sell and Id are
  offered at location 1 unless the healer is open. Trade, Deposit, Drop and Sell first pass CheckItemAvail.
  @param(rawDone A Boolean, set when an action ends the character's turn.) }
procedure UseItemMenu(var rawDone);

{ Ready or unready an item of GDVars.curChar's. A readied item is unreadied unless cursed ('It's Cursed!'). Otherwise it
  is readied unless the class may not use it ('Wrong Class'), its slot is taken ('already using <item>'), or the hands
  would hold more than two ('Your hands are full!', silent in combat with quickfight). An item with special $80 or more,
  or 15, has its special applied or undone through ToggleItemEffect.
  @param(it The item, a Types.PItem.) }
procedure ToggleReadyItem(it: Pointer);

{ Tells whether a character cannot take an item: the pack already holds 16 items and the item does not join an existing
  stack, or its weight would exceed the carrying allowance by more than 1500.
  @param(cr The character.)
  @param(quantity Nonzero enables the stack check.)
  @param(it The item.)
  @returns(True when the character cannot take it.) }
function CannotCarryItem(cr: Pointer; quantity: Byte; it: Pointer): Boolean;

{ Changes the current character: with a mouse and a character picked by it, to that one; otherwise up moves to the
  previous roster member, wrapping from the first to the last, and down to the next, wrapping from the last to the
  first.
  @param(c The key: up selects the previous member, down the next.) }
procedure SelectPrevNextChar(c: Char);

{ Build the spell list of menuType (GenerateSpellList) and, when it is not empty, run it (SpellSelection) and return the
  chosen spell, else return 0 with notEmpty False. The title reads 'Spells ' and, by menuType, 'in Memory' (0), 'in
  Grimoire' (1), 'on Scroll' (2), 'on Scrolls' (3), 'to Choose' (4, 8), 'to Memorize' (5) or 'to Scribe' (6). The screen
  is redrawn when idx is below 0 or selType is 1; type 8 with more than one level left also shows '<n> level <m> spells
  remain'.
  @param(menuType The kind of spell list, as Magic.GenerateSpellList takes it.)
  @param(selType The selection type, as Magic.SpellSelection takes it.)
  @param(idx The highlighted position, kept between calls.)
  @param(notEmpty Receives whether the list held any spells.)
  @returns(The chosen spell, or 0.) }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ Finds the smaller of two numbers.
  @param(a One number.)
  @param(b The other.)
  @returns(The smaller.) }
function MinWord(a, b: Word): Word;

{ Rolls or removes the hit points for a level in each class whose bit is set in a mask, divided among the classes. Each
  die is rolled twice and the better kept; above the fixed-gain level a class adds a flat amount. Removal never leaves
  maximum hit points above what HitPointCap allows.
  @param(cr The character.)
  @param(a The mask of classes that gained or lost a level.)
  @param(b The number of classes the hit points are divided among.)
  @param(c Nonzero rolls the hit points; 0 removes them.) }
procedure AdjustLevelHitPoints(cr: Pointer; a, b, c: Byte);

{ Finds the highest maximum hit points the character's levels allow, with each die at its top value plus the
  constitution bonus, averaged over the active classes.
  @param(cr The character.)
  @returns(The cap.) }
function HitPointCap(cr: Pointer): Byte;

{ Joins each matching stack in the current character's pack into an item, up to 255 per stack; the overflow stays in the
  last stack touched. Note: the charges, effect and special tests compare a stack with itself, so they always pass.
  @param(it The item.) }
procedure JoinItem(it: Pointer);

{ Lets the player pick a character with the prompt 'Pick Character '.
  @returns(True when a character was chosen.) }
function PickCharacterDefault: Boolean;

{ Show query with a 'Select Exit' menu; the arrow keys move the highlight through the party (SelectPrevNextChar).
  Returns True for Select and False for Exit or Escape. partyClickMode is 1 meanwhile.
  @param(query The prompt.)
  @returns(True when a character was chosen, False on Exit.) }
function PickCharacter(query: String): Boolean;

{ Drops money: lists the current character's coin types, asks how much of the chosen one to drop (at a vault, to
  deposit) and drops that many, until Exit or no coins are left. On the character sheet the coin panel is redrawn and
  the menu sits in it; otherwise the menu is in the lower window.
  @param(mode Nonzero on the character sheet, where the coin panel is redrawn; 0 for the menu in the lower window.) }
procedure DropMoneyMenu(mode: Byte);

implementation

uses Types, Money, Magic, FxEngine, CharHlp, ClassCal, MenuCore, CbtMap, View3D, Sym8x8, Border, Blit, TextRend, DaxIo,
  ZeroFree, Crt, GDConsts, GDVars, C_Effect, C_Keys, C_Status, C_Stat,
  C_Class, C_Equip, C_Ifc, C_Npc, C_Race, C_Spell;

const
  { effect ids only this unit names }
  { paladin can heal }
  EFF_RECENT_HEAL = 109;
  { paladin cant't remove curse }
  EFF_RECENT_CURE = 110;

type
  TByteFunc = function: Byte;

var
  runtimeTailChooseSpellLevel: TByteFunc absolute GDVars.chooseSpellLevelHook;

procedure ToggleItemEffect(it: Types.PItem; readying: Boolean); forward;

procedure TradeTreasureMenu; forward;

function CanHeal(cr: Types.PCharacter): Boolean; forward;

function CanCure(cr: Types.PCharacter): Boolean; forward;

procedure PaladinLayOnHands(cr: Types.PCharacter); forward;

procedure PaladinCureDisease(cr: Types.PCharacter); forward;

function ClassConHpBonus(cr: Pointer; extra: Byte): ShortInt; forward;

function CheckItemAvail(it: Types.PItem): Boolean; forward;

procedure UseItem(it: Types.PItem; var done: Boolean); forward;

procedure ItemTradeMenu(it: Types.PItem); forward;

procedure HalveItem(it: Types.PItem); forward;

procedure SellItem(it: Types.PItem); forward;

procedure IdentifyItem(it: Types.PItem; var redraw: Boolean); forward;

procedure UseEffectItem(it: Types.PItem; var done: Boolean); forward;

procedure UseJumpItem(it: Types.PItem; var done: Boolean); forward;

procedure ShowItemMap(it: Types.PItem); forward;

procedure ReadLuckyPaper(it: Types.PItem); forward;

procedure DisplayChar;
var
  { Unused in this version; see the other implementations of this routine. }
  statRow: Byte;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  statCol: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
  dual: Boolean;
begin
  GDVars.globals.tempCr1 := GDVars.curChar;
  Border.DrawCharViewFrame;
  CharHlp.DisplayCreatureName(GDVars.globals.tempCr1, 1, 1, False);
  if GDVars.globals.tempCr1^.npc in [$80..$B2] then
    TextRend.DisplayString(13, 1, Yellow, Black, ' <NPC>');
  TextRend.DisplayString(20, 1, White, Black, 'Status:');
  TextRend.DisplayString(27, 1, LightGreen, Black, GDConsts.statusNames[GDVars.globals.tempCr1^.status]);
  s := GDConsts.genderNames[GDVars.globals.tempCr1^.gender];
  TextRend.DisplayString(1, 3, White, Black, s);
  TextRend.DisplayString(8, 3, White, Black, CharHlp.Uint16Str(GDVars.globals.tempCr1^.age) + ' years');
  s := GDConsts.alignmentNames[ShortInt(GDVars.globals.tempCr1^.alignment)];
  TextRend.DisplayString(1, 4, White, Black, s);
  s := GDConsts.raceNames[GDVars.globals.tempCr1^.race];
  TextRend.DisplayString(20, 4, White, Black, s);

  dual := False;
  s := GDConsts.classNameTable[GDVars.globals.tempCr1^.charClass];
  if GDVars.globals.tempCr1^.race = C_Race.HUMAN then begin
    for j := 0 to 6 do
      if GDVars.globals.tempCr1^.oldLevels[j] > 0 then begin
        dual := True;
        if GDVars.globals.tempCr1^.oldLevels[j] <
           ClassCal.CurrentDualClassLevel(Types.PCharacter(GDVars.globals.tempCr1)) then begin
          s := s + '/' + GDConsts.classNameTable[j];
          j := 6
        end
      end
  end;
  TextRend.DisplayString(1, 5, White, Black, s);
  TextRend.DisplayString(1, 7, White, Black, 'Level');

  s := '';
  if dual then begin
    for j := 0 to 6 do
      if GDVars.globals.tempCr1^.classLevels[j] > 0 then begin
        s := s + CharHlp.Uint8Str(GDVars.globals.tempCr1^.classLevels[j]);
        j := 6
      end;
    for j := 0 to 6 do
      if (GDVars.globals.tempCr1^.oldLevels[j] <
          ClassCal.CurrentDualClassLevel(Types.PCharacter(GDVars.globals.tempCr1))) and
          (GDVars.globals.tempCr1^.oldLevels[j] > 0) then begin
        s := s + '/' + CharHlp.Uint8Str(GDVars.globals.tempCr1^.oldLevels[j]);
        j := 6
      end
  end else begin
    multi := False;
    for j := 0 to 6 do
      if GDVars.globals.tempCr1^.classLevels[j] > 0 then begin
        if multi then s := s + '/';
        s := s + CharHlp.Uint8Str(GDVars.globals.tempCr1^.classLevels[j] + GDVars.globals.tempCr1^.oldLevels[j]);
        multi := True
      end
  end;
  TextRend.DisplayString(7, 7, White, Black, s);
  TextRend.DisplayString(24, 6, White, Black, 'Experience:');
  s := CharHlp.Int32Str(GDVars.globals.tempCr1^.experience);
  TextRend.DisplayString(20 + ((20 - Length(s)) div 2), 7, LightGreen, Black, s);
  for i := C_Stat.STRENGTH to C_Stat.CHARISMA do begin
    case i of
      C_Stat.STRENGTH: s := 'STR ';
      C_Stat.INTELLIGENCE: s := 'INT ';
      C_Stat.WISDOM: s := 'WIS ';
      C_Stat.DEXTERITY: s := 'DEX ';
      C_Stat.CONSTITUTION: s := 'CON ';
      C_Stat.CHARISMA: s := 'CHA '
    end;
    TextRend.DisplayString(1, i + 9, LightGreen, Black, s);
    ViewChar.PrintStat(i, False)
  end;
  ViewChar.PrintMoney;
  ViewChar.PrintCombatStats;
  if GDVars.globals.tempCr1^.equipped[C_Equip.WEAPON] <> nil then
    CharHlp.PrintItemString(GDVars.globals.tempCr1, Types.PItem(GDVars.globals.tempCr1^.equipped[C_Equip.WEAPON]), 1,
                            21, False, True);
  if GDVars.globals.tempCr1^.equipped[C_Equip.ARMOR] <> nil then
    CharHlp.PrintItemString(GDVars.globals.tempCr1, Types.PItem(GDVars.globals.tempCr1^.equipped[C_Equip.ARMOR]), 1, 22,
                            False, True)
end;

procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.EraseBox(20, 9, 38, 15);
  row := 9;
  for m := 0 to 2 do
    if GDVars.curChar^.coins[m] > 0 then begin
      s := GDConsts.wealthNames[m];
      TextRend.DisplayString(20, row, LightGreen, Black, s);
      s := CharHlp.Uint16Str(GDVars.curChar^.coins[m]);
      TextRend.DisplayString(38 - Length(s), row, LightGreen, Black, s);
      Inc(row)
    end
end;

procedure PrintCombatStats;
var
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  row: Byte;
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  mv: Byte;
  s: Types.TStr40;
  { Unused in this version; see the other implementations of this routine. }
  eff: Pointer;

  { Right-aligns a sheet field to its width. }
  procedure RightAlignField(var t: Types.TStr40; width: Byte);
  begin
    while Length(t) < width do
      t := ' ' + t
  end;

begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  TextRend.DisplayString(20, 3, White, Black, 'Hit Points ');
  Border.EraseBox(31, 3, 37, 3);
  CharHlp.PrintHitPoints(p, 31, 3, False, True);
  TextRend.DisplayString(1, 17, White, Black, 'Armor Class');
  case p^.acCur[0] of
    1..50: col := 16;
    51..60: col := 17;
    61..69: col := 16
  else
    col := 15
  end;
  Border.EraseBox(15, 17, 17, 17);
  CharHlp.PrintArmorClass(p, col, 17);
  TextRend.DisplayString(20, 17, White, Black, 'Encumbrance');
  s := CharHlp.Uint16Str(p^.encumbrance);
  RightAlignField(s, 5);
  TextRend.DisplayStringClear(33, 17, LightGreen, Black, s);

  TextRend.DisplayString(1, 18, White, Black, 'THAC0   ');
  Str(60 - p^.thac0Cur:0, s);
  RightAlignField(s, 2);
  TextRend.DisplayStringClear(16, 18, LightGreen, Black, s);

  TextRend.DisplayString(20, 18, White, Black, 'Movement');
  mv := CharHlp.RecalcMovement(p);
  s := CharHlp.Uint8Str(p^.movementCur);
  RightAlignField(s, 3);
  TextRend.DisplayStringClear(35, 18, LightGreen, Black, s);

  s := CharHlp.Uint8Str(p^.curRolls[1]) + 'd' + CharHlp.Uint8Str(p^.curDice[1]);
  if p^.curMod[1] > 0 then
    s := s + '+' + CharHlp.Uint8Str(p^.curMod[1]);
  if p^.curMod[1] < 0 then
    s := s + '-' + CharHlp.Uint8Str(Abs(p^.curMod[1]));
  TextRend.DisplayString(1, 19, White, Black, 'Damage');
  RightAlignField(s, 7);
  TextRend.DisplayStringClear(11, 19, LightGreen, Black, s)
end;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := 13
  else
    hlCol := 10;
  col := 5;
  Border.EraseBox(col, statIdx + 9, 11, statIdx + 9);
  if GDVars.curChar^.stats[statIdx].current < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 9, hlCol, Black, CharHlp.Uint8Str(GDVars.curChar^.stats[statIdx].current));
  if (statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.stats[C_Stat.STRENGTH].current = 18) and
      (GDVars.curChar^.strExc > 0) then begin
    s := CharHlp.Uint8Str(GDVars.curChar^.strExc);
    if GDVars.curChar^.strExc < 10 then
      s := '0' + s;
    if GDVars.curChar^.strExc = 100 then
      s := '00';
    TextRend.DisplayString(7, 9, hlCol, Black, '(' + s + ')')
  end;
  if (GDVars.curChar^.stats[statIdx].current <> GDVars.curChar^.stats[statIdx].base) or
      ((statIdx = C_Stat.STRENGTH) and (GDVars.curChar^.strExcBase <> GDVars.curChar^.strExc)) then
    TextRend.DisplayString(12, statIdx + 9, hlCol, Black, '*')
end;

procedure ViewCharMenu(var rawDone);
var
  done: Boolean absolute rawDone;
  ch: Byte;
  { Unused in this version; see the other implementations of this routine. }
  choice: Byte;
  hasMoney: Boolean;
  hasSpells: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  ext: Boolean;
  spellResult: Byte;
  j: ShortInt;
  idx: Integer;
  optionCount: Byte;
  selection: Byte;
begin
  done := False;
  ch := $FF;
  GDVars.globals.tempCr2 := GDVars.curChar;
  ViewChar.DisplayChar;
  FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
  selection := 1;
  while (ch <> 7) and not done do begin
    optionCount := 0;
    hasSpells := False;
    hasMoney := False;
    for spellResult := 0 to 140 do
      if (GDVars.globals.tempCr1^.memorized[spellResult] and C_Spell.ID_MASK) > 0 then
        hasSpells := True;
    for j := 0 to 2 do
      if GDVars.globals.tempCr1^.coins[j] > 0 then
        hasMoney := True;
    if GDVars.globals.tempCr1^.items <> nil then
      MenuCore.AppendSlot(0, optionCount);
    if hasSpells then
      MenuCore.AppendSlot(1, optionCount);
    if (((GDVars.globals.tempCr1^.npc < C_Npc.NON_PLAYER) or (GDVars.globals.tempCr1^.inPlay = 0) or
         (GDVars.globals.tempCr1^.status = C_Status.ANIMATED)) and hasMoney and
        (GDVars.locState.current <> C_Ifc.IN_COMBAT)) then
      MenuCore.AppendSlot(2, optionCount);
    if hasMoney then
      if GDVars.locState.current = C_Ifc.IN_VAULT then begin
        if GDVars.globals.tempCr1^.npc < C_Npc.NON_PLAYER then
          MenuCore.AppendSlot(3, optionCount)
      end else
        MenuCore.AppendSlot(4, optionCount);
    if ViewChar.CanHeal(GDVars.curChar) then
      MenuCore.AppendSlot(5, optionCount);
    if ViewChar.CanCure(GDVars.curChar) then
      MenuCore.AppendSlot(6, optionCount);
    MenuCore.AppendSlot(7, optionCount);
    GDVars.horizChoice := selection;
    ch := Byte(MenuCore.MenuHorizontal('', GDConsts.menuLabels, 0, 0));
    if GDVars.menuReturnedKey and (ch = $1B) then
      ch := 7;
    selection := GDVars.horizChoice;
    idx := -1;
    case ch of
      0: ViewChar.UseItemMenu(done);
      1: spellResult := ViewChar.SpellMenu(0, 0, idx, hasSpells);
      2: ViewChar.TradeTreasureMenu;
      3, 4: begin
              ViewChar.DropMoneyMenu(1);
              ViewChar.PrintMoney
            end;
      5: ViewChar.PaladinLayOnHands(GDVars.curChar);
      6: ViewChar.PaladinCureDisease(GDVars.curChar)
    end;
    if not done and (ch < 3) then
      ViewChar.DisplayChar
  end;
  if GDVars.locState.current = C_Ifc.IN_COMBAT then
    CbtMap.SetNoncombatPalette;
  CharHlp.DisplayNoncombatInterface
end;

{ Tells whether an item may leave the current character's inventory: a readied item must be unreadied first, and a
  scroll with scribing pending (charges, effect or special above $7F) asks before that work is lost.
  @param(it The item.)
  @returns(True when the item may go.) }
function CheckItemAvail(it: Types.PItem): Boolean;
var
  { Unused in this version; see the other implementations of this routine. }
  p: Pointer;
begin
  CheckItemAvail := False;
  if it^.equipped <> 0 then
    CharHlp.PrintBottomLine('Must be unreadied')
  else if not Magic.ItemReadable(it) then
    CheckItemAvail := True
  else if (it^.charges > $7F) or (it^.effect > $7F) or (it^.special > $7F) then begin
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', GDConsts.noChoice) = GDConsts.yesChoice then
      CheckItemAvail := True
  end else
    CheckItemAvail := True;
  Border.EraseBox(1, 21, 38, 22)
end;

procedure UseItemMenu(var rawDone);
var
  done: Boolean absolute rawDone;
  optionCount: Byte;
  ch: Byte;
  { Unused in this version; see the other implementations of this routine. }
  menuState: Byte;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItem;
  sel: Pointer;
  idx: Integer;
  { Unused in this version; see the other implementations of this routine. }
  previousItem: Types.PItem;
  cr: Types.PCharacter;
  itemCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  itemTotal: Byte;
  selection: Byte;
begin
  cr := GDVars.curChar;
  sel := cr^.items;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  ch := $FF;
  selection := 1;
  while (ch <> 9) and not done and (cr^.numberOfItems > 0) do begin
    itemCount := cr^.numberOfItems;
    if cr^.items <> nil then begin
      FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
      optionCount := 0;
      MenuCore.AppendSlot(0, optionCount);
      if (cr^.inPlay <> 0) and (GDVars.gameState^.antiMagic = 0) and
          ((GDVars.locState.current = C_Ifc.CAMPING) or (GDVars.locState.current = C_Ifc.AREA_MAP) or
           (GDVars.locState.current = C_Ifc.DUNGEON) or
           ((GDVars.locState.current = C_Ifc.IN_COMBAT) and (cr^.combatAddr^.itemUseAllowed <> 0))) then
        MenuCore.AppendSlot(1, optionCount);
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (cr^.status = C_Status.ANIMATED)) and
          (GDVars.locState.current <> C_Ifc.IN_COMBAT) then
        MenuCore.AppendSlot(2, optionCount);
      if GDVars.locState.current = C_Ifc.IN_VAULT then begin
        if cr^.npc < C_Npc.NON_PLAYER then MenuCore.AppendSlot(3, optionCount)
      end else MenuCore.AppendSlot(4, optionCount);
      if cr^.numberOfItems < 16 then MenuCore.AppendSlot(5, optionCount);
      MenuCore.AppendSlot(6, optionCount);
      if ((cr^.npc < C_Npc.NON_PLAYER) or (cr^.inPlay = 0) or (cr^.status = C_Status.ANIMATED)) and
          (GDVars.locState.current = C_Ifc.IN_SHOP) and (GDVars.gameState^.healerRequest <> 1) then
        MenuCore.AppendSlot(7, optionCount);
      if (GDVars.locState.current = C_Ifc.IN_SHOP) and (GDVars.gameState^.healerRequest <> 1) then
        MenuCore.AppendSlot(8, optionCount)
      ;
      p := cr^.items;
      while p <> nil do begin
        CharHlp.PrintItemString(cr, Types.PItem(p), 0, 0, True, False);
        p := p^.next
      end;
      if needRedraw or (GDVars.viewCharRedraw <> 0) then begin
        Border.DrawListFrame;
        CharHlp.DisplayCreatureName(cr, 1, 1, True);
        TextRend.DisplayString(Length(cr^.name) + 4, 1, LightGreen, Black, GDConsts.itemsHeader);
        TextRend.DisplayString(1, 3, White, Black, GDConsts.readyItemHeader);
        vmRedraw := True;
        needRedraw := False;
        GDVars.viewCharRedraw := 0
      end;
      GDVars.horizChoice := selection;
      ch := Byte(MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.itemActionMenu, 1, 5, 38, 22,
                                       Types.PItemRec(cr^.items), True, 8, vmRedraw, idx, sel));
      selection := GDVars.horizChoice;
      if GDVars.menuReturnedKey then
        if ch = $1B then ch := 9
      ;
      if sel <> nil then
        case ch of
          0: ViewChar.ToggleReadyItem(sel);
          1: if Types.PItem(sel)^.equipped = 0 then begin
               CharHlp.PrintBottomLine(GDConsts.itemMustBeReadied);
               ch := $FF
             end else if Magic.ItemReadable(sel) or
               ((Types.PItem(sel)^.effect > 0) and (Types.PItem(sel)^.special < $80)) then begin
               ViewChar.UseItem(Types.PItem(sel), done);
               if GDVars.locState.current <> C_Ifc.IN_COMBAT then done := False;
               if not done then needRedraw := True
             end;
          2: begin
               if ViewChar.CheckItemAvail(Types.PItem(sel)) then ViewChar.ItemTradeMenu(Types.PItem(sel))
               else ch := $FF;
               needRedraw := True
             end;
          3: if ViewChar.CheckItemAvail(Types.PItem(sel)) then begin
               GDVars.lastVaultItem := GDVars.treasureItems;
               while (GDVars.lastVaultItem <> nil) and (GDVars.lastVaultItem^.next <> nil) do
                 GDVars.lastVaultItem := GDVars.lastVaultItem^.next;
               CharHlp.PrintItemString(cr, Types.PItem(sel), 0, 0, False, False);
               if GDVars.locState.current = C_Ifc.IN_VAULT then begin
                 TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                               'Your ' + Types.PItem(sel)^.name + 'will be left in the vault');
                 TextRend.PauseOnly;
                 if GDVars.treasureItems = nil then begin
                   New(GDVars.treasureItems);
                   GDVars.lastVaultItem := GDVars.treasureItems
                 end else begin
                   New(GDVars.lastVaultItem^.next);
                   GDVars.lastVaultItem := GDVars.lastVaultItem^.next
                 end;
                 GDVars.lastVaultItem^ := Types.PItem(sel)^;
                 GDVars.lastVaultItem^.next := nil;
                 CharHlp.RemoveItem(cr, sel);
                 vmRedraw := True
               end
             end else ch := $FF;
          4: if ViewChar.CheckItemAvail(Types.PItem(sel)) then begin
               CharHlp.PrintItemString(cr, Types.PItem(sel), 0, 0, False, False);
               TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                             GDConsts.itemGonePrefix + Types.PItem(sel)^.name +
                                             GDConsts.itemGoneSuffix);
               if MenuCore.YesNoMenu(GDConsts.itemDropQuery, GDConsts.noChoice) = GDConsts.yesChoice then begin
                 CharHlp.RemoveItem(GDVars.curChar, sel);
                 vmRedraw := True
               end;
               Border.EraseBox(1, 21, 38, 22)
             end else ch := $FF;
          5: ViewChar.HalveItem(Types.PItem(sel));
          6: begin
               ViewChar.JoinItem(sel);
               vmRedraw := True
             end;
          7: if ViewChar.CheckItemAvail(Types.PItem(sel)) then ViewChar.SellItem(Types.PItem(sel))
             else ch := $FF;
          8: ViewChar.IdentifyItem(Types.PItem(sel), vmRedraw)
        end;
      CharHlp.RecalcStats(cr)
    end;
    if cr^.numberOfItems <> itemCount then vmRedraw := True
  end;
end;

{ Apply or undo a readied item's special (special and $7F): 0 and 15 run the handler of the item's effect, with removed
  set when unreadying; 1 doubles the level-5 magic-user spell slots when readying, and when unreadying resets them to
  the level-5 spell slots of the Magic-User level (clamped to 2..29) and forgets the memorized level-5 magic-user spells
  past that count; 2 recomputes dexterity and the thief skills; 3 and 5 recompute strength; 9 removes the spiritual
  hammer effect when unreadying.
  @param(it The item.)
  @param(readying True when the item is being readied, False when unreadied.) }
procedure ToggleItemEffect(it: Types.PItem; readying: Boolean);
var
  specialType: Byte;
  rawSlots: Byte;
  { Unused in this version; see the other implementations of this routine. }
  damage: Byte;
  cr: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  classIndex: Byte;
  clampSlots: Byte;
  { Unused in this version; see the other implementations of this routine. }
  levelIndex: Byte;
  i: Byte;
  { Unused in this version; see the other implementations of this routine. }
  level: Byte;
  forgottenCount: Byte;
begin
  cr := GDVars.curChar;
  specialType := it^.special and $7F;
  case specialType of
    0, 15: begin
         GDVars.overrideFlag := 1;
         FxEngine.CallEffectHandler(it^.effect, cr, it, not readying)
       end;
    1: if readying then begin
         i := cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] shl 1;
         cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] := i
       end else begin
         rawSlots := ClassCal.EffectiveClassLevel(Types.PCharacter(cr), C_Class.MAGE);
         clampSlots := rawSlots;
         cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] := 0;
         if clampSlots > 29 then clampSlots := 29
         else if clampSlots < 2 then clampSlots := 2;
         Inc(cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5], GDConsts.classLevelTable[5].spellSlots[clampSlots, 5]);
         forgottenCount := 0;
         for i := 0 to 140 do
           if cr^.memorized[i] <> 0 then
             if GDConsts.spellTable[cr^.memorized[i]].spellBand = 2 then
               if GDConsts.spellTable[cr^.memorized[i]].spellLevel = 5 then begin
                 Inc(forgottenCount);
                 if forgottenCount > cr^.spellSlots[C_Spell.MAGIC_USER_LIST, 5] then
                   cr^.memorized[i] := 0
               end
       end;
    2: begin
         FxEngine.RecalcAbility(cr, C_Stat.DEXTERITY);
         ClassCal.RecalcThiefSkills(Types.PCharacter(cr))
       end;
    3: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    5: FxEngine.RecalcAbility(cr, C_Stat.STRENGTH);
    9: if not readying then FxEngine.RemoveEffect(cr, C_Effect.SPIRITUAL_HAMMER, nil);
    14: ;
  end
end;

procedure ToggleReadyItem(it: Pointer);
var
  specialFlag: Boolean;
  readyOutcome: Byte;
  slot: Byte;
  cr: Types.PCharacter;
begin
  specialFlag := Boolean(Types.PItem(it)^.special > $7F) or (Types.PItem(it)^.special = $0F);
  cr := GDVars.curChar;
  if Types.PItem(it)^.equipped <> 0 then begin
    if Types.PItem(it)^.cursed <> 0 then
      CharHlp.PrintBottomLine('It''s Cursed!')
    else begin
      Types.PItem(it)^.equipped := 0;
      if specialFlag then
        ViewChar.ToggleItemEffect(Types.PItem(it), False)
    end
  end else begin
    readyOutcome := 0;
    if cr^.handsEquipped + GDVars.baseItems[Types.PItem(it)^.itemType].hands > 2 then
      readyOutcome := 3;
    slot := GDVars.baseItems[Types.PItem(it)^.itemType].slot;
    case slot of
      C_Equip.WEAPON..C_Equip.BOOTS: if cr^.equipped[ShortInt(slot)] <> nil then readyOutcome := 2;
      C_Equip.FIRST_RING: if cr^.equipped[C_Equip.SECOND_RING] <> nil then readyOutcome := 2
    end;
    if Types.PItem(it)^.itemType = 30 then
      if cr^.equipped[C_Equip.ARROW] <> nil then begin
        readyOutcome := 2;
        slot := C_Equip.ARROW
      end;
    if (Types.PItem(it)^.itemType = 12) or (Types.PItem(it)^.itemType = 74) then
      if cr^.equipped[C_Equip.BOLT] <> nil then begin
        readyOutcome := 2;
        slot := C_Equip.BOLT
      end;
    if (GDVars.baseItems[Types.PItem(it)^.itemType].classMask and cr^.classMask) = 0 then
      readyOutcome := 1;
    case readyOutcome of
      0: begin
           Types.PItem(it)^.equipped := 1;
           if specialFlag then
             ViewChar.ToggleItemEffect(Types.PItem(it), True)
         end;
      1: CharHlp.PrintBottomLine('Wrong Class');
      2: begin
           CharHlp.PrintItemString(cr, Types.PItem(cr^.equipped[ShortInt(slot)]), 0, 0, False, False);
           CharHlp.PrintBottomLine('already using ' + cr^.equipped[ShortInt(slot)]^.name)
         end;
      3: if not ((GDVars.locState.current = C_Ifc.IN_COMBAT) and (cr^.quickfight <> 0)) then
           CharHlp.PrintBottomLine('Your hands are full!')
    end
  end
end;

{ Gives an item to another party member chosen by the player, unless that member cannot carry it.
  @param(it The item.) }
procedure ItemTradeMenu(it: Types.PItem);
var
  target: Types.PCharacter;
begin
  target := GDVars.globals.tempCr2;
  CharHlp.DisplayNoncombatInterface;
  CharHlp.SelectChar('Trade with Whom?', True, 1, target);
  if target <> nil then begin
    GDVars.globals.tempCr2 := target;
    if ViewChar.CannotCarryItem(target, 0, it) then
      CharHlp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AddItemCopy(target, it);
      CharHlp.RemoveItem(GDVars.curChar, it);
      CharHlp.RecalcStats(target)
    end
  end
end;

{ Splits an item stack: a copy holding half the quantity, rounded down, and unreadied, follows the original, which keeps
  the rest. A quantity below 2 cannot be halved ("Can't halve that").
  @param(it The item.) }
procedure HalveItem(it: Types.PItem);
var
  newItem: Types.PItem;
  half: Byte;
  remainder: Byte;
begin
  half := it^.quantity shr 1;
  if half > 0 then begin
    remainder := it^.quantity - half;
    GetMem(newItem, SizeOf(Types.TItem));
    Move(it^, newItem^, SizeOf(Types.TItem));
    newItem^.quantity := half;
    newItem^.equipped := 0;
    newItem^.next := it^.next;
    it^.quantity := remainder;
    it^.next := newItem
  end else
    CharHlp.PrintBottomLine('Can''t halve that')
end;

procedure JoinItem(it: Pointer);
var
  candidate: Types.PItem;
  nextItem: Types.PItem;
  itLocal: Types.PItem;
  remainingQty: Byte;
begin
  itLocal := Types.PItem(it);
  remainingQty := itLocal^.quantity;
  candidate := GDVars.curChar^.items;
  while candidate <> nil do begin
    nextItem := candidate^.next;
    if candidate <> itLocal then
      if candidate^.quantity > 0 then
        if candidate^.nameIds[1] = itLocal^.nameIds[1] then
          if candidate^.nameIds[2] = itLocal^.nameIds[2] then
            if candidate^.nameIds[3] = itLocal^.nameIds[3] then
              if candidate^.unidMask = itLocal^.unidMask then
                if candidate^.itemType = itLocal^.itemType then
                  if candidate^.plus = itLocal^.plus then
                    if candidate^.saveBonus = itLocal^.saveBonus then
                      if candidate^.cursed = itLocal^.cursed then
                        if candidate^.weight = itLocal^.weight then
                          if candidate^.charges = candidate^.charges then
                            if candidate^.charges < 2 then
                            if candidate^.effect = candidate^.effect then
                              if candidate^.special = candidate^.special then begin
                                if remainingQty + candidate^.quantity <= 255 then begin
                                  Inc(remainingQty, candidate^.quantity);
                                  CharHlp.RemoveItem(GDVars.curChar, candidate)
                                end else begin
                                  itLocal^.quantity := 255;
                                  candidate^.quantity := candidate^.quantity - (255 - remainingQty);
                                  remainingQty := candidate^.quantity;
                                  itLocal := candidate
                                end
                              end;
    candidate := nextItem
  end;
  itLocal^.quantity := remainingQty
end;

{ Use an item of special type $11: when GDVars.curChar already has the item's effect, say 'is already affected';
  otherwise (showing the combat map in combat) run the effect's handler on GDVars.curChar for the item and set done.
  @param(it The item.)
  @param(done Set when the use ends the character's turn.) }
procedure UseEffectItem(it: Types.PItem; var done: Boolean);
var
  effectNode: Pointer;
begin
  if CharHlp.HasEffect(GDVars.curChar, it^.effect, effectNode) then
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'is already affected', 10, 1)
  else begin
    if GDVars.locState.current = C_Ifc.IN_COMBAT then CharHlp.DisplayCombatInterface;
    GDVars.overrideFlag := 1;
    FxEngine.CallEffectHandler(it^.effect, GDVars.curChar, it, False);
    done := True
  end
end;

{ Use an item of special type $0F, the jump (combat only): show the combat map and pick a cell. An occupied cell gives
  'cannot go there'. Otherwise GDVars.curChar loses the cannot-move effect ('is free to move'), moves to the cell and
  'jumps'. done is set True when no cell is picked.
  @param(it Unused.)
  @param(done Set when the jump ends the character's turn.) }
procedure UseJumpItem(it: Types.PItem; var done: Boolean);
var
  cr: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  moved: Boolean;
  effectNode: Pointer;
  occupant: Byte;
  terrainId: Byte;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    CharHlp.DisplayCombatInterface;
    GDVars.spellFns.selectTarget($7F, 0, done);
    if not done then
      done := True
    else begin
      CbtMap.GetArenaContents(GDVars.targetCoordX, GDVars.targetCoordY, occupant, terrainId);
      if occupant <> 0 then begin
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot go there', 10, 1);
        TextRend.PauseOnly
      end else begin
        cr := GDVars.curChar;
        GDVars.combatGfxOn := 1;
        GDVars.combatPanelDirty := 1;
        CbtMap.DisplayMapViewCentered(cr, 3, 1);
        CharHlp.CombatPrintCreatureInfo(cr);
        if CharHlp.HasEffect(cr, C_Effect.CANNOT_MOVE, effectNode) then begin
          FxEngine.RemoveEffect(cr, C_Effect.CANNOT_MOVE, nil);
          CharHlp.PrintCreatureMessage(cr, 'is free to move', 10, 1);
          TextRend.PauseOnly
        end;
        CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(cr));
        moved := CbtMap.IsValidCreatureLoc(cr, GDVars.targetCoordX, GDVars.targetCoordY, False);
        CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 0, 8);
        CharHlp.PrintCreatureMessage(cr, 'jumps', 10, 1)
      end
    end
  end
end;

{ Use an item of special type $10, a map: draw the whole 16 x 16 wall map of GEO1.DAX record it^.effect, with the item's
  name centered below, then reload the current map and wait on the continue prompt.
  @param(it The map item.) }
procedure ShowItemMap(it: Types.PItem);
var
  { Unused in this version; see the other implementations of this routine. }
  yLead: array[1..2] of Byte;
  y: ShortInt;
  x: ShortInt;
  tile: Word;
  { Unused in this version; see the other implementations of this routine. }
  deadString: String;
begin
  Border.DrawCharViewFrame;
  View3D.Load3DMap(it^.effect);
  for x := 0 to 15 do
    for y := 0 to 15 do begin
      tile := GDConsts.bankFirstTile[3];
      if View3D.GetWallType(y, x, 0) > 0 then Inc(tile);
      if View3D.GetWallType(y, x, 2) > 0 then Inc(tile, 2);
      if View3D.GetWallType(y, x, 4) > 0 then Inc(tile, 4);
      if View3D.GetWallType(y, x, 6) > 0 then Inc(tile, 8);
      Sym8x8.Put8x8Sym(y + 10, x + 2, tile, True, 0)
    end;
  CharHlp.PrintItemString(GDVars.curChar, Types.PItem(it), 10, 21, False, False);
  TextRend.DisplayString(19 - Length(it^.name) div 2, 21, LightGreen, Black, it^.name);
  View3D.Load3DMap(GDVars.gameState^.currentMap);
  Blit.FlushView;
  TextRend.PauseContinue
end;

{ Use an item of special type $0E, a lucky paper: show 'The lucky paper of <item name> reads:' and LUCK.DAX block
  it^.effect + 50 a line per two rows. The letters take crystal bits 1, 2 and 4 in turn; a letter whose crystal the
  party does not have (gameState^.crystals) shows as '@'. Waits on the continue prompt.
  @param(it The lucky paper.) }
procedure ReadLuckyPaper(it: Types.PItem);
var
  bitMask: Byte;
  row: Byte;
  fileId: Byte;
  index: Word;
  sizeRead: Word;
  data: Types.PByteBuffer;
  line: String;
begin
  if it^.special = $0E then begin
    Border.DrawCharViewFrame;
    fileId := it^.effect;
    DaxIo.LoadDaxRetrying('LUCK', '.dax', fileId + 50, sizeRead, data);
    TextRend.DisplayString(2, 2, White, Black,
                           'The lucky paper of ' + GDConsts.itemNameParts[it^.nameIds[1]] + ' reads:');
    row := 7;
    index := 0;
    bitMask := 1;
    line := '';
    while index < sizeRead do begin
      case data^[index] of
        10: begin
              TextRend.DisplayString(2, row, Yellow, Black, line);
              Inc(row, 2);
              line := ''
            end;
        32: line := line + ' ';
        26, 13: ;
      else begin
        if (bitMask and GDVars.gameState^.crystals) <> 0 then
          line := line + UpCase(Char(data^[index]))
        else
          line := line + '@';
        if bitMask >= 4 then bitMask := 1
        else bitMask := bitMask + bitMask
      end
      end;
      Inc(index)
    end;
    ZeroFree.PrefixFree(data, sizeRead);
    TextRend.PauseContinue
  end
end;

{ Use item it for GDVars.curChar; done says whether it was used up for this turn. A scroll offers its spells
  (SpellMenu); an item with an effect and a special type below $80 runs its special ($0E lucky paper, $0F jump, $10 map,
  $11 effect) or casts its effect as a spell, after announcing 'uses an item' and the item. A scroll casts for a cleric
  or magic-user; a thief above level 9 succeeds 75% of the time, and anyone else gets 'oops!'. In combat a spell whose
  definition ends the turn ends GDVars.curChar's. A used scroll loses that spell (RemoveSpellFromScroll); a used item
  with charges loses one from its quantity while there are several, else a charge, and goes when the charges run out.
  @param(it The item.)
  @param(done Set when the use ends the character's turn.) }
procedure UseItem(it: Types.PItem; var done: Boolean);
var
  effectId: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItem := 0;
  effectId := 0;
  if Magic.ItemReadable(it) then begin
    GDVars.selectedItem := it;
    effectId := ViewChar.SpellMenu(2, 1, idx, notEmpty)
  end else if (it^.effect > 0) and (it^.special < $80) then begin
    if it^.special = $11 then
      ViewChar.UseEffectItem(it, done)
    else if it^.special = $0E then
      ViewChar.ReadLuckyPaper(it)
    else if it^.special = $0F then
      ViewChar.UseJumpItem(it, done)
    else if it^.special = $10 then
      ViewChar.ShowItemMap(it)
    else begin
      GDVars.usingItem := 1;
      effectId := it^.effect and $7F
    end
  end;
  if effectId = 0 then begin
    if not (it^.special in [$0E..$11]) then done := False
  end else begin
    if (GDVars.locState.current = C_Ifc.IN_COMBAT) and (GDVars.curChar^.quickfight = 0) then
      CharHlp.DisplayCombatInterface;
    if GDVars.usingItem <> 0 then begin
      CharHlp.PrintCreatureMessage(GDVars.curChar, 'uses an item', 10, 0);
      if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
        TextRend.DisplayString(0, 23, LightGreen, Black, 'Item:');
        CharHlp.PrintItemString(GDVars.curChar, Types.PItem(it), 5, 23, False, True)
      end else
        CharHlp.PrintItemString(GDVars.curChar, Types.PItem(it), 1, 22, False, True);
      TextRend.PauseOnly;
      CharHlp.ClearMessageWindow
    end;
    GDVars.usingItem := 1;
    if Magic.ItemReadable(it) then begin
      if (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.MAGE) > 0) or
          (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.CLERIC) > 0) then
        Magic.CastSpell(effectId, GDVars.curChar^.quickfight, 0, done)
      else if (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.THIEF) > 9) and
        (FxEngine.RollDice(1, 100) <= 75) then
        Magic.CastSpell(effectId, GDVars.curChar^.quickfight, 0, done)
      else
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'oops!', GDVars.curRow + 1, 1)
    end else
      Magic.CastSpell(effectId, GDVars.curChar^.quickfight, 0, done);
    GDVars.usingItem := 0;
    if (GDVars.locState.current = C_Ifc.IN_COMBAT) and (GDConsts.spellTable[effectId].whenCast <> 0) then
      done := CharHlp.EndActions(GDVars.curChar)
  end;
  if done then
    if Magic.ItemReadable(it) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, it, effectId)
    else if it^.charges > 0 then
      if it^.quantity > 1 then
        Dec(it^.quantity)
      else begin
        Dec(it^.charges);
        if it^.charges = 0 then
          CharHlp.RemoveItem(GDVars.curChar, it)
      end
end;

{ Makes the shop's offer for an item: half its value times the quantity, divided by 20 for ammunition bundles. With a
  price, it names the platinum it will pay and asks whether the player will sell; without one, the item is worthless and
  the shop offers to dispose of it. On Yes the item goes, and the price is paid in platinum to the current character,
  any part that would overload the character going to the party pool.
  @param(it The item offered.) }
procedure SellItem(it: Types.PItem);
var
  priceWord: Word;
  sellPrice: Word;
  takable: LongInt;
  { Unused in this version; see the other implementations of this routine. }
  t: LongInt;
  promptStr: String[40];
begin
  sellPrice := 0;
  if it^.value > 0 then
    sellPrice := it^.value shr 1;
  if it^.quantity > 1 then
    if (it^.itemType = 30) or (it^.itemType = 12) then
      sellPrice := (it^.quantity * sellPrice) div 20
    else
      sellPrice := it^.quantity * sellPrice;
  CharHlp.PrintItemString(GDVars.globals.tempCr1, Types.PItem(it), 0, 0, False, False);
  if sellPrice > 0 then begin
    TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                  'I''ll give you ' + CharHlp.Uint16Str(sellPrice) + ' platinum pieces for your ' +
                                       it^.name);
    promptStr := 'Will you sell ';
    if it^.quantity < 2 then
      promptStr := promptStr + 'it? '
    else
      promptStr := promptStr + 'them? '
  end else begin
    if it^.quantity < 2 then begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'Your ' + it^.name + ' is worthless to me.');
      promptStr := 'Shall I dispose of it for you? '
    end else begin
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'Your ' + it^.name + ' are worthless.');
      promptStr := 'Would you like to discard them? '
    end
  end;
  if MenuCore.YesNoMenu(promptStr, GDConsts.yesChoice) = GDConsts.yesChoice then begin
    if sellPrice > 0 then
      CharHlp.PrintBottomLine('Sold!')
    else if it^.quantity < 2 then
      CharHlp.PrintBottomLine('I will give it to one of my sons.')
    else
      CharHlp.PrintBottomLine('Very well.  I''ll take them.');
    CharHlp.RemoveItem(GDVars.curChar, it);
    priceWord := sellPrice;
    if Money.CheckOverload(GDVars.curChar, priceWord, takable) then begin
      CharHlp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      Inc(GDVars.curChar^.coins[0], takable);
      Dec(sellPrice, takable);
      Inc(GDVars.pooledMoney[0], sellPrice)
    end else
      Inc(GDVars.curChar^.coins[0], sellPrice)
  end;
  Border.EraseBox(1, 21, 38, 22)
end;

{ Makes the shop's identify offer: 20 platinum pieces, asking whether it is a deal. On Yes the price comes from the
  current character's platinum and then the party pool, or the offer fails for lack of money. Once paid, it clears the
  item's three identify bits and shows what the item looks like, or says nothing new can be told when none was set.
  @param(it The item.)
  @param(redraw Set when the item's name changes, so the item list must be redrawn.) }
procedure IdentifyItem(it: Types.PItem; var redraw: Boolean);
var
  moneyOnHand: LongInt;
  poolCopy: LongInt;
  canIdentify: Boolean;
begin
  canIdentify := False;
  CharHlp.PrintItemString(GDVars.globals.tempCr1, Types.PItem(it), 0, 0, False, False);
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                'For 20 platinum pieces I''ll identify your ' + it^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', GDConsts.yesChoice) = GDConsts.yesChoice then
  begin
    poolCopy := GDVars.pooledMoney[0];
    moneyOnHand := GDVars.curChar^.coins[0];
    if moneyOnHand >= 20 then begin
      canIdentify := True;
      Dec(GDVars.curChar^.coins[0], 20)
    end else if poolCopy + moneyOnHand >= 20 then begin
      canIdentify := True;
      GDVars.curChar^.coins[0] := 0;
      Dec(GDVars.pooledMoney[0], 20 - moneyOnHand)
    end else begin
      CharHlp.PrintBottomLine('Not Enough Money');
      TextRend.PauseOnly
    end
  end;
  if canIdentify then begin
    if (it^.unidMask and 7) = 0 then
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True,
                                    'I can''t tell anything new about your ' + it^.name)
    else begin
      it^.unidMask := it^.unidMask and $F8;
      CharHlp.PrintItemString(GDVars.globals.tempCr1, Types.PItem(it), 0, 0, False, False);
      TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, Black, True, 'It looks like some sort of ' + it^.name);
      redraw := True
    end
  end;
  if canIdentify then
    TextRend.PauseOnly;
  Border.EraseBox(1, 21, 38, 22)
end;

{ Trades money: the player picks a party member to trade to (Exit leaves), then repeatedly picks one of the current
  character's coin types and an amount to give. It leaves once the character has no coins left. Note: leaving the coin
  menu does not set the outer loop's exit flag, so whether it goes back to picking a recipient depends, on the first
  pass, on an uninitialized local. }
procedure TradeTreasureMenu;
var
  selectedChar: Types.PCharacter;
  i: ShortInt;
  moneyTypeIdx: ShortInt;
  j: Byte;
  spaceCount: Byte;
  listHead: Types.PItemRec;
  sel: Pointer;
  savedListHead: Pointer;
  entryCount: Integer;
  idx: Integer;
  numText: String[15];
  spaces: String[15];
  workStr: String;
  selChar: Char;
  qty: Word;
  keepGoing: Boolean;
  tradedOK: Boolean;
  redraw: Boolean;
begin
  repeat
    selectedChar := GDVars.globals.tempCr2;
    CharHlp.DisplayNoncombatInterface;
    CharHlp.SelectChar(GDConsts.tradeToPrompt, True, 1, Types.PCharacter(selectedChar));
    if selectedChar = nil then
      keepGoing := True
    else begin
      ViewChar.DisplayChar;
      repeat
        ViewChar.PrintMoney;
        GDVars.globals.tempCr2 := selectedChar;
        listHead := nil;
        sel := nil;
        savedListHead := nil;
        entryCount := 0;
        for i := 2 downto 0 do
          if GDVars.curChar^.coins[i] <> 0 then begin
            Inc(entryCount);
            if listHead = nil then begin
              GetMem(Pointer(listHead), SizeOf(Types.TItemRec));
              listHead^.next := nil
            end else begin
              sel := listHead;
              GetMem(Pointer(listHead), SizeOf(Types.TItemRec));
              listHead^.next := sel
            end;
            numText := CharHlp.Uint16Str(GDVars.curChar^.coins[i]);
            spaceCount := 14 - Length(GDConsts.wealthNames[i]);
            spaces := '';
            for j := 1 to spaceCount do
              spaces := spaces + ' ';
            listHead^.name := GDConsts.wealthNames[i] + spaces + numText;
            listHead^.inUse := 0
          end;
        savedListHead := listHead;
        idx := 0;
        redraw := True;
        MenuCore.ResetMenuSlots(0);
        selChar := MenuCore.MenuVertical(GDConsts.tradeQuery, GDConsts.selectExitMenu, 20, 9, 38, 15, listHead, True, 1,
                                         redraw, idx, sel);
        if (selChar = #1) or (GDVars.menuReturnedKey and (selChar = C_Keys.ESCAPE)) then
          sel := nil;
        if sel = nil then
          tradedOK := True
        else begin
          workStr := '';
          moneyTypeIdx := Money.ParseMoneyType(Types.PItemRec(sel)^.name, workStr);
          workStr := GDConsts.howMuchText + workStr + GDConsts.willYouTradePrompt;
          qty := Money.InputNumberMax(GDVars.curChar^.coins[moneyTypeIdx], workStr, $A);
          Money.TradeMoney(GDVars.curChar, Types.PCharacter(selectedChar), qty, moneyTypeIdx);
          tradedOK := True;
          keepGoing := True;
          for i := 0 to 2 do
            if GDVars.curChar^.coins[i] > 0 then begin
              keepGoing := False;
              tradedOK := False
            end
        end;
        if savedListHead <> nil then
          MenuCore.FreeStringList(savedListHead)
      until tradedOK
    end
  until keepGoing
end;

procedure DropMoneyMenu(mode: Byte);
var
  i: ShortInt;
  moneyTypeIdx: ShortInt;
  spaceCount: Byte;
  j: Byte;
  entryCount: Integer;
  idx: Integer;
  listHead: Types.PItemRec;
  sel: Pointer;
  savedListHead: Pointer;
  keepGoing: Boolean;
  redraw: Boolean;
  numText: String[15];
  spaces: String[15];
  workStr: String;
  selChar: Char;
  qty: Word;
  ulCol: ShortInt;
  lrCol: ShortInt;
  ulRow: ShortInt;
  lrRow: ShortInt;
begin
  repeat
    if mode <> 0 then
      ViewChar.PrintMoney;
    listHead := nil;
    sel := nil;
    savedListHead := nil;
    entryCount := 0;
    for i := 2 downto 0 do
      if GDVars.curChar^.coins[i] <> 0 then begin
        Inc(entryCount);
        if listHead = nil then begin
          GetMem(Pointer(listHead), SizeOf(Types.TItemRec));
          listHead^.next := nil
        end else begin
          sel := listHead;
          GetMem(Pointer(listHead), SizeOf(Types.TItemRec));
          listHead^.next := sel
        end;
        numText := CharHlp.Uint16Str(GDVars.curChar^.coins[i]);
        spaceCount := 18 - Length(GDConsts.wealthNames[i]) - Length(numText);
        spaces := '';
        for j := 1 to spaceCount do
          spaces := spaces + ' ';
        listHead^.name := GDConsts.wealthNames[i] + spaces + numText;
        listHead^.inUse := 0
      end;
    savedListHead := listHead;
    idx := 0;
    redraw := True;
    MenuCore.ResetMenuSlots(1);
    if mode <> 0 then begin
      ulCol := 20;
      lrCol := 38;
      ulRow := 9;
      lrRow := 15
    end else begin
      ulCol := 1;
      lrCol := 38;
      ulRow := 17;
      lrRow := 22
    end;
    selChar := MenuCore.MenuVertical(GDConsts.tradeQuery, GDConsts.selectMenu, ulCol, ulRow, lrCol, lrRow, listHead,
                                     True, 1, redraw, idx, sel);
    if (sel = nil) or (selChar = #1) then
      keepGoing := True
    else begin
      workStr := '';
      moneyTypeIdx := Money.ParseMoneyType(Types.PItemRec(sel)^.name, workStr);
      if GDVars.locState.current = C_Ifc.IN_VAULT then
        workStr := GDConsts.howMuchText + workStr + GDConsts.willYouDepositPrompt
      else
        workStr := GDConsts.howMuchText + workStr + GDConsts.willYouDropPrompt;
      qty := Money.InputNumberMax(GDVars.curChar^.coins[moneyTypeIdx], workStr, $A);
      Money.DropMoney(GDVars.curChar, qty, moneyTypeIdx);
      keepGoing := True;
      for i := 0 to 2 do
        if GDVars.curChar^.coins[i] > 0 then
          keepGoing := False
    end;
    if savedListHead <> nil then
      MenuCore.FreeStringList(savedListHead)
  until keepGoing
end;

function CannotCarryItem(cr: Pointer; quantity: Byte; it: Pointer): Boolean;
var
  full: Boolean;
  itemWeight: Word;
  walkPtr: Types.PItem;
  merged: Boolean;
begin
  CharHlp.RecalcStats(cr);
  full := False;
  merged := False;
  walkPtr := Types.PCharacter(cr)^.items;
  if Types.PItem(it)^.quantity > 0 then
    if quantity <> 0 then
      while (not merged) and (walkPtr <> nil) do begin
        merged := (walkPtr^.nameIds[1] = Types.PItem(it)^.nameIds[1]) and
          (walkPtr^.nameIds[2] = Types.PItem(it)^.nameIds[2]) and
          (walkPtr^.nameIds[3] = Types.PItem(it)^.nameIds[3]) and (walkPtr^.itemType = Types.PItem(it)^.itemType) and
          (walkPtr^.plus = Types.PItem(it)^.plus) and (walkPtr^.saveBonus = Types.PItem(it)^.saveBonus) and
          (walkPtr^.cursed = Types.PItem(it)^.cursed) and (walkPtr^.weight = Types.PItem(it)^.weight) and
          (walkPtr^.charges = Types.PItem(it)^.charges) and (walkPtr^.charges < 2) and
          (walkPtr^.effect = Types.PItem(it)^.effect) and (walkPtr^.special = Types.PItem(it)^.special);
        walkPtr := walkPtr^.next
      end;
  if (Types.PCharacter(cr)^.numberOfItems > 15) and (not merged) then
    full := True;
  itemWeight := Types.PItem(it)^.weight;
  if Types.PItem(it)^.quantity > 0 then
    itemWeight := Types.PItem(it)^.quantity * itemWeight;
  if LongInt(Types.PCharacter(cr)^.encumbrance + itemWeight) > LongInt(CharHlp.WeightAllowance(cr) + 1500) then
    full := True;
  CannotCarryItem := full
end;

procedure SelectPrevNextChar(c: Char);
var
  walkPtr: Types.PCharacter;
  localC: Char;
begin
  if (GDVars.mousePresent) and (GDVars.mouseClicked) and (GDVars.alternateChar <> nil) then begin
    GDVars.curChar := GDVars.alternateChar;
    GDVars.alternateChar := nil
  end else begin
    localC := c;
    walkPtr := GDVars.partyHead;
    if walkPtr <> nil then
      case localC of
      C_Keys.UP:
      begin
        if walkPtr = GDVars.curChar then
          while walkPtr^.next <> nil do
            walkPtr := walkPtr^.next
        else
          while (walkPtr <> nil) and (walkPtr^.next <> GDVars.curChar) do
            walkPtr := walkPtr^.next;
        GDVars.curChar := walkPtr
      end;
      C_Keys.DOWN:
      begin
        if GDVars.curChar^.next <> nil then
          walkPtr := GDVars.curChar^.next
        else
          walkPtr := GDVars.partyHead;
        GDVars.curChar := walkPtr
      end
      end
  end
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  queryStr: String[40];
  infoStr: String[40];
  { Unused in this version; see the other implementations of this routine. }
  spellLevel: Byte;
begin
  case menuType of
    0: queryStr := 'in Memory';
    1: queryStr := 'in Grimoire';
    2: queryStr := 'on Scroll';
    3: queryStr := 'on Scrolls';
    8, 4: queryStr := 'to Choose';
    5: queryStr := 'to Memorize';
    6: queryStr := 'to Scribe'
  else
    queryStr := ''
  end;
  notEmpty := Magic.GenerateSpellList(menuType);
  if notEmpty then begin
    if (idx < 0) or (selType = 1) then begin
      Border.DrawListFrame;
      if selType = 2 then spellLevel := runtimeTailChooseSpellLevel
    end;
    CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
    TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, Black, 'Spells ' + queryStr);
    if (menuType = 8) and (GDVars.remainingLevel > 1) then begin
      infoStr := GDVars.intToStringHook(GDVars.remainingLevel) + ' level ' +
        GDVars.intToStringHook(GDVars.spellFilter) + ' spells remain';
      TextRend.DisplayString(1, 3, LightGreen, Black, infoStr)
    end;
    SpellMenu := Magic.SpellSelection(selType, idx)
  end else
    SpellMenu := 0
end;

{ Tells whether a character can lay on hands: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, and not within a day of its last healing.
  @param(cr The character.)
  @returns(True when it can heal.) }
function CanHeal(cr: Types.PCharacter): Boolean;
var
  eff: Pointer;
begin
  CanHeal := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldLevels[C_Class.PALADIN] > 0) and
               ClassCal.EarlierClassActive(Types.PCharacter(cr)))) and
    (GDVars.locState.current <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and
    (not CharHlp.HasEffect(cr, ViewChar.EFF_RECENT_HEAL, eff))
end;

{ Tells whether a character can cure disease: a paladin, or a former paladin with its earlier class active, okay,
  outside combat, with a cure left.
  @param(cr The character.)
  @returns(True when it can cure.) }
function CanCure(cr: Types.PCharacter): Boolean;
begin
  CanCure := ((cr^.charClass = C_Class.PALADIN) or
              ((cr^.oldLevels[C_Class.PALADIN] > 0) and
               ClassCal.EarlierClassActive(Types.PCharacter(cr)))) and
    (GDVars.locState.current <> C_Ifc.IN_COMBAT) and (cr^.status = C_Status.OKAY) and (cr^.poisonCount > 0)
end;

{ Lays on hands: asks whom to heal, restores 2 hit points per paladin level to the chosen character (who feels better,
  or is unaffected), and gives the paladin the recent-healing effect for 1440 minutes, so it heals once a day. Returns
  to the character sheet, also when nobody is chosen.
  @param(cr The paladin.) }
procedure PaladinLayOnHands(cr: Types.PCharacter);
var
  selectedChar: Types.PCharacter;
begin
  CharHlp.DisplayNoncombatInterface;
  selectedChar := GDVars.partyHead;
  CharHlp.SelectChar('Heal whom? ', True, 0, Types.PCharacter(selectedChar));
  if selectedChar = nil then
    ViewChar.DisplayChar
  else begin
    if FxEngine.RestoreHitPoints(selectedChar,
                                 ClassCal.EffectiveClassLevel(Types.PCharacter(cr), C_Class.PALADIN) * 2,
                                 False) then begin
      CharHlp.PrintMiscInfo(selectedChar, 1);
      CharHlp.PrintBottomLine(selectedChar^.name + ' feels better')
    end else
      CharHlp.PrintBottomLine(selectedChar^.name + ' is unaffected');
    FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_HEAL, 1440, 0, False);
    ViewChar.DisplayChar
  end
end;

{ Cures disease: asks whom to cure, then says the target is not diseased and asks whether to cure anyway. On Yes, it
  uses one of the paladin's cures, gives the paladin the recent-cure effect for 10080 minutes (a week) unless it has it,
  and says the paladin cures the healthy. Nothing is cured. Returns to the character sheet. Note: the flag that marks a
  diseased target is never set, so each target is reported as not diseased.
  @param(cr The paladin.) }
procedure PaladinCureDisease(cr: Types.PCharacter);
var
  selectedChar: Types.PCharacter;
  confirmFlag: Boolean;
  answer: Byte;
  eff: Pointer;
begin
  CharHlp.DisplayNoncombatInterface;
  selectedChar := GDVars.partyHead;
  CharHlp.SelectChar('Cure whom? ', True, 0, Types.PCharacter(selectedChar));
  if selectedChar = nil then
    ViewChar.DisplayChar
  else begin
    confirmFlag := False;
    answer := GDConsts.yesChoice;
    if not confirmFlag then begin
      CharHlp.PrintCreatureMessage(selectedChar, 'is not diseased', 0, 0);
      answer := MenuCore.YesNoMenu('cure anyway: ', GDConsts.noChoice);
      CharHlp.ClearMessageWindow
    end;
    if answer = GDConsts.yesChoice then begin
      GDVars.effectBusy := 1;
      GDVars.effectBusy := 0;
      if cr^.poisonCount > 0 then
        Dec(cr^.poisonCount);
      if not CharHlp.HasEffect(cr, ViewChar.EFF_RECENT_CURE, eff) then
        FxEngine.AddEffect(cr, ViewChar.EFF_RECENT_CURE, 10080, 0, True);
      if confirmFlag then
        CharHlp.PrintBottomLine(selectedChar^.name + ' is cured')
      else
        CharHlp.PrintBottomLine(cr^.name + ' cures the healthy')
    end;
    ViewChar.DisplayChar
  end
end;

function PickCharacterDefault: Boolean;
begin
  PickCharacterDefault := ViewChar.PickCharacter(GDConsts.pickCharacterPrompt)
end;

function PickCharacter(query: String): Boolean;
var
  selChar: Char;
  savedMouseMode: Byte;
begin
  savedMouseMode := GDVars.partyClickMode;
  GDVars.partyClickMode := 1;
  repeat
    MenuCore.ResetMenuSlots(1);
    selChar := MenuCore.MenuHorizontal(query, 'Select Exit', 1, 0);
    if GDVars.menuReturnedKey then
      if selChar = C_Keys.ESCAPE then begin
        selChar := #1;
        GDVars.menuReturnedKey := False
      end else begin
        CharHlp.PrintMiscInfo(GDVars.curChar, 0);
        ViewChar.SelectPrevNextChar(selChar);
        CharHlp.PrintMiscInfo(GDVars.curChar, 1)
      end
  until (not GDVars.menuReturnedKey) and (selChar <= #1);
  CharHlp.PrintMiscInfo(GDVars.curChar, 1);
  PickCharacter := (selChar = #0);
  GDVars.partyClickMode := savedMouseMode
end;

{ Finds the constitution bonus to hit points per hit die for a class. Fighters, paladins and rangers get the extra bonus
  for constitution above 16.
  @param(cr The character.)
  @param(extra The class.)
  @returns(The bonus.) }
function ClassConHpBonus(cr: Pointer; extra: Byte): ShortInt;
var
  total: Byte;
  { Unused in this version; see the other implementations of this routine. }
  conScore: Integer;
begin
  total := 0;
  Inc(total, GDConsts.conBonusTable[Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current]);
  if (extra = C_Class.FIGHTER) or (extra = C_Class.PALADIN) or (extra = C_Class.RANGER) then
    case Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current of
      17: Inc(total);
      18: Inc(total, 2);
      19, 20: Inc(total, 3);
      21..23: Inc(total, 4);
      24, 25: Inc(total, 5)
    end;
  ClassConHpBonus := total
end;

procedure AdjustLevelHitPoints(cr: Pointer; a, b, c: Byte);
var
  spent: Byte;
  roll2: Byte;
  slotTotal: Byte;
  diceCount: Byte;
  weightedTotal: Byte;
  lvl: ShortInt;
  pointsCost: Byte;
  reserve: Byte;
begin
  slotTotal := 0;
  weightedTotal := 0;
  for lvl := 0 to 6 do
    if Types.PCharacter(cr)^.classLevels[lvl] > 0 then
      if (GDConsts.classBits[lvl] and a) > 0 then
        if Types.PCharacter(cr)^.classLevels[lvl] < GDConsts.hitDiceLevelCap[lvl] then begin
          if Types.PCharacter(cr)^.classLevels[lvl] > 1 then
            diceCount := 1
          else
            diceCount := GDConsts.firstLevelHitDice[lvl];
          spent := FxEngine.RollDice(diceCount, GDConsts.classHitDie[lvl]);
          roll2 := FxEngine.RollDice(diceCount, GDConsts.classHitDie[lvl]);
          if roll2 > spent then
            spent := roll2;
          Inc(slotTotal, spent);
          Inc(weightedTotal, ViewChar.ClassConHpBonus(cr, lvl) * diceCount)
        end else
          case lvl of
            C_Class.FIGHTER, C_Class.PALADIN: slotTotal := 3;
            C_Class.RANGER, C_Class.CLERIC, C_Class.THIEF: slotTotal := 2;
            C_Class.MAGE: slotTotal := 1
          end;
  with Types.PCharacter(cr)^ do begin
    if b > 0 then begin
      slotTotal := slotTotal div b;
      if slotTotal < 1 then
        slotTotal := 1;
      weightedTotal := weightedTotal div b;
      spent := hpMax - hpCur;
      if c <> 0 then begin
        Inc(hpRolled, slotTotal);
        Inc(hpMax, slotTotal + weightedTotal);
        if spent > hpMax then
          hpCur := 0
        else
          hpCur := hpMax - spent
      end else begin
        if hpRolled > slotTotal then
          Dec(hpRolled, slotTotal)
        else
          hpRolled := 0;
        pointsCost := slotTotal + weightedTotal;
        reserve := ViewChar.HitPointCap(cr);
        if (hpMax - pointsCost) > reserve then
          pointsCost := hpMax - reserve;
        if pointsCost > hpMax then
          hpMax := 0
        else
          Dec(hpMax, pointsCost);
        if spent > hpMax then
          hpCur := 0
        else
          hpCur := hpMax - spent
      end
    end else begin
      hpCur := 0;
      hpRolled := 0;
      hpMax := 0
    end
  end
end;

function HitPointCap(cr: Pointer): Byte;
var
  levelCount: Byte;
  total: Word;
  levelValue: ShortInt;
  lvl: ShortInt;
  adjLevel: Byte;
  termB: Byte;
  termA: Byte;
  flag: Boolean;
begin
  with Types.PCharacter(cr)^ do begin
    levelCount := 0;
    total := 0;
    for lvl := 0 to 6 do
      if ((classLevels[lvl] > 0) and (classLevels[lvl] > dualLevel))
         or (oldLevels[lvl] > 0) then begin
        levelValue := CharHlp.ClassConAdj(cr, lvl);
        if oldLevels[lvl] > 0 then begin
          adjLevel := oldLevels[lvl];
          flag := True
        end else begin
          Inc(levelCount);
          adjLevel := classLevels[lvl];
          flag := (dualLevel = 0)
        end;
        if GDConsts.hitDiceLevelCap[lvl] > adjLevel then begin
          if (not flag) and (adjLevel > dualLevel) then begin
            adjLevel := adjLevel - dualLevel;
            flag := True
          end else
            if lvl = C_Class.RANGER then Inc(adjLevel);
          if flag then
            Inc(total, (GDConsts.classHitDie[lvl] + levelValue) * adjLevel)
        end else begin
          if (not flag) and (adjLevel > dualLevel) then begin
            flag := True;
            if dualLevel >= GDConsts.hitDiceLevelCap[lvl] - 1 then begin
              termA := adjLevel - dualLevel;
              termB := 0
            end else begin
              termB := (GDConsts.hitDiceLevelCap[lvl] - dualLevel - 1) * (GDConsts.classHitDie[lvl] + levelValue);
              termA := adjLevel - GDConsts.hitDiceLevelCap[lvl] + 1
            end
          end else begin
            termA := adjLevel - GDConsts.hitDiceLevelCap[lvl] + 1;
            termB := (GDConsts.hitDiceLevelCap[lvl] - 1) * (GDConsts.classHitDie[lvl] + levelValue)
          end;
          if lvl = C_Class.RANGER then
            Inc(termB, GDConsts.classHitDie[lvl] + levelValue);
          if flag then
            case lvl of
              C_Class.CLERIC, C_Class.RANGER, C_Class.THIEF: Inc(total, termB + termA * 2);
              C_Class.FIGHTER, C_Class.PALADIN: Inc(total, termB + termA * 3);
              C_Class.MAGE: Inc(total, termB + termA)
            end
        end
      end;
    if levelCount > 0 then
      total := total div levelCount
    else if dualLevel = 0 then
      total := 0;
    HitPointCap := Byte(total)
  end
end;

function MinWord(a, b: Word): Word;
begin
  MinWord := a;
  if b < a then
    MinWord := b
end;

begin
end.
