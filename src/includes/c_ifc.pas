{ Interface states (GDVars.locState.current). }
unit C_Ifc;

interface

const
  { the main menu }
  MAIN_MENU = 0;
  { a shop }
  IN_SHOP = 1;
  { camping }
  CAMPING = 2;
  { the overland map, where gameState^.location is 0 }
  AREA_MAP = 3;
  { the 3-D view }
  DUNGEON = 4;
  IN_COMBAT = 5;
  { the treasure screen after combat }
  LOOT = 6;
  { the vault }
  IN_VAULT = 10;

implementation

end.
