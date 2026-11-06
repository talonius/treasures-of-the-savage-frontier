{ CharHlp -- character helpers shared by the game's overlays: the derived combat values (THAC0, damage, armor class,
  movement and encumbrance from abilities, items and effects), item names, the party roster panel and the combat
  character panel, combat and status messages, effect lookup, damage, side and team counts, the four-frame icon builder
  and the bolt animation. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit CharHlp;

interface

uses Types, GDConsts, GDVars, C_Effect, C_Keys, C_Status, C_Class, C_Spell,
  C_Stat, C_Dir, C_Equip, C_Ifc, C_Item, C_Race, Crt, ClassCal, MenuCore, MapView, Portrait, Pathing, CbtMap, Border,
  Music, Blit, TextRend, GameIo;

type
  TAcAdjust = array[0..6] of ShortInt;
  PAcAdjust = ^TAcAdjust;
  P27Boolean = ^Boolean;
  T27Str2 = String[2];

{ Rolls a percentile chance.
  @param(percent The chance in 100.)
  @returns(True with a chance of percent in 100.) }
function PercentileRoll(percent: Byte): Boolean;

{ Build an item's display name: Yes/No for readied when showName, '*' for a magic item while someone has Detect Magic,
  the quantity, then the identified name parts with plural endings; draw it at (col, row) when showStatus.
  @param(outS Unused.)
  @param(item The item; its name is built in place.)
  @param(col The column it is printed at.)
  @param(row The row.)
  @param(showName True adds the Yes/No readied column of an inventory list.)
  @param(showStatus True prints the name.) }
procedure PrintItemString(outS: Pointer; item: Types.PItem; col, row: Byte; showName, showStatus: Boolean);

{ Draws the party panel and records its rectangle for mouse picks (to column 38, from row 4 down one row per member):
  the 'Name' and 'AC/HP' headings, then one row per party member (name, armor class and hit points right-aligned), each
  row cleared first, and one cleared row after the last. The given member is drawn plainly in white; the others are
  colored by DisplayCreatureName. The panel starts in column 1 in the main menu and column 17 otherwise. Skipped on the
  area map while the map pane is enabled, or while the party panel is hidden.
  @param(p The member drawn plainly in white.) }
procedure DisplayParty(p: Pointer);

{ Redraw one roster line, the highlighted character's (p if none is set), with its name in white when clearHighlight is
  set, then forget the highlight.
  @param(p The character highlighted when none is.)
  @param(clearHighlight Nonzero draws the name in white.) }
procedure PrintMiscInfo(p: Pointer; clearHighlight: Byte);

{ Prints a creature's current hit points at a screen position: yellow when wounded, light green when whole, light
  magenta when asked. When asked, the maximum follows after a slash in light green.
  @param(cr The creature.)
  @param(col The column.)
  @param(row The row.)
  @param(hotPink Set to print in light magenta.)
  @param(showMax Set to add the maximum after a slash.) }
procedure PrintHitPoints(cr: Pointer; col, row: Byte; hotPink, showMax: Boolean);

{ Prints a character's armor class in light green: 60 minus the stored value, with a minus sign when the value is above
  60.
  @param(cr The character.)
  @param(col Screen column.)
  @param(row Screen row.) }
procedure PrintArmorClass(cr: Pointer; col, row: Byte);

{ Fills the combat side panel for a creature when the panel is marked dirty (and clears the mark): name, hit points,
  armor class, readied weapon, and the status name of a creature out of play, '(Helpless)' or '(Casting)'.
  @param(cr The creature to show.) }
procedure CombatPrintCreatureInfo(cr: Pointer);

{ Tells whether a creature is helpless: any of the four helplessness effects is on it.
  @param(cr The creature.)
  @returns(True when the creature is helpless.) }
function IsHelpless(cr: Pointer): Boolean;

{ Recompute a character's equipment, item count, encumbrance, attacks, saving bonus, armor class, movement and THAC0
  from its items, abilities and effects.
  @param(cr The creature, a Types.PCharacter.) }
procedure RecalcStats(cr: Pointer);

{ Format value as a decimal string.
  @param(value The number.)
  @returns(Its decimal string.) }
function Int32Str(value: LongInt): String;

{ Format value as a decimal string.
  @param(value The number.)
  @returns(Its decimal string.) }
function Uint16Str(value: Word): String;

{ Format value as a decimal string.
  @param(value The number.)
  @returns(Its decimal string.) }
function Uint8Str(value: Byte): String;

{ Computes the Dexterity missile adjustment from the current Dexterity: -4 at 0..2, -3..-1 at 3..5, +1..+3 at 16..18, 3
  at 19..20, 4 at 21..23, 5 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexMissileAdjust(cr: Pointer): ShortInt;

{ Gives the Strength adjustment to damage, by translated Strength.
  @param(cr The creature.)
  @returns(The adjustment.) }
function StrDamageAdjust(cr: Pointer): ShortInt;

{ Finds a creature's weight allowance for its translated Strength, from -350 to 15000 encumbrance units.
  @param(cr The creature.)
  @returns(The allowance, which may be negative.) }
function WeightAllowance(cr: Pointer): Integer;

{ Marks the first memorized copy of a spell on a creature as cast by setting its high bit.
  @param(cr The creature.)
  @param(value The spell.) }
procedure RemoveSpell(cr: Pointer; value: Byte);

{ Unlinks an item from a creature's item list and returns it to the item pool; a nil item or one not in the list is
  reported instead.
  @param(character The creature.)
  @param(item The item.) }
procedure RemoveItem(character, item: Pointer);

{ Appends a copy of an item to a creature's item list. A monster in combat takes its copy from the heap; everyone else
  uses the slot pool.
  @param(character The creature.)
  @param(item The item.) }
procedure AddItemCopy(character, item: Pointer);

{ Shows a message on the bottom row in light green for the text delay, then clears the row.
  @param(message The message.) }
procedure PrintBottomLine(message: Types.TStr40);

{ Prints a creature's name with a message under it: in combat in the side panel from the given row on, elsewhere in the
  text window from row 17, or 18 while the border is off.
  @param(p The creature.)
  @param(name The message.)
  @param(row The panel row of the name, read in combat.)
  @param(pause When set, pauses and then clears the message area.) }
procedure PrintCreatureMessage(p: Pointer; name: String; row, pause: Byte);

{ Clears the message area: the side panel's rows 10..21 in combat, otherwise rows 18..22. }
procedure ClearMessageWindow;

{ Draw a character's name, with 's when possessive: red when out of play, yellow for a hostile in combat, magenta when
  highlighted, else cyan.
  @param(cr The creature, a Types.PCharacter; nil draws nothing.)
  @param(col The column.)
  @param(row The row.)
  @param(possessive True adds 's.) }
procedure DisplayCreatureName(cr: Pointer; col, row: Byte; possessive: Boolean);

{ Copies one half of a combat icon into a row of the composite icon sheet, mirrored through a scratch image when asked;
  the sheet takes the icon's key color, and the mask is copied only when there is one.
  @param(cell The icon's row in the icon table.)
  @param(half The half, 0 or 1.)
  @param(row The row of the sheet filled.)
  @param(mirror True mirrors it.) }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

{ Builds the four-frame moving-icon sheet from an icon: frame 0 straight and mirrored, then frame 1 mirrored and
  straight.
  @param(cell The icon slot.) }
procedure BuildIconFacings(cell: Byte);

{ Moves a combat icon from the start cell to the end cell. Both cells are clamped into the 50x25 arena, the line between
  them is walked into a list of step directions, and the combat view is scrolled to show the move. The icon then steps
  three pixels per cell, cycling through its facing frames, waiting the given pace per step and restoring the background
  behind it. If the icon leaves the view before the end, the walk backs up from the end cell to find where the path
  re-enters the view, scrolls there and walks again. Very short moves are not animated, and the last two steps are not
  walked.
  @param(x1 The start column.)
  @param(y1 The start row.)
  @param(x2 The end column.)
  @param(y2 The end row.)
  @param(kind The facing frames cycled through.)
  @param(effectId The wait per step.) }
procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; kind, effectId: Byte);

{ Prints the creature's name and a message with an effect or damage flash. In combat it builds the facing sheet from the
  flash icon, scrolls the creature into view if needed, plays the effect or damage sound, prints the message, then
  flashes the icon over the creature: an effect repeats the flash for the game's delay setting, while a damage flash
  plays once and is followed by a pause. Out of combat it prints the message with a pause.
  @param(cr The creature.)
  @param(animated True for an effect flash, False for a damage flash.)
  @param(message The text.) }
procedure PrintNameStringAnim(cr: Pointer; animated: Boolean; message: String);

{ True if the creature carries effect effectId. node is left on the matching effect node, or nil when there is none; a
  nil creature carries nothing.
  @param(cr The creature, a Types.PCharacter.)
  @param(effectId The effect.)
  @param(node Receives the matching effect node, or nil.)
  @returns(True when it carries the effect.) }
function HasEffect(cr: Pointer; effectId: Byte; var node: Pointer): Boolean;

{ Takes damage off a creature's hit points and updates its status. Falling more than 9 below 0, or an animated creature
  reaching 0, is death; any other drop below 0 is dying (combat records how far below); exactly 0 is unconscious. A
  creature that is then not okay or animated is taken out of play with no hit points (in combat its side's count drops
  and its initiative is cleared); otherwise it keeps the hit points left.
  @param(cr The creature.)
  @param(damage The damage.) }
procedure InflictDamage(cr: Pointer; damage: Word);

{ Announces that a creature is fully or partially healed; out of combat, also repaints its party-panel row, plainly when
  it is the current character.
  @param(cr The creature.) }
procedure AnnounceHealStatus(cr: Pointer);

{ Finds a creature's opposing team.
  @param(cr The creature.)
  @returns(1 for a creature that is not hostile, else 0.) }
function EnemyTeam(cr: Pointer): Byte;

{ Recounts the creatures in play on each side. }
procedure CountTeams;

{ Counts the creatures within range of a creature on the wanted side: its own side when asked, else the enemy side. The
  ranked approach list is compacted in place to those creatures, their indices are copied into the target table, and the
  count is returned. Under effect 91 the preferred target is moved to the front of that list.
  @param(cr The creature.)
  @param(range The range.)
  @param(ownTeam True counts the creature's own side, False the enemy side.)
  @returns(The count.) }
function CountTargets(cr: Pointer; range: Byte; ownTeam: Boolean): Byte;

{ Measures the distance in whole steps from one creature to another, read from a fresh range-255 target list built
  ignoring terrain (the previous list is saved and restored). Note: an absent target gives the last entry's distance.
  @param(cr The creature measuring.)
  @param(p The creature to find.)
  @returns(The distance.) }
function CalcDistance(cr, p: Pointer): Byte;

{ Ends a creature's actions for the round: clears its initiative, casting, guarding and movement.
  @param(cr The creature.)
  @returns(Always True.) }
function EndActions(cr: Pointer): Boolean;

{ Ends a creature's actions and, unless it is turned, sets it guarding with a 'Guarding' message.
  @param(cr The creature.)
  @returns(Always True.) }
function Guard(cr: Pointer): Boolean;

{ The level at which the current character casts `spell`, by the spell's casting class. A character with no cleric or
  mage levels and a ranger level below 8 casts at 6. Otherwise cleric spells use the better of the cleric and paladin
  levels, druid spells the ranger level less 7, mage spells the better of the mage level and the ranger level less 8,
  and magic-item spells cast at 12. While GDVars.usingItem is set, any spell but a magic item's casts at 6. The
  empowered effect adds 3, and with capped the result is at most 31.
  @param(spell The spell.)
  @param(capped True caps the level at 31.)
  @returns(The level.) }
function GetCasterLevel(spell: Byte; capped: Boolean): Byte;

{ Pick a party member from the roster with the arrow keys and the select menu, starting at selected; with addExit, Exit
  or Escape returns nil.
  @param(query The menu prompt.)
  @param(addExit True offers Exit.)
  @param(mode Nonzero sends Up back to the character current on entry, with the mouse active.)
  @param(selected The member to start at; receives the choice, or nil.) }
procedure SelectChar(query: Types.TStr40; addExit: Boolean; mode: Byte; var selected: Types.PCharacter);

{ Redraw the current screen for locState.current: the main menu's frame; in a shop or the vault, the picture, party
  panel and status line; camping, picture gameState^.layoutPic (128 when it is 0), the party panel and status line; on
  the 3-D view, unless field55 is set, the frame, map view, party panel and status line; on the overland map, the map
  view when its layout is shown; on the treasure screen, picture 129 and the party panel. }
procedure DisplayNoncombatInterface;

{ Draw the status line: map position and facing unless hidden, the clock, and 'camping', 'in boat' or 'search'. }
procedure PrintPositionAndTime;

{ Set up the combat screen: palette and frame, then scroll the view onto the map camera. }
procedure DisplayCombatInterface;

{ Tells whether a creature's readied weapon reaches beyond 1, thrown weapons included.
  @param(cr The creature.)
  @returns(True for a ranged weapon.) }
function HasRangedWeapon(cr: Pointer): Boolean;

{ Tells whether the readied weapon is ranged and its properties mark it both thrown ($10) and Strength-adjusted ($04).
  @param(cr The creature.)
  @returns(True for a throwable weapon.) }
function HasThrowableWeapon(cr: Pointer): Boolean;

{ Finds the item that does the damage in a ranged attack: the readied weapon itself when thrown, else the readied arrows
  for a bow or the readied quarrels for a crossbow, or nil when there is none.
  @param(w The creature.)
  @param(item Receives the item, or nil.)
  @returns(True when an item is found, and also for a weapon whose properties are exactly $0A, which needs no
    ammunition.) }
function FindDamagingRangedWeapon(w: Pointer; var item: Pointer): Boolean;

{ Return a character's combat movement: the base rate after armor and encumbrance, doubled by haste and by magic boots
  and halved by slow, adjusted for the party by gameState^.partyMoveAdj (to at least 1), doubled, then cut to 3/5
  (gameState^.weather 0) or 2/5 (weather 1) unless the creature is immune to weather.
  @param(cr The creature, a Types.PCharacter.)
  @returns(The movement, doubled.) }
function RecalcMovement(cr: Pointer): Byte;

{ Tells whether any party member (a side-0 player or non-player character) is dying. With `apply` set, the first dying
  member found is bandaged: it becomes unconscious, its overkill is cleared and the bandaging is announced.
  @param(apply Set to bandage the first dying member.)
  @returns(True when a member is dying.) }
function BandageDying(apply: Boolean): Boolean;

{ Finds the compass direction (0 = N, 1 = NE, ... 7 = NW) from one creature to another on the combat grid, by octant:
  the slopes 618/256 and 106/256 are tan 67.5 and tan 22.5 degrees.
  @param(creature The creature looked from.)
  @param(other The creature looked at.)
  @returns(The direction.) }
function DirTowardTarget(creature, other: Pointer): Byte;

{ True if some class of the creature (level 1..39) already has the experience for its next level and is not held back by
  its race. raceCaps gives each race's limit per class, and the per-race exceptions below stop some classes earlier,
  mostly for an ability score under 18. Despite the name, True means a level can be gained.
  @param(cr The creature, a Types.PCharacter.)
  @returns(True when a level can be gained.) }
function CanLevelUp(cr: Pointer): Boolean;

{ Plays a scatter effect around the combat target point: issues the sound cue, builds the effect's four frames from an
  icon, then scatters frames over growing rings, each point at a random angle, clipped to the effect box and flushed
  ring by ring. Near an arena edge the pattern is offset toward that edge. The view is scrolled to the point before and
  after.
  @param(step The number of rings, less 1, divided by 3.)
  @param(cell The icon the frames are built from.)
  @param(soundId The sound cue.) }
procedure ScatterCombatIcon(step, cell, soundId: Byte);

{ Computes the Constitution hit-point adjustment: -2 at Constitution 3, -1 at 4 to 6, +1 at 15, +2 at 16, and at 17 to
  19 the Constitution less 14 for fighters, rangers and paladins but +2 for everyone else. Note: a Constitution outside
  3 to 19 leaves the result undefined.
  @param(cr The creature.)
  @param(cls The class.)
  @returns(The adjustment.) }
function ClassConAdj(cr: Pointer; cls: Byte): ShortInt;

{ Resets the encounter state: clears three flags, sets the monster icon slot to 8, zeroes the money pool, and returns
  each node queued on the treasure list to the pool. }
procedure ClearEncounterState;

{ Builds the single facing frame of an icon for a compass direction: the diagonals use the next icon (cell + 1),
  mirrored for 5 and 7; the cardinal directions take cell or cell + 2 and the half from the direction.
  @param(direction The compass direction.)
  @param(cell The icon's row in the icon table.) }
procedure BuildIconFacingsDir(direction, cell: Byte);

{ A debug dump of each party member's items and effects, gated on GDConsts.editorEnabled and a BIOS key state bit. Note:
  it exits before dumping anything. }
procedure DebugDumpParty;

implementation

const
  { effect ids only this unit names }
  { Immune to weather }
  EFF_IMMUNE_WEATHER = 158;
  { Magically Empowered }
  EFF_EMPOWERED = 159;

const
  { the cloak slot of Types.TCharacter.equipped }
  EQUIP_CLOAK = 7;
  { a base item's props bit: a missile weapon, so the Dexterity missile adjustment applies to hit }
  ITEM_PROP_MISSILE = $02;

var
  biosBreak: Byte absolute $0000:$0417;

function StrToHitAdjust(cr: Pointer): ShortInt; forward;

function DexterityArmorAdjustment(cr: Pointer): ShortInt; forward;

function PercentileRoll(percent: Byte): Boolean;
begin
  PercentileRoll := percent > Random(100)
end;

{ Recompute the to-hit and damage figures from the readied weapon. Dexterity applies to missile weapons and Strength to
  melee weapons, and the readied ammunition's bonus adds to the weapon's own.
  @param(cr The creature.) }
procedure WeaponAdjust(cr: Types.PCharacter);
var
  weapon: Types.PItem;
  weaponType: Byte;
  plus: ShortInt;
begin
  weapon := cr^.equipped[C_Equip.WEAPON];
  if weapon = nil then Exit;
  weaponType := weapon^.itemType;
  cr^.thac0Cur := cr^.thac0Base;
  if (GDVars.baseItems[weaponType].props and CharHlp.ITEM_PROP_MISSILE) <> 0 then
    cr^.thac0Cur := CharHlp.DexMissileAdjust(cr) + cr^.thac0Cur;
  cr^.curMod[1] := GDVars.baseItems[weaponType].dmgSmMod;
  if (GDVars.baseItems[weaponType].props and C_Item.STRENGTH_BONUS) <> 0 then begin
    cr^.thac0Cur := CharHlp.StrToHitAdjust(cr) + cr^.thac0Cur;
    cr^.curMod[1] := CharHlp.StrDamageAdjust(cr) + cr^.curMod[1]
  end;
  plus := weapon^.plus;
  if GDVars.baseItems[weaponType].props > $7F then
    if cr^.equipped[C_Equip.BOLT] <> nil then
      plus := plus + cr^.equipped[C_Equip.BOLT]^.plus;
  if (GDVars.baseItems[weaponType].props and C_Item.USES_ARROWS) > 0 then
    if cr^.equipped[C_Equip.ARROW] <> nil then
      plus := plus + cr^.equipped[C_Equip.ARROW]^.plus;
  cr^.curMod[1] := cr^.curMod[1] + plus;
  if (cr^.race = C_Race.ELF) and
      (((weapon^.itemType > 21) and (weapon^.itemType < 27)) or (weapon^.itemType = 19) or
       (weapon^.itemType = 18)) then
    Inc(plus);
  cr^.thac0Cur := cr^.thac0Cur + plus;
  cr^.curRolls[1] := GDVars.baseItems[weaponType].dmgSmRolls;
  cr^.curDice[1] := GDVars.baseItems[weaponType].dmgSmDice
end;

{ Sets movement from readied body armor's weight: the base movement up to 150, 9 up to 399, else 6; magic armor adds 3
  when that leaves 9 or less.
  @param(cr The character.)
  @param(item A readied item; anything but body armor is ignored.) }
procedure ArmorMoveAdjust(cr: Types.PCharacter; item: Types.PItem);
begin
  if GDVars.baseItems[item^.itemType].slot = C_Equip.ARMOR then begin
    case item^.weight of
      0..150: cr^.movementCur := cr^.movementBase;
      151..399: cr^.movementCur := 9;
    else
      cr^.movementCur := 6
    end;
    if (item^.plus <> 0) and (cr^.movementCur <= 9) then
      cr^.movementCur := cr^.movementCur + 3
  end
end;

{ Fold one equipped item into the AC-adjustment array and the creature's saving-throw bonus. Only items whose AC
  descriptor has the high bit set count. A shield adds its AC plus its bonus. A descriptor-0 item adds protection -- the
  first ring slot keeps the best, the cloak slot and slot 5 replace their entries, any other slot sums -- and its save
  bonus. Any other item keeps the best AC total in adjust^[5], and magical body armor sets magicBody.
  @param(cr The creature.)
  @param(item The item.)
  @param(adjust The AC adjustments gathered.)
  @param(magicBody Set for magical body armor.) }
procedure AddItemArmorAdjust(cr: Types.PCharacter; item: Types.PItem; adjust: PAcAdjust; magicBody: P27Boolean);
var
  description: Byte;
  slot: Byte;
begin
  description := GDVars.baseItems[item^.itemType].acDescr;
  if description > $7F then begin
    description := description and $7F;
    slot := GDVars.baseItems[item^.itemType].slot;
    if slot = C_Equip.SHIELD then
      adjust^[1] := description + item^.plus
    else if description = 0 then begin
      if slot = C_Equip.FIRST_RING then begin
        if item^.plus > adjust^[3] then
          adjust^[3] := item^.plus
      end else if slot = CharHlp.EQUIP_CLOAK then
        adjust^[4] := item^.plus
      else if slot = 5 then
        adjust^[6] := item^.plus
      else
        adjust^[2] := adjust^[2] + item^.plus;
      cr^.saveBonus := cr^.saveBonus + item^.saveBonus
    end else if description + item^.plus > adjust^[5] then begin
      adjust^[5] := description + item^.plus;
      if item^.plus > 0 then
        if slot = C_Equip.ARMOR then
          magicBody^ := True
    end
  end
end;

{ Lowers a creature's movement for the coins it carries past its weight allowance: up to 512 over changes nothing, and
  each further band of 256 steps down to 9, 6 and 3. The movement is only ever lowered.
  @param(cr The creature.) }
procedure EncumbranceAdjust(cr: Types.PCharacter);
var
  over: Integer;
  moveRate: Byte;
begin
  over := cr^.encumbrance - CharHlp.WeightAllowance(cr);
  if over < 0 then over := 0;
  case over of
    0..512: moveRate := cr^.movementCur;
    513..768: moveRate := 9;
    769..1024: moveRate := 6;
  else
    moveRate := 3
  end;
  if moveRate < cr^.movementCur then
    cr^.movementCur := moveRate
end;

procedure PrintItemString(outS: Pointer; item: Types.PItem; col, row: Byte; showName, showStatus: Boolean);
var
  part: Byte;
  mask: Byte;
  effect: Pointer;
  found: Boolean;
  appended: Boolean;
  cr: Types.PCharacter;
begin
  item^.name := '';
  if showName then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   '
  end;
  found := False;
  cr := GDVars.partyHead;
  while (cr <> nil) and not found do begin
    if CharHlp.HasEffect(cr, C_Effect.DETECT_MAGIC, effect) then
      found := True;
    cr := cr^.next
  end;
  if found then
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  if item^.quantity > 0 then
    item^.name := item^.name + CharHlp.Uint8Str(item^.quantity) + ' ';
  mask := 0;
  for part := 1 to 3 do
    if item^.nameIds[part] <> 0 then
      if (item^.unidMask shr (3 - part)) and 1 = 0 then
        Inc(mask, 1 shl (part - 1));
  appended := False;
  for part := 3 downto 1 do
    if (mask shr (part - 1)) and 1 > 0 then begin
      item^.name := item^.name + GDConsts.itemNameParts[item^.nameIds[part]];
      if (item^.quantity < 2) or appended or (item^.nameIds[part] in [106..114, 116..118, 133..143]) then
        item^.name := item^.name + ' '
      else if ((1 shl (part - 1)) = mask) or (item^.nameIds[part] = $7E) or
        ((part = 1) and (mask > 4) and (item^.itemType <> 55)) or ((part = 2) and not Odd(mask)) or
        ((part = 3) and (item^.itemType = 55)) or
        (((item^.itemType = 30) or (item^.itemType = 5) or (item^.itemType = 7) or (item^.itemType = 12)) and
         (item^.nameIds[3] <> 93)) then begin
        item^.name := item^.name + 's ';
        appended := True
      end else
        item^.name := item^.name + ' '
    end;
  if showStatus then
    TextRend.DisplayString(col, row, LightGreen, Black, item^.name)
end;

procedure DisplayParty(p: Pointer);
var
  cr: Types.PCharacter;
  col: Byte;
  row: Byte;
  band: Byte;
begin
  if ((GDVars.locState.current = C_Ifc.AREA_MAP) and (GDVars.gameState^.layoutFlag = 1)) or
      (GDVars.partyShown <> 0) then
    Exit;
  if GDVars.locState.current = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  GDVars.partyPanelLeft := col;
  GDVars.partyPanelTop := 4;
  GDVars.partyPanelRight := 38;
  GDVars.partyPanelBottom := 3;
  row := 2;
  TextRend.DisplayString(col, row, White, Black, 'Name');
  TextRend.DisplayString(33, row, White, Black, 'AC  HP');
  Inc(row, 2);
  cr := GDVars.partyHead;
  while cr <> nil do begin
    Inc(GDVars.partyPanelBottom);
    Border.EraseBox(col, row, 38, row);
    if cr = p then
      TextRend.DisplayString(col, row, White, Black, cr^.name)
    else
      CharHlp.DisplayCreatureName(cr, col, row, False);
    case cr^.acCur[0] of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1;
    else
      band := 0
    end;
    CharHlp.PrintArmorClass(cr, band + 32, row);
    case cr^.hpCur of
      0..9: band := 2;
      10..99: band := 1;
    else
      band := 0
    end;
    CharHlp.PrintHitPoints(cr, band + 36, row, False, False);
    Inc(row);
    cr := cr^.next
  end;
  Border.EraseBox(col, row, 38, row)
end;

procedure PrintMiscInfo(p: Pointer; clearHighlight: Byte);
var
  cr: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  crTail: array[1..4] of Byte;
  col: Byte;
  row: Byte;
  band: Byte;
begin
  if ((GDVars.locState.current = C_Ifc.AREA_MAP) and (GDVars.gameState^.layoutFlag = 1)) or
      (GDVars.partyShown <> 0) then
    Exit;
  if GDVars.highlightedCharacter = nil then
    GDVars.highlightedCharacter := p;
  if GDVars.locState.current = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  GDVars.partyPanelLeft := col;
  GDVars.partyPanelTop := 4;
  GDVars.partyPanelRight := 38;
  GDVars.partyPanelBottom := 3;
  row := 4;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    Inc(GDVars.partyPanelBottom);
    if cr = GDVars.highlightedCharacter then begin
      Border.EraseBox(col, row, 38, row);
      if clearHighlight <> 0 then
        TextRend.DisplayString(col, row, White, Black, cr^.name)
      else
        CharHlp.DisplayCreatureName(cr, col, row, False);
      case cr^.acCur[0] of
        0..50: band := 1;
        51..60: band := 2;
        61..69: band := 1;
      else
        band := 0
      end;
      CharHlp.PrintArmorClass(cr, band + 32, row);
      case cr^.hpCur of
        0..9: band := 2;
        10..99: band := 1;
      else
        band := 0
      end;
      CharHlp.PrintHitPoints(cr, band + 36, row, False, False)
    end;
    Inc(row);
    cr := cr^.next
  end;
  Border.EraseBox(col, row, 38, row);
  GDVars.highlightedCharacter := nil
end;

procedure PrintArmorClass(cr: Pointer; col, row: Byte);
var
  s: String;
  { Unused in this version; see the other implementations of this routine. }
  color: Byte;
begin
  s := CharHlp.Uint8Str(Abs(Types.PCharacter(cr)^.acCur[0] - 60));
  if Types.PCharacter(cr)^.acCur[0] > 60 then
    s := '-' + s;
  TextRend.DisplayString(col, row, LightGreen, Black, s)
end;

procedure PrintHitPoints(cr: Pointer; col, row: Byte; hotPink, showMax: Boolean);
var
  s: String;
  color: Byte;
  len: ShortInt;
begin
  if Types.PCharacter(cr)^.hpCur < Types.PCharacter(cr)^.hpMax then
    color := 14
  else
    color := 10;
  if hotPink then
    color := 13;
  s := CharHlp.Uint8Str(Types.PCharacter(cr)^.hpCur);
  TextRend.DisplayString(col, row, color, Black, s);
  if showMax then begin
    len := Length(s);
    TextRend.DisplayString(col + len, row, LightGreen, Black, '/' + CharHlp.Uint8Str(Types.PCharacter(cr)^.hpMax))
  end
end;

procedure CombatPrintCreatureInfo(cr: Pointer);
var
  { Unused in this version; see the other implementations of this routine. }
  col: Byte;
  row: Byte;
begin
  if GDVars.combatPanelDirty <> 0 then begin
    GDVars.combatPanelDirty := 0;
    Border.EraseBox(23, 1, 38, 21);
    row := 1;
    CharHlp.PrintCreatureMessage(cr, ' ', row, 0);
    Inc(row);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'Hitpoints');
    CharHlp.PrintHitPoints(cr, 33, row + 1, False, False);
    Inc(row, 2);
    TextRend.DisplayString(23, row + 1, LightGreen, Black, 'AC');
    CharHlp.PrintArmorClass(cr, 26, row + 1);
    GDVars.curRow := row + 1;
    if Types.PCharacter(cr)^.equipped[C_Equip.WEAPON] <> nil then begin
      Inc(row, 2);
      col := 23;
      CharHlp.PrintItemString(cr, Types.PCharacter(cr)^.equipped[C_Equip.WEAPON], 0, 0, False, False);
      TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 1 + 1, LightGreen, Black, True,
                                    Types.PCharacter(cr)^.equipped[C_Equip.WEAPON]^.name)
    end;
    row := GDVars.curRow + 1;
    if Types.PCharacter(cr)^.inPlay = 0 then
      TextRend.DisplayString(23, row + 1, White, Black, GDConsts.statusNames[Types.PCharacter(cr)^.status])
    else if CharHlp.IsHelpless(cr) then
      TextRend.DisplayString(23, row + 1, White, Black, '(Helpless)')
    else if Types.PCharacter(cr)^.combatAddr^.spellCast > 0 then
      TextRend.DisplayString(23, row + 1, White, Black, '(Casting)')
  end
end;

function IsHelpless(cr: Pointer): Boolean;
var
  i: Byte;
  effect: Pointer;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(cr, GDConsts.helplessEffects[i], effect) then
      IsHelpless := True
end;

procedure RecalcStats(cr: Pointer);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItem;
  magicBody: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  bag: Boolean;
  adjust: TAcAdjust;
  i: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  coinIdx: Byte;
  coin: ShortInt;
  weight: Word;
  slot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  slotTail: LongInt;
begin
  for i := C_Equip.WEAPON to C_Equip.BOLT do
    Types.PCharacter(cr)^.equipped[i] := nil;
  bag := False;
  Types.PCharacter(cr)^.numberOfItems := 0;
  item := Types.PCharacter(cr)^.items;
  Types.PCharacter(cr)^.handsEquipped := 0;
  Types.PCharacter(cr)^.encumbrance := 0;
  GDVars.equippedWeight := 0;
  while item <> nil do begin
    Inc(Types.PCharacter(cr)^.numberOfItems);
    weight := item^.weight;
    if item^.quantity > 0 then
      weight := item^.quantity * weight;
    Inc(Types.PCharacter(cr)^.encumbrance, weight);
    if item^.equipped <> 0 then begin
      Inc(GDVars.equippedWeight, weight);
      slot := GDVars.baseItems[item^.itemType].slot;
      case slot of
        C_Equip.WEAPON..C_Equip.BOOTS: Types.PCharacter(cr)^.equipped[ShortInt(slot)] := item;
        C_Equip.FIRST_RING:
          if Types.PCharacter(cr)^.equipped[C_Equip.FIRST_RING] <> nil then begin
            if Types.PCharacter(cr)^.equipped[C_Equip.SECOND_RING] = nil then
              Types.PCharacter(cr)^.equipped[C_Equip.SECOND_RING] := item
          end else
            Types.PCharacter(cr)^.equipped[C_Equip.FIRST_RING] := item
      end;
      if item^.itemType = 30 then
        Types.PCharacter(cr)^.equipped[C_Equip.ARROW] := item;
      if (item^.itemType = 12) or (item^.itemType = 74) then
        Types.PCharacter(cr)^.equipped[C_Equip.BOLT] := item;
      Types.PCharacter(cr)^.handsEquipped := Types.PCharacter(cr)^.handsEquipped +
        GDVars.baseItems[item^.itemType].hands
    end;
    item := item^.next
  end;
  for coin := 0 to 2 do
    Types.PCharacter(cr)^.encumbrance := Types.PCharacter(cr)^.encumbrance + Types.PCharacter(cr)^.coins[coin];
  for j := 1 to 2 do begin
    Types.PCharacter(cr)^.curRolls[j] := Types.PCharacter(cr)^.unarmedRolls[j];
    Types.PCharacter(cr)^.curDice[j] := Types.PCharacter(cr)^.unarmedDice[j];
    Types.PCharacter(cr)^.curMod[j] := Types.PCharacter(cr)^.unarmedMod[j]
  end;
  GameIo.ZeroFill(adjust, SizeOf(adjust));
  magicBody := False;
  Types.PCharacter(cr)^.saveBonus := 0;
  Types.PCharacter(cr)^.acCur[0] := Types.PCharacter(cr)^.acBase;
  Types.PCharacter(cr)^.movementCur := Types.PCharacter(cr)^.movementBase;
  Types.PCharacter(cr)^.thac0Cur := Types.PCharacter(cr)^.thac0Base;
  adjust[0] := CharHlp.DexterityArmorAdjustment(cr);
  if Types.PCharacter(cr)^.equipped[C_Equip.WEAPON] = nil then begin
    Types.PCharacter(cr)^.thac0Cur := CharHlp.StrToHitAdjust(cr) + Types.PCharacter(cr)^.thac0Cur;
    Types.PCharacter(cr)^.curMod[1] := CharHlp.StrDamageAdjust(cr) + Types.PCharacter(cr)^.curMod[1]
  end;
  CharHlp.WeaponAdjust(Types.PCharacter(cr));
  item := Types.PCharacter(cr)^.items;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(Types.PCharacter(cr), item);
      CharHlp.AddItemArmorAdjust(Types.PCharacter(cr), item, @adjust, @magicBody)
    end;
    item := item^.next
  end;
  if magicBody then begin
    if adjust[3] > 0 then adjust[3] := 0;
    if adjust[4] > 0 then adjust[4] := 0;
    if adjust[6] > 0 then adjust[6] := 0
  end;
  Types.PCharacter(cr)^.movementCur := CharHlp.RecalcMovement(cr) div 2;
  if adjust[5] < Types.PCharacter(cr)^.acCur[0] then
    adjust[5] := Types.PCharacter(cr)^.acCur[0];
  Types.PCharacter(cr)^.acCur[0] := 0;
  for k := 6 downto 0 do
    Types.PCharacter(cr)^.acCur[0] := Types.PCharacter(cr)^.acCur[0] + adjust[k];
  Types.PCharacter(cr)^.acCur[1] := adjust[5] + adjust[2] + adjust[4] + adjust[3] - 1 - 1
end;

function RecalcMovement(cr: Pointer): Byte;
var
  item: Types.PItem;
  effect: Pointer;
  movementEffect: Pointer;
begin
  Types.PCharacter(cr)^.movementCur := Types.PCharacter(cr)^.movementBase;
  item := Types.PCharacter(cr)^.items;
  while item <> nil do begin
    if item^.equipped <> 0 then
      CharHlp.ArmorMoveAdjust(Types.PCharacter(cr), item);
    item := item^.next
  end;
  CharHlp.EncumbranceAdjust(Types.PCharacter(cr));
  if CharHlp.HasEffect(cr, C_Effect.HASTED, effect) then
    Types.PCharacter(cr)^.movementCur := Types.PCharacter(cr)^.movementCur * 2;
  if CharHlp.HasEffect(cr, C_Effect.SLOWED, effect) then
    Types.PCharacter(cr)^.movementCur := Types.PCharacter(cr)^.movementCur div 2;
  if CharHlp.HasEffect(cr, C_Effect.MAGIC_BOOTS, effect) then
    Types.PCharacter(cr)^.movementCur := Types.PCharacter(cr)^.movementCur * 2;
  GDVars.fxScratchA := Types.PCharacter(cr)^.movementCur;
  if Types.PCharacter(cr)^.side = 0 then begin
    if GDVars.fxScratchA + ShortInt(GDVars.gameState^.partyMoveAdj) < 1 then
      GDVars.fxScratchA := 1
    else
      GDVars.fxScratchA := GDVars.fxScratchA + GDVars.gameState^.partyMoveAdj
  end;
  GDVars.fxScratchA := GDVars.fxScratchA * 2;
  if not CharHlp.HasEffect(cr, CharHlp.EFF_IMMUNE_WEATHER, movementEffect) then
    if GDVars.gameState^.weather = 0 then
      GDVars.fxScratchA := Word(GDVars.fxScratchA) * 3 div 5
    else if GDVars.gameState^.weather = 1 then
      GDVars.fxScratchA := Word(GDVars.fxScratchA) * 2 div 5;
  RecalcMovement := GDVars.fxScratchA
end;

function Uint8Str(value: Byte): String;
var
  s: String;
begin
  Str(value, s);
  Uint8Str := s
end;

function Uint16Str(value: Word): String;
var s: String;
begin Str(value:0, s); Uint16Str := s end;

function Int32Str(value: LongInt): String;
var s: String;
begin Str(value:0, s); Int32Str := s end;

{ Computes the Dexterity defensive adjustment from the current Dexterity: -4 at 1..3, -3..-1 at 4..6, +1..+4 at 15..18,
  4 at 19..20, 5 at 21..23, 6 at 24..25, else 0.
  @param(cr The creature.)
  @returns(The adjustment.) }
function DexterityArmorAdjustment;
var
  dexterity: Byte;
begin
  dexterity := Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].current;
  case dexterity of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := dexterity - 7;
    15..18: DexterityArmorAdjustment := dexterity - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0
  end
end;

function DexMissileAdjust(cr: Pointer): ShortInt;
var
  dexterity: Byte;
begin
  dexterity := Types.PCharacter(cr)^.stats[C_Stat.DEXTERITY].current;
  case dexterity of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := dexterity - 6;
    16..18: DexMissileAdjust := dexterity - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0
  end
end;

{ Converts Strength to one scale: 0..17 as is; 18 by exceptional Strength (without it 18, 01-50 19, 51-75 20, 76-90 21,
  91-99 22, 00 23); 19..25 become 24..30. Note: other values leave the result undefined.
  @param(cr The creature.)
  @returns(Strength on that scale.) }
function TranslatedStrength(cr: Types.PCharacter): Byte;
begin
  case cr^.stats[C_Stat.STRENGTH].current of
    0..17: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].current;
    18:
      case cr^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
        100: TranslatedStrength := 23
      end;
    19..25: TranslatedStrength := cr^.stats[C_Stat.STRENGTH].current + 5
  end
end;

{ The Strength adjustment to hit, by translated Strength.
  @param(cr The creature.)
  @returns(The adjustment.) }
function StrToHitAdjust(cr: Pointer): ShortInt;
var
  strength: Byte;
begin
  StrToHitAdjust := 0;
  strength := CharHlp.TranslatedStrength(cr);
  case strength of
    1..3: StrToHitAdjust := -3;
    4..5: StrToHitAdjust := -2;
    6..7: StrToHitAdjust := -1;
    17..19: StrToHitAdjust := 1;
    20..22: StrToHitAdjust := 2;
    23..25: StrToHitAdjust := 3;
    26..27: StrToHitAdjust := 4;
    28..30: StrToHitAdjust := strength - 23
  end
end;

function StrDamageAdjust(cr: Pointer): ShortInt;
var
  strength: Byte;
begin
  StrDamageAdjust := 0;
  strength := CharHlp.TranslatedStrength(cr);
  case strength of
    1..2: StrDamageAdjust := -2;
    3..5: StrDamageAdjust := -1;
    16: StrDamageAdjust := 1;
    17..19: StrDamageAdjust := strength - 16;
    20..29: StrDamageAdjust := strength - 17;
    30: StrDamageAdjust := 14
  end
end;

function WeightAllowance(cr: Pointer): Integer;
var
  strength: Byte;
begin
  strength := CharHlp.TranslatedStrength(cr);
  case strength of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (strength - 17) * 250 + 500;
    22..26: WeightAllowance := (strength - 22) * 1000 + 2000;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (strength - 28) * 3000 + 9000;
  else
    WeightAllowance := 0
  end
end;

procedure RemoveSpell(cr: Pointer; value: Byte);
var
  index: Byte;
begin
  index := 0;
  while index <= 140 do begin
    if Types.PCharacter(cr)^.memorized[index] = value then begin
      Types.PCharacter(cr)^.memorized[index] := value or C_Spell.PENDING_FLAG;
      index := 141
    end;
    Inc(index)
  end
end;

procedure RemoveItem(character, item: Pointer);
var
  cursor: Types.PItem;
begin
  if item = nil then
    TextRend.DisplayAndPause(Yellow, Black, 'Nil Item pointer...')
  else begin
    cursor := Types.PCharacter(character)^.items;
    if cursor = item then
      Types.PCharacter(character)^.items := Types.PItem(item)^.next
    else
      while (cursor <> nil) and (cursor^.next <> item) do
        cursor := cursor^.next;
    if cursor = nil then
      TextRend.DisplayAndPause(Yellow, Black, 'Tried to Lose item & couldn''t find it!')
    else begin
      cursor^.next := Types.PItem(item)^.next;
      Types.PItem(item)^.next := nil;
      GameIo.FreeSlot(Pointer(item))
    end
  end
end;

procedure AddItemCopy(character, item: Pointer);
var
  cursor: Types.PItem;
  newItem: Types.PItem;
begin
  if (GDVars.locState.current = C_Ifc.IN_COMBAT) and (Types.PCharacter(character)^.combatAddr <> nil) and
      (Types.PCharacter(character)^.combatAddr^.notPcNpc = 1) then
    GetMem(newItem, SizeOf(Types.TItem))
  else
    newItem := Types.PItem(GameIo.AllocSlot);
  Move(Types.PItem(item)^, newItem^, SizeOf(Types.TItem));
  newItem^.next := nil;
  cursor := Types.PCharacter(character)^.items;
  if cursor = nil then
    Types.PCharacter(character)^.items := newItem
  else begin
    while cursor^.next <> nil do
      cursor := cursor^.next;
    cursor^.next := newItem
  end
end;

procedure PrintBottomLine(message: Types.TStr40);
begin
  Border.EraseBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, Black, message);
  TextRend.PauseOnly;
  Border.EraseBox(0, 24, 39, 24)
end;

procedure PrintCreatureMessage(p: Pointer; name: String; row, pause: Byte);
var
  top: Byte;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    Border.EraseBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(p, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, Black, True, name)
  end else begin
    if GDVars.noBorder <> 0 then
      top := 18
    else
      top := 17;
    Border.EraseBox(1, top, 38, 22);
    CharHlp.DisplayCreatureName(p, 1, top + 1, False);
    TextRend.DisplayMessageWindow(1, top + 2, 38, 22, LightGreen, Black, True, name)
  end;
  if pause <> 0 then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow
  end
end;

procedure ClearMessageWindow;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then
    Border.EraseBox(23, 10, 38, 21)
  else
    Border.EraseBox(1, 17, 38, 22)
end;

procedure DisplayCreatureName(cr: Pointer; col, row: Byte; possessive: Boolean);
var
  color: Byte;
begin
  if cr <> nil then begin
    if Types.PCharacter(cr)^.inPlay = 0 then
      color := 12
    else if (Types.PCharacter(cr)^.side = 1) and (GDVars.locState.current = C_Ifc.IN_COMBAT) then
      color := 14
    else if Types.PCharacter(cr)^.displayHighlight <> 0 then
      color := 13
    else
      color := 11;
    TextRend.DisplayString(col, row, color, Black, Types.PCharacter(cr)^.name);
    if possessive then
      TextRend.DisplayString(col + Length(Types.PCharacter(cr)^.name), row, color, Black, '''s')
  end
end;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  temp: Types.PImage;
  frameSize: Word;
  dataOffset: Word;
begin
  frameSize := Types.PImage(GDVars.combatImage)^.frameBytes;
  dataOffset := row * frameSize;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, temp);
    Blit.MirrorPic(GDVars.iconSet[cell, half], temp);
    Move(Types.PImage(temp)^.data, Types.PImage(GDVars.combatImage)^.data[dataOffset], frameSize);
    Types.PImage(GDVars.combatImage)^.colorKey := Types.PImage(GDVars.iconSet[cell, half])^.colorKey;
    if Types.PImage(temp)^.mask <> nil then
      Move(Types.PImage(temp)^.mask^, Types.PImage(GDVars.combatImage)^.mask^[dataOffset], frameSize);
    Blit.FreePic(temp)
  end else begin
    Move(Types.PImage(GDVars.iconSet[cell, half])^.data, Types.PImage(GDVars.combatImage)^.data[dataOffset],
         frameSize);
    Types.PImage(GDVars.combatImage)^.colorKey := Types.PImage(GDVars.iconSet[cell, half])^.colorKey;
    if Types.PImage(GDVars.iconSet[cell, half])^.mask <> nil then
      Move(Types.PImage(GDVars.iconSet[cell, half])^.mask^, Types.PImage(GDVars.combatImage)^.mask^[dataOffset],
           frameSize)
  end
end;

procedure BuildIconFacings(cell: Byte);
begin
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, True);
  CharHlp.CopyIconFacing(cell, 1, 3, False)
end;

procedure CombatAnimateMovingIcon(x1, y1, x2, y2: Integer; kind, effectId: Byte);
var
  path: array[0..147] of Byte;
  walk: Types.TPathReq;
  { Unused in this version; see the other implementations of this routine. }
  req: Integer;
  n: Byte;
  count: Byte;
  frame: Byte;
  { Unused in this version; see the other implementations of this routine. }
  lastFrame: Byte;
  lastPass: Boolean;
  done: Boolean;
  cameraX: Integer;
  cameraY: Integer;
  { Unused in this version; see the other implementations of this routine. }
  previousX: Integer;
  { Unused in this version; see the other implementations of this routine. }
  previousY: Integer;
  accumulatedX: Integer;
  accumulatedY: Integer;
  directionX: Integer;
  directionY: Integer;
  stepX: Integer;
  stepY: Integer;
  pixelX: Integer;
  pixelY: Integer;
  overshootX: Integer;
  overshootY: Integer;

  { Clamp a cell into the 50x25 arena. }
  procedure ClampIconPosition(var x, y: Integer);
  begin
    if x < 0 then x := 0
    else if x > 49 then x := 49;
    if y < 0 then y := 0
    else if y > 24 then y := 24
  end;

begin
  ClampIconPosition(x1, y1);
  ClampIconPosition(x2, y2);
  previousX := x1;
  previousY := y1;
  FillChar(path, SizeOf(path), C_Dir.CENTER);
  GameIo.ZeroFill(walk, SizeOf(walk));
  n := 0;
  frame := 0;
  walk.x1 := x1 * 3;
  walk.y1 := y1 * 3;
  walk.x2 := x2 * 3;
  walk.y2 := y2 * 3;
  Pathing.PathFind(walk);
  repeat
    done := not Pathing.NextPathStep(walk);
    path[n] := walk.dir;
    Inc(n)
  until done;
  if n < 4 then Exit;
  count := n - 2;
  directionX := x2 - x1;
  directionY := y2 - y1;
  if not CbtMap.ViewCoordsValid(x1 - GDVars.combatMap^.originX, y1 - GDVars.combatMap^.originY) or
      not CbtMap.ViewCoordsValid(x2 - GDVars.combatMap^.originX, y2 - GDVars.combatMap^.originY) then begin
    if (Abs(directionX) <= 6) and (Abs(directionY) <= 6) then begin
      lastPass := True;
      cameraX := x1 + directionX div 2;
      cameraY := y1 + directionY div 2
    end else begin
      lastPass := False;
      cameraX := GDVars.combatMap^.originX + 3;
      cameraY := GDVars.combatMap^.originY + 3
    end
  end else begin
    lastPass := True;
    cameraX := GDVars.combatMap^.originX + 3;
    cameraY := GDVars.combatMap^.originY + 3
  end;
  CbtMap.ScrollView(cameraX, cameraY, $FF, C_Dir.CENTER);
  n := 0;
  accumulatedX := 0;
  accumulatedY := 0;
  repeat
    pixelX := (x1 - GDVars.combatMap^.originX) * 3 + accumulatedX;
    pixelY := (y1 - GDVars.combatMap^.originY) * 3 + accumulatedY;
    previousX := x1;
    previousY := y1;
    done := False;
    repeat
      stepX := GDConsts.dirDx[path[n]];
      stepY := GDConsts.dirDy[path[n]];
      Inc(pixelX, stepX);
      Inc(pixelY, stepY);
      if (effectId > 0) or (pixelX mod 3 = 0) or (pixelY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixelX, pixelY, frame, 5, Types.PImage(GDVars.combatImage),
                             Types.PImage(GDVars.viewSurface));
        Blit.FlushView;
        Delay(effectId);
        Blit.BlitTileClipped(pixelX, pixelY, 0, 0, GDVars.savedPic, Types.PImage(GDVars.viewSurface));
        Inc(frame);
        if frame >= kind then frame := 0
      end;
      Inc(n);
      if (pixelX < 0) or (pixelX > 18) or (pixelY < 0) or (pixelY > 18) then done := True;
      if not done and (n < count) then begin
        Inc(accumulatedX, stepX);
        Inc(accumulatedY, stepY);
        if Abs(accumulatedX) = 3 then begin
          Inc(x1, Pathing.SignOf(accumulatedX));
          Inc(cameraX, Pathing.SignOf(accumulatedX));
          accumulatedX := 0
        end;
        if Abs(accumulatedY) = 3 then begin
          Inc(y1, Pathing.SignOf(accumulatedY));
          Inc(cameraY, Pathing.SignOf(accumulatedY));
          accumulatedY := 0
        end
      end
    until (n >= count) or done;
    if n < count then begin
      overshootX := 0;
      overshootY := 0;
      accumulatedY := 0;
      accumulatedX := 0;
      x1 := x2;
      y1 := y2;
      previousX := x1;
      previousY := y1;
      if x2 + 3 > 49 then overshootX := x2 - 49
      else if x2 < 3 then overshootX := 3 - x2;
      if y2 + 3 > 24 then overshootY := y2 - 24
      else if y2 < 3 then overshootY := 3 - y2;
      cameraX := x2 + overshootX;
      cameraY := y2 + overshootY;
      CbtMap.ScrollView(cameraX, cameraY, $FF, C_Dir.CENTER);
      pixelX := (x2 - GDVars.combatMap^.originX) * 3;
      pixelY := (y2 - GDVars.combatMap^.originY) * 3;
      n := count;
      done := False;
      repeat
        stepX := -GDConsts.dirDx[path[n]];
        stepY := -GDConsts.dirDy[path[n]];
        Inc(pixelX, stepX);
        Inc(pixelY, stepY);
        if pixelX > 18 then x1 := GDVars.combatMap^.originX + 6
        else if pixelX < 0 then x1 := GDVars.combatMap^.originX;
        if pixelY > 18 then y1 := GDVars.combatMap^.originY + 6
        else if pixelY < 0 then y1 := GDVars.combatMap^.originY;
        if (pixelX < 0) or (pixelX > 18) or (pixelY < 0) or (pixelY > 18) then done := True;
        if not done then begin
          Inc(accumulatedX, stepX);
          Inc(accumulatedY, stepY);
          if Abs(accumulatedX) = 3 then begin
            Inc(x1, Pathing.SignOf(accumulatedX));
            Inc(cameraX, Pathing.SignOf(accumulatedX));
            accumulatedX := 0
          end;
          if Abs(accumulatedY) = 3 then begin
            Inc(y1, Pathing.SignOf(accumulatedY));
            Inc(cameraY, Pathing.SignOf(accumulatedY));
            accumulatedY := 0
          end;
          Dec(n)
        end
      until done
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(x2 - GDVars.combatMap^.originX, y2 - GDVars.combatMap^.originY) then
        CbtMap.ScrollView(x2, y2, 3, C_Dir.CENTER);
      pixelX := (x2 - GDVars.combatMap^.originX) * 3;
      pixelY := (y2 - GDVars.combatMap^.originY) * 3;
      Blit.BlitTileClipped(pixelX, pixelY, frame, 5, Types.PImage(GDVars.combatImage),
                           Types.PImage(GDVars.viewSurface));
      if effectId > 0 then begin
        Blit.FlushView;
        Delay(effectId);
        Blit.BlitTileClipped(pixelX, pixelY, 0, 0, GDVars.savedPic, Types.PImage(GDVars.viewSurface))
      end
    end
  until lastPass;
  Blit.FlushView
end;

procedure PrintNameStringAnim(cr: Pointer; animated: Boolean; message: String);
var
  x: ShortInt;
  y: ShortInt;
  cell: Byte;
  facing: Byte;
  iteration: Byte;
  repetitions: Byte;
begin
  if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
    if animated then
      cell := 21
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(cr, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 3, C_Dir.CENTER);
    if animated then
      Music.SendSoundCommand(GDConsts.soundIds[4])
    else
      Music.SendSoundCommand(GDConsts.soundIds[7]);
    CharHlp.PrintCreatureMessage(cr, message, 10, 0);
    if animated then
      repetitions := GDVars.gameState^.gameDelay
    else
      repetitions := 0;
    x := GDVars.work.relX[CbtMap.CombatSlot(cr)] * 3;
    y := GDVars.work.relY[CbtMap.CombatSlot(cr)] * 3;
    for iteration := 0 to repetitions do
      for facing := 0 to 3 do begin
        Blit.BlitTileClipped(x, y, facing, 5, Types.PImage(GDVars.combatImage), Types.PImage(GDVars.viewSurface));
        Blit.FlushView;
        Delay(70);
        Blit.BlitTileClipped(x, y, 0, 0, GDVars.savedPic, Types.PImage(GDVars.viewSurface))
      end;
    Blit.FlushView;
    if repetitions = 0 then
      TextRend.PauseOnly
  end else
    CharHlp.PrintCreatureMessage(cr, message, 10, 1)
end;

function HasEffect(cr: Pointer; effectId: Byte; var node: Pointer): Boolean;
var
  found: Boolean;
begin
  found := False;
  HasEffect := False;
  if cr = nil then Exit;
  node := Types.PCharacter(cr)^.effects;
  while (node <> nil) and not found do begin
    if Types.PEffect(node)^.id = effectId then
      found := True
    else
      node := Types.PEffect(node)^.next
  end;
  HasEffect := found
end;

procedure InflictDamage(cr: Pointer; damage: Word);
var
  remain: Byte;
  overkill: Word;
begin
  overkill := 0;
  remain := 0;
  if Types.PCharacter(cr)^.hpCur >= damage then
    remain := Types.PCharacter(cr)^.hpCur - damage
  else
    overkill := damage - Types.PCharacter(cr)^.hpCur;
  if (overkill > 9) or ((remain = 0) and (Types.PCharacter(cr)^.status = C_Status.ANIMATED)) then
    Types.PCharacter(cr)^.status := C_Status.DEAD_STATUS
  else if overkill > 0 then begin
    Types.PCharacter(cr)^.status := C_Status.DYING;
    if GDVars.locState.current = C_Ifc.IN_COMBAT then
      Types.PCharacter(cr)^.combatAddr^.overkill := overkill
  end else if remain = 0 then
    Types.PCharacter(cr)^.status := C_Status.UNCONSCIOUS;
  if not (Types.PCharacter(cr)^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    Types.PCharacter(cr)^.inPlay := 0;
    Types.PCharacter(cr)^.hpCur := 0;
    if GDVars.locState.current = C_Ifc.IN_COMBAT then begin
      Dec(GDVars.sideTally[Types.PCharacter(cr)^.side]);
      Types.PCharacter(cr)^.combatAddr^.initiative := 0
    end
  end else
    Types.PCharacter(cr)^.hpCur := remain
end;

procedure AnnounceHealStatus(cr: Pointer);
var
  message: Types.TStr40;
begin
  if Types.PCharacter(cr)^.hpCur = Types.PCharacter(cr)^.hpMax then
    message := 'is fully healed'
  else
    message := 'is partially healed';
  CharHlp.PrintCreatureMessage(cr, message, 10, 1);
  if GDVars.locState.current <> C_Ifc.IN_COMBAT then
    CharHlp.PrintMiscInfo(cr, Byte(cr = GDVars.curChar))
end;

function EnemyTeam(cr: Pointer): Byte;
begin
  if Types.PCharacter(cr)^.side = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0
end;

procedure CountTeams;
var
  cursor: Types.PCharacter;
begin
  GDVars.sideTally[0] := 0;
  GDVars.sideTally[1] := 0;
  cursor := GDVars.partyHead;
  while cursor <> nil do begin
    if cursor^.inPlay <> 0 then
      Inc(GDVars.sideTally[cursor^.side]);
    cursor := cursor^.next
  end
end;

function CountTargets(cr: Pointer; range: Byte; ownTeam: Boolean): Byte;
var
  count: Byte;
  compacted: Byte;
  index: Byte;
  effect: Pointer;
  done: Boolean;
  wantedSide: ShortInt;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), range, 255, CbtMap.GetIconSize(cr));
  count := GDVars.targetCount;
  compacted := 0;
  if ownTeam then
    wantedSide := Types.PCharacter(cr)^.side
  else
    wantedSide := CharHlp.EnemyTeam(cr);
  if count > 0 then begin
    for index := 1 to count do
      if Types.PCharacter(GDVars.creatureArr[GDVars.rankedTargets[index].entity])^.side = wantedSide then begin
        Inc(compacted);
        if compacted <> index then
          Move(GDVars.rankedTargets[index], GDVars.rankedTargets[compacted], SizeOf(GDVars.rankedTargets[index]))
      end;
    count := compacted;
    GDVars.targetCount := compacted
  end;
  CountTargets := count;
  for index := 1 to count do
    GDVars.targetOrder[index] := GDVars.rankedTargets[index].entity;
  if CharHlp.HasEffect(cr, C_Effect.BLUE_DRAGON_BREATH, effect) then begin
    index := 1;
    done := False;
    while (index <= count) and not done do begin
      if GDVars.creatureArr[GDVars.targetOrder[index]] = GDVars.specialTarget then begin
        compacted := GDVars.targetOrder[1];
        GDVars.targetOrder[1] := GDVars.targetOrder[index];
        GDVars.targetOrder[index] := compacted;
        done := True
      end;
      Inc(index)
    end
  end
end;

function CalcDistance(cr, p: Pointer): Byte;
var
  saved: array[1..255] of Types.TCombatTarget;
  index: Byte;
begin
  Move(GDVars.rankedTargets, saved, SizeOf(GDVars.rankedTargets));
  GDVars.combatMap^.noHeight := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(cr), CbtMap.CombatCellY(cr), 255, 255, CbtMap.GetIconSize(cr));
  GDVars.combatMap^.noHeight := 0;
  index := 1;
  while (GDVars.creatureArr[GDVars.rankedTargets[index].entity] <> p) and (index < GDVars.targetCount) do
    Inc(index);
  CalcDistance := GDVars.rankedTargets[index].cost shr 1;
  Move(saved, GDVars.rankedTargets, SizeOf(GDVars.rankedTargets))
end;

function EndActions(cr: Pointer): Boolean;
begin
  Types.PCharacter(cr)^.combatAddr^.initiative := 0;
  Types.PCharacter(cr)^.combatAddr^.spellCast := 0;
  Types.PCharacter(cr)^.combatAddr^.guarding := 0;
  Types.PCharacter(cr)^.combatAddr^.movement := 0;
  EndActions := True
end;

function Guard(cr: Pointer): Boolean;
begin
  Guard := CharHlp.EndActions(cr);
  if Types.PCharacter(cr)^.combatAddr^.turned = 0 then begin
    Types.PCharacter(cr)^.combatAddr^.guarding := 1;
    CharHlp.PrintBottomLine('Guarding')
  end
end;

function GetCasterLevel(spell: Byte; capped: Boolean): Byte;
var
  level: ShortInt;
  alternate: ShortInt;
  { Unused in this version; see the other implementations of this routine. }
  bonusLevels: array[1..2] of Byte;
  effect: Pointer;
begin
  if (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.CLERIC) = 0) and
      (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.MAGE) = 0) and
      (ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.RANGER) < 8) then
    level := 6
  else
    case GDConsts.spellTable[spell].spellBand of
      C_Spell.CLERIC_LIST:
        begin
          level := ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.CLERIC);
          alternate := ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.PALADIN);
          if level < alternate then
            level := alternate
        end;
      C_Spell.DRUID_LIST:
        begin
          level := ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.RANGER) - 7;
          if level < 0 then
            level := 0
        end;
      C_Spell.MAGIC_USER_LIST:
        begin
          level := ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.MAGE);
          alternate := ClassCal.EffectiveClassLevel(GDVars.curChar, C_Class.RANGER) - 8;
          if level < alternate then
            level := alternate
        end;
      C_Spell.ITEM_LIST:
        level := 12
    end;
  if (GDVars.usingItem <> 0) and (GDConsts.spellTable[spell].spellBand <> C_Spell.ITEM_LIST) then
    level := 6;
  if CharHlp.HasEffect(GDVars.curChar, CharHlp.EFF_EMPOWERED, effect) then
    Inc(level, 3);
  if capped and (level > 31) then
    level := 31;
  GetCasterLevel := level
end;

procedure DisplayNoncombatInterface;
begin
  GDVars.pendingRefresh := 1;
  case GDVars.locState.current of
    C_Ifc.MAIN_MENU:
      Border.DrawWindowFrame(0);
    C_Ifc.IN_VAULT, C_Ifc.IN_SHOP:
      begin
        if GDVars.splitFrameGate <> 0 then
          Border.DrawExploreFrame;
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.curChar);
        CharHlp.PrintPositionAndTime
      end;
    C_Ifc.CAMPING:
      begin
        Border.DrawExploreFrame;
        if GDVars.gameState^.layoutPic = 0 then
          Portrait.LoadAnimation('PIC', 128, 0)
        else
          Portrait.LoadAnimation('PIC', GDVars.gameState^.layoutPic, 0);
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.curChar);
        CharHlp.PrintPositionAndTime;
        GDVars.palettePending := 1
      end;
    4:
      begin
        if GDVars.gameState^.field55 = 0 then begin
          Border.DrawExploreFrame;
          MapView.DisplayMapView;
          CharHlp.DisplayParty(GDVars.curChar);
          CharHlp.PrintPositionAndTime
        end;
        GDVars.mapDirtyFlag := 0
      end;
    3:
      if (GDVars.resourceCurrentId <> 9) and (GDVars.gameState^.layoutFlag = 1) then
        MapView.DisplayMapView;
    6:
      begin
        Border.DrawExploreFrame;
        Portrait.LoadAnimation('PIC', 129, 0);
        Portrait.DisplayImageBuf(3, 3, True, 0);
        CharHlp.DisplayParty(GDVars.curChar);
        GDVars.palettePending := 1
      end
  end
end;

procedure PrintPositionAndTime;
var
  x: Byte;
  y: Byte;
  hrs: T27Str2;
  mins: T27Str2;
  info: Types.TStr40;
begin
  if GDVars.locState.current = C_Ifc.AREA_MAP then Exit;
  info := '';
  x := GDVars.partyPos.x;
  y := GDVars.partyPos.y;
  hrs := CharHlp.Uint8Str(GDVars.gameState^.hour);
  if Length(hrs) < 2 then
    hrs := '0' + hrs;
  mins := CharHlp.Uint8Str(GDVars.gameState^.minuteTens * 10 + GDVars.gameState^.minuteOnes);
  if Length(mins) < 2 then
    mins := '0' + mins;
  if GDVars.gameState^.mapHidden = 0 then
    info := CharHlp.Uint8Str(x) + ',' + CharHlp.Uint8Str(y) + ' ';
  if GDVars.gameState^.facingHidden = 0 then
    info := info + GDConsts.directionNames[GDVars.partyPos.facing] + ' ';
  info := info + hrs + ':' + mins;
  if GDVars.locState.current = C_Ifc.CAMPING then
    info := info + ' camping'
  else if GDVars.gameState^.inBoat <> 0 then
    info := info + ' in boat'
  else if GDVars.gameState^.searchFlags and 1 > 0 then
    info := info + ' search';
  Border.EraseBox(18, 15, 38, 15);
  TextRend.DisplayString(18, 15, LightGreen, Black, info)
end;

procedure DisplayCombatInterface;
begin
  CbtMap.SetNoncombatPalette;
  Border.DrawCombatFrame;
  CbtMap.ScrollView(GDVars.combatMap^.originX + 3, GDVars.combatMap^.originY + 3, $FF, C_Dir.CENTER)
end;

function HasRangedWeapon(cr: Pointer): Boolean;
begin
  if (Types.PCharacter(cr)^.equipped[C_Equip.WEAPON] <> nil) and
      (GDVars.baseItems[Types.PCharacter(cr)^.equipped[C_Equip.WEAPON]^.itemType].range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False
end;

function HasThrowableWeapon(cr: Pointer): Boolean;
begin
  HasThrowableWeapon := CharHlp.HasRangedWeapon(cr) and
    Boolean((GDVars.baseItems[Types.PCharacter(cr)^.equipped[C_Equip.WEAPON]^.itemType].props and $14) = $14)
end;

function FindDamagingRangedWeapon(w: Pointer; var item: Pointer): Boolean;
var
  weapon: Types.PItem;
  properties: Byte;
begin
  FindDamagingRangedWeapon := False;
  weapon := Types.PCharacter(w)^.equipped[C_Equip.WEAPON];
  item := nil;
  properties := 0;
  if weapon <> nil then begin
    properties := GDVars.baseItems[weapon^.itemType].props;
    if (properties and C_Item.THROWN) <> 0 then
      item := weapon;
    if (properties and C_Item.FIRES_AMMO) <> 0 then begin
      if (properties and C_Item.USES_ARROWS) <> 0 then
        item := Types.PCharacter(w)^.equipped[C_Equip.ARROW];
      if (properties and C_Item.USES_QUARRELS) <> 0 then
        item := Types.PCharacter(w)^.equipped[C_Equip.BOLT]
    end
  end;
  if (item <> nil) or (properties = $0A) then
    FindDamagingRangedWeapon := True
end;

function BandageDying(apply: Boolean): Boolean;
var
  character: Types.PCharacter;
  found: Boolean;
begin
  found := False;
  character := GDVars.partyHead;
  while character <> nil do begin
    if (character^.combatAddr^.notPcNpc = 0) and (character^.side = 0) and
        (character^.status = C_Status.DYING) then begin
      found := True;
      if apply then begin
        character^.status := C_Status.UNCONSCIOUS;
        character^.combatAddr^.overkill := 0;
        CharHlp.PrintCreatureMessage(character, 'is bandaged', 10, 1);
        apply := False
      end
    end;
    character := character^.next
  end;
  BandageDying := found
end;

procedure SelectChar(query: Types.TStr40; addExit: Boolean; mode: Byte; var selected: Types.PCharacter);
var
  dispatch: Char;
  key: Char;
  { Unused in this version; see the other implementations of this routine. }
  reinterpret: Byte;
  animate: Boolean;
  candidate: Pointer;
  oldMenuState: Byte;
  oldInputState: Byte;
begin
  oldMenuState := GDVars.partyClickMode;
  GDVars.selectionMode := mode;
  GDVars.menuSelection := GDVars.partyHead;
  while (GDVars.menuSelection <> nil) and (selected <> GDVars.menuSelection) do
    GDVars.menuSelection := GDVars.menuSelection^.next;
  if GDVars.menuSelection = nil then
    selected := GDVars.partyHead;
  GDVars.menuSelection := GDVars.curChar;
  key := #255;
  oldInputState := GDVars.isMoveMode;
  GDVars.isMoveMode := 0;
  while (key >= #2) and (key <> C_Keys.ESCAPE) do begin
    CharHlp.DisplayParty(selected);
    if (GDVars.locState.current = C_Ifc.CAMPING) or (GDVars.locState.current = C_Ifc.LOOT) then
      animate := True
    else
      animate := False;
    if GDVars.locState.current = C_Ifc.MAIN_MENU then
      GDVars.partyClickMode := 1;
    if addExit then
      MenuCore.ResetMenuSlots(1)
    else
      MenuCore.ResetMenuSlots(0);
    key := MenuCore.MenuHorizontal(query + ' ', GDConsts.selectExitMenu, 1, Byte(animate));
    GDVars.partyClickMode := oldMenuState;
    candidate := selected;
    if GDVars.menuReturnedKey then begin
      dispatch := key;
      case dispatch of
        C_Keys.ESCAPE:
          if addExit then candidate := nil;
        C_Keys.DOWN:
          begin
            candidate := Types.PCharacter(candidate)^.next;
            if candidate = nil then candidate := GDVars.partyHead
          end;
        C_Keys.UP:
          if GDVars.mouseClicked then begin
            if GDVars.selectionMode <> 0 then
              candidate := GDVars.menuSelection
            else begin
              candidate := GDVars.alternateChar;
              GDVars.curChar := GDVars.alternateChar
            end
          end else begin
            candidate := GDVars.partyHead;
            if selected <> GDVars.partyHead then
              while (candidate <> nil) and (Types.PCharacter(candidate)^.next <> selected) do
                candidate := Types.PCharacter(candidate)^.next
            else
              while (candidate <> nil) and (Types.PCharacter(candidate)^.next <> nil) do
                candidate := Types.PCharacter(candidate)^.next
          end
      end
    end else if addExit and (key = #1) then
      candidate := nil;
    selected := candidate
  end;
  GDVars.isMoveMode := oldInputState;
  GDVars.selectionMode := 0
end;

function DirTowardTarget(creature, other: Pointer): Byte;
var
  dir: Byte;
  found: Boolean;
  x1: Integer;
  y1: Integer;
  x2: Integer;
  y2: Integer;
  deltaX: Integer;
  deltaY: Integer;
begin
  x1 := ShortInt(CbtMap.CombatCellX(creature));
  y1 := ShortInt(CbtMap.CombatCellY(creature));
  x2 := ShortInt(CbtMap.CombatCellX(other));
  y2 := ShortInt(CbtMap.CombatCellY(other));
  deltaX := Abs(x2 - x1);
  deltaY := Abs(y2 - y1);
  dir := C_Dir.NORTH;
  found := False;
  while not found do begin
    case dir of
      C_Dir.NORTH: found := (y2 <= y1) and (deltaX * 618 div 256 <= deltaY);
      C_Dir.EAST: found := (x2 >= x1) and (deltaX * 106 div 256 >= deltaY);
      C_Dir.SOUTH: found := (y2 >= y1) and (deltaX * 618 div 256 <= deltaY);
      C_Dir.WEST: found := (x2 <= x1) and (deltaX * 106 div 256 >= deltaY);
      C_Dir.NORTHEAST:
        found := (y2 < y1) and (x2 > x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      C_Dir.SOUTHEAST:
        found := (y2 > y1) and (x2 > x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      C_Dir.SOUTHWEST:
        found := (y2 > y1) and (x2 < x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY);
      C_Dir.NORTHWEST:
        found := (y2 < y1) and (x2 < x1) and (deltaX * 618 div 256 >= deltaY) and (deltaX * 106 div 256 <= deltaY)
    end;
    if not found then Inc(dir)
  end;
  DirTowardTarget := dir
end;

function CanLevelUp(cr: Pointer): Boolean;
var
  capped: Boolean;
  found: Boolean;
  classId: ShortInt;
  level: Byte;
  needed: LongInt;
begin
  found := False;
  classId := 0;
  while (classId <= C_Class.THIEF) and not found do begin
    if Types.PCharacter(cr)^.classLevels[classId] > 0 then
      if Types.PCharacter(cr)^.classLevels[classId] < 40 then begin
        level := Types.PCharacter(cr)^.classLevels[classId];
        needed := ClassCal.XpForLevel(Types.PCharacter(cr), level + 1, classId);
        capped := GDConsts.raceCaps[Types.PCharacter(cr)^.race, classId] <= level;
        if not capped then
          with Types.PCharacter(cr)^ do
            case race of
              C_Race.DWARF: if (classId = C_Class.FIGHTER) and
                (((level = 8) and (stats[C_Stat.STRENGTH].current = 17)) or
                 ((level = 7) and (stats[C_Stat.STRENGTH].current < 17))) then
                   capped := True;
              C_Race.ELF: begin
                   if (classId = C_Class.FIGHTER) and
                       (((level = 6) and (stats[C_Stat.STRENGTH].current = 17)) or
                        ((level = 5) and (stats[C_Stat.STRENGTH].current < 17))) then
                     capped := True;
                   if (classId = C_Class.MAGE) and
                       (((level = 9) and (stats[C_Stat.INTELLIGENCE].current < 17)) or
                        ((level = 10) and (stats[C_Stat.INTELLIGENCE].current = 17))) then
                     capped := True
                 end;
              C_Race.GNOME: begin
                   if (classId = C_Class.FIGHTER) and (level = 5) and
                       (stats[C_Stat.STRENGTH].current < 18) then
                     capped := True;
                   if (classId = C_Class.CLERIC) and (level >= 7) then
                     capped := True
                 end;
              C_Race.HALF_ELF: begin
                   if ((classId = C_Class.FIGHTER) or (classId = C_Class.RANGER)) and
                       (((level = 7) and (stats[C_Stat.STRENGTH].current = 17)) or
                        ((level = 6) and (stats[C_Stat.STRENGTH].current < 17))) then
                     capped := True;
                   if (classId = C_Class.MAGE) and
                       (((level = 7) and (stats[C_Stat.INTELLIGENCE].current = 17)) or
                        ((level = 6) and (stats[C_Stat.INTELLIGENCE].current < 17))) then
                     capped := True
                 end;
              C_Race.HALFLING: if (classId = C_Class.FIGHTER) and
                (((level = 5) and (stats[C_Stat.STRENGTH].current = 17)) or
                 ((level = 4) and (stats[C_Stat.STRENGTH].current < 17))) then
                   capped := True
            end;
        found := (Types.PCharacter(cr)^.experience >= needed) and (needed > 0) and
          (GDConsts.trainingLimits[classId] > level) and not capped
      end;
    Inc(classId)
  end;
  CanLevelUp := found
end;

procedure ScatterCombatIcon(step, cell, soundId: Byte);
var
  randomFrame: Byte;
  radius: Real;
  angle: Real;
  count: Byte;
  ring: Byte;
  point: Byte;
  flags: Byte;
  savedX: ShortInt;
  savedY: ShortInt;
  xOffset: ShortInt;
  yOffset: ShortInt;
  yBase: ShortInt;
  xBase: ShortInt;
begin
  CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, 255, C_Dir.CENTER);
  savedX := GDVars.targetCoordX;
  savedY := GDVars.targetCoordY;
  Music.SendSoundCommand(soundId);
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, False);
  CharHlp.CopyIconFacing(cell, 1, 3, True);
  flags := 1;
  xBase := 0;
  yBase := 0;
  if savedX < 3 then
    xBase := (savedX - 3) * 3
  else if savedX > 46 then
    xBase := ((savedX - 49) + 3) * 3;
  if savedY < 3 then
    yBase := (savedY - 3) * 3
  else if savedY > 21 then
    yBase := ((savedY - 24) + 3) * 3;
  count := step * 3 + 1;
  for ring := 1 to count do begin
    radius := ring;
    for point := ring * 2 - 2 downto 0 do begin
      angle := Random * 2.0 * Pi;
      xOffset := xBase + Trunc(Cos(angle) * radius);
      yOffset := yBase + Trunc(Sin(angle) * radius);
      if (xOffset >= -9) and (xOffset <= 9) and (yOffset >= -9) and (yOffset <= 9) then begin
        randomFrame := Random(4);
        Blit.BlitTileClipped(xOffset + 9, yOffset + 9, randomFrame, flags, Types.PImage(GDVars.combatImage),
                             Types.PImage(GDVars.viewSurface))
      end
    end;
    Blit.FlushView
  end;
  CbtMap.ScrollView(GDVars.targetCoordX, GDVars.targetCoordY, 255, C_Dir.CENTER)
end;

function ClassConAdj(cr: Pointer; cls: Byte): ShortInt;
var
  adjustment: ShortInt;
begin
  case Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current of
    3: adjustment := -2;
    4..6: adjustment := -1;
    7..14: adjustment := 0;
    15: adjustment := 1;
    16: adjustment := 2;
    17..19:
      if (cls = C_Class.FIGHTER) or (cls = C_Class.RANGER) or (cls = C_Class.PALADIN) then
        adjustment := Types.PCharacter(cr)^.stats[C_Stat.CONSTITUTION].current - 14
      else
        adjustment := 2
  end;
  ClassConAdj := adjustment
end;

procedure ClearEncounterState;
var
  next: Pointer;
begin
  GDVars.undeadCount := 0;
  GDVars.cloneCount2 := 0;
  GDVars.wallDirty[0] := 0;
  GDVars.monsterCount := 8;
  GameIo.ZeroFill(GDVars.pooledMoney, SizeOf(GDVars.pooledMoney));
  while GDVars.treasureItems <> nil do begin
    next := GDVars.treasureItems^.next;
    GameIo.FreeSlot(Pointer(GDVars.treasureItems));
    GDVars.treasureItems := next
  end;
  GDVars.treasureItems := nil
end;

procedure BuildIconFacingsDir(direction, cell: Byte);
begin
  if Odd(direction) then begin
    if (direction = C_Dir.SOUTHEAST) or (direction = C_Dir.SOUTHWEST) then
      CharHlp.CopyIconFacing(cell + 1, 1, 0, direction = C_Dir.SOUTHWEST)
    else
      CharHlp.CopyIconFacing(cell + 1, 0, 0, direction = C_Dir.NORTHWEST)
  end else
    CharHlp.CopyIconFacing(cell + (direction mod 4), direction div 4, 0, False)
end;

procedure DebugDumpParty;
var
  cr: Types.PCharacter;
  item: Types.PItem;
  effect: Types.PEffect;

  { Return an effect's name, or its number outside 1..160. }
  function EffectName(effectId: Byte): String;
  begin
    if effectId in [1..160] then
      EffectName := GDVars.effectNames^[effectId]
    else
      EffectName := GDVars.intToStringHook(effectId)
  end;

  { Return an item name part with a trailing space, or its number outside 1..130. }
  function ItemPartName(partId: Byte): String;
  begin
    if partId in [1..130] then
      ItemPartName := GDConsts.itemNameParts[partId] + ' '
    else
      ItemPartName := GDVars.intToStringHook(partId) + ' '
  end;

begin
  if not (GDConsts.editorEnabled and ((biosBreak and $10) <> 0)) then Exit;
  Exit;
  cr := GDVars.partyHead;
  while cr <> nil do begin
    GDVars.showMessage(cr^.name);
    if not (GDConsts.editorEnabled and ((biosBreak and $10) <> 0)) then Exit;
    item := cr^.items;
    while item <> nil do begin
      GDVars.showMessage(cr^.name + ' ' + ItemPartName(item^.nameIds[1]) + ItemPartName(item^.nameIds[2]) +
        ItemPartName(item^.nameIds[3]));
      if not (GDConsts.editorEnabled and ((biosBreak and $10) <> 0)) then Exit;
      item := item^.next
    end;
    effect := cr^.effects;
    while effect <> nil do begin
      GDVars.showMessage(cr^.name + ' ' + EffectName(effect^.id));
      if not (GDConsts.editorEnabled and ((biosBreak and $10) <> 0)) then Exit;
      effect := effect^.next
    end;
    cr := cr^.next
  end
end;

begin
end.
