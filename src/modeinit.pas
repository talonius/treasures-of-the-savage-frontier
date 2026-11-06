{ At start-up, copies the automap password, item-name part 122 ('Gem'), into GDVars.automapPassword, which Explore
  compares: a third command-line parameter equal to it shows the automap on a hidden map. }
{$F+,S+,A+}
unit ModeInit;

interface

implementation

uses GDConsts, GDVars;

begin
  GDVars.automapPassword := GDConsts.itemNameParts[122];
end.
