{ Camp -- camp and noncombat spell workflow.

  It holds the spell workflows, the magic/display/rest menus, party-order movement, alter/level/speed menus, wound
  counting, the nested camp-fix workflow, the LUCK.DAX reader, and the final camp dispatcher. }
{$O+,F+,S+,A+,R-,V-,B-,I-}
unit Camp;

interface

{ Run the camp menu: Save (saving to the vault, then offering to quit), View, Magic, Rest and Fix (hidden when every
  rest would be interrupted), Alter, Luck (with the crown, until its texts run out) and Exit. The quest crystals found
  are shown first. It ends on Exit, an interrupted rest or a first cast; Escape sets the choice to the Luck item, which
  runs nothing, so the menu is shown again. On leaving it discards pending scribings and restores the interface state.
  @param(interrupted Set when a rest was interrupted.) }
procedure CampMainMenu(var interrupted: Boolean);

{ Cast: if the current character can cast, run the out-of-combat spell list until no spell is picked, recording each
  cast spell in gameState^.lastSpell (the first one, from $FF, sets actionDone), and redraw the interface if the list
  was shown. }
procedure NoncombatCastMenu;

{ Sorts the current character's memorized-spell slots by spell ID, keeping each pending flag with its spell. Empty slots
  sort to the front. }
procedure SortMemorizedSpells;

{ Show the next LUCK.DAX text: block 0 the first time, block 12 when the fallback is set, otherwise the first of blocks
  1..10 whose GBVM flag is not set. Each form feed shows the line so far in the message window and waits for a key. }
procedure ShowNextLuckText;

{ Runs the Fix menu: the party rests while its clerics and magic-users heal everyone. The first rest casts every
  cure-wounds spell the party can memorize, shortened when that is more healing than is needed, then cures conditions
  and hands out the healing. A second rest, timed for the spells the remaining conditions need, cures them as well.
  Either rest can be interrupted. Nothing happens in an anti-magic area or when nobody is hurt. Note: when the first
  rest's time is worked out, a member who cannot cast keeps the previous member's time terms, which are cleared only
  before the loop; and blindness is detected on each member but removed and reported on the current character, without
  using up a cure blindness spell.
  @param(interrupted Receives True when a rest was interrupted.) }
procedure CampFixMenu(var interrupted: Boolean);

{ Shows the current character's free spell slots in the lower window, after clearing it: a line for each of the cleric,
  druid and magic-user lists with any allowance, a column for each level 1..9. A level with no allowance is blank; a
  full level shows zero. Also resets the magic-user bonus slot count to 0.
  @returns(True when the character has any spell allowance, even if every slot is taken.) }
function DisplaySpellSlots: Boolean;

implementation

uses Types, SaveLoad, Romance, CharGen, ViewChar, GameTime, Magic, FxEngine, CharHlp, MenuCore, Portrait, Border,
  TextRend, ZeroFree, DaxIo, GameIo, Crt, GDConsts, GDVars, C_Keys, C_Spell, C_Status,
  C_Effect, C_Stat, C_Class, C_Race, C_Ifc;

const
  ACTIVITY_CAST = 1;
  ACTIVITY_MEMORIZE = 2;
  ACTIVITY_SCRIBE = 3;
  MAX_GAME_DELAY = 9;
  SPELL_CURE_LIGHT_WOUNDS = 3;
  SPELL_HEAL = 36;
  SPELL_CURE_BLINDNESS = 37;
  SPELL_REMOVE_CURSE_CLERIC = 43;
  SPELL_CURE_SERIOUS_WOUNDS = 58;
  SPELL_NEUTRALIZE_POISON = 67;
  SPELL_CURE_CRITICAL_WOUNDS = 71;
  SPELL_RAISE_DEAD = 75;
  SPELL_REMOVE_CURSE_MAGIC_USER = 89;
  SPELL_RESTORATION = 102;
  SPELL_RESURRECTION = 105;
  SPELL_STONE_TO_FLESH = 113;
  VISIBLE_EFFECT_IDS = [1, 2, 4..6, 8..10, 12..17, 19..21, 23..25, 28, 29,
                        32..39, 41, 42, 45, 46, 49, 50, 54..57, 61..63, 68, 69,
                        71, 74, 75, 78, 89, 92, 93, 98, 115, 119, 121..123, 126,
                        159, 160];

var
  spellSlotCallback: function: Boolean absolute GDVars.chooseSpellLevelHook;

{ Finds the rest time a character needs to finish memorizing and scribing: 15 minutes per level of each pending spell,
  plus 4 hours when any spell is pending, or 6 when any is above level 2. Spells being memorized count only while the
  character is in play; scribing counts readable items only. The base hours (0, 4 or 6) are kept in the character's
  record.
  @param(cr The character.)
  @returns(The rest time in minutes.) }
function CampSpellPrepTime(cr: Types.PCharacter): Word;
var
  maxMem: Byte;
  maxScr: Byte;
  cntMem: Byte;
  cntScr: Byte;
  p: Types.PItem;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to SizeOf(cr^.memorized) - 1 do
    if (cr^.memorized[i] > C_Spell.ID_MASK) and (cr^.inPlay <> 0) then begin
      lvl := GDConsts.spellTable[cr^.memorized[i] and C_Spell.ID_MASK].spellLevel;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := cr^.items;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        if p^.spells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellTable[p^.spells[i] and C_Spell.ID_MASK].spellLevel;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then base := 4;
  if (maxMem > 2) or (maxScr > 2) then base := 6;
  cr^.spellPrep := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Removes every pending memorize request of a character, zeroing the slot, and clears its preparation hours.
  @param(cr The character.) }
procedure ResetMemorize(cr: Types.PCharacter);
var
  i: Byte;
begin
  for i := 0 to SizeOf(cr^.memorized) - 1 do
    if cr^.memorized[i] > C_Spell.ID_MASK then cr^.memorized[i] := 0;
  cr^.spellPrep := 0;
end;

{ Clears the pending flag of every scroll spell on a character's readable items.
  @param(cr The character.) }
procedure ResetScribe(cr: Types.PCharacter);
var
  i: Byte;
  p: Types.PItem;
begin
  p := cr^.items;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        p^.spells[i] := p^.spells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Clears every member's scribing marks. }
procedure ResetPartySpellActivities;
var
  character: Types.PCharacter;
begin
  character := GDVars.partyHead;
  while character <> nil do begin
    Camp.ResetScribe(character);
    character := character^.next;
  end;
end;

{ Finds the current character's free slots for spells of one class and level: its allowance less the spells of that
  class and level memorized or pending, never below 0.
  @param(spellLevel The spell level.)
  @param(spellClass The spell list: cleric, druid or magic-user.)
  @param(usedSlots Receives how many spells of that class and level are memorized or pending.)
  @returns(The free slots.) }
function SpellSlotsRemaining(spellLevel: Byte; spellClass: ShortInt; var usedSlots: Byte): Byte;
var
  n: Byte;
  i: Byte;
begin
  with GDVars.curChar^ do begin
    n := 0;
    for i := 0 to SizeOf(memorized) - 1 do
      if memorized[i] > 0 then
        if (GDConsts.spellTable[memorized[i] and C_Spell.ID_MASK].spellLevel = Byte(spellLevel)) and
            (GDConsts.spellTable[memorized[i] and C_Spell.ID_MASK].spellBand = Byte(spellClass)) then
          Inc(n);
    usedSlots := n;
    if spellSlots[spellClass, spellLevel] < n then n := spellSlots[spellClass, spellLevel];
    SpellSlotsRemaining := spellSlots[spellClass, spellLevel] - n;
  end;
end;

{ Checks whether the current character can cast, memorize or scribe. The area's anti-magic flag blocks casting; animated
  or disabled characters can do none of them. On failure, prints the character's name and the reason.
  @param(activity The activity: cast, memorize or scribe.)
  @returns(True when the character can do it.) }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  message: String[40];
begin
  message := '';
  if (activity = Camp.ACTIVITY_CAST) and (GDVars.gameState^.antiMagic > 0) then
    message := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.inPlay = 0) then begin
    message := 'is in no condition to ';
    case activity of
      Camp.ACTIVITY_CAST: message := message + 'cast any spells';
      Camp.ACTIVITY_MEMORIZE: message := message + 'memorize spells';
      Camp.ACTIVITY_SCRIBE: message := message + 'scribe any scrolls';
    end;
  end;
  if message = '' then CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharHlp.PrintCreatureMessage(GDVars.curChar, message, 10, Byte(True));
  end;
end;

procedure NoncombatCastMenu;
var
  menuIndex: Integer;
  notEmpty: Boolean;
  needsRedraw: Boolean;
  castSelected: Boolean;
  spellId: Byte;
begin
  needsRedraw := False;
  menuIndex := -1;
  GDVars.horizChoice := 1;
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, menuIndex, notEmpty);
      if spellId <> 0 then begin
        needsRedraw := True;
        Border.EraseBox(1, 17, 38, 22);
        Magic.CastSpell(spellId, 0, 1, castSelected);
        if GDVars.gameState^.lastSpell = $FF then GDConsts.actionDone := 1;
        GDVars.gameState^.lastSpell := spellId;
      end else begin
        if notEmpty then needsRedraw := True
        else CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no spells memorized', 10, Byte(True));
      end;
    until spellId = 0;
  end;
  if needsRedraw then CharHlp.DisplayNoncombatInterface;
end;

function DisplaySpellSlots: Boolean;
var
  s: String[40];
  slotStr: array[1..9, 0..2] of String[2];
  canDo: array[0..2] of Byte;
  typ: ShortInt;
  lvl: Byte;
  col: Byte;
  row: Byte;
  any: Boolean;
  usedSlotsRaw: Word;
  usedSlots: Byte absolute usedSlotsRaw;
begin
  GDVars.magicBonusSlots := 0;
  any := False;
  for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do begin
    canDo[typ] := 0;
    for lvl := 1 to 9 do begin
      slotStr[lvl, typ] := TextRend.ByteToString(Camp.SpellSlotsRemaining(lvl, typ, usedSlots));
      if GDVars.curChar^.spellSlots[typ, lvl] = 0 then slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True
      end;
    end;
  end;
  if any then begin
    Border.EraseBox(1, 17, 38, 22);
    row := 1;
    for typ := C_Spell.CLERIC_LIST to C_Spell.MAGIC_USER_LIST do
      if canDo[typ] <> 0 then begin
        case typ of
          C_Spell.CLERIC_LIST: s := '    Cleric :';
          C_Spell.DRUID_LIST: s := '     Druid :';
          C_Spell.MAGIC_USER_LIST: s := 'Magic-User :';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, Black, s);
        col := 13;
        for lvl := 1 to 9 do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, Black, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
  end;
  DisplaySpellSlots := any;
end;

{ Rests the party for the longest spell preparation time among its members, then clears the rest clock.
  @param(interrupted Set when the rest is interrupted.) }
procedure RestForSpellPrep(var interrupted: Boolean);
var
  character: Types.PCharacter;
  maxPrepMinutes: Word;
  prepMinutes: Word;
  { Unused in this version; see the other implementations of this routine. }
  hours: Word;
begin
  maxPrepMinutes := 0;
  character := GDVars.partyHead;
  while character <> nil do begin
    prepMinutes := Camp.CampSpellPrepTime(character);
    if maxPrepMinutes < prepMinutes then maxPrepMinutes := prepMinutes;
    character := character^.next;
  end;
  GDVars.restClock[3] := maxPrepMinutes div 60;
  GDVars.restClock[2] := (maxPrepMinutes - 60 * GDVars.restClock[3]) div 10;
  GDVars.restClock[1] := maxPrepMinutes mod 10;
  interrupted := GameTime.CampRest(True);
  GameIo.ZeroFill(GDVars.restClock, SizeOf(GDVars.restClock));
  CharHlp.PrintPositionAndTime;
end;

procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  swappedSpell: Byte;
begin
  for i := 0 to SizeOf(GDVars.curChar^.memorized) - 2 do
    for j := i to SizeOf(GDVars.curChar^.memorized) - 1 do
      if (GDVars.curChar^.memorized[i] and C_Spell.ID_MASK) >
          (GDVars.curChar^.memorized[j] and C_Spell.ID_MASK) then begin
        swappedSpell := GDVars.curChar^.memorized[i];
        GDVars.curChar^.memorized[i] := GDVars.curChar^.memorized[j];
        GDVars.curChar^.memorized[j] := swappedSpell;
      end;
end;

{ Runs the Memorize menu. When spells are pending they are shown first; picking one keeps them and ends the menu, while
  leaving the list discards them. Then each spell picked from the spellbook is marked pending while a slot of its level
  and class is free (or, for a magic-user spell, a bonus slot), and the pending list is shown again if the spellbook was
  shown. When the character may not memorize but is in play, 'cannot memorize any spells' is printed as well. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
  used: Byte;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_MEMORIZE) then begin
    done := False;
    idx := -1;
    GDVars.horizChoice := 1;
    spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if spellId = 0 then Camp.ResetMemorize(GDVars.curChar)
      else done := True;
    end else redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot memorize any spells', 10, Byte(True))
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = 0 then done := True
        else if (Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].spellLevel,
                                          ShortInt(GDConsts.spellTable[spellId].spellBand), used) > 0) or
          ((GDConsts.spellTable[spellId].spellBand = C_Spell.MAGIC_USER_LIST) and
           (GDVars.magicBonusSlots > 0))
        then begin
          GDVars.memorizeRedraw := 0;
          i := 0;
          while GDVars.curChar^.memorized[i] <> 0 do Inc(i);
          GDVars.curChar^.memorized[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
      if notEmpty then
        if spellId = 0 then Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then CharHlp.DisplayNoncombatInterface;
  end else if GDVars.curChar^.inPlay <> 0 then
    CharHlp.PrintCreatureMessage(GDVars.curChar, 'cannot memorize any spells', 10, Byte(True));
end;

{ Scribe: if scribings are pending, ask whether to keep them, which ends the menu, or discard them. Then mark each spell
  picked from the character's scrolls as pending on its scroll (the remembered scribe candidate first), unless the
  character knows it, is scribing it already or has no slot of its level and class, and ask again if the scrolls were
  shown. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellClass: Byte;
  i: Byte;
  idx: Integer;
  p: Types.PItem;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(Camp.ACTIVITY_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu(GDConsts.scribeQuery, GDConsts.yesChoice) = GDConsts.noChoice then
        Camp.ResetScribe(GDVars.curChar)
      else done := True;
    end else redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = 0 then begin
        done := True;
        if notEmpty = False then
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'has no copyable scrolls', 10, Byte(True))
        else redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.knownSpells[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.items;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scribing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GDVars.curChar^.spellSlots[ShortInt(GDConsts.spellTable[spellId].spellBand),
                                            GDConsts.spellTable[spellId].spellLevel] > 0 then begin
              if (GDVars.selectedItem <> nil) and (GDVars.scribeSpellIndex <> 0) and
                  Magic.ItemReadable(GDVars.selectedItem) then
                if GDVars.selectedItem^.
                     spells[GDVars.scribeSpellIndex] = spellId then begin
                  GDVars.selectedItem^.
                    spells[GDVars.scribeSpellIndex] := GDVars.selectedItem^.spells[GDVars.scribeSpellIndex] or
                      C_Spell.PENDING_FLAG;
                  found := True;
                end;
              p := GDVars.curChar^.items;
              while (p <> nil) and (found = False) do begin
                if Magic.ItemReadable(p) then begin
                  i := 1;
                  repeat
                    if p^.spells[i] = spellId then begin
                      p^.spells[i] := p^.spells[i] or C_Spell.PENDING_FLAG;
                      found := True;
                    end;
                    Inc(i);
                  until (i > SizeOf(p^.spells)) or found;
                end;
                p := p^.next;
              end;
            end else CharHlp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu(GDConsts.scribeQuery, GDConsts.yesChoice) = GDConsts.noChoice then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then CharHlp.DisplayNoncombatInterface;
  end;
end;

{ Lists each party member's visible spell effects by name, or ' <No Spell Effects>', in a vertical menu. }
procedure CampDisplayMenu;
var
  effect: Types.PEffect;
  listHead: Types.PItemRec;
  listTail: Types.PItemRec;
  character: Types.PCharacter;
  effectId: Byte;
  { Unused in this version; see the other implementations of this routine. }
  spellIndex: Byte;
  effectCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  isHeading: Byte;
  { Unused in this version; see the other implementations of this routine. }
  effectNameFound: Boolean;
  displayEffect: Boolean;
  viewNeedsRedraw: Boolean;
  effectName: String[40];
  menuIndex: Integer;
  { Unused in this version; see the other implementations of this routine. }
  choice: Char;

  { Appends a line to the list, as a title or an entry. }
  procedure AddToList(isTitle: Boolean; displayText: Types.TStr40);
  begin
    GetMem(listTail^.next, SizeOf(Types.TItemRec));
    listTail := listTail^.next;
    listTail^.next := nil;
    listTail^.name := displayText;
    listTail^.inUse := Ord(isTitle);
  end;

begin
  GetMem(listHead, SizeOf(Types.TItemRec));
  listTail := listHead;
  listTail^.inUse := Ord(True);
  listTail^.name := ' ';
  listTail^.next := nil;
  character := GDVars.partyHead;
  while character <> nil do begin
    effectCount := 0;
    AddToList(True, character^.name);
    effect := Types.PEffect(character^.effects);
    while effect <> nil do begin
      displayEffect := True;
      effectId := effect^.id;
      if effectId in Camp.VISIBLE_EFFECT_IDS then effectName := GDVars.effectNames^[effectId]
      else displayEffect := False;
      if displayEffect then begin
        Inc(effectCount);
        AddToList(False, ' ' + effectName);
      end;
      effect := effect^.next;
    end;
    if effectCount = 0 then AddToList(False, ' <No Spell Effects>');
    AddToList(True, ' ');
    character := character^.next;
  end;
  viewNeedsRedraw := True;
  menuIndex := 0;
  Border.DrawWindowFrame(0);
  MenuCore.ResetMenuSlots(0);
  choice := MenuCore.MenuVertical(GDConsts.emptyQuery, GDConsts.blankMenuText, 1, 4, 38, 22, listHead, True, 255,
                                  viewNeedsRedraw, menuIndex, Pointer(listTail));
  MenuCore.FreeStringList(Pointer(listHead));
  CharHlp.DisplayNoncombatInterface;
end;

{ Magic: Cast, Memorize, Scribe, Display, Rest and Exit, Rest hidden when every rest would be interrupted. The menu ends
  on Exit, Escape, an interrupted rest or a first cast (actionDone).
  @param(interrupted Set when a rest was interrupted.) }
procedure CampMagicMenu(var interrupted: Boolean);
var
  i: Byte;
  active: Byte;
  c: Char;
  savedChoice: Byte;
begin
  c := #255;
  savedChoice := 1;
  while (GDConsts.actionDone = 0) and (interrupted = False) and (c <> #5) and
      ((GDVars.menuReturnedKey = False) or (c <> C_Keys.ESCAPE)) do begin
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
    active := 0;
    for i := 0 to 5 do
      if (i <> 4) or (GDVars.gameState^.interruptPct < 100) or (GDVars.gameState^.restPeriod <> 1) then
        MenuCore.AppendSlot(i, active);
    GDVars.horizChoice := savedChoice;
    c := MenuCore.MenuHorizontal('', GDConsts.campMagicMenuItems, 1, 1);
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then begin
      CharHlp.PrintMiscInfo(GDVars.curChar, 0);
      ViewChar.SelectPrevNextChar(c);
      CharHlp.PrintMiscInfo(GDVars.curChar, 1);
    end else
      case Ord(c) of
        0: Camp.NoncombatCastMenu;
        1: Camp.CampMemorizeMenu;
        2: Camp.CampScribeMenu;
        3: Camp.CampDisplayMenu;
        4: Camp.RestForSpellPrep(interrupted);
      end;
  end;
end;

{ Moves the current character one place earlier in the party; the first character moves to the end. }
procedure OrderMoveUp;
var
  prev: Types.PCharacter;
  p: Types.PCharacter;
  savedNext: Types.PCharacter;
begin
  p := GDVars.partyHead;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.next <> nil do p := p^.next;
  end else
    while p^.next <> GDVars.curChar do begin
      prev := p;
      p := p^.next;
    end;
  savedNext := GDVars.curChar^.next;
  if GDVars.partyHead = GDVars.curChar then begin
    if savedNext <> nil then GDVars.partyHead := savedNext;
    p^.next := GDVars.curChar;
    GDVars.curChar^.next := nil;
  end else begin
    p^.next := savedNext;
    GDVars.curChar^.next := p;
    if (p = GDVars.partyHead) or (prev = nil) then
      GDVars.partyHead := GDVars.curChar
    else
      prev^.next := GDVars.curChar;
  end;
end;

{ Moves the current character one place later in the party; the last character moves to the front. }
procedure OrderMoveDown;
var
  predecessor: Types.PCharacter;
  successor: Types.PCharacter;
begin
  predecessor := GDVars.partyHead;
  if predecessor <> GDVars.curChar then
    while predecessor^.next <> GDVars.curChar do predecessor := predecessor^.next;
  successor := GDVars.curChar^.next;
  if successor = nil then begin
    GDVars.curChar^.next := GDVars.partyHead;
    GDVars.partyHead := GDVars.curChar;
    predecessor^.next := successor;
  end else begin
    GDVars.curChar^.next := successor^.next;
    if GDVars.partyHead = GDVars.curChar then GDVars.partyHead := successor;
    if predecessor <> GDVars.curChar then predecessor^.next := successor;
    successor^.next := GDVars.curChar;
  end;
end;

{ Runs the party-order menu: in Select mode extended keys change the current character; choosing Select picks it
  (announcing it) and switches to Place mode, where the up and down arrows move it up or down the order, and choosing
  Place switches back. Ends on Exit or Escape. }
procedure PartyOrderMenu;
var
  selected: Byte;
  key: Byte;
  choice: Char;
  savedChoice: Byte;
begin
  selected := 0;
  choice := #255;
  savedChoice := 1;
  while (choice <> #2) and ((GDVars.menuReturnedKey = False) or (choice <> C_Keys.ESCAPE)) do begin
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
    if selected <> 0 then
      GDVars.menuSlots[0].optionId := 1
    else
      GDVars.menuSlots[0].optionId := 0;
    GDVars.menuSlots[1].optionId := 2;
    GDVars.horizChoice := savedChoice;
    choice := MenuCore.MenuHorizontal(GDConsts.orderQuery, GDConsts.selectPlaceMenu, 1, 1);
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then begin
      if selected = 0 then begin
        CharHlp.PrintMiscInfo(GDVars.curChar, 0);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.PrintMiscInfo(GDVars.curChar, 1);
      end else begin
        key := Ord(choice);
        case key of
          Ord(C_Keys.UP): Camp.OrderMoveUp;
          Ord(C_Keys.DOWN): Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else if (Ord(choice) < 2) or (GDVars.menuReturnedKey and (choice = C_Keys.ESCAPE)) then begin
      selected := Ord(selected = 0);
      if selected <> 0 then
        CharHlp.PrintCreatureMessage(GDVars.curChar, GDConsts.hasBeenSelectedMsg, 10, 0)
      else
        CharHlp.ClearMessageWindow;
    end;
  end;
  GDVars.selectionMode := 0;
end;

{ Shows the level menu with the current difficulty preselected and stores the level picked as 1..5; extended keys change
  the current character instead. }
procedure CampDifficultyMenu;
var
  choice: Char;
  difficulty: Byte;
begin
  difficulty := GDVars.gameState^.gameLevel;
  GDVars.menuCursorIndex := 255;
  GDVars.horizChoice := difficulty;
  MenuCore.ResetMenuSlots(4);
  choice := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.classTitles, 0, 1);
  if GDVars.menuReturnedKey then begin
    CharHlp.PrintMiscInfo(GDVars.curChar, 0);
    ViewChar.SelectPrevNextChar(choice);
    CharHlp.PrintMiscInfo(GDVars.curChar, 1);
  end else if Ord(choice) < 5 then
    difficulty := Ord(choice) + 1;
  GDVars.gameState^.gameLevel := difficulty;
end;

{ Runs the speed menu: shows the game delay, 0 fastest to 9 slowest, and steps it with Faster, Slower or the arrow keys;
  Escape or Exit ends it. }
procedure CampSpeedMenu;
var
  slotCount: Byte;
  choice: Char;
  savedChoice: Byte;
begin
  savedChoice := 1;
  repeat
    TextRend.DisplayStringClear(1, 18, LightGreen, Black,
                                GDConsts.gameSpeedPrompt + TextRend.ByteToString(GDVars.gameState^.gameDelay));
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
    slotCount := 0;
    if GDVars.gameState^.gameDelay > 0 then
      MenuCore.AppendSlot(0, slotCount);
    if GDVars.gameState^.gameDelay < Camp.MAX_GAME_DELAY then
      MenuCore.AppendSlot(1, slotCount);
    MenuCore.AppendSlot(2, slotCount);
    GDVars.horizChoice := savedChoice;
    choice := MenuCore.MenuHorizontal(GDConsts.speedQuery, GDConsts.speedMenuItems, 1, 1);
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then
      case Ord(choice) of
        Ord(C_Keys.DOWN):
          if GDVars.gameState^.gameDelay > 0 then Dec(GDVars.gameState^.gameDelay);
        Ord(C_Keys.UP):
          if GDVars.gameState^.gameDelay < Camp.MAX_GAME_DELAY then Inc(GDVars.gameState^.gameDelay);
        Ord(C_Keys.ESCAPE): choice := #2;
      end else
      case Ord(choice) of
        0: Dec(GDVars.gameState^.gameDelay);
        1: Inc(GDVars.gameState^.gameDelay);
      end;
  until choice = #2;
  CharHlp.ClearMessageWindow;
end;

{ Alter: Order, Drop (only with more than one member), Speed, Icon (not for an NPC), Level and Exit. }
procedure CampAlterMenu;
var
  choice: Char;
  { Unused in this version; see the other implementations of this routine. }
  toggleChoice: Char;
  savedChoice: Byte;
begin
  choice := #255;
  savedChoice := 1;
  GDVars.horizChoice := 1;
  while choice <> #5 do begin
    Border.EraseBox(1, 17, 38, 22);
    MenuCore.ResetMenuSlots(5);
    choice := MenuCore.MenuHorizontal('', GDConsts.campAlterMenuItems, 1, 1);
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then begin
      if choice = C_Keys.ESCAPE then
        choice := #5
      else begin
        CharHlp.PrintMiscInfo(GDVars.curChar, 0);
        ViewChar.SelectPrevNextChar(choice);
        CharHlp.PrintMiscInfo(GDVars.curChar, 1);
      end;
    end else begin
      case Ord(choice) of
        0: Camp.PartyOrderMenu;
        1:
          if GDVars.gameState^.partySize > 1 then CharGen.DropCharacterMenu;
        2: Camp.CampSpeedMenu;
        3:
          if GDVars.curChar^.npc in [0..127] then begin
            CharGen.CustomizePortrait;
            CharHlp.DisplayNoncombatInterface;
          end else
            CharHlp.PrintCreatureMessage(GDVars.curChar, 'is an NPC', 10, 1);
        4: Camp.CampDifficultyMenu;
      end;
      GDVars.horizChoice := savedChoice;
    end;
  end;
end;

{ Counts the levels a character has lost to drain, summed over the classes.
  @param(character The character.)
  @returns(The levels lost.) }
function LevelsDrained(character: Pointer): Byte;
var
  total: Byte;
  i: ShortInt;
begin
  total := 0;
  with Types.PCharacter(character)^ do
    for i := 0 to 6 do
      if classLevels[i] < classLevelCap[i] then
        Inc(total, classLevelCap[i] - classLevels[i]);
  LevelsDrained := total;
end;

procedure CampFixMenu(var interrupted: Boolean);
var
  healPool: Word;
  cureLightSlots: Word;
  cureSeriousSlots: Word;
  cureCriticalSlots: Word;
  healSlots: Word;
  { Unused in this version; see the other implementations of this routine. }
  menuChoice: Byte;
  resurrectionCount: Word;
  raiseDeadCount: Word;
  deadCount: Word;
  removeCurseCount: Word;
  cursedCount: Word;
  cureBlindnessCount: Word;
  blindCount: Word;
  healCount: Word;
  feeblemindedCount: Word;
  neutralizePoisonCount: Word;
  poisonedCount: Word;
  stoneToFleshCount: Word;
  petrifiedCount: Word;
  restorationCount: Word;
  drainedLevelCount: Word;
  savedRestTime: Types.TClock;

  { True when character is in okay condition. }
  function CanCast(character: Types.PCharacter): Boolean;
  begin
    CanCast := character^.status = C_Status.OKAY;
  end;

  { Adds up the healing the conscious members can prepare into healPool, and counts their curing spells by slots. }
  procedure AccumResources;
  var
    total: Word;
    { Unused in this version; see the other implementations of this routine. }
    spellIndex: Byte;
    ch: Types.PCharacter;
  begin
    total := 0;
    ch := GDVars.partyHead;
    while ch <> nil do begin
      if CanCast(Types.PCharacter(ch)) then
        with ch^ do begin
          if knownSpells[Camp.SPELL_CURE_LIGHT_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 1] * 9);
          if knownSpells[Camp.SPELL_CURE_SERIOUS_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 4] * 17);
          if knownSpells[Camp.SPELL_CURE_CRITICAL_WOUNDS] <> 0 then
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 5] * 27);
          if knownSpells[Camp.SPELL_HEAL] <> 0 then begin
            Inc(total, spellSlots[C_Spell.CLERIC_LIST, 6] * 50);
            Inc(healCount, spellSlots[C_Spell.CLERIC_LIST, 6])
          end;
          if knownSpells[Camp.SPELL_NEUTRALIZE_POISON] <> 0 then
            Inc(neutralizePoisonCount, spellSlots[C_Spell.CLERIC_LIST, 4]);
          if knownSpells[Camp.SPELL_RAISE_DEAD] <> 0 then
            Inc(raiseDeadCount, spellSlots[C_Spell.CLERIC_LIST, 5]);
          if knownSpells[Camp.SPELL_REMOVE_CURSE_CLERIC] <> 0 then
            Inc(removeCurseCount, spellSlots[C_Spell.CLERIC_LIST, 3]);
          if knownSpells[Camp.SPELL_REMOVE_CURSE_MAGIC_USER] <> 0 then
            Inc(removeCurseCount, spellSlots[C_Spell.MAGIC_USER_LIST, 3]);
          if knownSpells[Camp.SPELL_STONE_TO_FLESH] <> 0 then
            Inc(stoneToFleshCount, spellSlots[C_Spell.MAGIC_USER_LIST, 6]);
          if knownSpells[Camp.SPELL_CURE_BLINDNESS] <> 0 then
            Inc(cureBlindnessCount, spellSlots[C_Spell.CLERIC_LIST, 3]);
          if knownSpells[Camp.SPELL_RESURRECTION] <> 0 then
            Inc(resurrectionCount, spellSlots[C_Spell.CLERIC_LIST, 6]);
        end;
      ch := ch^.next;
    end;
    Inc(healPool, total);
  end;

  { Adds a cure roll for each counted cure slot to the healing pool. }
  procedure RollCureSlots;
  var
    rolledHealing: Word;
    rollIndex: Byte;
  begin
    rolledHealing := 0;
    for rollIndex := 1 to cureLightSlots do
      Inc(rolledHealing, FxEngine.RollDice(1, 8));
    for rollIndex := 1 to cureSeriousSlots do
      Inc(rolledHealing, FxEngine.RollDice(2, 8) + 1);
    for rollIndex := 1 to cureCriticalSlots do
      Inc(rolledHealing, FxEngine.RollDice(3, 8) + 3);
    for rollIndex := 1 to healSlots do
      Inc(rolledHealing, FxEngine.RollDice(4, 8) + 3);
    Inc(healPool, rolledHealing);
  end;

  { Returns the party's total missing hit points. }
  function PartyHitPointsMissing: Word;
  var
    totalDamage: Word;
    character: Types.PCharacter;
  begin
    totalDamage := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      Inc(totalDamage, character^.hpMax - character^.hpCur);
      character := character^.next;
    end;
    PartyHitPointsMissing := totalDamage;
  end;

  { Sets the first rest's duration and the cure dice of each kind, scaled down to the party's total wounds. }
  procedure ComputeFixTime;
  var
    ch: Types.PCharacter;
    maxTime: Word;
    cureLightTime: Word;
    druidCureLightTime: Word;
    cureSeriousTime: Word;
    cureCriticalTime: Word;
    healTime: Word;
    charTime: Word;
    resourceCount: Word;
    ratio: Word;
  begin
    ch := GDVars.partyHead;
    cureLightTime := 0;
    druidCureLightTime := 0;
    cureSeriousTime := 0;
    cureCriticalTime := 0;
    healTime := 0;
    cureLightSlots := 0;
    cureSeriousSlots := 0;
    cureCriticalSlots := 0;
    healSlots := 0;
    maxTime := 0;
    while ch <> nil do begin
      charTime := 0;
      if CanCast(Types.PCharacter(ch)) and (ch^.stats[C_Stat.WISDOM].current > 3) then begin
        resourceCount := ch^.spellSlots[C_Spell.CLERIC_LIST, 1];
        Inc(cureLightSlots, resourceCount);
        cureLightTime := resourceCount * 15;
        resourceCount := ch^.spellSlots[C_Spell.DRUID_LIST, 2];
        Inc(cureLightSlots, resourceCount);
        druidCureLightTime := resourceCount * 30;
        Inc(cureSeriousSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        cureSeriousTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 4] * 60;
        Inc(cureCriticalSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        cureCriticalTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 5] * 75;
        Inc(healSlots, ch^.spellSlots[C_Spell.CLERIC_LIST, 6]);
        healTime := ch^.spellSlots[C_Spell.CLERIC_LIST, 6] * 90;
      end;
      Inc(charTime, cureLightTime + druidCureLightTime + cureSeriousTime + cureCriticalTime + healTime);
      if maxTime < charTime then maxTime := charTime;
      ch := ch^.next;
    end;
    if PartyHitPointsMissing < healPool then begin
      ratio := healPool div PartyHitPointsMissing;
      maxTime := maxTime div ratio;
    end;
    GameIo.ZeroFill(GDVars.restClock, SizeOf(GDVars.restClock));
    GDVars.restClock[3] := maxTime div 60;
    GDVars.restClock[2] := (maxTime - 60 * GDVars.restClock[3]) div 10;
    GDVars.restClock[1] := maxTime mod 10;
  end;

  { Count the curing spells by slot and set the second rest's duration for as many of each as there are targets. }
  procedure ComputeCureTime;
  var
    character: Types.PCharacter;
    cureMinutes: Word;
    { Unused in this version; see the other implementations of this routine. }
    hours: Byte;
  begin
    character := GDVars.partyHead;
    while character <> nil do begin
      if CanCast(Types.PCharacter(character)) then begin
        Inc(restorationCount, character^.spellSlots[C_Spell.CLERIC_LIST, 7]);
        Inc(resurrectionCount, character^.spellSlots[C_Spell.CLERIC_LIST, 7]);
        Inc(healCount, character^.spellSlots[C_Spell.CLERIC_LIST, 6]);
        Inc(stoneToFleshCount, character^.spellSlots[C_Spell.MAGIC_USER_LIST, 6]);
        Inc(raiseDeadCount, character^.spellSlots[C_Spell.CLERIC_LIST, 5]);
        Inc(neutralizePoisonCount, character^.spellSlots[C_Spell.CLERIC_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.MAGIC_USER_LIST, 4]);
        Inc(removeCurseCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
        Inc(cureBlindnessCount, character^.spellSlots[C_Spell.CLERIC_LIST, 3]);
      end;
      character := character^.next;
    end;
    cureMinutes := 0;
    cureMinutes := cureMinutes + ViewChar.MinWord(restorationCount, drainedLevelCount) * 105;
    cureMinutes := cureMinutes + ViewChar.MinWord(resurrectionCount, deadCount) * 105;
    cureMinutes := cureMinutes + ViewChar.MinWord(healCount, feeblemindedCount) * 90;
    cureMinutes := cureMinutes + ViewChar.MinWord(stoneToFleshCount, petrifiedCount) * 90;
    if resurrectionCount = 0 then begin
      cureMinutes := cureMinutes + ViewChar.MinWord(raiseDeadCount, deadCount) * 75;
      raiseDeadCount := 0;
    end;
    cureMinutes := cureMinutes + ViewChar.MinWord(neutralizePoisonCount, poisonedCount) * 60;
    cureMinutes := cureMinutes + ViewChar.MinWord(cureBlindnessCount, blindCount) * 45;
    cureMinutes := cureMinutes + ViewChar.MinWord(removeCurseCount, cursedCount) * 45;
    GameIo.ZeroFill(GDVars.restClock, SizeOf(GDVars.restClock));
    GDVars.restClock[3] := cureMinutes div 60;
    GDVars.restClock[2] := (cureMinutes - 60 * GDVars.restClock[3]) div 10;
    GDVars.restClock[1] := cureMinutes mod 10;
  end;

  { Spends the healing pool on each member in party order, up to that member's missing hit points. }
  procedure HealParty;
  var
    character: Types.PCharacter;
    healingNeeded: Word;
  begin
    character := GDVars.partyHead;
    while character <> nil do begin
      if character^.hpMax > character^.hpCur then begin
        healingNeeded := character^.hpMax - character^.hpCur;
        if healingNeeded > healPool then healingNeeded := healPool;
        if healingNeeded < 1 then healingNeeded := 0;
        if healingNeeded > 0 then
          if FxEngine.RestoreHitPoints(character, Byte(healingNeeded), False) then
            if healingNeeded <= healPool then Dec(healPool, healingNeeded);
      end;
      character := character^.next;
    end;
  end;

  { Spends the counted condition-curing spells on each party member in turn. }
  procedure CureStatusEffects;
  var
    character: Types.PCharacter;
    effect: array[0..3] of Byte;
    { Unused in this version; see the other implementations of this routine. }
    diseaseIndex: Byte;
    wasHealed: Boolean;
    bonusHitPoints: Byte;
    bonusDivisor: Byte;
    classIndex: ShortInt;
  begin
    character := GDVars.partyHead;
    while character <> nil do begin
      wasHealed := False;
      while (Camp.LevelsDrained(character) > 0) and (restorationCount > 0) do begin
        GDVars.spellTargets[1] := character;
        GDVars.opMode := Camp.SPELL_RESTORATION;
        GDVars.spellFns.spells[Camp.SPELL_RESTORATION];
        Dec(restorationCount);
      end;
      if healCount > 0 then
        if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.FEEBLEMIND, Pointer(effect)) then begin
          FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.FEEBLEMIND, nil);
          if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.BLIND, Pointer(effect)) then
            FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.BLIND, nil);
          wasHealed := True;
          CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'is healed', 10, 1);
          Dec(healCount);
          FxEngine.RecalcAbility(Types.PCharacter(character), C_Stat.INTELLIGENCE);
          FxEngine.RecalcAbility(Types.PCharacter(character), C_Stat.WISDOM);
        end;
      if (stoneToFleshCount > 0) and (character^.status = C_Status.PETRIFIED) then begin
        character^.status := C_Status.OKAY;
        character^.inPlay := 1;
        character^.hpCur := 1;
        CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'is changed back to flesh', 10, 1);
        Dec(stoneToFleshCount);
      end;
      if neutralizePoisonCount > 0 then
        if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.POISONED, Pointer(effect)) then begin
          if character^.hpCur = 0 then character^.hpCur := 1;
          GDVars.effectBusy := 1;
          FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.POISONED, nil);
          FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.SLOW_POISON_END, nil);
          FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.SLOW_POISON_HIT, nil);
          GDVars.effectBusy := 0;
          character^.inPlay := 1;
          character^.status := C_Status.OKAY;
          CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'is detoxified', 10, 1);
          Dec(neutralizePoisonCount);
        end;
      if (resurrectionCount > 0) or (raiseDeadCount > 0) then
        if character^.status = C_Status.DEAD_STATUS then
          if character^.race <> C_Race.ELF then begin
            GDVars.effectBusy := 1;
            FxEngine.RemoveEffect(Types.PCharacter(character), C_Effect.POISONED, nil);
            GDVars.effectBusy := 0;
            character^.hpCur := 1;
            character^.status := C_Status.OKAY;
            character^.inPlay := 1;
            if resurrectionCount > 0 then begin
              raiseDeadCount := 0;
              CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'has been ressurected', 10, 1);
              Dec(resurrectionCount);
            end else begin
              if (character^.stats[C_Stat.CONSTITUTION].current > 0) and (raiseDeadCount > 0) then
                Dec(character^.stats[C_Stat.CONSTITUTION].current);
              if character^.hpMax > character^.hpRolled then
                bonusHitPoints := character^.hpMax - character^.hpRolled
              else
                bonusHitPoints := 0;
              bonusDivisor := 0;
              if character^.stats[C_Stat.CONSTITUTION].current >= 14 then begin
                for classIndex := 0 to 6 do
                  if character^.classLevels[classIndex] > 0 then
                    if (classIndex = C_Class.FIGHTER) or (classIndex = C_Class.PALADIN) or
                        (classIndex = C_Class.RANGER) then
                      Inc(bonusDivisor,
                          (character^.stats[C_Stat.CONSTITUTION].current - 14) * character^.classLevels[classIndex])
                    else if character^.stats[C_Stat.CONSTITUTION].current > 15 then
                      Inc(bonusDivisor, character^.classLevels[classIndex] shl 1)
                    else
                      Inc(bonusDivisor, character^.classLevels[classIndex]);
                if bonusDivisor > 0 then bonusHitPoints := bonusHitPoints div bonusDivisor;
                if (character^.stats[C_Stat.CONSTITUTION].current < 17) or
                    (character^.classLevels[C_Class.FIGHTER] > 0) or (character^.classLevels[C_Class.RANGER] > 0) or
                    (character^.classLevels[C_Class.PALADIN] > 0) then
                  Dec(character^.hpMax, bonusHitPoints);
              end;
              CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'has been raised from the dead', 10, 1);
              Dec(raiseDeadCount);
            end;
          end;
      if removeCurseCount > 0 then
        if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.BESTOW_CURSE, Pointer(effect)) then begin
          GDVars.spellTargets[1] := character;
          Magic.SpellRemoveCurse;
          CharHlp.PrintCreatureMessage(Types.PCharacter(character), 'is relieved of a curse', 10, 1);
          Dec(removeCurseCount);
        end;
      if (not wasHealed) and (cureBlindnessCount > 0) then
        if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.BLIND, Pointer(effect)) then begin
          FxEngine.RemoveEffect(GDVars.curChar, C_Effect.BLIND, nil);
          CharHlp.PrintCreatureMessage(GDVars.curChar, 'regains sight', 10, 1);
        end;
      character := character^.next;
    end;
  end;

  { Count the party members each curing spell has to treat. }
  procedure CountCureNeeds;
  var
    character: Types.PCharacter;
    effect: array[0..3] of Byte;
  begin
    drainedLevelCount := 0;
    deadCount := 0;
    cursedCount := 0;
    blindCount := 0;
    feeblemindedCount := 0;
    poisonedCount := 0;
    petrifiedCount := 0;
    character := GDVars.partyHead;
    while character <> nil do begin
      Inc(drainedLevelCount, Camp.LevelsDrained(character));
      if (character^.status = C_Status.DEAD_STATUS) and (character^.race > C_Race.ELF) then
        Inc(deadCount);
      if character^.status = C_Status.PETRIFIED then Inc(petrifiedCount);
      if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.BESTOW_CURSE, Pointer(effect)) then
        Inc(cursedCount);
      if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.POISONED, Pointer(effect)) then
        Inc(poisonedCount);
      if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.FEEBLEMIND, Pointer(effect)) then
        Inc(feeblemindedCount)
      else if CharHlp.HasEffect(Types.PCharacter(character), C_Effect.BLIND, Pointer(effect)) then
        Inc(blindCount);
      character := character^.next;
    end;
  end;

begin
  if GDVars.gameState^.antiMagic <> 0 then Exit;
  raiseDeadCount := 0;
  removeCurseCount := 0;
  cureBlindnessCount := 0;
  healCount := 0;
  neutralizePoisonCount := 0;
  stoneToFleshCount := 0;
  resurrectionCount := 0;
  restorationCount := 0;
  interrupted := False;
  healPool := 0;
  if PartyHitPointsMissing = 0 then Exit;
  AccumResources;
  savedRestTime := GDVars.restClock;
  ComputeFixTime;
  GDVars.fixBusy := 1;
  interrupted := GameTime.CampRest(False);
  GDVars.fixBusy := 0;
  if interrupted then Exit;
  RollCureSlots;
  CureStatusEffects;
  HealParty;
  CharHlp.DisplayParty(GDVars.curChar);
  CharHlp.PrintPositionAndTime;
  GDVars.restClock := savedRestTime;
  savedRestTime := GDVars.restClock;
  CountCureNeeds;
  ComputeCureTime;
  GDVars.fixBusy := 1;
  interrupted := GameTime.CampRest(False);
  GDVars.fixBusy := 0;
  if not interrupted then begin
    CureStatusEffects;
    CharHlp.DisplayParty(GDVars.curChar);
    CharHlp.PrintPositionAndTime;
    GDVars.restClock := savedRestTime;
  end;
end;

procedure ShowNextLuckText;
var
  i: Word;
  sizeRead: Word;
  data: Types.PByteBuffer;
  fileId: Byte;
  textLine: String;
begin
  if GDVars.gameState^.luckState = 1 then begin
    fileId := 0;
    GDVars.gameState^.luckState := 2;
  end else if GDVars.gameState^.luckFallback = 255 then
    fileId := 12
  else begin
    fileId := 1;
    while (fileId <= 10) and (GDVars.gameState^.gbvm[fileId + 1 + $126 - 1] = 1) do
      fileId := fileId + 1;
  end;
  DaxIo.LoadDaxRetrying('LUCK', '.dax', fileId, sizeRead, data);
  i := 0;
  textLine := '';
  while i < sizeRead do begin
    case data^[i] of
      12: begin
        if textLine <> '' then
          TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, True, textLine);
        MenuCore.WaitContinueClear;
        textLine := '';
      end;
      26, 10, 13: ;
    else
      textLine := textLine + UpCase(Char(data^[i]));
    end;
    Inc(i);
  end;
  if textLine <> '' then
    TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, True, textLine);
  ZeroFree.PrefixFree(data, sizeRead);
  MenuCore.WaitContinueClear;
  Border.EraseBox(1, 17, 38, 22);
end;

{ Luck: show picture 130, then the next luck text, and redraw. }
procedure CampShowLuck;
begin
  Portrait.FreeAnimation;
  Portrait.LoadAnimation('PIC', 130, 0);
  Portrait.DisplayImageBuf(3, 3, True, 0);
  GDVars.palettePending := 1;
  Camp.ShowNextLuckText;
  Border.EraseBox(3, 3, 13, 13);
  Portrait.FreeAnimation;
  CharHlp.DisplayNoncombatInterface;
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedMode: Byte;
  choice: ShortInt;
  viewRedraw: Byte;
  activeSlotCount: Byte;
  savedChoice: Byte;
begin
  savedMode := GDVars.locState.current;
  GDVars.locState.current := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  GameIo.ZeroFill(GDVars.restClock, SizeOf(GDVars.restClock));
  GDVars.resourceSavedName := GDVars.resourceCurrentName;
  GDVars.resourceSavedId := GDVars.resourceCurrentId;
  CharHlp.DisplayNoncombatInterface;
  Romance.UpdateRelationship;
  Border.EraseBox(1, 17, 38, 22);
  if GDVars.gameState^.crystals <> 0 then begin
    TextRend.DisplayString(1, 17, LightGreen, Black, 'The party has acquired the...');
    if (GDVars.gameState^.crystals and 1) <> 0 then
      TextRend.DisplayString(11, 18, White, Black, 'Red crystal');
    if (GDVars.gameState^.crystals and 2) <> 0 then
      TextRend.DisplayString(11, 19, White, Black, 'Green crystal');
    if (GDVars.gameState^.crystals and 4) <> 0 then
      TextRend.DisplayString(11, 20, White, Black, 'Blue crystal');
  end else
    TextRend.DisplayString(1, 18, LightGreen, Black, GDConsts.campIntroText);
  Camp.ResetPartySpellActivities;
  interrupted := False;
  choice := -1;
  savedChoice := 1;
  GDConsts.actionDone := 0;
  while (GDConsts.actionDone = 0) and (interrupted = False) and (choice <> 7) do begin
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
    activeSlotCount := 0;
    for GDVars.scratchIndex := 0 to 7 do begin
      case GDVars.scratchIndex of
        0, 1, 2,
        4, 7:
          MenuCore.AppendSlot(GDVars.scratchIndex, activeSlotCount);
        3, 5:
          if (GDVars.gameState^.interruptPct < 100) or (GDVars.gameState^.restPeriod <> 1) then
            MenuCore.AppendSlot(GDVars.scratchIndex, activeSlotCount);
        6:
          if (GDVars.gameState^.crown <> 0) and (GDVars.gameState^.luckState <> 2) then
            MenuCore.AppendSlot(GDVars.scratchIndex, activeSlotCount);
      end;
    end;
    GDVars.horizChoice := savedChoice;
    if (GDVars.gameState^.crown <> 0) and (GDVars.gameState^.luckState <> 2) then
      choice := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.campMenuWithCrown, 1, 1))
    else
      choice := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.campMenuText, 1, 1));
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then begin
      if choice = Ord(C_Keys.ESCAPE) then
        choice := 6
      else begin
        CharHlp.PrintMiscInfo(GDVars.curChar, 0);
        ViewChar.SelectPrevNextChar(Char(choice));
        CharHlp.PrintMiscInfo(GDVars.curChar, 1);
      end;
    end else begin
      case choice of
        0: begin
          SaveLoad.SaveGame(0, 0);
          if MenuCore.YesNoMenu(GDConsts.quitToDosPrompt, GDConsts.noChoice) = GDConsts.yesChoice then
            GameIo.ExitGame(0);
        end;
        1: ViewChar.ViewCharMenu(viewRedraw);
        2: Camp.CampMagicMenu(interrupted);
        3: Camp.RestForSpellPrep(interrupted);
        4: Camp.CampAlterMenu;
        5: Camp.CampFixMenu(interrupted);
        6: Camp.CampShowLuck;
      end;
    end;
  end;
  Camp.ResetPartySpellActivities;
  GDVars.locState.current := savedMode;
  CharHlp.PrintPositionAndTime;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
  spellSlotCallback := Camp.DisplaySpellSlots;
end.
