{ Class values (TCharacter.charClass), in GDConsts.classNameTable's order: single classes 0..7, then multiclass
  combinations 8..16. A single class also indexes a character's classLevels. }
unit C_Class;

interface

const
  CLERIC = 0;
  FIGHTER = 2;
  PALADIN = 3;
  RANGER = 4;
  MAGE = 5;
  THIEF = 6;
  CLERIC_FIGHTER = 8;
  CLERIC_FIGHTER_MAGE = 9;
  CLERIC_RANGER = 10;
  FIGHTER_THIEF = 14;
  FIGHTER_MAGE_THIEF = 15;
  MAGE_THIEF = 16;
  { no class: ClassCal.ChangeClass's result when the class did not change }
  NO_CLASS = 17;

implementation

end.
