{ Vault -- the vault, the party's stored treasure, and its "View Take Pool Money Items Exit" menu. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Vault;

interface

{ Runs the vault menu until Exit or Escape, then writes the vault contents back as tmpvault.dat. Does nothing more than
  redraw the party if the save directory is not ready. The treasure list is freed and the vault's money and items are
  loaded into it on entry; the menu offers View, Take (when the vault holds anything), Pool, money deposits (when the
  current character has coins; refused for an NPC), item deposits (when it has items) and Exit, and the up and down
  arrows change the current character. }
procedure PoolVault;

implementation

uses Types, GDConsts, GDVars, C_Keys, C_Ifc, C_Npc, Border, GameIo, PostCbt, SaveLoad, ViewChar, Money, CharHlp,
  MenuCore;

procedure PoolVault;
var
  navKey: Char;
  menuKey: Char;
  { Unused in this version; see the other implementations of this routine. }
  moneyAmount: Word;
  done: Byte;
  moneyPresent: Boolean;
  itemsPresent: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  itemsPresentTail: Byte;
  { Unused in this version; see the other implementations of this routine. }
  menuPosLead: Byte;
  menuPos: Byte;
  actionDone: Byte;
  optionCount: Byte;
  oldNode: Pointer;
begin
  GDVars.locState.current := C_Ifc.IN_VAULT;
  GDVars.splitFrameGate := 1;
  CharHlp.DisplayNoncombatInterface;
  GDVars.splitFrameGate := 1;
  CharHlp.DisplayParty(GDVars.curChar);
  if not SaveLoad.CheckSaveDir then begin
    CharHlp.ClearEncounterState;
    Exit
  end;

  while GDVars.treasureItems <> nil do begin
    oldNode := GDVars.treasureItems;
    GDVars.treasureItems := GDVars.treasureItems^.next;
    GameIo.FreeSlot(oldNode)
  end;
  GDVars.treasureItems := nil;

  SaveLoad.LoadVault(moneyPresent, itemsPresent);
  GDVars.poolHasMoney := False;
  done := 0;
  optionCount := 1;
  repeat
    GameIo.ZeroFill(GDVars.menuSlots, SizeOf(GDVars.menuSlots));
    menuPos := 0;
    MenuCore.AppendSlot(0, menuPos);
    Money.DetermineTreasure(moneyPresent, itemsPresent);
    if moneyPresent or itemsPresent then
      MenuCore.AppendSlot(1, menuPos);
    MenuCore.AppendSlot(2, menuPos);
    if (GDVars.curChar^.coins[0] > 0) or (GDVars.curChar^.coins[1] > 0) or
        (GDVars.curChar^.coins[2] > 0) then
      MenuCore.AppendSlot(3, menuPos);
    if GDVars.curChar^.items <> nil then
      MenuCore.AppendSlot(4, menuPos);
    MenuCore.AppendSlot(5, menuPos);

    GDVars.horizChoice := optionCount;
    menuKey := MenuCore.MenuHorizontal('', GDConsts.vaultMenuItems, 1, 0);
    optionCount := GDVars.horizChoice;
    if GDVars.menuReturnedKey and (menuKey = C_Keys.ESCAPE) then begin
      GDVars.menuReturnedKey := False;
      menuKey := #5
    end;
    actionDone := 0;

    if not GDVars.menuReturnedKey then begin
      case Ord(menuKey) of
        0: ViewChar.ViewCharMenu(actionDone);
        1: PostCbt.LootTakeMenu(moneyPresent, itemsPresent);
        2: Money.PoolMoney;
        3:
          if (GDVars.curChar^.npc < C_Npc.NON_PLAYER) or
              (GDVars.curChar^.npc = C_Npc.ANIMATED_PLAYER) then begin
            ViewChar.DropMoneyMenu(0);
            Border.EraseBox(1, 17, 38, 22)
          end else
            CharHlp.PrintCreatureMessage(GDVars.curChar, 'Is an NPC', 10, 0);
        4: begin
          ViewChar.UseItemMenu(actionDone);
          CharHlp.DisplayNoncombatInterface
        end;
        5: done := 1
      end
    end else begin
      navKey := menuKey;
      if (navKey = C_Keys.DOWN) or (navKey = C_Keys.UP) then begin
        CharHlp.PrintMiscInfo(GDVars.curChar, 0);
        ViewChar.SelectPrevNextChar(menuKey);
        CharHlp.PrintMiscInfo(GDVars.curChar, 1)
      end
    end
  until done <> 0;
  SaveLoad.WriteVaultFile(GDVars.configLine1 + 'tmpvault.dat');
  CharHlp.ClearEncounterState
end;

begin
end.
