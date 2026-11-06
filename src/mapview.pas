{ MapView -- the view refresh. DisplayMapView redraws the area picture or the 3-D view and clears the pending-refresh
  flag. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit MapView;

interface

{ Refreshes the view pane, unless the party is defeated. With a redraw pending, shows the area's big picture, except at
  location 1 with layout flag 0. Otherwise, in the exploration interface only, draws the 3D view at the party's square
  and facing; in any other interface it returns with the redraw still pending. Clears the pending redraw. }
procedure DisplayMapView;

implementation

uses Types, GDConsts, GDVars, C_Ifc, Portrait, View3D;

procedure DisplayMapView;
var
  value: Byte;
begin
  if GDVars.partyDefeated then
    Exit;
  if ((GDVars.gameState^.location <> 1) or (GDVars.gameState^.layoutFlag <> 0)) and
      (GDVars.pendingRefresh <> 0) then begin
    value := GDConsts.areaPictureIds[GDVars.gameState^.pictureIndex];
    Portrait.LoadBigPic(value);
    Portrait.DisplayBigPic
  end else begin
    if GDVars.locState.current <> C_Ifc.DUNGEON then
      Exit;
    View3D.Display3DMapView(GDVars.partyPos.x, GDVars.partyPos.y, GDVars.partyPos.facing)
  end;
  GDVars.pendingRefresh := 0
end;

begin
end.
