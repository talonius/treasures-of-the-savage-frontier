{ DevMenu -- the developer menu (DeveloperMenu), with editors for teleporting and walking the map, the current
  character's items, wealth and statistics, memorized spells, and combat on or off. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit DevMenu;

interface

{ Run the developer menu until E, or until a teleport off the map or Jump (which runs the finish hook with environment
  99) sets done; then record the party's position as the saved one and redraw its map cell.
  @param(done Set to 1 when the party leaves the map.) }
procedure DeveloperMenu(var done: Byte);

implementation

uses Types, Crt, GDConsts, GDVars, C_Keys, Border, TextRend, Camp, ViewChar,
  Magic, CharHlp, MenuCore, MapView, View3D;

{ Return 'YES' or 'NO'.
  @param(value The flag.)
  @returns(Its text.) }
function BoolStr(value: Boolean): String;
begin
  if value then
    BoolStr := 'YES'
  else
    BoolStr := 'NO';
end;

{ Show the edited item's name and fields under the view, and '>' at the field being changed.
  @param(item The item being edited.) }
procedure DrawItem(item: Types.PItem);
begin
  Border.EraseBox(1, 17, 38, 22);
  with item^ do begin
    CharHlp.PrintItemString(GDVars.curChar, item, 6, $11, True, True);
    TextRend.DisplayString(2, 18, White, Black, 'Type:');
    TextRend.DisplayString(7, 18, White, Black, GDVars.intToStringHook(itemType));
    TextRend.DisplayString(2, 19, White, Black, 'identified:' + CharHlp.Uint8Str(unidMask));
    TextRend.DisplayString(21, 19, White, Black, 'cursed:' + DevMenu.BoolStr(Boolean(cursed)));
    TextRend.DisplayString(2, 20, White, Black, 'plus:' + CharHlp.Uint8Str(Byte(plus)));
    TextRend.DisplayString(21, 20, White, Black, 'plussave: ' + CharHlp.Uint8Str(Byte(saveBonus)));
    TextRend.DisplayString(2, 21, White, Black, 'weight:' + CharHlp.Uint16Str(weight));
    TextRend.DisplayString(21, 21, White, Black, 'value:' + CharHlp.Uint16Str(value));
    TextRend.DisplayString(4, 22, White, Black,
                     'specials:' + CharHlp.Uint8Str(charges) + ' ' + CharHlp.Uint8Str(effect) + ' ' +
                         CharHlp.Uint8Str(special));
  end;
  TextRend.DisplayString(GDConsts.itemXs14Local[GDVars.itemField14Local],
                         GDConsts.itemYs14Local[GDVars.itemField14Local], LightRed, Black, '>');
end;

{ Edit a copy of the current character's items field by field: the arrow keys pick the field, Add and Sub change it by
  the step, which Inc multiplies by ten up to 1000, Next takes a copy of the next item, and Keep adds the copy to the
  inventory if it can be carried. }
procedure ItemEditor;
var
  item: Types.TItem;
  source: Types.PItem;
  increment: LongInt;
  c: Char;

  { Change the selected field of the edited item by delta, or toggle a flag field. }
  procedure ChangeItem(delta: Integer);
  var
    value: Integer;
  begin
    case GDVars.itemField14Local of
      0: item.equipped := Ord(item.equipped = 0);
      1: Inc(item.quantity, delta);
      2, 3, 4: begin
        value := item.nameIds[5 - GDVars.itemField14Local] + delta;
        if value in [0..255] then
          item.nameIds[5 - GDVars.itemField14Local] := value;
      end;
      5: begin
        value := item.itemType + delta;
        if value in [1..128] then item.itemType := value;
      end;
      6: item.unidMask := (item.unidMask + delta) and 7;
      7: item.cursed := Ord(item.cursed = 0);
      8: Inc(item.plus, delta);
      9: Inc(item.saveBonus, delta);
      10: Inc(item.weight, delta);
      11: Inc(item.value, delta);
      12, 13, 14: Inc(item.spells[GDVars.itemField14Local - 11], delta);
    end;
  end;

begin
  GDVars.itemField14Local := 0;
  increment := 1;
  source := GDVars.curChar^.items;
  if source <> nil then begin
    item := source^;
    source := source^.next;
  end else begin
    FillChar(item, SizeOf(item), 0);
    item.itemType := 1;
  end;
  repeat
    DevMenu.DrawItem(@item);
    MenuCore.ResetMenuSlots(19);
    c := MenuCore.MenuHorizontal('Change by ' + CharHlp.Uint16Str(Word(increment)) + ':', 'Add Sub Inc Next Keep Exit',
                                 1, 0);
    if GDVars.menuReturnedKey then
      case c of
        C_Keys.DOWN: begin
          Inc(GDVars.itemField14Local);
          if GDVars.itemField14Local > 14 then GDVars.itemField14Local := 0;
        end;
        C_Keys.UP: if GDVars.itemField14Local = 0 then GDVars.itemField14Local := 14
             else Dec(GDVars.itemField14Local);
      end else if not GDVars.menuReturnedKey then
      case c of
        #2: begin
          increment := increment * 10;
          if increment >= 10000 then increment := 1;
        end;
        #0: ChangeItem(increment);
        #1: ChangeItem(-increment);
        #3: begin
          if source <> nil then begin
            item := source^;
            source := source^.next;
          end else
            source := GDVars.curChar^.items;
        end;
        #4: if not ViewChar.CannotCarryItem(GDVars.curChar, 0, @item) then begin
          CharHlp.AddItemCopy(GDVars.curChar, @item);
          TextRend.DisplayAndPause(White, Black, 'Item added to inventory');
        end else
          TextRend.DisplayAndPause(White, Black, 'Inventory full');
        #5: ;
      end;
  until c = #5;
end;

{ After a walk step or a teleport: redraw the status line (coordinates, facing, time and the camping/search/boat tag on
  row 15, through CharHlp.PrintPositionAndTime), the 3D view at the party's cell and the sheet headers. }
procedure RedrawStatusLineViewAndHeaders;
begin
  CharHlp.PrintPositionAndTime;
  MapView.DisplayMapView;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ Shows 'visible' or 'invisible' by whether the current character is hostile, and the free heap. }
procedure DrawPosition;
begin
  if GDVars.curChar^.side = 0 then
    TextRend.DisplayString(1, 20, White, Black, 'visible')
  else
    TextRend.DisplayString(1, 20, White, Black, 'invisible');
  TextRend.DisplayString(1, 21, White, Black,
                         GDVars.intToStringHook(MemAvail) + ' ' + GDVars.intToStringHook(MaxAvail));
end;

{ Moves the party: Up steps it forward, wrapping on the 16-by-16 map; Down, Left and Right turn it about, left and
  right; Exit ends. }
procedure WalkEditor;
var
  c: Char;
begin
  repeat
    Border.EraseBox(1, 17, 38, 22);
    DevMenu.DrawPosition;
    MenuCore.ResetMenuSlots(19);
    c := MenuCore.MenuHorizontal('(Use arrow keys):', 'Exit', 1, 0);
    if GDVars.menuReturnedKey then
      case c of
        C_Keys.UP: begin
          Inc(GDVars.partyPos.x, GDConsts.dirDx[GDVars.partyPos.facing]);
          Inc(GDVars.partyPos.y, GDConsts.dirDy[GDVars.partyPos.facing]);
          GDVars.partyPos.x := GDVars.partyPos.x and $0F;
          GDVars.partyPos.y := GDVars.partyPos.y and $0F;
          DevMenu.RedrawStatusLineViewAndHeaders;
        end;
        C_Keys.DOWN: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 4) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime;
        end;
        C_Keys.LEFT: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 6) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime;
        end;
        C_Keys.RIGHT: begin
          GDVars.partyPos.facing := (GDVars.partyPos.facing + 2) mod 8;
          View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing);
          CharHlp.PrintPositionAndTime;
        end;
      end else
      case c of
        #0: Exit;
      end;
  until False;
end;

{ Lets the player pick a map cell to teleport the party to, X and Y stepping by the increment (Inc flips it between 1
  and -1) and wrapping on the 16-by-16 map; Self moves the party there and, with Map set at the map's edge, sends it off
  the map. Walk runs WalkEditor.
  @param(done Set when the party is sent off the map.) }
procedure TeleportEditor(var done: Byte);
var
  x: Byte;
  y: Byte;
  { Unused in this version; see the other implementations of this routine. }
  field: Byte;
  c: Char;
  all: Boolean;
  increment: Integer;
begin
  x := GDVars.partyPos.x;
  y := GDVars.partyPos.y;
  all := False;
  increment := 1;
  repeat
    if (x <> $0F) and (x <> 0) and (y <> 0) and (y <> $0F) then
      all := False;
    Border.EraseBox(1, 17, 38, 22);
    TextRend.DisplayString(1, 17, LightGreen, Black,
                           'teleport to: ' + CharHlp.Uint8Str(x) + ' ' + CharHlp.Uint8Str(y));
    TextRend.DisplayString(1, 18, LightGreen, Black, 'go off of map: ' + DevMenu.BoolStr(all));
    if increment = -1 then
      TextRend.DisplayString(1, 21, LightGreen, Black, 'Increment: -1')
    else
      TextRend.DisplayString(1, 21, LightGreen, Black, 'Increment: 1');
    TextRend.DisplayString(1, 22, LightGreen, Black, 'Self=teleport self, all=teleport all');
    DevMenu.DrawPosition;
    c := MenuCore.MenuHorizontal('', 'Walk X Y Inc Map Self Exit', 1, 0);
    if GDVars.menuReturnedKey then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        #3: increment := -increment;
        #4: all := not all;
        #5: begin
          GDVars.partyPos.x := x;
          GDVars.partyPos.y := y;
          DevMenu.RedrawStatusLineViewAndHeaders;
          if all then begin
            GDVars.gameState^.leaveMap := 1;
            GDVars.gameState^.moveLocked := $FF;
            done := 1;
          end;
        end;
        #1: begin Inc(x, increment); x := x and $0F end;
        #2: begin Inc(y, increment); y := y and $0F end;
        #0: begin
          DevMenu.WalkEditor;
          x := GDVars.partyPos.x;
          y := GDVars.partyPos.y;
        end;
        #6: ;
      end;
  until (c = #6) or (done <> 0);
end;

{ Wealth and statistics: with the editor enabled the three coin counts, then the NPC number, party love, NPC love,
  experience, current and maximum hit points, crystals (1 red, 2 green, 4 blue) and the crown, changed by the increment
  (Inc cycles up to 1000000). Field 6 can be selected but changes nothing. }
procedure WealthEditor;
var
  field: Byte;
  { Unused in this version; see the other implementations of this routine. }
  fieldTail: array[0..2] of Byte;
  increment: LongInt;
  c: Char;
  startField: Byte;

  { Show the editable values and '>' at the field being changed. }
  procedure DrawStats;
  var
    i: Byte;
  begin
    Border.EraseBox(1, 17, 38, 22);
    if GDConsts.editorEnabled then
      for i := 0 to 2 do
        TextRend.DisplayString(GDConsts.wealthXs[i] + 1, GDConsts.wealthYs[i], White, Black,
                         GDConsts.wealthNames[ShortInt(i + 0)] + ' ' +
                             GDVars.intToStringHook(GDVars.curChar^.coins[ShortInt(i + 0)]));
    TextRend.DisplayString(GDConsts.wealthXs[3] + 1, GDConsts.wealthYs[3], White, Black,
                     'npcnumber ' + GDVars.intToStringHook(GDVars.gameState^.npcNumber));
    TextRend.DisplayString(GDConsts.wealthXs[4] + 1, GDConsts.wealthYs[4], White, Black,
                     'partylove ' + GDVars.intToStringHook(GDVars.gameState^.partyLove));
    TextRend.DisplayString(GDConsts.wealthXs[5] + 1, GDConsts.wealthYs[5], White, Black,
                           'npclove ' + GDVars.intToStringHook(GDVars.gameState^.npcLove));
    TextRend.DisplayString(2, 21, White, Black, 'Experience ' + CharHlp.Int32Str(GDVars.curChar^.experience));
    TextRend.DisplayString(2, 22, White, Black, 'Current HP ' + CharHlp.Uint8Str(GDVars.curChar^.hpCur));
    TextRend.DisplayString(21, 22, White, Black, 'Max HP ' + CharHlp.Uint8Str(GDVars.curChar^.hpMax));
    TextRend.DisplayString(GDConsts.wealthXs[field], GDConsts.wealthYs[field], LightRed, Black, '>');
    TextRend.DisplayString(21, 20, White, Black, 'Crys(1r2g4b) ' + CharHlp.Uint8Str(GDVars.gameState^.crystals));
    TextRend.DisplayString(21, 21, White, Black, 'Crown ' + CharHlp.Uint8Str(GDVars.gameState^.crown));
  end;

  { Change the cursor's field by delta; crystals stay within 0..7 and the crown 0..1. }
  procedure ChangeScalar(delta: LongInt);
  begin
    case field of
      0..2: Inc(GDVars.curChar^.coins[ShortInt(field + 0)], delta);
      3: GDVars.gameState^.npcNumber := GDVars.gameState^.npcNumber + delta;
      4: GDVars.gameState^.partyLove := GDVars.gameState^.partyLove + delta;
      5: GDVars.gameState^.npcLove := GDVars.gameState^.npcLove + delta;
      7: Inc(GDVars.curChar^.experience, delta);
      8: Inc(GDVars.curChar^.hpCur, delta);
      9: Inc(GDVars.curChar^.hpMax, delta);
      10: GDVars.gameState^.crystals := (GDVars.gameState^.crystals + delta) and 7;
      11: GDVars.gameState^.crown := (GDVars.gameState^.crown + delta) and 1;
    end;
  end;

begin
  if GDConsts.editorEnabled then startField := 0 else startField := 7;
  field := startField;
  increment := 1;
  repeat
    DrawStats;
    c := MenuCore.MenuHorizontal('Change by ' + GDVars.intToStringHook(increment) + ':', 'Add Sub Inc Exit', 1, 0);
    if GDVars.menuReturnedKey then
      case c of
        C_Keys.DOWN: begin
          Inc(field);
          if field > 11 then field := startField;
        end;
        C_Keys.UP: if field = startField then field := 11 else Dec(field);
      end else if not GDVars.menuReturnedKey then
      case c of
        #2: begin
          increment := increment * 10;
          if increment >= 10000000 then increment := 1;
        end;
        #0: ChangeScalar(increment);
        #1: ChangeScalar(-increment);
        #3: ;
      end;
  until c = #3;
end;

{ Lets the player pick a spell from 1 to 100, Add and Sub stepping by 1 or 10 (Inc), showing whether the character's
  classes can cast it; Memorize memorizes it in the first free slot when they can, and otherwise shows 'Cannot use
  spell'. The memorized spells are sorted on leaving. }
procedure SpellEditor;
var
  c: Char;
  spell: Byte;
  increment: Word;
  candidate: Byte;

  { Memorize spell value in the first free slot and show its name. }
  procedure AddMemorizedSpell(value: Byte);
  var
    i: Byte;
  begin
    for i := 0 to 140 do
      if GDVars.curChar^.memorized[i] = 0 then begin
        GDVars.curChar^.memorized[i] := value;
        TextRend.DisplayAndPause(White, Black, GDConsts.spellNames[value]);
        Exit;
      end;
  end;

begin
  increment := 1;
  spell := 1;
  repeat
    Border.EraseBox(1, 17, 38, 22);
    TextRend.DisplayString(2, 17, White, Black,
                           GDVars.intToStringHook(spell) + ' ' +
                           DevMenu.BoolStr(Magic.ClassCanCastSpell(GDVars.curChar, spell, 0)) + '-' +
                           GDConsts.spellNames[spell]);
    c := MenuCore.MenuHorizontal('Change by ' + CharHlp.Uint16Str(increment) + ':', 'Memorize Add Sub Inc Exit', 1, 0);
    if not GDVars.menuReturnedKey then
      case c of
        #0: if Magic.ClassCanCastSpell(GDVars.curChar, spell, 0) then
              AddMemorizedSpell(spell)
            else
              TextRend.DisplayAndPause(White, Black, 'Cannot use spell');
        #3: begin
          increment := increment * 10;
          if increment >= 100 then increment := 1;
        end;
        #1: begin
          candidate := spell + increment;
          if candidate in [1..100] then spell := candidate;
        end;
        #2: begin
          candidate := spell - increment;
          if candidate in [1..100] then spell := candidate;
        end;
        #4: ;
      end;
  until c = #4;
  Camp.SortMemorizedSpells;
end;

{ Switches combat off (Disable) and on (Reenable) through the combat-disabled flag, until Exit or the aim flag is set. }
procedure CombatEditor;
var
  c: Char;
begin
  repeat
    Border.EraseBox(1, 17, 38, 22);
    DevMenu.DrawPosition;
    if GDConsts.combatDisabled = 0 then
      TextRend.DisplayString(1, 21, White, Black, 'combat enabled')
    else
      TextRend.DisplayString(1, 21, White, Black, 'combat disabled');
    c := MenuCore.MenuHorizontal('', 'Disable Reenable Exit', 1, 0);
    if not GDVars.menuReturnedKey then
      case c of
        #0: begin
          GDConsts.combatDisabled := 1;
          GDVars.bottomMessageHook('Combat disabled');
        end;
        #1: begin
          GDConsts.combatDisabled := 0;
          GDVars.bottomMessageHook('Combat reenabled');
        end;
      end;
  until (c = #2) or GDVars.targetSelected;
  MenuCore.ClearBottomLine;
end;

procedure DeveloperMenu(var done: Byte);
var
  c: Char;
begin
  repeat
    Border.EraseBox(1, 17, 38, 22);
    DevMenu.DrawPosition;
    c := MenuCore.MenuHorizontal('', 'Tport Item Wealth Spells Combat Jump E', 1, 0);
    if not GDVars.menuReturnedKey then
      case c of
        #4: DevMenu.CombatEditor;
        #0: DevMenu.TeleportEditor(done);
        #3: DevMenu.SpellEditor;
        #1: DevMenu.ItemEditor;
        #2: DevMenu.WealthEditor;
        #5: begin
          GDVars.environmentId := 99;
          GDVars.finishHook;
          done := 1;
        end;
      end;
  until (c = #6) or (done <> 0);
  GDVars.gameState^.savedX := GDVars.partyPos.x;
  GDVars.gameState^.savedY := GDVars.partyPos.y;
  View3D.RefreshCurrentMapCell;
  Border.EraseBox(1, 17, 38, 22);
end;

begin
end.
