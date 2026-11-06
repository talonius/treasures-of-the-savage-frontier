{ Romance -- the relationship between party member A and NPC B, whose names the GBVM holds as 0-terminated strings
  (PartySideName and NpcSideName). When gameState's npcNumber is set, A and B each get effect 131 (In love) while in the
  party, and every other member loses it. When A and B are both in play and partyLove or npcLove moves to a new band of
  25 (0..4), the LUCK.DAX text for the pair of bands (partyLove/npcLove) is shown; 0/0 shows nothing. B leaves at bands
  0/4 and 4/0, or when A rejects the proposal B makes at 4/4. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit Romance;
interface

{ When A and B are both in play and either love band has changed, record the bands and show the entry for the pair
  (101..113). Bands 0/4 or 4/0: B leaves the party (104). Bands 4/4: B proposes (114) over picture PIC 131. Accept
  (115); Reject (116, 117) makes B leave and costs A 6 points of charisma (base and current), setting A's effect 131
  active. }
procedure UpdateRelationship;

{ Finds the two sides of the romance in the party by name, gives each the In love effect if it lacks it, and takes it
  from everyone else. Nothing happens, beyond forgetting the pair, unless the game state names an NPC. }
procedure TagRelationshipPair;
implementation
uses Types, Crt, GDConsts, GDVars, C_Effect, CharGen, FxEngine, CharHlp,
  MenuCore, Portrait, Border, TextRend, ZeroFree, DaxIo, C_Stat;

{ Reads the NPC's name, the zero-terminated string at GBVM byte $F5 of the game state.
  @returns(The name.) }
function NpcSideName: String;
var s: String; i: Byte;
begin
  s := ''; i := 0;
  while GDVars.gameState^.gbvm[$F5 + i] <> 0 do begin
    s := s + Chr(GDVars.gameState^.gbvm[$F5 + i]); Inc(i)
  end;
  NpcSideName := s
end;

{ Reads the party member's name, the zero-terminated string at GBVM byte $E5 of the game state.
  @returns(The name.) }
function PartySideName: String;
var s: String; i: Byte;
begin
  s := ''; i := 0;
  while GDVars.gameState^.gbvm[$E5 + i] <> 0 do begin
    s := s + Chr(GDVars.gameState^.gbvm[$E5 + i]); Inc(i)
  end;
  PartySideName := s
end;

{ Names the side whose love is greater.
  @returns(The party member's name when its love is greater than the NPC's, else the NPC's.) }
function StrongerName: String;
begin
  if GDVars.gameState^.partyLove > GDVars.gameState^.npcLove then StrongerName := Romance.PartySideName
  else StrongerName := Romance.NpcSideName
end;

{ Gives the possessive pronoun of the side whose love is greater, by that character's gender.
  @returns('HIS' or 'HER'.) }
function StrongerPronoun: String;
var p: Types.PCharacter;
begin
  if GDVars.gameState^.partyLove >
      GDVars.gameState^.npcLove then p := GDVars.relationA else p := GDVars.relationB;
  if p^.gender = 0 then StrongerPronoun := 'HIS' else StrongerPronoun := 'HER'
end;

{ Gives the possessive pronoun of the side whose love is not greater, by that character's gender.
  @returns('HIS' or 'HER'.) }
function WeakerPronoun: String;
var p: Types.PCharacter;
begin
  if GDVars.gameState^.partyLove <=
      GDVars.gameState^.npcLove then p := GDVars.relationA else p := GDVars.relationB;
  if p^.gender = 0 then WeakerPronoun := 'HIS' else WeakerPronoun := 'HER'
end;

{ Names the side whose love is not greater.
  @returns(The party member's name when its love is at most the NPC's, else the NPC's.) }
function WeakerName: String;
begin
  if GDVars.gameState^.partyLove <= GDVars.gameState^.npcLove then WeakerName := Romance.PartySideName
  else WeakerName := Romance.NpcSideName
end;

{ Names a third party member: the first one in play who is neither side of the pair nor the one named last time,
  remembered in GDConsts.otherPartyMember; failing that the one remembered, if still in play, else the party leader.
  @returns(The name.) }
function OtherPartyName: String;
var p: Types.PCharacter;
begin
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p^.inPlay <> 0) and (p <> GDVars.relationA) and (p <> GDConsts.otherPartyMember) and
        (p <> GDVars.relationB) then begin
      GDConsts.otherPartyMember := p; OtherPartyName := p^.name; Exit
    end;
    p := p^.next
  end;
  if (GDConsts.otherPartyMember <> nil) and (GDConsts.otherPartyMember^.inPlay <> 0) and
      (GDConsts.otherPartyMember <> GDVars.relationA)
  then OtherPartyName := GDConsts.otherPartyMember^.name else OtherPartyName := GDVars.partyHead^.name
end;

{ Shows a LUCK.DAX entry in the message window, upper-cased, then waits for a key. Codes 2 to 8 insert the stronger and
  weaker names, the NPC's and the party member's names, a third member's name and the two pronouns; 12 waits for a key
  and clears the window, 13 breaks the line, and 10 and 26 are skipped.
  @param(fileId The entry.) }
procedure ShowLuckEntry(fileId: Word);
var
  i: Word;
  sizeRead: Word; data: Types.PByteBuffer; line: String;
begin
  DaxIo.LoadDaxRetrying('LUCK', '.dax', fileId, sizeRead, data);
  i := 0;
  TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, True, '');
  line := '';
  while i < sizeRead do begin
    case data^[i] of
      2: line := line + Romance.StrongerName;
      3: line := line + Romance.WeakerName;
      4: line := line + Romance.NpcSideName;
      5: line := line + Romance.PartySideName;
      6: line := line + Romance.OtherPartyName;
      7: line := line + Romance.StrongerPronoun;
      8: line := line + Romance.WeakerPronoun;
      12: begin
        if line <> '' then TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, False, line);
        MenuCore.WaitContinueClear; TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, True,
                                                                  ''); line := ''
      end;
      13: begin
        if line <> '' then
          TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, False, line + ' ');
        line := ''
      end;
      26, 10: ;
    else line := line + UpCase(Char(data^[i])) end;
    Inc(i)
  end;
  if line <> '' then TextRend.DisplayMessageWindow(1, 25, 38, 29, LightGreen, Black, True, line);
  ZeroFree.PrefixFree(data, sizeRead); MenuCore.WaitContinueClear
end;

{ Grades a love value in bands of 25.
  @param(value The love value.)
  @returns(The band, 0..4.) }
function RelationBand(value: Word): Word;
var n: Word;
begin
  n := value div 25; if n >= 4 then n := 4; RelationBand := n
end;

procedure TagRelationshipPair;
var node: Pointer; p: Types.PCharacter;
begin
  GDVars.relationB := nil; GDVars.relationA := nil;
  if GDVars.gameState^.npcNumber = 0 then Exit;
  p := GDVars.partyHead;
  while p <> nil do begin
    if p^.name = Romance.NpcSideName then GDVars.relationB := p;
    if p^.name = Romance.PartySideName then GDVars.relationA := p;
    p := p^.next
  end;
  if GDVars.relationB <> nil then
    if not CharHlp.HasEffect(GDVars.relationB, C_Effect.IN_LOVE, node) then
      FxEngine.AddEffect(GDVars.relationB, C_Effect.IN_LOVE, 0, 0, False);
  if GDVars.relationA <> nil then
    if not CharHlp.HasEffect(GDVars.relationA, C_Effect.IN_LOVE, node) then
      FxEngine.AddEffect(GDVars.relationA, C_Effect.IN_LOVE, 0, 0, False);
  p := GDVars.partyHead;
  while p <> nil do begin
    if (p <> GDVars.relationB) and (p <> GDVars.relationA) and
        CharHlp.HasEffect(p, C_Effect.IN_LOVE, node) then FxEngine.RemoveEffect(p, C_Effect.IN_LOVE, nil);
    p := p^.next
  end
end;

procedure UpdateRelationship;
var node: Pointer;
begin
  Romance.TagRelationshipPair;
  if (GDVars.relationB = nil) or (GDVars.relationA = nil) then Exit;
  if (GDVars.relationB^.inPlay = 0) or (GDVars.relationA^.inPlay = 0) or
      ((Romance.RelationBand(GDVars.gameState^.npcLove) = GDVars.gameState^.npcLoveBand) and
       (Romance.RelationBand(GDVars.gameState^.partyLove) = GDVars.gameState^.partyLoveBand)) then Exit;
  GDVars.gameState^.npcLoveBand := Romance.RelationBand(GDVars.gameState^.npcLove);
  GDVars.gameState^.partyLoveBand := Romance.RelationBand(GDVars.gameState^.partyLove);
  Border.EraseBox(1, 25, 38, 29);
  case Romance.RelationBand(GDVars.gameState^.partyLove) of
    0: case Romance.RelationBand(GDVars.gameState^.npcLove) of
      0: Exit;
      1: Romance.ShowLuckEntry(101); 2: Romance.ShowLuckEntry(102); 3: Romance.ShowLuckEntry(103);
      4: begin
        Romance.ShowLuckEntry(104); GDVars.curChar := GDVars.relationB;
        CharGen.RemoveCreature(False,
                               True); GDVars.curChar := GDVars.partyHead; CharHlp.DisplayParty(GDVars.curChar);
        GDVars.curChar := GDVars.partyHead
      end end;
    1: case Romance.RelationBand(GDVars.gameState^.npcLove) of
      0: Romance.ShowLuckEntry(101); 1: Romance.ShowLuckEntry(105); 2: Romance.ShowLuckEntry(106);
      3: Romance.ShowLuckEntry(107); 4: Romance.ShowLuckEntry(108) end;
    2: case Romance.RelationBand(GDVars.gameState^.npcLove) of
      0: Romance.ShowLuckEntry(102); 1: Romance.ShowLuckEntry(106); 2: Romance.ShowLuckEntry(109);
      3: Romance.ShowLuckEntry(110); 4: Romance.ShowLuckEntry(111) end;
    3: case Romance.RelationBand(GDVars.gameState^.npcLove) of
      0: Romance.ShowLuckEntry(103); 1: Romance.ShowLuckEntry(107); 2: Romance.ShowLuckEntry(110);
      3: Romance.ShowLuckEntry(112); 4: Romance.ShowLuckEntry(113) end;
    4: case Romance.RelationBand(GDVars.gameState^.npcLove) of
      0: begin
        Romance.ShowLuckEntry(104); GDVars.curChar := GDVars.relationB;
        CharGen.RemoveCreature(False,
                               True); GDVars.curChar := GDVars.partyHead; CharHlp.DisplayParty(GDVars.curChar)
      end;
      1: Romance.ShowLuckEntry(108); 2: Romance.ShowLuckEntry(111); 3: Romance.ShowLuckEntry(112);
      4: begin
        Portrait.FreeAnimation; Portrait.LoadAnimation('PIC', 131, 0); Portrait.DisplayImageBuf(3, 3, True, 0);
        GDVars.palettePending := 1; Romance.ShowLuckEntry(114); MenuCore.ResetMenuSlots(1);
        if MenuCore.MenuHorizontal('', 'Accept Reject', 0, Byte(GDVars.eclPicShown)) = #0 then
          Romance.ShowLuckEntry(115) else begin
          Romance.ShowLuckEntry(116); GDVars.curChar := GDVars.relationB;
          CharGen.RemoveCreature(False,
                                 True); GDVars.curChar := GDVars.partyHead; CharHlp.DisplayParty(GDVars.curChar);
          Romance.ShowLuckEntry(117);
          if GDVars.relationA^.stats[C_Stat.CHARISMA].base >
              6 then Dec(GDVars.relationA^.stats[C_Stat.CHARISMA].base, 6)
          else GDVars.relationA^.stats[C_Stat.CHARISMA].base := 0;
          if GDVars.relationA^.stats[C_Stat.CHARISMA].current >
              6 then Dec(GDVars.relationA^.stats[C_Stat.CHARISMA].current, 6)
          else GDVars.relationA^.stats[C_Stat.CHARISMA].current := 0;
          if CharHlp.HasEffect(GDVars.relationA, C_Effect.IN_LOVE, node) then
            Types.PEffect(node)^.strength := 1
        end
      end
    end
  end
end;
begin end.
