{ Effect ids: TEffect ids, the index of an effect's handler, and indices into the effect names (BORD.DAX block 9) the
  character screen shows. Each comment is that name. }
unit C_Effect;

interface

const
  { Blessed }
  BLESS = 1;
  { Cursed }
  CURSE = 2;
  { Harrassed by Snakes }
  SNAKE_HARASS = 3;
  { Dispelling Evil }
  DISPEL_EVIL = 4;
  { Detecting Magic }
  DETECT_MAGIC = 5;
  { Immune to Electricity }
  IMMUNE_ELECTRICITY = 6;
  { Gnome thac0 bonus }
  GNOME_THAC0_BONUS = 7;
  { Protected from Evil }
  PROTECTION_FROM_EVIL = 8;
  { Charmed }
  CHARM = 11;
  { Enlarged }
  ENLARGE = 12;
  { Slow Poison }
  SLOW_POISON_HIT = 15;
  { Shielded }
  SHIELD = 17;
  { 30% resistant to charm }
  RESIST_CHARM_30 = 18;
  { Fire Resistant (spell) }
  RESIST_FIRE = 20;
  { Silenced }
  SILENCE = 21;
  { Slow poison wears off }
  SLOW_POISON_END = 22;
  { Carries Spiritual Hammer }
  SPIRITUAL_HAMMER = 23;
  { Invisible (spell) }
  INVISIBLE = 25;
  { Dwarf thac0 bonus }
  DWARF_THAC0_BONUS = 26;
  { Confused. Lose Turn }
  CONFUSED_LOSE_TURN = 27;
  { Duplicated }
  MIRROR_IMAGE = 28;
  { Nauseated }
  STINKING_CLOUD_COUGH = 30;
  { Helpless Effect # 31 }
  HELPLESS = 31;
  { Dispel Evil On }
  DISPEL_EVIL_TOUCH = 32;
  { Blind }
  BLIND = 33;
  { Diseased }
  DISEASED = 34;
  { Confused }
  CONFUSED = 35;
  { Accursed }
  BESTOW_CURSE = 36;
  { Strengthened }
  STRENGTH = 38;
  { Hastened }
  HASTED = 39;
  { Protected from Normal Missiles }
  PROTECTION_FROM_MISSILES = 41;
  { Slowed }
  SLOWED = 42;
  { Disease Strength Lose }
  DISEASE_STRENGTH = 43;
  { Disease Health Lose }
  DISEASE_HIT_POINTS = 44;
  { Dwarf Giant Bonus }
  DWARF_GIANT_BONUS = 47;
  { Gnome Large Monster Bonus }
  GNOME_LARGE_MONSTER_BONUS = 48;
  { Affected by Prayer }
  PRAYER = 49;
  { Fire Shield, Hot flames }
  FIRE_SHIELD_HOT = 50;
  { Helpless Effect #51 }
  HELPLESS_51 = 51;
  { Held }
  HELD = 52;
  { Asleep }
  ASLEEP = 53;
  { Fire Shield, Cold flames }
  FIRE_SHIELD_COLD = 54;
  { POISONED }
  POISONED = 55;
  { Enveloped in Globe of Invulnerability }
  GLOBE_OF_INVULNERABILITY = 57;
  { +3 weapons or better to hit }
  HIT_BY_PLUS_3_ONLY = 60;
  { Within Minor Globe of Invulnerability }
  MINOR_GLOBE = 63;
  { Deadly Poison Attack }
  DEADLY_POISON_ATTACK = 64;
  { half damage from pierce/cut weapons }
  HALF_DAMAGE_PIERCE_CUT = 66;
  { half damage from crushing weapons }
  HALF_DAMAGE_CRUSH = 67;
  { Mentally Enfeebled }
  FEEBLEMIND = 68;
  { Wearing Magical Boots }
  MAGIC_BOOTS = 74;
  { Confused }
  CONFUSED_BERSERK = 77;
  { luck stone }
  LUCK_STONE = 80;
  { half damage fro weapons < +3 }
  HALF_DAMAGE_WEAPONS_UNDER_PLUS_3 = 81;
  { big red dragon breath }
  BIG_RED_DRAGON_BREATH = 83;
  { red dragon breath }
  RED_DRAGON_BREATH = 84;
  { white dragon breath }
  WHITE_DRAGON_BREATH = 85;
  { green dragon breath }
  GREEN_DRAGON_BREATH = 90;
  { blue dragon breath }
  BLUE_DRAGON_BREATH = 91;
  { immune to fear }
  IMMUNE_FEAR = 92;
  { immune to fire }
  IMMUNE_FIRE = 93;
  { 90% resistant to sleep/charm }
  RESIST_SLEEP_CHARM_90 = 95;
  { black dragon breath }
  BLACK_DRAGON_BREATH = 96;
  { dwarven save bonus }
  CON_SPELL_SAVE_BONUS = 97;
  { drain 1 level }
  DRAIN_ONE_LEVEL = 101;
  { immune to nonmagical weapons }
  IMMUNE_NONMAGIC = 103;
  { bonus damage from rangers }
  RANGER_BONUS_DAMAGE = 105;
  { Stunned }
  STUNNED = 106;
  { Berserk }
  BERSERK = 107;
  { FRIGHTENED }
  FRIGHTENED = 111;
  { fire shield }
  FIRE_SHIELD = 112;
  { Giant Strength }
  GIANT_STRENGTH = 113;
  { Dancing }
  DANCING = 118;
  { Resist Fire (Druid) }
  RESIST_FIRE_DRUID = 119;
  { affected by dragon fear }
  DRAGON_FEARED = 120;
  { immune to weapons < +2 }
  IMMUNE_WEAPONS_UNDER_PLUS_2 = 125;
  { immune to gaze attacks }
  IMMUNE_GAZE = 126;
  { Red Crystal }
  RED_CRYSTAL = 128;
  { Green Crystal }
  GREEN_CRYSTAL = 129;
  { Blue Crystal }
  BLUE_CRYSTAL = 130;
  { In love }
  IN_LOVE = 131;
  { Kampfult tentacles }
  KAMPFULT_TENTACLES = 144;
  { Stone creature }
  STONE_CREATURE = 147;
  { Yetti squeeze 3 }
  YETI_SQUEEZE_3 = 151;
  { Cannot Move }
  CANNOT_MOVE = 156;

implementation

end.
