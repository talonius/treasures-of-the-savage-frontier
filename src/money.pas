{ Money -- coins, carried as three types (platinum, gems, jewelry) weighing one each, and the party pool: pooling,
  sharing, dropping, taking and trading coins, the carrying limit, and appraising gems and jewelry. }
{$O+,F+,S+,A+}
unit Money;

interface

uses Types, GameIo, Border, TextRend, FxEngine, CharHlp, MenuCore, Crt, GDConsts, GDVars, C_Keys,
  C_Ifc, C_Npc;

{ Tells whether more weight would overload a character.
  @param(p Character to test.)
  @param(w Weight to add.)
  @param(takable Receives what it can still take when it would be overloaded (0 if already over), otherwise 0.)
  @returns(True when the weight would overload it.) }
function CheckOverload(p: Types.PCharacter; w: LongInt; var takable: LongInt): Boolean;

{ Puts all the money carried by party members who are players or animated players into the pool. }
procedure PoolMoney;

{ Divides the pool. Each money type's share is the pool divided by CountPoolers, the remainder held back. The first pass
  gives each member with an NPC value below $80, highest money type first, its share and one coin of the remainder while
  they fit, or as much of the share as it can carry, the rest going back to the remainder. The second pass hands what is
  left, type by type, to each member in list order as far as it can carry, and the rest stays in the pool, which is
  marked as holding money when anything stays. Note: the divisor counts animated members ($B3), whom the first pass
  skips, and not NPC values 1 to $7F, whom it pays. }
procedure ShareMoney;

{ Lists the money in the pool and lets the current character take an amount of the chosen type, until the pool is empty
  or the player leaves. Note: leaving the menu without choosing does not free the list it was built from. }
procedure TakeMoneyMenu;

{ Finds the money type named by the first non-blank letter of a string.
  @param(s The string, a money menu line.)
  @param(typeName Receives the type's name.)
  @returns(Platinum 0, Gems 1, Jewelry 2. Note: any other letter leaves it undefined.) }
function ParseMoneyType(s: String; var typeName: String): ShortInt;

{ Shows a query on the bottom line and reads a number typed after it; a leading 0 is ignored.
  @param(max The largest number accepted; a larger one becomes max.)
  @param(query The query.)
  @param(color The query's color.)
  @returns(The number, or 0 on Escape.) }
function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;

{ Moves coins of one type, with their weight, from one character to another when the receiver can carry them; otherwise
  shows "Overloaded", pauses and flushes the keyboard.
  @param(giver The character giving the coins.)
  @param(rcv The character receiving them.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure TradeMoney(var giver, rcv: Types.PCharacter; qty: LongInt; mType: ShortInt);

{ Takes money from a character; in the loot screen, in shops and temples and in the vault it goes into the pool,
  elsewhere it is lost.
  @param(p The character.)
  @param(qty The amount.)
  @param(mType The money type.) }
procedure DropMoney(p: Types.PCharacter; qty: LongInt; mType: ShortInt);

{ Reports whether the pool holds money and whether the treasure list holds items.
  @param(hasMoney Receives True when the pool holds money.)
  @param(items Receives True when the treasure list holds items.) }
procedure DetermineTreasure(var hasMoney, items: Boolean);

{ Appraises the current character's gems and jewelry one piece at a time. A piece can be kept as an item when the
  character has room and fewer than 16 items, or sold for its value in platinum. Note: a kept piece is lost when the
  character carries no items, because it is linked to a local pointer rather than to the item list.
  @param(ok Receives False when there was nothing to appraise, True otherwise.) }
procedure AppraiseMenu(var ok: Boolean);

implementation

{ Gives the most weight a character can carry: its weight allowance plus 1500.
  @param(p The character.)
  @returns(The capacity.) }
function CarryingCapacity(p: Types.PCharacter): Word;
begin
  CarryingCapacity := CharHlp.WeightAllowance(p) + 1500;
end;

{ Takes weight off a character's encumbrance.
  @param(p The character.)
  @param(w The weight removed.) }
procedure RemoveWeight(p: Types.PCharacter; w: LongInt);
begin
  Types.PCharacter(p)^.encumbrance := Types.PCharacter(p)^.encumbrance - w;
end;

{ Adds weight to a character's encumbrance.
  @param(p The character.)
  @param(w The weight added.) }
procedure AddWeight(p: Types.PCharacter; w: LongInt);
begin
  Types.PCharacter(p)^.encumbrance := Types.PCharacter(p)^.encumbrance + w;
end;

function CheckOverload(p: Types.PCharacter; w: LongInt; var takable: LongInt): Boolean;
var cap: Word;
begin
  cap := Money.CarryingCapacity(p);
  if Types.PCharacter(p)^.encumbrance + w > cap then begin
    CheckOverload := True;
    if Types.PCharacter(p)^.encumbrance > cap then
      takable := 0
    else
      takable := cap - Types.PCharacter(p)^.encumbrance;
  end else begin
    CheckOverload := False;
    takable := 0;
  end;
end;

{ Gives platinum to the current character; what does not fit goes to the pooled money, with a message on the bottom row.
  @param(qty The platinum pieces.) }
procedure GivePlatinum(qty: Word);
var takable: LongInt;
begin
  if Money.CheckOverload(GDVars.curChar, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded.  Money will be put in Pool.');
    Inc(GDVars.curChar^.coins[0], takable);
    Money.AddWeight(GDVars.curChar, takable);
    Inc(GDVars.pooledMoney[0], qty - takable);
  end else begin
    Inc(GDVars.curChar^.coins[0], qty);
    Money.AddWeight(GDVars.curChar, qty);
  end;
end;

function InputNumberMax(max: LongInt; query: Types.TStr40; color: Byte): LongInt;
var
  col: Byte;
  { Unused in this version; see the other implementations of this routine. }
  questionLength: Byte;
  qLen: Byte;
  maxStr: String[5];
  s: String[6];
  ch: Char;
  v: LongInt;
  code: Integer;
  n: LongInt;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
  TextRend.DisplayString(0, 24, color, Black, query);
  qLen := Length(query);
  col := qLen;
  Str(max, maxStr);
  s := '';
  repeat
    ch := GameIo.ReadGameKey;
    case ch of
      '0'..'9':
        if (ch = '0') and (Length(s) = 0) then begin
        end else begin
          s := Concat(s, ch);
          Val(s, v, code);
          if v <= max then begin
            Inc(col);
            TextRend.DisplayString(qLen, 24, White, Black, s)
          end else begin
            s := maxStr;
            col := qLen + Length(maxStr);
            TextRend.DisplayStringClear(qLen, 24, White, Black, s)
          end
        end;
      C_Keys.BACKSPACE: if Length(s) > 0 then begin
        s := Copy(s, 1, Length(s) - 1);
        Dec(col);
        TextRend.PrintSpaces(col, 24, Black, 1);
      end;
    end;
  until (ch = C_Keys.ENTER) or (ch = C_Keys.ESCAPE);
  TextRend.PrintSpaces(0, 24, Black, 40);
  if ch = C_Keys.ESCAPE then
    n := 0
  else
    Val(s, n, code);
  InputNumberMax := n;
end;

procedure TradeMoney(var giver, rcv: Types.PCharacter; qty: LongInt; mType: ShortInt);
begin
  if Types.PCharacter(rcv)^.encumbrance + qty <= Money.CarryingCapacity(rcv) then begin
    Types.PCharacter(giver)^.coins[mType] := Types.PCharacter(giver)^.coins[mType] - qty;
    Money.RemoveWeight(giver, qty);
    Types.PCharacter(rcv)^.coins[mType] := Types.PCharacter(rcv)^.coins[mType] + qty;
    Money.AddWeight(rcv, qty);
  end else begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.DrainKeys;
  end;
end;

procedure PoolMoney;
var
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  coinIndex: Byte;
  i: ShortInt;
begin
  p := GDVars.partyHead;
  GDVars.poolHasMoney := True;
  while p <> nil do begin
    if (p^.npc < C_Npc.NON_PLAYER) or (p^.npc = C_Npc.ANIMATED_PLAYER) then begin
      for i := 0 to 2 do begin
        Inc(GDVars.pooledMoney[i], p^.coins[i]);
        Money.RemoveWeight(p, p^.coins[i]);
      end;
      GameIo.ZeroFill(p^.coins, SizeOf(p^.coins));
    end;
    p := p^.next;
  end;
end;

{ Counts the party members and animated creatures (NPC value 0 or $B3).
  @returns(The count.) }
function CountPoolers: Byte;
var
  p: Types.PCharacter;
  n: Byte;
begin
  p := GDVars.partyHead;
  n := 0;
  while p <> nil do begin
    if (p^.npc = 0) or (p^.npc = C_Npc.ANIMATED_PLAYER) then
      Inc(n);
    p := p^.next;
  end;
  CountPoolers := n;
end;

procedure ShareMoney;
var
  p: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  receiver: Types.PCharacter;
  cnt: Byte;
  { Unused in this version; see the other implementations of this routine. }
  done: Boolean;
  takable: LongInt;
  share: array[0..2] of Word;
  rem: array[0..2] of Word;
  i: ShortInt;
begin
  p := GDVars.partyHead;
  done := False;
  cnt := Money.CountPoolers;
  GameIo.ZeroFill(share, SizeOf(share));
  GameIo.ZeroFill(rem, SizeOf(rem));
  for i := 0 to 2 do
    if GDVars.pooledMoney[i] > 0 then begin
      share[i] := GDVars.pooledMoney[i] div cnt;
      rem[i] := GDVars.pooledMoney[i] mod cnt;
    end else begin
      share[i] := 0;
      rem[i] := 0;
    end;
  while p <> nil do begin
    if p^.npc < C_Npc.NON_PLAYER then
      for i := 2 downto 0 do
        if not Money.CheckOverload(p, share[i], takable) then begin
          p^.coins[i] := share[i] + p^.coins[i];
          Money.AddWeight(p, share[i]);
          if rem[i] > 0 then
            if not Money.CheckOverload(p, 1, takable) then begin
              p^.coins[i] := p^.coins[i] + 1;
              Money.AddWeight(p, 1);
              Dec(rem[i]);
            end;
        end else begin
          p^.coins[i] := p^.coins[i] + takable;
          rem[i] := rem[i] + share[i] - takable;
          Money.AddWeight(p, takable);
        end;
    p := p^.next;
  end;
  for i := 2 downto 0 do
    if rem[i] > 0 then begin
      p := GDVars.partyHead;
      while p <> nil do begin
        takable := Money.CarryingCapacity(p) - p^.encumbrance;
        if takable > 0 then
          if rem[i] > takable then begin
            p^.coins[i] := p^.coins[i] + takable;
            Money.AddWeight(p, takable);
            rem[i] := rem[i] - takable;
          end else begin
            p^.coins[i] := p^.coins[i] + rem[i];
            Money.AddWeight(p, rem[i]);
            rem[i] := 0;
          end;
        p := p^.next;
      end;
    end;
  GDVars.poolHasMoney := False;
  for i := 0 to 2 do begin
    GDVars.pooledMoney[i] := rem[i];
    if GDVars.pooledMoney[i] <> 0 then
      GDVars.poolHasMoney := True;
  end;
end;

procedure DropMoney(p: Types.PCharacter; qty: LongInt; mType: ShortInt);
begin
  Types.PCharacter(p)^.coins[mType] := Types.PCharacter(p)^.coins[mType] - qty;
  Money.RemoveWeight(p, qty);
  if (GDVars.locState.current = C_Ifc.LOOT) or (GDVars.locState.current = C_Ifc.IN_SHOP) or
      (GDVars.locState.current = C_Ifc.IN_VAULT) then
    GDVars.pooledMoney[mType] := GDVars.pooledMoney[mType] + qty;
end;

{ Moves money from the pool to a character, at most what the pool holds; an amount that would overload the character is
  refused whole: "Overloaded" is shown, the game pauses and the keyboard is flushed. Note: the overload test uses the
  amount asked for, before it is cut down to what the pool holds.
  @param(p The character.)
  @param(qty The amount asked for.)
  @param(mType The money type.) }
procedure TakeMoney(p: Types.PCharacter; qty: LongInt; mType: ShortInt);
var takable: LongInt;
begin
  if Money.CheckOverload(p, qty, takable) then begin
    CharHlp.PrintBottomLine('Overloaded');
    TextRend.PauseOnly;
    GameIo.DrainKeys;
  end else begin
    if qty > GDVars.pooledMoney[mType] then
      qty := GDVars.pooledMoney[mType];
    GDVars.pooledMoney[mType] := GDVars.pooledMoney[mType] - qty;
    Types.PCharacter(p)^.coins[mType] := Types.PCharacter(p)^.coins[mType] + qty;
    Money.AddWeight(p, qty);
  end;
end;

function ParseMoneyType(s: String; var typeName: String): ShortInt;
var i: Byte;
begin
  i := 1;
  while s[i] = ' ' do Inc(i);
  case s[i] of
    'G': begin
      ParseMoneyType := 1;
      typeName := 'Gems ';
    end;
    'P': begin
      typeName := 'Platinum ';
      ParseMoneyType := 0;
    end;
    'J': begin
      typeName := 'Jewelry ';
      ParseMoneyType := 2;
    end;
  end;
end;

procedure TakeMoneyMenu;
var
  i: ShortInt;
  mType: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  weight: Word;
  p: Types.PItem;
  sel: Types.PItem;
  save: Types.PItem;
  cnt: Word;
  idx: Integer;
  numStr: String;
  n: Word;
  exitF: Boolean;
  redraw: Boolean;
  ch: Char;
begin
  Border.DrawWindowFrame(1);
  idx := 0;
  repeat
    redraw := True;
    p := nil;
    sel := nil;
    for i := 0 to 2 do
      if GDVars.pooledMoney[i] > 0 then begin
        Inc(cnt);
        if p = nil then begin
          GetMem(p, SizeOf(Types.TItemRec));
          p^.next := nil;
        end else begin
          sel := p;
          GetMem(p, SizeOf(Types.TItemRec));
          p^.next := sel;
        end;
        Str(GDVars.pooledMoney[i], numStr);
        p^.name := GDConsts.wealthNames[i] + ' ' + numStr;
        p^.inUse := 0;
      end;
    sel := p;
    save := p;
    MenuCore.ResetMenuSlots(1);
    ch := MenuCore.MenuVertical(GDConsts.tradeQuery, GDConsts.selectMenu, 2, 2, 15, 8, Types.PItemRec(p), True, 0,
                                redraw, idx,
                       Pointer(sel));
    if (sel = nil) or (ch = #1) or (GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE)) then
      exitF := True
    else begin
      exitF := False;
      mType := Money.ParseMoneyType(sel^.name, numStr);
      if mType = 1 then
        numStr := GDConsts.howManyText + numStr + GDConsts.willTakeText
      else
        numStr := GDConsts.howMuchText + numStr + GDConsts.willTakeText;
      n := Money.InputNumberMax(GDVars.pooledMoney[mType], numStr, 10);
      Money.TakeMoney(GDVars.curChar, n, mType);
      MenuCore.FreeStringList(Pointer(save));
      GDVars.poolHasMoney := False;
      exitF := True;
      for i := 0 to 2 do
        if GDVars.pooledMoney[i] > 0 then begin
          GDVars.poolHasMoney := True;
          exitF := False;
        end;
    end;
  until exitF;
end;

procedure DetermineTreasure(var hasMoney, items: Boolean);
var i: ShortInt;
begin
  hasMoney := False;
  items := False;
  for i := 0 to 2 do
    if GDVars.pooledMoney[i] <> 0 then hasMoney := True;
  if GDVars.treasureItems <> nil then items := True;
end;

procedure AppraiseMenu(var ok: Boolean);
var
  gemStr: String[40];
  jwlStr: String[40];
  ch: Char;
  { Unused in this version; see the other implementations of this routine. }
  menu: String[40];
  { Unused in this version; see the other implementations of this routine. }
  actionStr: String[40];
  r: Byte;
  value: LongInt;
  takable: LongInt;
  p: Types.PItem;
  gem: Types.PItem;
  exitF: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  extendedKey: Byte;
  mustSell: Boolean;
  ext: Boolean;
begin
  ok := True;
  if (GDVars.curChar^.coins[1] = 0) and (GDVars.curChar^.coins[2] = 0) then begin
    CharHlp.PrintBottomLine('No Gems or Jewelry');
    ok := False;
  end else
    repeat
      if (GDVars.curChar^.coins[1] = 0) and (GDVars.curChar^.coins[2] = 0) then
        exitF := True
      else begin
        Border.DrawCharViewFrame;
        exitF := False;
        Str(GDVars.curChar^.coins[1], gemStr);
        Str(GDVars.curChar^.coins[2], jwlStr);
        gemStr := GDConsts.appraiseHeading + gemStr;
        jwlStr := GDConsts.appraisePrompt + jwlStr;
        Border.EraseBox(1, 1, 38, 22);
        CharHlp.DisplayCreatureName(GDVars.curChar, 1, 1, False);
        TextRend.DisplayString(1, 7, White, Black, GDConsts.collectionText);
        TextRend.DisplayString(1, 9, White, Black, gemStr);
        TextRend.DisplayString(1, 10, White, Black, jwlStr);
        FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
        ext := False;
        if GDVars.curChar^.coins[1] <> 0 then MenuCore.AppendSlot(0, Byte(ext));
        if GDVars.curChar^.coins[2] <> 0 then MenuCore.AppendSlot(1, Byte(ext));
        MenuCore.AppendSlot(2, Byte(ext));
        ch := MenuCore.MenuHorizontal(GDConsts.appraiseQuery, GDConsts.appraiseMenuText, Byte(True), Byte(False));
        if GDVars.menuReturnedKey and (ch = C_Keys.ESCAPE) then ch := #2;
        case ch of
          #0: if GDVars.curChar^.coins[1] <> 0 then begin
              Dec(GDVars.curChar^.coins[1]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..25: value := 5;
                26..50: value := 25;
                51..70: value := 50;
                71..90: value := 250;
                91..99: value := 500;
                100: value := 2500;
              end;
              Str(value, gemStr);
              gemStr := GDConsts.gemValueText + gemStr + ' platinum.';
              TextRend.DisplayString(1, 12, White, Black, gemStr);
              FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
              GDVars.menuSlots[0].optionId := 0;
              if Money.CheckOverload(GDVars.curChar, 1, takable) or (GDVars.curChar^.numberOfItems >= 16) then begin
                mustSell := True;
              end else begin
                GDVars.menuSlots[1].optionId := 1;
                mustSell := False;
              end;
              ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.actionMenuText, Byte(False), Byte(False));
              if (ch = #1) and not mustSell then begin
                gem := Types.PItem(GameIo.AllocSlot);
                GameIo.ZeroFill(gem^, SizeOf(Types.TItem));
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 122;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.items;
                if p = nil then p := gem
                else begin
                  while p^.next <> nil do p := p^.next;
                  p^.next := gem;
                end;
              end else
                Money.GivePlatinum(value);
            end;
          #1: if GDVars.curChar^.coins[2] <> 0 then begin
              Dec(GDVars.curChar^.coins[2]);
              r := FxEngine.RollDice(1, 100);
              case r of
                1..10: value := Trunc(Random(450)) + 50;
                11..20: value := Trunc(Random(500)) + 100;
                21..40: value := Trunc(Random(750)) + 150;
                41..50: value := Trunc(Random(1250)) + 250;
                51..70: value := Trunc(Random(2500)) + 500;
                71..90: value := Trunc(Random(3000)) + 1000;
                91..100: value := Trunc(Random(5000)) + 1000;
              end;
              Str(value, jwlStr);
              jwlStr := GDConsts.jewelValueText + jwlStr + ' platinum.';
              TextRend.DisplayString(1, 12, White, Black, jwlStr);
              FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), $FF);
              GDVars.menuSlots[0].optionId := 0;
              if Money.CheckOverload(GDVars.curChar, 1, takable) or (GDVars.curChar^.numberOfItems >= 16) then
                mustSell := True
              else begin GDVars.menuSlots[1].optionId := 1; mustSell := False end;
              ch := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.actionMenuText, Byte(False), Byte(False));
              if (ch = #1) and not mustSell then begin
                gem := Types.PItem(GameIo.AllocSlot);
                GameIo.ZeroFill(gem^, SizeOf(Types.TItem));
                gem^.next := nil;
                gem^.equipped := 0;
                gem^.nameIds[3] := 123;
                gem^.nameIds[2] := 0;
                gem^.nameIds[1] := 0;
                gem^.itemType := 47;
                gem^.value := value;
                gem^.weight := 1;
                gem^.unidMask := 0;
                p := GDVars.curChar^.items;
                if p = nil then p := gem
                else begin while p^.next <> nil do p := p^.next; p^.next := gem end;
              end else
                Money.GivePlatinum(value);
            end;
          #2: exitF := True;
        end;
        CharHlp.RecalcStats(GDVars.curChar);
      end;
    until exitF;
end;

begin
end.
