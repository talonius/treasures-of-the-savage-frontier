{ Combat-map terrain codes laid by spells and by downed creatures (a cloud or body cell remembers the terrain beneath
  it), and the movement cost of impassable terrain. }
unit C_Terr;

interface

const
  TERRAIN_BLADE_BARRIER = 27;
  TERRAIN_CLOUDKILL = 28;
  TERRAIN_STINK_CLOUD = 29;
  TERRAIN_CORPSE = 31;
  { a terrain movement cost no move can pay }
  TERRAIN_IMPASSABLE = 255;

implementation

end.
