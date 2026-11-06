{ PostCbt -- after a fight: combat results and experience, the summary screen and the loot menus. PostCombat runs it
  all; LootTakeMenu is the take menu. }
{$O+,F+,S+,A+}
unit PostCbt;

interface

{ Everything after a fight: settles the results (not after a duel) and the field, stops there when GDConsts.postSkipFlag
  is set, recalculates the party's stats, reports the outcome to the script, shows the summary and the treasure menu (or
  the party's destruction), frees what treasure is left, and resets the fight's special rules and frees the loaded
  picture. }
procedure PostCombat;

{ Offers Money, Items and Exit for taking from the treasure while both remain, going straight to the one that is left
  otherwise. The cursor keys change the current character.
  @param(hasMoney Whether the treasure holds money; updated after each choice while both remain.)
  @param(items Whether the treasure holds items; updated likewise.) }
procedure LootTakeMenu(var hasMoney, items: Boolean);

implementation

uses Types, Shop, CharGen, ViewChar, Money, Magic, FxEngine, CharHlp, MenuCore, Portrait, Border, GameIo, TextRend, Crt,
  GDConsts, GDVars, C_Keys, C_Status, C_Class, C_Npc, C_Ifc, C_Effect, C_Stat;

const
  PRIME_STAT_THRESHOLD = 15;

{ Merges the treasure item it with every identical item in the treasure list, adding up their quantities in stacks of at
  most 255. Note: charges, effect and special are each compared with themselves rather than with the item being merged,
  so items that differ only in those still merge.
  @param(it The treasure item to merge.) }
procedure CoalesceItem(it: Types.PItem);
var
  prev: Types.PItem;
  p: Types.PItem;
  next: Types.PItem;
  target: Types.PItem;
  quantity: Byte;
begin
  target := it;
  quantity := target^.quantity;
  p := GDVars.treasureItems;
  while p <> nil do begin
    next := p^.next;
    if (p <> target) and (p^.quantity > 0) and (p^.nameIds[1] = target^.nameIds[1]) and
        (p^.nameIds[2] = target^.nameIds[2]) and (p^.nameIds[3] = target^.nameIds[3]) and
        (p^.itemType = target^.itemType) and (p^.plus = target^.plus) and
        (p^.saveBonus = target^.saveBonus) and (p^.cursed = target^.cursed) and (p^.weight = target^.weight) and
        (p^.charges = p^.charges) and (p^.charges < 2) and (p^.effect = p^.effect) and
        (p^.special = p^.special) then begin
      if Integer(quantity) + p^.quantity <= 255 then begin
        Inc(quantity, p^.quantity);
        prev := GDVars.treasureItems;
        if p = prev then
          GDVars.treasureItems := p^.next
        else
          while (prev <> nil) and (prev^.next <> p) do
            prev := prev^.next;
        prev^.next := p^.next;
        GameIo.FreeSlot(Pointer(p));
      end else begin
        target^.quantity := 255;
        p^.quantity := p^.quantity - (255 - quantity);
        quantity := p^.quantity;
        target := p;
      end;
    end;
    p := next;
  end;
  target^.quantity := quantity;
end;

{ Gathers the spoils of a won fight and works out each member's share of the experience. Every hostile that was put down
  (not okay, fleeing, held in reserve or in statuses 11 to 19) adds its experience award, and its coins if CombatSt
  marked it notPcNpc. Unless the fight forbids it, its items other than type 73 are copied into the treasure list. The
  coins add 2, 250 and 2200 experience apiece by kind, and every new treasure item ahead of GDVars.currentItem adds 400
  per point of its magical bonus. The total is divided among the party members who share in it.
  @param(share Receives each sharing member's experience.) }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharacter;
  { coin loop }
  i: ShortInt;
  expTotal: LongInt;
  { saved head / XP-walk cursor }
  q: Types.PItem;
  it: Types.PItem;
  { the items looked at; never read }
  cnt: Byte;
begin
  expTotal := 0;
  p := GDVars.partyHead;
  cnt := 0;
  while p <> nil do begin
    it := p^.items;
    if (p^.side = 1) and (p^.status <> C_Status.OKAY) and not (p^.status in [9, 11..19]) and
        (p^.status <> C_Status.RUNNING) then begin
      GDVars.monstersKilled := True;
      if p^.combatAddr^.notPcNpc = 1 then
        for i := 0 to 2 do
          Inc(GDVars.pooledMoney[i], p^.coins[i]);
      Inc(expTotal, p^.xpAward);
      if GDVars.gameState^.noCombatItems <> 1 then
        while it <> nil do begin
          Inc(cnt);
          if it^.itemType <> 73 then begin
            if GDVars.treasureItems = nil then begin
              GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
              CharHlp.PrintItemString(p, Types.PItem(it), 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := nil;
            end else begin
              q := GDVars.treasureItems;
              GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
              CharHlp.PrintItemString(p, Types.PItem(it), 0, 0, False, False);
              GDVars.treasureItems^ := it^;
              GDVars.treasureItems^.equipped := 0;
              GDVars.treasureItems^.next := q;
            end;
            if GDVars.treasureItems^.quantity > 0 then
              PostCbt.CoalesceItem(GDVars.treasureItems);
          end;
          it := it^.next;
        end;
    end;
    p := p^.next;
  end;
  Inc(expTotal, GDVars.pooledMoney[0] * 2);
  Inc(expTotal, GDVars.pooledMoney[1] * 250);
  Inc(expTotal, GDVars.pooledMoney[2] * 2200);
  q := GDVars.treasureItems;
  while (q <> nil) and (q <> GDVars.currentItem) do begin
    if q^.plus > 0 then
      Inc(expTotal, q^.plus * 400);
    q := q^.next;
  end;
  share := expTotal div (GDVars.gameState^.partySize - GDVars.nonAnimCount);
end;

{ Gives experience to each party member still in play and not animated, unless the fight was a mirror duel, and then
  sets the member's level-up flag from CanLevelUp. A single-class character with a high prime requisite gets 10 percent
  more: Wisdom for a cleric, Strength for a fighter, Strength and Wisdom for a paladin, Strength, Intelligence and
  Wisdom for a ranger, Intelligence for a mage, Dexterity for a thief. A two-class character gets half, a three-class
  character a third. Note: the cleric's threshold is one lower than the others'.
  @param(xp Each member's share before the class adjustment.) }
procedure AwardExperience(xp: LongInt);
var
  p: Types.PCharacter;
  share: LongInt;
begin
  if GDVars.gameState^.mirrorDuel = 0 then begin
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.inPlay <> 0) and (p^.status <> C_Status.ANIMATED) then begin
        share := xp;
        case p^.charClass of
          C_Class.CLERIC: if p^.stats[C_Stat.WISDOM].current > 14 then share := xp div 10 + xp;
          C_Class.FIGHTER: if p^.stats[C_Stat.STRENGTH].current >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.PALADIN: if (p^.stats[C_Stat.STRENGTH].current > PostCbt.PRIME_STAT_THRESHOLD) and
              (p^.stats[C_Stat.WISDOM].current > PostCbt.PRIME_STAT_THRESHOLD) then
               share := xp div 10 + xp;
          C_Class.RANGER:
            if (p^.stats[C_Stat.STRENGTH].current > PostCbt.PRIME_STAT_THRESHOLD) and
                (p^.stats[C_Stat.INTELLIGENCE].current > PostCbt.PRIME_STAT_THRESHOLD) and
                (p^.stats[C_Stat.WISDOM].current > PostCbt.PRIME_STAT_THRESHOLD) then
              share := xp div 10 + xp;
          C_Class.MAGE: if p^.stats[C_Stat.INTELLIGENCE].current >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.THIEF: if p^.stats[C_Stat.DEXTERITY].current >
            PostCbt.PRIME_STAT_THRESHOLD then share := xp div 10 + xp;
          C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
              C_Class.MAGE_THIEF: share := xp div 2;
          C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF: share := xp div 3;
        end;
        Inc(p^.experience, share);
        p^.displayHighlight := Byte(CharHlp.CanLevelUp(p));
      end;
      p := p^.next;
    end;
  end;
end;

{ Decides how the fight went and settles the party. The party sits at the head of the combatant list, ahead of the first
  combatant marked notPcNpc. Works out whether the party fled, was defeated or won, counts the members who take no
  share, strips the combat-only effects under trigger condition 28, ends a charm of strength 2 (an animated player
  charmed that way becomes a player again), and awards experience on a win. Then, unless the party was defeated, it
  restores statuses: a fleeing member is back to okay, a dying one falls unconscious (or revives at 1 hit point when the
  fight allows it), and an unconscious one with hit points wakes. If the party fled, everyone who did not flee with it
  is left behind. A defeated party is removed entirely. In a duel (GDVars.inputAbort) the winners share the experience
  and nobody is lost. Note: PostCombat calls this only when GDVars.inputAbort is clear, so the duel branch never runs. }
procedure DetermineCombatResults;
var
  p: Types.PCharacter;
  b: Boolean;
  i: Byte;
  alive: Boolean;
  effect: Types.PEffect;
begin
  GDVars.nonAnimCount := 0; GDVars.partyDefeated := True;
  GDVars.partyFled := False;
  p := GDVars.partyHead;
  while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
    if p^.status = C_Status.RUNNING then GDVars.partyFled := True;
    p := p^.next
  end;
  p := GDVars.partyHead; alive := False;
  while (p <> nil) and not alive do begin
    if (p^.inPlay <> 0) or (p^.status = C_Status.UNCONSCIOUS) or (p^.status = C_Status.RUNNING) or
        (p^.status = C_Status.DYING) then alive := True;
    p := p^.next
  end;
  if (GDVars.gameState^.reviveFlag <> 0) and alive then
    GDVars.partyDefeated := False;
  GDVars.combatWon := False; p := GDVars.partyHead;
  if not GDVars.inputAbort then begin
    while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY)) and (p^.side = 0) and
          (p^.npc < C_Npc.NON_PLAYER) then GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True; GDVars.partyFled := False
      end;
      if (p^.inPlay = 0) or (p^.status = C_Status.ANIMATED) then Inc(GDVars.nonAnimCount);
      GDConsts.currentCondition := 28;
      for i := 1 to 17 do FxEngine.RemoveEffect(p, GDConsts.postCombatEffects[i], nil);
      GDConsts.currentCondition := 0;
      if CharHlp.HasEffect(p, C_Effect.IN_LOVE, Pointer(effect)) then
        if effect^.strength = 2 then begin
          effect^.strength := 0;
          if p^.npc = C_Npc.ANIMATED_PLAYER then begin
            p^.npc := 0;
            p^.quickfight := 0
          end
        end;
      p := p^.next
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare); PostCbt.AwardExperience(GDVars.expShare)
    end;
    p := GDVars.partyHead;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (p^.combatAddr^.notPcNpc <> 1) do begin
        if not GDVars.partyFled then begin
          case p^.status of
            C_Status.RUNNING: begin p^.status := C_Status.OKAY; p^.inPlay := 1 end;
            C_Status.DYING: if GDVars.gameState^.reviveFlag <> 0 then begin
                p^.status := C_Status.OKAY; p^.inPlay := 1; p^.hpCur := 1
              end else p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCur >
              0 then begin p^.status := C_Status.OKAY; p^.inPlay := 1 end
              else if GDVars.gameState^.reviveFlag <> 0 then begin
                p^.status := C_Status.OKAY; p^.inPlay := 1; p^.hpCur := 1
              end
          end;
          p := p^.next
        end else begin
          if p^.status =
              C_Status.RUNNING then begin p^.status := C_Status.OKAY; p^.inPlay := 1; p := p^.next end
          else begin GDVars.curChar := p; p := p^.next; CharGen.RemoveCreature(False, True) end
        end
      end
    end else begin
      p := GDVars.partyHead; b := False;
      while (p <> nil) and not b do begin
        if p^.combatAddr^.notPcNpc <> 1 then begin GDVars.curChar := p; CharGen.RemoveCreature(False, True) end
        else b := True;
        p := p^.next
      end;
      GDVars.gameState^.partySize := 0
    end
  end else begin
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.inPlay = 1) and (p^.status = C_Status.OKAY) and (p^.side <> 1) then begin
        GDVars.combatWon := True; PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare)
      end;
      p := p^.next
    end;
    p := GDVars.partyHead;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then p^.inPlay := 1;
      if p^.status = C_Status.DYING then p^.status := C_Status.UNCONSCIOUS;
      p := p^.next
    end
  end
end;

{ The summary screen, over a rebuilt heap and the border backdrop: how the fight ended, the experience each member
  receives, and whether treasure was found. A party that fled abandons the treasure and, like one revived after losing,
  earns nothing, so xp is shown as 0.
  @param(xp The experience each member receives.) }
procedure PostCombatSummary(xp: LongInt);
var
  numStr: String[10];
  msg: String;
  { Unused in this version; see the other implementations of this routine. }
  c: Char;
  query: String[1];
  p: Types.PItem;
  q: Types.PItem;
begin
  GameIo.RebuildLists;
  Border.LoadBorderBackdrop;
  query[0] := #0;
  Border.DrawWindowFrame(0);
  if GDVars.monstersKilled then begin
    if GDVars.partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.partyFledMsg); xp := 0;
      p := GDVars.treasureItems;
      while p <> nil do begin q := p^.next; GameIo.FreeSlot(Pointer(p)); p := q end;
      GameIo.ZeroFill(GDVars.pooledMoney, SizeOf(GDVars.pooledMoney))
    end else if (not GDVars.combatWon) and (GDVars.gameState^.reviveFlag <> 0) then begin
      TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.lostFightMsg); xp := 0
    end else TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.wonDuelMsg)
  end else TextRend.DisplayString(1, 3, LightGreen, Black, GDConsts.partyWonMsg);
  Str(xp, numStr);
  msg := GDConsts.eachReceivesText + numStr;
  if GDVars.gameState^.mirrorDuel = 0 then begin
    TextRend.DisplayString(1, 5, LightGreen, Black, msg);
    TextRend.DisplayString(1, 7, LightGreen, Black, GDConsts.experiencePointsText)
  end;
  GDVars.treasureHasMoney := False;
  GDVars.treasureHasItems := False;
  Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
  if GDVars.monstersKilled then begin
    if GDVars.treasureHasMoney or GDVars.treasureHasItems then
      TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.partyWonMsg)
    else TextRend.DisplayString(1, 10, LightGreen, Black, GDConsts.noTreasureMsg)
  end;
  c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.pressButtonPrompt, Byte(True), Byte(False))
end;

{ Lists the treasure items in a vertical Take menu.
  @param(c Receives the key pressed.)
  @param(itemToTake Receives the chosen item.)
  @param(cursor The highlighted item, kept between calls; receives the chosen item.)
  @param(idx The highlighted item's position, kept between calls.) }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItem; var cursor: Types.PItem; var idx: Integer);
var
  head: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  tmp: String[16];
  { Unused in this version; see the other implementations of this routine. }
  lenv: Byte;
  { Unused in this version; see the other implementations of this routine. }
  i: Byte;
  { MenuVertical's force-full-draw flag, seeded True; the callee clears it }
  redraw: Boolean;
  p: Types.PItem;
begin
  redraw := True;
  Border.DrawWindowFrame(0);
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(nil, Types.PItem(p), 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  MenuCore.ResetMenuSlots(0);
  c := MenuCore.MenuVertical(GDConsts.itemsPrompt, GDConsts.takeMenuText, 1, 1, 38, 22, head, True, 0, redraw, idx,
                             Pointer(cursor));
  itemToTake := cursor;
end;

{ Gives the current character copies of the picked items, removing each taken one from the treasure, until it leaves or
  the treasure is empty. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItem;
  p: Types.PItem;
  c: Char;
  done: Boolean;
  cursor: Types.PItem;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GDVars.treasureItems;
  idx := 0;
  GDVars.horizChoice := 1;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if c <> #0 then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then GameIo.FreeSlot(Pointer(itemToTake));
        if GDVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharHlp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var hasMoney, items: Boolean);
var
  c: Char;
  done: Boolean;
begin
  GDVars.horizChoice := 1; done := False;
  if hasMoney then begin
    if items then begin
      repeat
        MenuCore.ResetMenuSlots(2);
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', Byte(True), Byte(True));
        if GDVars.menuReturnedKey then begin
          case c of
            C_Keys.ESCAPE: done := True;
            C_Keys.UP: ViewChar.SelectPrevNextChar(c);
            C_Keys.DOWN: ViewChar.SelectPrevNextChar(c)
          end
        end else begin
          case c of
            #0: begin Money.TakeMoneyMenu; CharHlp.DisplayNoncombatInterface end;
            #1: PostCbt.LootTakeItemMenu;
            #2: done := True
          end
        end;
        CharHlp.DisplayParty(GDVars.curChar);
        Money.DetermineTreasure(hasMoney, items);
        if not hasMoney or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharHlp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ The treasure menu after a won fight: View, Pool and Exit always, Take while any treasure remains, Share while money
  remains, and Detect while there are items and the current character, in play, has spell 5, 11 or 77 memorized. The
  cursor keys change the current character. Leaving with treasure still on the ground asks for confirmation. }
procedure LootMenu;
var
  { Unused in this version; see the other implementations of this routine. }
  treasure: Boolean;
  i: Byte;
  menuState: Byte;
  c: Char;
  done: Boolean;
  changed: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  itemIndex: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  savedChoice: Byte;
begin
  done := False;
  CharHlp.DisplayNoncombatInterface;
  savedChoice := 1;
  repeat
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
    Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
    i := 0; hasDetect := False;
    if GDVars.treasureHasItems then
      while (i <= 140) and not hasDetect do begin
        if (GDVars.curChar^.memorized[i] = 5) or (GDVars.curChar^.memorized[i] = 11) or
            (GDVars.curChar^.memorized[i] = 77) then
          if GDVars.curChar^.inPlay <> 0 then begin
            hasDetect := True; detectSpell := GDVars.curChar^.memorized[i]
          end;
        Inc(i)
      end;
    menuState := 0;
    for i := 0 to 5 do
      case i of
        1: if GDVars.treasureHasMoney or GDVars.treasureHasItems then MenuCore.AppendSlot(1, menuState);
        3: if GDVars.treasureHasMoney then MenuCore.AppendSlot(3, menuState);
        4: begin if hasDetect then MenuCore.AppendSlot(4, menuState) end
      else MenuCore.AppendSlot(i, menuState)
      end;
    GDVars.horizChoice := savedChoice;
    c := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.treasureMenuText, Byte(True), Byte(True));
    savedChoice := GDVars.horizChoice;
    if GDVars.menuReturnedKey then begin
      case c of
        C_Keys.ESCAPE: c := #5;
        C_Keys.UP, C_Keys.DOWN: begin
          CharHlp.PrintMiscInfo(GDVars.curChar, Byte(False)); ViewChar.SelectPrevNextChar(c);
          CharHlp.PrintMiscInfo(GDVars.curChar, Byte(True)); c := #255
        end
      end
    end;
    case c of
      #0: ViewChar.ViewCharMenu(changed);
      #1: PostCbt.LootTakeMenu(GDVars.treasureHasMoney, GDVars.treasureHasItems);
      #2: Money.PoolMoney;
      #3: Money.ShareMoney;
      #4: Magic.CastSpell(detectSpell, 0, 0, changed);
      #5: begin
        Money.DetermineTreasure(GDVars.treasureHasMoney, GDVars.treasureHasItems);
        if GDVars.treasureHasMoney or GDVars.treasureHasItems then begin
          TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, GDConsts.treasureLeftText1);
          TextRend.DisplayMessageWindow(1, 17, 38, 22, White, Black, False, GDConsts.treasureLeftText2);
          if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.noChoice) = GDConsts.noChoice then done := True
          else Border.EraseBox(1, 17, 38, 22);
          TextRend.ClearStatusLine
        end else done := True
      end
    end;
  until done;
end;

{ Clears the field: removes each combatant that is neither a player character nor an NPC, or is on the hostile side,
  recording it as a monster killed and counting those out of play for the script, and frees the combat record of each
  remaining party member. The current character is left at the head of the list. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharacter;
  next: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  first: Boolean;
begin
  first := True;
  GDVars.gameState^.monstersDefeated := 0;
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 1) or (p^.side = 1) then begin
      GDVars.monstersKilled := True;
      if p^.inPlay <> 1 then Inc(GDVars.gameState^.monstersDefeated);
      first := False;
      next := p^.next;
      GDVars.curChar := p;
      CharGen.RemoveCreature(p^.combatAddr^.notPcNpc = 1, True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      p := p^.next;
    end;
  end;
  GDVars.curChar := GDVars.partyHead;
end;

procedure PostCombat;
var
  p: Types.PItem;
  q: Types.PItem;
  cr: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  itemCount: Word;
begin
  GameIo.ZeroFill(GDVars.compareFlags, SizeOf(GDVars.compareFlags));
  GDVars.monstersKilled := False;
  if not GDVars.inputAbort then PostCbt.DetermineCombatResults;
  GDVars.locState.current := C_Ifc.LOOT;
  PostCbt.PostCombatCreatureCleanup;
  if GDConsts.postSkipFlag <> 0 then Exit;
  cr := GDVars.partyHead;
  GDVars.compareFlags[2] := 1;
  while cr <> nil do begin
    CharHlp.RecalcStats(cr); cr := cr^.next
  end;
  if not GDVars.partyDefeated then begin
    if GDVars.partyFled then begin
      p := GDVars.treasureItems;
      while p <> nil do begin q := p; p := p^.next; GameIo.FreeSlot(Pointer(q)) end;
      GDVars.treasureItems := nil
    end else begin
      GDVars.compareFlags[1] := 1; GDVars.compareFlags[2] := 0
    end;
    if not GDVars.inputAbort then begin
      PostCbt.PostCombatSummary(GDVars.expShare);
      if GDVars.treasureHasMoney or GDVars.treasureHasItems then PostCbt.LootMenu
    end;
    p := GDVars.treasureItems;
    while p <> nil do begin
      q := p;
      p := p^.next;
      GameIo.FreeSlot(Pointer(q));
    end;
    GDVars.treasureItems := nil;
  end else begin
    Border.LoadBorderBackdrop;
    Border.DrawWindowFrame(0);
    GDVars.curCol := 2; GDVars.curRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, Black, True, 'The party has been destroyed.');
    TextRend.DisplayAndPause(LightMagenta, Black, 'Press any key to continue');
  end;
  GDVars.msgDelayFlag := 1;
  GDVars.gameState^.enemyToHitAdj := 0; GDVars.gameState^.partyToHitAdj := 0; GDVars.gameState^.partyMoveAdj := 0;
  GDVars.gameState^.noCombatItems := 0; GDVars.gameState^.reviveFlag := 0; GDVars.gameState^.mirrorDuel := 0;
  Portrait.FreeAnimation;
  CharHlp.ClearEncounterState
end;

begin
end.
