{ Shop -- the general store: purchasing and party-fund management.

  ShopMainMenu draws the noncombat store screen and offers Buy, View, Take, Pool, Share, Appraise, and Exit. Entering a
  store clears the pooled-money account; the player must explicitly Pool the party's funds before pooled money can pay
  for a purchase. Exiting with money still pooled requires confirmation.

  ShopBuyItemSelection formats the store inventory as a priced vertical menu. The price setting scales an item's value
  from one-sixteenth through eight times its base value, after which quantity is applied and the result is clamped to at
  least one. Payment uses the current character's platinum (coin type 0) first, then the pooled platinum.

  GiveItemCopyToCreature checks encumbrance, allocates and copies the inventory record, links it into the character's
  item chain, and recalculates derived statistics. }
{$O+,F+,S+,R-,V-,B-,I-}
unit Shop;

interface

{ Runs a store: the money pool starts empty and the store's goods are the treasure item list. The menu offers View,
  Pool, Appraise and Exit, plus Take and Share while the pool holds money and Buy while the store holds items; the up
  and down arrow keys change the current character; leaving with money in the pool asks first. }
procedure ShopMainMenu;

{ Appends a copy of an item to the current character's items, joins a stackable item into matching stacks and
  recalculates the character's stats; a character who cannot carry it is reported as overloaded instead. Note: when the
  character had no items, the stack is joined through a pointer that was never set.
  @param(sourceItem The item to copy.)
  @param(overloaded Set when the character cannot carry the item, cleared otherwise.) }
procedure GiveItemCopyToCreature(sourceItem: Pointer; var overloaded: Boolean);

implementation

uses Types, ViewChar, Money, CharHlp, MenuCore, Border, GameIo, TextRend, Crt, GDConsts, GDVars, C_Keys, C_Ifc;

const
  { GDVars.gameState^.priceScale values: the price as sixteenths of the item's value }
  PRICE_SCALE_SIXTEENTH = 1;
  PRICE_SCALE_EIGHTH = 2;
  PRICE_SCALE_QUARTER = 4;
  PRICE_SCALE_HALF = 8;
  PRICE_SCALE_BASE = 16;
  PRICE_SCALE_DOUBLE = 32;
  PRICE_SCALE_QUADRUPLE = 64;
  PRICE_SCALE_OCTUPLE = 128;
  { the store menu's choices }
  STORE_OPTION_BUY = #0;
  STORE_OPTION_VIEW = #1;
  STORE_OPTION_TAKE = #2;
  STORE_OPTION_POOL = #3;
  STORE_OPTION_SHARE = #4;
  STORE_OPTION_APPRAISE = #5;
  STORE_OPTION_EXIT = #6;

  { seven store commands }

{ Shows the current character's funds and the pooled funds on rows 20 and 21. }
procedure DisplayShopMoney;
var
  { Unused in this version; see the other implementations of this routine. }
  alignmentByte: Byte;
  fundsText: String[10];
begin
  Str(GDVars.curChar^.coins[0], fundsText);
  TextRend.RightAlignString(fundsText, 10);
  TextRend.DisplayText(1, 20, White, Black, 'Personal funds:' + fundsText);
  Str(GDVars.pooledMoney[0], fundsText);
  TextRend.RightAlignString(fundsText, 10);
  TextRend.DisplayText(1, 21, White, Black, 'Pooled funds:  ' + fundsText);
end;

{ Writes each item's price, right-aligned, into its name, runs the vertical menu over the shop's items and restores the
  names. Price level 1, 2, 4 or 8 divides the value by 16, 8, 4 or 2; $20, $40 or $80 multiplies it by 2, 4 or 8;
  anything else is the value. A stack costs its quantity times as much and nothing costs less than 1.
  @param(choice Receives the key that ended the menu.)
  @param(chosen Receives the item under the cursor when the menu ended.)
  @param(selectedNode The menu's cursor row, kept between calls.)
  @param(listIndex The menu's scroll position, kept between calls.) }
procedure ShopBuyItemSelection(var choice: Char; var chosen: Types.PItem; var selectedNode: Pointer;
                               var listIndex: Integer);
var
  menuHead: Pointer;
  node: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  alignmentByte: Byte;
  priceStr: String[16];
  { Unused in this version; see the other implementations of this routine. }
  alignmentByte2: Byte;
  priceLine: String[30];
  textLength: Byte;
  characterIndex: Byte;
  scaledPrice: Word;
begin
  node := GDVars.treasureItems;
  while node <> nil do begin
    priceLine := GDConsts.blankPriceLine;
    if node^.value = 0 then
      node^.value := 1;
    case GDVars.gameState^.priceScale of
      Shop.PRICE_SCALE_SIXTEENTH: scaledPrice := node^.value div 16;
      Shop.PRICE_SCALE_EIGHTH: scaledPrice := node^.value div 8;
      Shop.PRICE_SCALE_QUARTER: scaledPrice := node^.value div 4;
      Shop.PRICE_SCALE_HALF: scaledPrice := node^.value div 2;
      Shop.PRICE_SCALE_DOUBLE: scaledPrice := node^.value shl 1;
      Shop.PRICE_SCALE_QUADRUPLE: scaledPrice := node^.value * 4;
      Shop.PRICE_SCALE_OCTUPLE: scaledPrice := node^.value * 8;
      else scaledPrice := node^.value;
    end;
    if node^.quantity > 1 then
      scaledPrice := node^.quantity * scaledPrice;
    if scaledPrice = 0 then
      scaledPrice := 1;
    Str(scaledPrice, priceStr);
    textLength := Length(priceStr);
    for characterIndex := 1 to textLength do
      priceLine[30 - textLength + characterIndex] := priceStr[characterIndex];
    textLength := Length(node^.name);
    for characterIndex := 1 to textLength do
      priceLine[characterIndex] := node^.name[characterIndex];
    node^.name := priceLine;
    node^.name[0] := #30;
    node := node^.next;
  end;
  menuHead := Pointer(GDVars.treasureItems);
  GDVars.horizChoice := 0;
  MenuCore.ResetMenuSlots(0);
  choice := MenuCore.MenuVertical(GDConsts.itemsPrompt, GDConsts.buyMenu, 1, 1, 38, 18, menuHead, True, 0,
                                  GDVars.menuNeedsRedraw, listIndex, selectedNode);
  chosen := Types.PItem(selectedNode);
  node := GDVars.treasureItems;
  while node <> nil do begin
    CharHlp.PrintItemString(nil, Types.PItem(node), 0, 0, False, False);
    node := node^.next;
  end;
end;

procedure GiveItemCopyToCreature(sourceItem: Pointer; var overloaded: Boolean);
var
  node: Types.PItem;
  tailNode: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  alignmentByte: Byte;
begin
  if ViewChar.CannotCarryItem(GDVars.curChar, 1, sourceItem) then begin
    CharHlp.PrintBottomLine('OverLoaded');
    overloaded := True;
    Exit;
  end;
  overloaded := False;
  node := GDVars.curChar^.items;
  if node = nil then begin
    node := Types.PItem(GameIo.AllocSlot);
    node^ := Types.PItem(sourceItem)^;
    node^.next := nil;
    GDVars.curChar^.items := node;
  end else begin
    while node^.next <> nil do
      node := node^.next;
    tailNode := Types.PItem(GameIo.AllocSlot);
    tailNode^ := Types.PItem(sourceItem)^;
    tailNode^.next := nil;
    node^.next := tailNode;
  end;
  if Types.PItem(sourceItem)^.quantity > 0 then
    ViewChar.JoinItem(tailNode);
  CharHlp.RecalcStats(GDVars.curChar);
end;

{ The Buy menu: price the chosen item and pay for it from the character's funds, then from the pool, until Escape. }
procedure ShopBuyMenu;
var
  chosen: Types.PItem;
  choice: Char;
  exitFlag: Boolean;
  scaledPrice: Word;
  personalFunds: Word;
  pooledFunds: LongInt;
  overloaded: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  alignmentByte: Byte;
  selectedNode: Pointer;
  listIndex: Integer;
begin
  chosen := nil;
  selectedNode := Pointer(GDVars.treasureItems);
  listIndex := 0;
  Border.DrawWindowFrame(0);
  GDVars.menuNeedsRedraw := True;
  repeat
    Shop.DisplayShopMoney;
    Shop.ShopBuyItemSelection(choice, chosen, selectedNode, listIndex);
    if (choice = C_Keys.ESCAPE) and GDVars.menuReturnedKey then
      exitFlag := True
    else begin
      exitFlag := False;
      { Unlike ShopBuyItemSelection, this case has no else. An unrecognized setting leaves scaledPrice uninitialized
        before quantity and payment use. }
      case GDVars.gameState^.priceScale of
        Shop.PRICE_SCALE_SIXTEENTH: scaledPrice := chosen^.value div 16;
        Shop.PRICE_SCALE_EIGHTH: scaledPrice := chosen^.value div 8;
        Shop.PRICE_SCALE_QUARTER: scaledPrice := chosen^.value div 4;
        Shop.PRICE_SCALE_HALF: scaledPrice := chosen^.value div 2;
        Shop.PRICE_SCALE_BASE: scaledPrice := chosen^.value;
        Shop.PRICE_SCALE_DOUBLE: scaledPrice := chosen^.value shl 1;
        Shop.PRICE_SCALE_QUADRUPLE: scaledPrice := chosen^.value * 4;
        Shop.PRICE_SCALE_OCTUPLE: scaledPrice := chosen^.value * 8;
      end;
      if chosen^.quantity > 1 then
        scaledPrice := chosen^.quantity * scaledPrice;
      if scaledPrice = 0 then
        scaledPrice := 1;
      personalFunds := GDVars.curChar^.coins[0];
      pooledFunds := GDVars.pooledMoney[0];
      if scaledPrice <= personalFunds then begin
        Shop.GiveItemCopyToCreature(chosen, overloaded);
        if not overloaded then begin
          Dec(GDVars.curChar^.coins[0], scaledPrice);
          if chosen^.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.curChar^.name + GDConsts.buysSuffix + chosen^.name)
          else
            CharHlp.PrintBottomLine(GDVars.curChar^.name + GDConsts.buysASuffix + chosen^.name);
        end;
      end else if scaledPrice <= personalFunds + pooledFunds then begin
        Shop.GiveItemCopyToCreature(chosen, overloaded);
        if not overloaded then begin
          GDVars.curChar^.coins[0] := 0;
          Dec(GDVars.pooledMoney[0], scaledPrice - personalFunds);
          if chosen^.quantity > 0 then
            CharHlp.PrintBottomLine(GDVars.curChar^.name + GDConsts.buysSuffix + chosen^.name)
          else
            CharHlp.PrintBottomLine(GDVars.curChar^.name + GDConsts.buysASuffix + chosen^.name);
        end;
      end else
        CharHlp.PrintBottomLine(GDConsts.notEnoughMoneyMsg);
    end;
  until exitFlag;
end;

procedure ShopMainMenu;
var
  viewCompleted: Byte;
  exitFlag: Boolean;
  slotCount: Byte;
  slotIndex: Byte;
  choice: Char;
  moneyPresent: Boolean;
  itemsPresent: Boolean;
  appraiseRedraw: Boolean;
  node: Types.PItem;
  defaultSelection: Byte;
begin
  GDVars.locState.previous := GDVars.locState.current;
  GDVars.locState.current := C_Ifc.IN_SHOP;
  GDVars.splitFrameGate := 0;
  CharHlp.DisplayNoncombatInterface;
  GDVars.splitFrameGate := 1;
  CharHlp.DisplayParty(GDVars.curChar);
  GameIo.ZeroFill(GDVars.pooledMoney, SizeOf(GDVars.pooledMoney));
  GDVars.poolHasMoney := False;
  exitFlag := False;
  node := GDVars.treasureItems;
  while node <> nil do begin
    CharHlp.PrintItemString(nil, Types.PItem(node), 0, 0, False, False);
    node := node^.next;
  end;
  defaultSelection := Ord(Shop.STORE_OPTION_VIEW);
  repeat
    Money.DetermineTreasure(moneyPresent, itemsPresent);
    slotCount := 0;
    for slotIndex := 0 to Ord(Shop.STORE_OPTION_EXIT) do
      case slotIndex of
        Ord(Shop.STORE_OPTION_TAKE), Ord(Shop.STORE_OPTION_SHARE):
          if moneyPresent then
            MenuCore.AppendSlot(slotIndex, slotCount);
        Ord(Shop.STORE_OPTION_BUY):
          if itemsPresent then
            MenuCore.AppendSlot(slotIndex, slotCount);
        else
          MenuCore.AppendSlot(slotIndex, slotCount)
      end;
    GDVars.horizChoice := defaultSelection;
    choice := MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.storeMenuItems, Byte(True), Byte(False));
    defaultSelection := GDVars.horizChoice;
    if GDVars.menuReturnedKey then
      case choice of
        C_Keys.UP, C_Keys.DOWN: begin
          ViewChar.SelectPrevNextChar(choice);
          choice := #255;
        end;
        C_Keys.ESCAPE: choice := Shop.STORE_OPTION_EXIT;
      end;
    case choice of
      Shop.STORE_OPTION_BUY: Shop.ShopBuyMenu;
      Shop.STORE_OPTION_VIEW: ViewChar.ViewCharMenu(viewCompleted);
      Shop.STORE_OPTION_TAKE: Money.TakeMoneyMenu;
      Shop.STORE_OPTION_POOL: Money.PoolMoney;
      Shop.STORE_OPTION_SHARE: Money.ShareMoney;
      Shop.STORE_OPTION_APPRAISE: Money.AppraiseMenu(appraiseRedraw);
      Shop.STORE_OPTION_EXIT: begin
        Money.DetermineTreasure(moneyPresent, itemsPresent);
        if moneyPresent then begin
          TextRend.DisplayMessageWindow(1, 17, 38, 22, LightGreen, Black, True, GDConsts.leftMoneyMsg);
          TextRend.DisplayMessageWindow(1, 17, 38, 22, White, Black, False, GDConsts.goBackForMoneyPrompt);
          if MenuCore.YesNoMenu(GDConsts.emptyQuery, GDConsts.yesChoice) = GDConsts.noChoice then
            exitFlag := True
          else
            Border.EraseBox(1, 17, 38, 22);
        end else
          exitFlag := True;
      end;
    end;
    { A first Pool choice reads uninitialized appraiseRedraw; after Appraise, a later Pool choice reads Appraise's stale
      result. }
    case choice of
      Shop.STORE_OPTION_BUY, Shop.STORE_OPTION_TAKE, Shop.STORE_OPTION_APPRAISE:
        CharHlp.DisplayNoncombatInterface;
      Shop.STORE_OPTION_POOL:
        if appraiseRedraw then CharHlp.DisplayNoncombatInterface;
    end;
    CharHlp.DisplayParty(GDVars.curChar);
  until exitFlag;
  GDVars.locState.current := GDVars.locState.previous;
end;

begin
end.
