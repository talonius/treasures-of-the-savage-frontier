{ Typed constants: every initialized table, message and menu in the data segment, grouped in sections by the subsystem
  that uses them and kept in address order. A new section starts wherever the data needs a word boundary. }
unit GDConsts;

interface

uses Types, C_Effect;

{ Script item lists, the copy-protection journal and the temple's spells. }
const
  { item templates a script hands out, in lists 1..16 each ended by $FF; 0 is no item }
  wardTable: array[1..114] of Byte = (
    $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F, $10, $11, $12, $13, $14, $15, $16, $17,
    $18, $19, $1A,
    $1B, $1C, $1D, $1E, $1F, $24, $25, $26, $27, $28, $29, $2A, $2B, $FF, $20, $21, $22, $23, $31, $A6, $FF, $32, $33,
    $34, $35, $36,
    $37, $38, $39, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4A, $4B, $4C, $4D,
    $4E, $FF, $50,
    $51, $52, $53, $54, $55, $56, $57, $58, $59, $5A, $5B, $5C, $5D, $5E, $5F, $60, $61, $62, $63, $64, $65, $66, $67,
    $68, $69, $6A,
    $6B, $6C, $FF, $6E, $6F, $70, $71, $72, $73, $74);
  { unused }
  journalWordBytes: array[0..97] of Byte = ($75, $76, $77, $78, $79, $7A, $7B, $7C, $7D, $7E, $7F, $80, $81,
    $82, $83, $84, $85,
    $86, $87, $88, $89, $8A, $FF, $20, $21, $22, $23, $31, $46, $A6, $FF, $20, $21, $22, $23, $31, $46, $A6, $A3, $FF,
    $20, $21, $22, $23, $31, $64, $A6, $A4, $FF, $9F, $A0, $A1, $A8, $A9, $FF, $9A, $9B, $9C, $9D, $A7, $FF, $AB, $AC,
    $AD, $AE, $B9, $FF, $00, $FF, $8C, $8D, $8E, $EE, $F5, $F7, $FF, $8F, $90, $91, $92, $98, $F3, $FF, $93, $94, $95,
    $96, $99, $F7, $FF, $20, $21, $22, $23, $31, $A6, $A5, $FF);
  { the journal checks: each heading, its page, three word numbers ($FF none) and the encoded words }
  journalTable: array[1..21] of Types.TJournalEntry4 = (
    (heading: #149#150#148#146#154#158;
     pageNumber: 3; wordNumber: (5, 6, 9);
     encodedWord: (#141#154#158,
       #141#144#162#160#156#152#160,
       #149#157#162#160#146)),
    (heading: #141#147#140#159#147#230#152#162#233#150#148#163#161#165#168#168#157;
     pageNumber: 4; wordNumber: (4, 5, 9);
     encodedWord: (#156#161#144#144#160#148#153,
       #156#158#156#159,
       #141#154#154#145)),
    (heading: #141#144#154#162#150#165#149;
     pageNumber: 4; wordNumber: (2, 7, $FF);
     encodedWord: (#141#144#162#160#156#152#160,
       #159#157#143#141#160#161#153,
       '')),
    (heading: #160#160#154#152#156#146#142#232#150#167#156#154#168#155;
     pageNumber: 6; wordNumber: (3, 4, 6);
     encodedWord: (#153#161#144,
       #142#153#139,
       #154#157#149#159#147#165#147#163#165)),
    (heading: #158#154#162#146#164#163#147#163#151#234#168#160#172#155#156#171#158;
     pageNumber: 7; wordNumber: (2, 8, $FF);
     encodedWord: (#160#144#158,
       #148#141#144#144,
       '')),
    (heading: #146#142#155#159#147#230#166#148#149#152#162#170#152#154#170#157;
     pageNumber: 8; wordNumber: (1, 3, 6);
     encodedWord: (#156#161#160#156,
       #160#150#144#149,
       #152#149#147#149#147#146#166#154#149)),
    (heading: #160#150#154#157#151#153#162#154#149;
     pageNumber: 8; wordNumber: (5, 7, 9);
     encodedWord: (#160,
       #149#153#141#159#146,
       #160#148#159)),
    (heading: #152#148#154#144#156#165#147#159#147#165;
     pageNumber: 10; wordNumber: (2, 3, 7);
     encodedWord: (#143#147#142#150#161,
       #146#156,
       #152#148#143#149)),
    (heading: #143#141#149#150#156#152#160#232#168#147#170#147;
     pageNumber: 12; wordNumber: (2, 5, 9);
     encodedWord: (#158#154#162#146#164#163#147#163#151,
       #155#144#148#151,
       #153#157)),
    (heading: #141#153#147#145#229#151#153#232#156#169#164#163#170;
     pageNumber: 13; wordNumber: (1, 2, $FF);
     encodedWord: (#159#147#143#156,
       #158#150#158#146#156#163#148,
       '')),
    (heading: #148#161#156#155#162#165#155#232#149#152#166#171#154#153#157#171#158;
     pageNumber: 14; wordNumber: (3, 4, 8);
     encodedWord: (#141#144#162#142#160#154,
       #160#160#148#143#145,
       #148#147#149#145#145#161#149#149)),
    (heading: #159#157#144#144#156#165#149#143;
     pageNumber: 15; wordNumber: (4, 9, $FF);
     encodedWord: (#141#154#158#145#160,
       #139#161#145#155#160#162,
       '')),
    (heading: #142#146#158#161#145#148#162#149;
     pageNumber: 17; wordNumber: (2, 4, 5);
     encodedWord: (#140#148#159#159#164#162,
       #153#161#142#150#145,
       #141#154#158)),
    (heading: #143#147#160#153#229#148#162#152#149#161#159#167#154;
     pageNumber: 17; wordNumber: (4, 5, $FF);
     encodedWord: (#149#153#137#163#147#162#148,
       #138#153#143#156,
       '')),
    (heading: #145#141#145#148#153#161#231#145#154#152#158#153;
     pageNumber: 17; wordNumber: (3, 5, $FF);
     encodedWord: (#156#148#148#146#152#151#146#149,
       #141#154#162#144,
       '')),
    (heading: #147#157#140#228#152#151#153#149#149#165#153#153;
     pageNumber: 18; wordNumber: (1, 3, 4);
     encodedWord: (#141#154#158,
       #158#144#158#163#145#145#149#163#150,
       #160#144#158)),
    (heading: #142#150#148#141#229#150#152#159#150#155#157;
     pageNumber: 20; wordNumber: (1, 2, 7);
     encodedWord: (#143#157#141#155#143#161#148,
       #160,
       #157#141#145#163#145#157#152#154)),
    (heading: #156#148#143#163#151#159#155#163;
     pageNumber: 21; wordNumber: (2, 4, 7);
     encodedWord: (#145#150#162#150#145#147,
       #154#144#148#141,
       #160#144#148#143#151#162)),
    (heading: #152#148#141#155#146#157#165#159#157#161#151#147#237#154#160#240#176#164#170#167#180#170#164;
     pageNumber: 21; wordNumber: (3, 5, $FF);
     encodedWord: (#141#161#145#157#160#146,
       #141#147,
       '')),
    (heading: #149#153#156#156#145#152#158#154#162#234#169#157#161#154;
     pageNumber: 23; wordNumber: (1, 3, 7);
     encodedWord: (#152#143,
       #148#161#156#155#162#165#155,
       #157#147#158#145)),
    (heading: #155#153#145#159#229#147#159#159#164#158#167;
     pageNumber: 24; wordNumber: (1, 9, $FF);
     encodedWord: (#145#144#148#144#160#163#147#149,
       #153#153#143#145,
       '')));
  { the temple's spells, as spellNames indexes }
  nameIdxTable: array[1..11] of Byte = (37, 39, 3, 58, 71, 36, 67, 75, 43, 113, 102);

{ The after-combat skip switch. }
const
  { nonzero ends the after-combat sequence before treasure; never set }
  postSkipFlag: Byte = $00;

{ Aging, combat AI steps, combat placement and terrain, and the editors' layouts. }
const
  { the age at which a character is warned of dying of old age, by race; death comes ten years past it }
  ageThreshold: array[0..5] of Word = (1600, 325, 525, 525, 199, 120);
  { the direction offsets, in eighths of a turn with 8 straight ahead, that each combat AI stance tries in order }
  aiDirOffsets: array[1..6, 1..5] of Byte = ((8, 7, 6, 1, 2), (8, 1, 2, 7, 6), (7, 1, 8, 6,
    2), (1, 7, 8, 2, 6), (8, 7, 6, 5, 4), (8, 1, 2, 3, 4));
  { combat placement, by team facing and ring: the ring's direction }
  ringDirTbl: array[0..3, 0..3] of Byte = ((8, 4, 6, 2), (8, 6, 4, 0), (8, 0, 6, 2), (8, 2,
    0, 4));
  { by team facing and ring: the ring's start quadrant }
  ringStart: array[0..3, 0..3] of Byte = ((0, 0, 2, 6), (2, 2, 0, 4), (4, 4, 2, 6), (6, 6,
    4, 0));
  { each quadrant's direction }
  quadDir: array[0..3] of Byte = (
    7, 2, 3, 6);
  { the quadrant start columns, for the first ring and the outer rings }
  startQX: array[Boolean, 0..3] of ShortInt = ((5, 4, 5, 6), (3, 8, 7, 2));
  { the quadrant start rows, for the first ring and the outer rings }
  startQY: array[Boolean, 0..3] of ShortInt = ((3, 2, 2, 3), (0, 2, 5, 3));
  { the columns a team may be placed in, by distance band and row }
  rowBand: array[0..4, 0..5] of Types.TBandRec = (((lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 1; hi: 0), (lo: 2; hi: 9),
    (lo: 3; hi: 10), (lo: 4; hi: 10)), ((lo: 0; hi: 2), (lo: 0; hi: 3), (lo: 1; hi: 4), (lo: 2; hi: 5),
    (lo: 3; hi: 6), (lo: 4; hi: 7)), ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 1; hi: 0), (lo: 1; hi: 0),
    (lo: 1; hi: 0)), ((lo: 3; hi: 6), (lo: 4; hi: 7), (lo: 5; hi: 8), (lo: 6; hi: 9), (lo: 7; hi: 10),
    (lo: 8; hi: 10)), ((lo: 0; hi: 6), (lo: 0; hi: 7), (lo: 1; hi: 8), (lo: 2; hi: 9), (lo: 3; hi: 10),
    (lo: 4; hi: 10)));
  { the combat terrain class of each wilderness terrain }
  terrainClassTbl: array[0..31] of Byte = (
    $00, $18, $11, $15, $01, $01, $60, $14, $08, $01, $00, $21, $71, $09, $06, $04, $01, $09, $09, $08, $59, $00, $11,
    $11, $00, $00,
    $01, $11, $00, $00, $20, $20);
  { the map editor's GEO file: its header, the name it saves and loads, and the wall kind names }
  geoNameAnchor: Types.TGeoNameAnchor = (initialized: 0; newWall: 0; header: $0400; name: 'GEO00'; loadName: 'GEO00';
    wallNames: ('Blocked', 'Clear', 'Locked Door', 'Magic Lock'));
  { the item editor's field columns, by field 0..14 }
  itemXs14Local: array[0..14] of Byte = (
    $01, $02, $03, $04, $05, $01, $01, $14, $01, $14, $01, $14, $01, $02, $03);
  { unused }
  itemXs14LocalTail: Byte = $00;
  { and their rows }
  itemYs14Local: array[0..14] of Byte = (
    $11, $11, $11, $11, $11, $12, $13, $13, $14, $14, $15, $15, $16, $16, $16);

{ The money editor's layout, character files and icons, legacy items, start-up items and colors, CGA fills and the
  shape-change icons. }
const
  { the money editor's field columns }
  wealthXs: array[0..11] of Byte = (
    $01, $14, $01, $14, $01, $14, $01, $01, $01, $14, $14, $14);
  { and their rows }
  wealthYs: array[0..11] of Byte = ($11, $11, $12, $12, $13, $13, $14, $15, $16, $16, $14, $15);
  { Romance: the third party member it last named }
  otherPartyMember: Types.PCharacter = nil;
  { pads a character name to 15 characters in the roster list }
  blankName: String[15] = '               ';
  { by storage mode (legacy, saved game): where a character file holds the name }
  nameOffsets: array[0..1] of Byte = ($00, $00);
  { where it holds the NPC marker byte }
  markerOffsets: array[0..1] of Word = ($00F7, $0147);
  { and the file's size }
  expectedFileSizes: array[0..1] of Word = ($01A6, $01FE);
  { the letter the CHEAD and CBODY picture names take for icon size 1 and 2 }
  iconSizeLetters: array[1..2] of Char = ('S', 'T');
  { the legacy item-name table, bord.dax block 10 }
  borderData: Types.PByteBuffer = nil;
  { a Gateway item's type in this game, by its old type; 0 cannot be used }
  legacyTypeMap: array[1..127] of Byte =
    ($01, $02, $00, $00, $00, $00, $03, $04, $05, $00, $00, $00, $00, $00, $00, $00, $00,
    $00, $00, $06, $07, $00, $08, $09, $00, $0A, $0B, $0C, $00, $0D, $0E, $00, $0F, $10, $11, $12, $13, $14, $15, $00,
    $16, $17, $18, $19, $1A, $1B, $1C, $1D, $1E, $1F, $00, $20, $20, $21, $22, $23, $23, $24, $25, $26, $27, $28, $48,
    $29, $2A, $2B, $2C, $2D,
    $2E, $2F, $30, $31, $1E, $00, $00, $00, $32, $33, $34, $00, $00, $00, $00, $35, $36,
    $00, $37, $38, $39, $00, $00, $3A, $3B, $3C, $3D, $3E, $3F, $40, $41, $42, $1D, $43, $44, $45, $46, $47, $00, $00,
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00);
  { unused }
  legacyTypeMapTail: Byte = $00;
  { menu slots per icon-edit state }
  iconMenuCounts: array[1..5] of Byte = (4, 2, 7, 3, 3);
  { unused }
  iconMenuCountsTail: Byte = 0;
  { the item templates a new character starts with, by equipment family and line 1..6; 0 is an empty line }
  startingItems: array[1..4, 1..6] of Byte = (($42, $28, $4E, $05, $01, $00), ($42, $3F, $00, $00, $00, $00),
    ($3C, $28, $4E, $19, $00, $00), ($40, $0B, $D2, $00, $00, $00));
  { the first four palette colors GameInit sets }
  defaultColors: array[0..3] of Types.TRGB = ((0, 0, 0), (0, 0, 170), (0, 170, 0), (0, 170, 170));
  { unused: nine CGA fill patterns of four rows each }
  cgaFillPatterns: array[0..8, 0..3] of Byte = (($AA, $00, $00, $AA), ($00, $AA, $AA, $55), ($00, $AA, $AA, $AA),
    ($55, $55, $55, $55), ($55, $FF, $55, $FF), ($55, $55, $FF, $FF), ($FF, $55, $55, $FF), ($55, $FF, $FF, $FF),
    ($55, $FF, $FF, $FF));
  { Set while the shape-change icons are loaded into their combat icon slots }
  shapeIconsLoaded: Boolean = False;

{ Shape changing: the icon blocks. }
const
  { The CPIC blocks a shape changer's forms load from, by the combat icon slot each loads into }
  shapeIconBlocks: array[$26..$2A] of Byte = ($72, $6F, $25, $0E, $02);

{ Turning undead. }
const
  { The d20 roll a turning attempt needs, by undead level and turning column; 99 cannot turn, and a negative entry also
    draws 1d6+6 attempts instead of 1d12 }
  turnUndeadTable: array[1..13, 0..10] of ShortInt = (
    (99, 10, 7, 4, 1, 1, 0, 0, -1, -1, -1),
    (99, 13, 10, 7, 1, 1, 0, 0, 0, -1, -1),
    (99, 16, 13, 10, 4, 1, 1, 0, 0, 0, -1),
    (99, 19, 16, 13, 7, 4, 1, 1, 0, 0, -1),
    (99, 20, 19, 16, 10, 7, 4, 1, 1, 0, 0),
    (99, 99, 20, 19, 13, 10, 7, 4, 1, 1, 0),
    (99, 99, 99, 20, 16, 13, 10, 7, 4, 1, 0),
    (99, 99, 99, 99, 20, 16, 13, 10, 7, 4, 1),
    (99, 99, 99, 99, 99, 20, 16, 13, 10, 7, 1),
    (99, 99, 99, 99, 99, 99, 20, 16, 13, 10, 4),
    (99, 99, 99, 99, 99, 99, 99, 20, 16, 13, 10),
    (99, 99, 99, 99, 99, 99, 99, 99, 19, 16, 10),
    (99, 99, 99, 99, 99, 99, 99, 99, 20, 19, 13));

{ Areas of effect. }
const
  { By row offset and radius 1..3: the half-width of an area of effect on that row; -3 marks a row it does not reach }
  areaHalfWidth: array[-3..3, 1..3] of ShortInt = (
    (-3, -3, 1),
    (-3, 1, 2),
    (1, 2, 3),
    (1, 2, 3),
    (1, 2, 3),
    (-3, 1, 2),
    (-3, -3, 1));

{ Spell headings, ray and aim steps, the effects a fall removes, the scrolling list's words and the first fixed
  palette-cycle chunk. }
const
  { the spell-list group headings by spell level; level 0 is the item group }
  spellLevelNames: array[0..9] of String[40] =
    ('Special', '1st Level', '2nd Level', '3rd Level', '4th Level', '5th Level',
    '6th Level', '7th Level', '8th Level', '9th Level');
  { Magic: the first side ray's column offset from a multi-ray spell's target cell, by the center ray's direction }
  sideRayDx1: array[0..7] of ShortInt = (-1, 0, 0, 1, 1, 0, 0, -1);
  { the first side ray's row offset }
  sideRayDy1: array[0..7] of ShortInt = (0, -1, -1, 0, 0, 1, 1, 0);
  { the second side ray's column offset }
  sideRayDx2: array[0..7] of ShortInt = (1, 1, 0, 0, -1, -1, 0, 0);
  { the second side ray's row offset }
  sideRayDy2: array[0..7] of ShortInt = (0, 0, 1, 1, 0, 0, -1, -1);
  { a diagonal aim step's column offset, by mode }
  aimDeltaX: array[1..4] of ShortInt = (-1, 1, -1, 1);
  { and its row offset }
  aimDeltaY: array[1..4] of ShortInt = (-1, -1, 1, 1);
  { the effects removed when a creature falls to zero hit points }
  hpZeroBlock: array[1..16] of Byte =
    (C_Effect.SNAKE_HARASS, C_Effect.IMMUNE_ELECTRICITY, C_Effect.CHARM, C_Effect.SILENCE,
     C_Effect.SPIRITUAL_HAMMER, C_Effect.CONFUSED_LOSE_TURN, C_Effect.STINKING_CLOUD_COUGH, C_Effect.HELPLESS,
     C_Effect.CONFUSED, C_Effect.HELD, C_Effect.ASLEEP, C_Effect.CONFUSED_BERSERK, C_Effect.STUNNED,
     C_Effect.BERSERK, C_Effect.FRIGHTENED, C_Effect.DANCING);
  { the scrolling list's Next word }
  nextText: String[10] = ' Next';
  { unused }
  nextTextTail: Byte = $00;
  { its Exit word }
  exitText: String[10] = ' Exit';
  { unused }
  exitTextTail: Byte = $00;
  { its Prev word }
  prevText: String[10] = ' Prev';
  { unused }
  prevTextTail: Byte = $00;
  { the arrow key a click on the view stands for, by facing and direction (both halved) }
  menuDirections: array[0..3, 0..3] of Byte = (($48, $4D, $50, $4B), ($4B, $48, $4D, $50), ($50, $4B, $48, $4D),
    ($4D, $50, $4B, $48));
  { Big picture 242's three fixed palette-cycle chunks }
  specialChunk0: Types.TChunk3 = ($E0, $07, $76);

{ The second fixed palette-cycle chunk. }
const
  { its second }
  specialChunk1: Types.TChunk3 = ($7D, $03, $27);

{ The third fixed palette-cycle chunk. }
const
  { its third }
  specialChunk2: Types.TChunk3 = ($EB, $0D, $1B);

{ The loaded backdrop, the 3-D view's wall slots, file-name filtering and the continue prompts. }
const
  { the backdrop picture loaded; $FF for none }
  backdropLoadedId: Byte = $FF;
  { unused }
  backdropLoadedIdTail: Byte = $00;
  { the 3-D view's wall slots: each slot's first symbol, its size in cells and where it is drawn }
  viewSlotTable: Types.TVsTbl = (start: (0, 2, 6, 10, 22, 38, 54, 110, 132, 154); cols: (1, 1, 1, 3, 2, 2, 7, 2, 2, 1);
    rows: (2, 4, 4, 4, 8, 8, 8, 11, 11, 2); xCol: (5, 4, 6, 4, 2, 7, 2, 0, 9, 5); yRow: (4, 3, 3, 3, 1, 1, 1, 0, 0, 4));
  { characters stripped from file names }
  invalidFileCharTable: array[1..10] of Char = (' ', '.', '*', ',', '?', '/', '\', ':', ';', '|');
  { the continue prompt }
  pressButtonPrompt: String[33] = 'Press button or enter to continue';
  { the continue prompt with a leading ~ }
  tildePressButtonPrompt: String[34] = '~Press button or enter to continue';

{ Class, race and alignment names. }
const
  { the class names, by class id: the single classes, then the multi-classes }
  classNameTable: array[0..17] of String[26] =
    ('Cleric', 'Druid', 'Fighter', 'Paladin', 'Ranger', 'Magic-User', 'Thief',
    'Monk', 'Cleric/Fighter', 'Cleric/Fighter/Magic-User', 'Cleric/Ranger', 'Cleric/Magic-User', 'Cleric/Thief',
    'Fighter/Magic-User', 'Fighter/Thief', 'Fighter/Magic-User/Thief', 'Magic-User/Thief', 'Illegal type');
  { the race names, by race }
  raceNames: array[0..6] of String[8] = ('Elf', 'Half-Elf', 'Dwarf', 'Gnome', 'Halfling', 'Human', 'Monster');
  { unused }
  raceNamesTail: Byte = $00;
  { the alignment names }
  alignmentNames: array[0..8] of String[16] = ('Lawful Good', 'Lawful Neutral', 'Lawful Evil', 'Neutral Good',
    'True Neutral', 'Neutral Evil', 'Chaotic Good', 'Chaotic Neutral', 'Chaotic Evil');

{ Gender, wealth and status names, the main menu, and the messages and prompts up to character creation. }
const
  { the gender names }
  genderNames: array[0..1] of String[6] = ('Male', 'Female');
  { the names of the three kinds of wealth }
  wealthNames: array[0..2] of String[10] = ('Platinum', 'Gems', 'Jewelry');
  { unused }
  wealthNamesTail: Byte = $00;
  { the status names a character sheet shows }
  statusNames: array[0..8] of String[12] = ('Okay', 'Animated', 'tempgone', 'Running', 'Unconscious', 'Dying', 'Dead',
    'Petrified', 'Gone');
  { unused }
  statusNamesTail: Byte = $00;
  { the main menu's choices, and which are offered before a party exists }
  mainMenuItems: array[0..12] of Types.TMenuItem =
    ((name: 'Create New Character'; enabled: 1), (name: 'Drop Character'; enabled: 0),
    (name: 'Modify Character'; enabled: 0), (name: 'Train Character'; enabled: 0),
    (name: 'Human Change Classes'; enabled: 0), (name: 'View Character'; enabled: 0),
    (name: 'Add Character to Party'; enabled: 1), (name: 'Remove Character from Party'; enabled: 0),
    (name: 'Load Saved Game'; enabled: 1), (name: 'Save Current Game'; enabled: 0),
    (name: 'Begin Adventuring'; enabled: 0), (name: 'Initialize Mouse/Joystick'; enabled: 1),
    (name: 'Exit to DOS'; enabled: 1));
  { asks whether an item is to be dropped for good }
  itemDropQuery: String[40] = 'Lose it? ';
  { unused }
  itemDropQueryTail: Byte = $00;
  { a spell or item that cannot be used where the party is }
  cantCastHereMsg: String[40] = 'Can''t be cast here...';
  { unused }
  cantCastHereMsgTail: Byte = $00;
  { starts the message about an item that cannot be used here }
  thatItemMsg: String[40] = 'That item';
  { unused }
  thatItemMsgTail: Byte = $00;
  { an item that works only in combat }
  combatOnlyItemMsg: String[40] = 'Is a combat-only item...';
  { unused }
  combatOnlyItemMsgTail: Byte = $00;
  { asks whether to use the item }
  useItemPrompt: String[40] = 'Use it? ';
  { unused }
  useItemPromptTail: Byte = $00;
  { between a caster's name and the spell }
  castsWord: String[40] = 'casts';
  { unused }
  castsWordTail: Byte = $00;
  { the choice that stops a spell being cast }
  abortSpellPrompt: String[40] = 'Abort Spell';
  { unused }
  abortSpellPromptTail: Byte = $00;
  { shown when a spell is stopped }
  spellAbortedMsg: String[40] = 'Spell Aborted';
  { unused }
  spellAbortedMsgTail: Byte = $00;
  { the money menu asks how many coins to take }
  howManyText: String[40] = 'How many ';
  { unused }
  howManyTextTail: Byte = $00;
  { and finishes the question }
  willTakeText: String[40] = ' will you take? ';
  { unused }
  willTakeTextTail: Byte = $00;
  { the money menus ask how much to move }
  howMuchText: String[40] = 'How much ';
  { unused }
  howMuchTextTail: Byte = $00;
  { the gems line of the valuables count }
  appraiseHeading: String[40] = 'gems : ';
  { unused }
  appraiseHeadingTail: Byte = $00;
  { the jewelry line of the valuables count }
  appraisePrompt: String[40] = 'jewelry : ';
  { unused }
  appraisePromptTail: Byte = $00;
  { heads the list of a character's valuables }
  collectionText: String[40] = 'You have a fine collection of:';
  { unused }
  collectionTextTail: Byte = $00;
  { starts an appraised gem's value }
  gemValueText: String[40] = 'The gem is valued at ';
  { unused }
  gemValueTextTail: Byte = $00;
  { starts an appraised jewel's value }
  jewelValueText: String[40] = 'The jewel is valued at ';
  { unused }
  jewelValueTextTail: Byte = $00;
  { the coin menu's prompt }
  tradeQuery: String[40] = 'select type of coin ';
  { unused }
  tradeQueryTail: Byte = $00;
  { asks who receives the coins }
  tradeToPrompt: String[40] = 'trade to?';
  { unused }
  tradeToPromptTail: Byte = $00;
  { asks how many coins to trade }
  willYouTradePrompt: String[40] = 'will you trade? ';
  { unused }
  willYouTradePromptTail: Byte = $00;
  { unused; asked whether to break off a rest }
  stopRestingPrompt: String[40] = 'Stop resting? ';
  { unused }
  stopRestingPromptTail: Byte = $00;
  { unused; followed the name of a character who could not scribe from a scroll }
  wasGoingToScribeMsg: String[40] = ' was going to scribe from that scroll';
  { unused }
  wasGoingToScribeMsgTail: Byte = $00;
  { heads the item list }
  itemsHeader: String[40] = 'Items';
  { unused }
  itemsHeaderTail: Byte = $00;
  { heads the list of items to ready }
  readyItemHeader: String[40] = 'Ready Item';
  { unused }
  readyItemHeaderTail: Byte = $00;
  { starts the warning before an item is dropped }
  itemGonePrefix: String[40] = 'Your ';
  { unused }
  itemGonePrefixTail: Byte = $00;
  { and ends it }
  itemGoneSuffix: String[40] = 'will be gone forever';
  { unused }
  itemGoneSuffixTail: Byte = $00;
  { an item that works only when readied }
  itemMustBeReadied: String[40] = 'Must be readied';
  { unused }
  itemMustBeReadiedTail: Byte = $00;
  { unused; started a shop's offer for an item }
  illGiveYouMsg: String[40] = 'I''ll give you ';
  { unused }
  illGiveYouMsgTail: Byte = $00;
  { unused; continued the offer }
  platinumForYourMsg: String[40] = ' platinum pieces for your ';
  { unused }
  platinumForYourMsgTail: Byte = $00;
  { unused; asked whether to take the offer }
  isItADealPrompt: String[40] = 'is it a deal? ';
  { unused }
  isItADealPromptTail: Byte = $00;
  { unused; shown when a sale went through }
  soldMsg: String[40] = 'sold!';
  { unused }
  soldMsgTail: Byte = $00;
  { unused; the seller could not carry the money }
  overloadedMsg: String[40] = 'overloaded. money will be put in pool.';
  { unused }
  overloadedMsgTail: Byte = $00;
  { unused; the identify offer, cut off at 40 characters }
  identifyOfferMsg: String[40] = 'for 100 platinum pieces i''ll identify yo';
  { unused }
  identifyOfferMsgTail: Byte = $00;
  { unused; an identified item with nothing more to learn }
  nothingNewMsg: String[40] = 'i cannot tell anything new about your ';
  { unused }
  nothingNewMsgTail: Byte = $00;
  { unused; started the description of an unidentified item }
  looksLikeMsg: String[40] = 'it looks like some sort of ';
  { unused }
  looksLikeMsgTail: Byte = $00;
  { asks how many coins to drop }
  willYouDropPrompt: String[40] = 'will you drop? ';
  { unused }
  willYouDropPromptTail: Byte = $00;
  { asks how many coins to deposit at a vault }
  willYouDepositPrompt: String[40] = 'will you deposit? ';
  { unused }
  willYouDepositPromptTail: Byte = $00;
  { asks whether to leave the game }
  quitToDosPrompt: String[40] = 'Quit to DOS ';
  { unused }
  quitToDosPromptTail: Byte = $00;
  { asks before quitting an unsaved game }
  quitUnsavedQuery: String[40] = 'game not saved. quit anyway? ';
  { unused }
  quitUnsavedQueryTail: Byte = $00;
  { heads the race list }
  raceHeader: String[40] = 'Pick Race';
  { unused }
  raceHeaderTail: Byte = $00;
  { heads the gender list }
  genderHeader: String[40] = 'Pick Gender';
  { unused }
  genderHeaderTail: Byte = $00;
  { heads the class list }
  classHeader: String[40] = 'Pick Class';
  { unused }
  classHeaderTail: Byte = $00;
  { unused; the deity menu }
  pickDeityPrompt: String[40] = 'Pick Diety';
  { unused }
  pickDeityPromptTail: Byte = $00;
  { heads the alignment list }
  alignmentHeader: String[40] = 'Pick Alignment';

{ The other messages, prompts and menus; item-name parts; direction, color, sound and symbol tables; terrain, icon
  shapes and effect lists; spell names and rules; the clock; THAC0 and class bits. }
const
  { unused; asked whether to roll the ability scores again }
  rerollStatsPrompt: String[40] = 'reroll stats? ';
  { unused }
  rerollStatsPromptTail: Byte = $00;
  { unused; asked for the new character's name }
  characterNamePrompt: String[40] = 'character name: ';
  { unused }
  characterNamePromptTail: Byte = $00;
  { unused; asked whether to keep the new character }
  saveCharacterPrompt: String[40] = 'save character? ';
  { unused }
  saveCharacterPromptTail: Byte = $00;
  { unused; started the question before a character was dropped }
  dropPrefix: String[40] = 'drop ';
  { unused }
  dropPrefixTail: Byte = $00;
  { unused; ended it }
  foreverSuffix: String[40] = ' forever ';
  { unused }
  foreverSuffixTail: Byte = $00;
  { unused; asked for confirmation }
  areYouSurePrompt: String[40] = 'Are you sure? ';
  { unused }
  areYouSurePromptTail: Byte = $00;
  { unused; followed the name of a character dropped from the party }
  dumpedOutBackMsg: String[40] = ' is dumped out back.';
  { unused }
  dumpedOutBackMsgTail: Byte = $00;
  { unused; followed the name of a character who left the party }
  bidsFarewellMsg: String[40] = ' bids you farewell.';
  { unused }
  bidsFarewellMsgTail: Byte = $00;
  { unused; followed the party's name when a dropped character was kept after all }
  sighOfReliefMsg: String[40] = ' breathe a sigh of relief.';
  { unused }
  sighOfReliefMsgTail: Byte = $00;
  { follows the name of a character that cannot be modified }
  modifyErrorSuffix: String[40] = ' can''t be modified.';
  { unused }
  modifyErrorSuffixTail: Byte = $00;
  { asks which storage to add a character from }
  addFromWherePrompt: String[40] = 'add from where? ';
  { unused }
  addFromWherePromptTail: Byte = $00;
  { asks which character to add }
  addCharacterPrompt: String[40] = 'add a character: ';
  { unused }
  addCharacterPromptTail: Byte = $00;
  { unused; a choice the CGA display does not offer }
  notInCgaMsg: String[40] = 'sorry not in CGA';
  { unused }
  notInCgaMsgTail: Byte = $00;
  { labels the icon editor's two poses }
  readyActionText: String[40] = 'ready   action';
  { unused }
  readyActionTextTail: Byte = $00;
  { labels the edited icon }
  iconNewText: String[40] = 'new';
  { unused }
  iconNewTextTail: Byte = $00;
  { labels the icon as it was }
  iconOldText: String[40] = 'old';
  { unused }
  iconOldTextTail: Byte = $00;
  { asks whether to keep the edited icon }
  iconOkPrompt: String[40] = 'is this icon ok? ';
  { unused }
  iconOkPromptTail: Byte = $00;
  { unused; a character not ready to train }
  notEnoughExperienceMsg: String[40] = 'not enough experience';
  { unused }
  notEnoughExperienceMsgTail: Byte = $00;
  { unused; followed the name of a character about to train }
  willBecomeMsg: String[40] = ' will become:';
  { unused }
  willBecomeMsgTail: Byte = $00;
  { unused; started each class line of the training result }
  aLevelPrefix: String[40] = '    a level ';
  { unused }
  aLevelPrefixTail: Byte = $00;
  { unused; started each further class line }
  andALevelPrefix: String[40] = 'and a level ';
  { unused }
  andALevelPrefixTail: Byte = $00;
  { unused; asked whether to train }
  wishToTrainPrompt: String[40] = 'do you wish to train? ';
  { unused }
  wishToTrainPromptTail: Byte = $00;
  { unused; shown when training succeeded }
  congratulationsMsg: String[40] = 'congratulations...';
  { unused }
  congratulationsMsgTail: Byte = $00;
  { unused; followed the name of a character seeking knighthood }
  petitioningMsg: String[40] = 'is petitioning to become a';
  { unused }
  petitioningMsgTail: Byte = $00;
  { unused; the knightly order of the sword }
  swordWord: String[40] = 'sword';
  { unused }
  swordWordTail: Byte = $00;
  { unused; the knightly order of the rose }
  roseWord: String[40] = 'rose';
  { unused }
  roseWordTail: Byte = $00;
  { unused; started the order's title }
  knightOfThePrefix: String[40] = 'knight of the ';
  { unused }
  knightOfThePrefixTail: Byte = $00;
  { unused; followed the name of a character too low in level to be knighted }
  tooInexperiencedMsg: String[40] = ' is too inexperienced';
  { unused }
  tooInexperiencedMsgTail: Byte = $00;
  { unused; followed the name of a character who did not qualify }
  doesNotQualifyMsg: String[40] = ' does not qualify.';
  { unused }
  doesNotQualifyMsgTail: Byte = $00;
  { unused; followed the name of a character who qualified }
  mayBecomeMsg: String[40] = ' may become a';
  { unused }
  mayBecomeMsgTail: Byte = $00;
  { asks for the save disk when the save directory is on a floppy }
  askDriveMsgB: String[40] = 'is your save disk in drive ';
  { unused }
  askDriveMsgBTail: Byte = $00;
  { the same question for the Gateway characters' disk }
  askDriveMsgA: String[40] = 'is your save disk in drive ';
  { unused }
  askDriveMsgATail: Byte = $00;
  { ends the save disk question after the drive letter }
  driveQMsg: String[40] = ':? ';
  { unused }
  driveQMsgTail: Byte = $00;
  { the save directory cannot be found }
  locatePodMsg: String[40] = 'can''t locate save directory';
  { unused }
  locatePodMsgTail: Byte = $00;
  { the Gateway directory cannot be found }
  locateSsbMsg: String[40] = 'can''t locate gateway directory';
  { unused }
  locateSsbMsgTail: Byte = $00;
  { a save that does not fit }
  diskFullMsg: String[40] = 'can''t save.  disk is full.';
  { unused }
  diskFullMsgTail: Byte = $00;
  { starts the question before a character file is overwritten }
  overwriteMsg: String[40] = 'overwrite ';
  { unused }
  overwriteMsgTail: Byte = $00;
  { and ends it }
  qMarkMsg: String[40] = '? ';
  { unused }
  qMarkMsgTail: Byte = $00;
  { asks for a new character file name }
  newFileMsg: String[40] = 'new file name : ';
  { unused }
  newFileMsgTail: Byte = $00;
  { follows the name of the character picked to move in the party order }
  hasBeenSelectedMsg: String[40] = 'has been selected';
  { unused }
  hasBeenSelectedMsgTail: Byte = $00;
  { shows the game speed }
  gameSpeedPrompt: String[40] = 'Game Speed (0=fastest 9=slowest) = ';
  { unused }
  gameSpeedPromptTail: Byte = $00;
  { shown when the party makes camp }
  campIntroText: String[40] = 'the party makes camp...';
  { unused }
  campIntroTextTail: Byte = $00;
  { shown when a search or camp is not allowed }
  notHereMsg: String[40] = 'not here';
  { unused }
  notHereMsgTail: Byte = $00;
  { asks before an ally is attacked }
  attackAllyPrompt: String[40] = 'attack ally? ';
  { unused }
  attackAllyPromptTail: Byte = $00;
  { starts the range line of the aim cursor }
  rangePrompt: String[40] = 'range = ';
  { unused }
  rangePromptTail: Byte = $00;
  { quick magic switched on }
  magicOnText: String[40] = 'magic on';
  { unused }
  magicOnTextTail: Byte = $00;
  { quick magic switched off }
  magicOffText: String[40] = 'magic off';
  { unused }
  magicOffTextTail: Byte = $00;
  { asks whether to flee }
  fleeText: String[40] = 'flee ? ';
  { unused }
  fleeTextTail: Byte = $00;
  { a move the combatant cannot make }
  cantGoText: String[40] = 'cant''t go there';
  { unused }
  cantGoTextTail: Byte = $00;
  { follows the name of a character who buys an item }
  buysSuffix: String[40] = ' buys ';
  { unused }
  buysSuffixTail: Byte = $00;
  { the same with the article }
  buysASuffix: String[40] = ' buys a ';
  { unused }
  buysASuffixTail: Byte = $00;
  { an item the buyer cannot pay for }
  notEnoughMoneyMsg: String[40] = 'not enough money.';
  { unused }
  notEnoughMoneyMsgTail: Byte = $00;
  { warns that pooled money was left in the shop }
  leftMoneyMsg: String[80] = 'as you leave a man says, "excuse me but you have left some money here." ';
  { unused }
  leftMoneyMsgTail: Byte = $00;
  { asks whether to go back for it }
  goBackForMoneyPrompt: String[80] = 'do you want to go back and get your money?';
  { unused }
  goBackForMoneyPromptTail: Byte = $00;
  { ends a fight the party ran from }
  partyFledMsg: String[40] = 'the party has fled.';
  { unused }
  partyFledMsgTail: Byte = $00;
  { ends a fight the party lost }
  lostFightMsg: String[40] = 'you have lost the fight.';
  { unused }
  lostFightMsgTail: Byte = $00;
  { ends a fight with no treasure to show }
  wonDuelMsg: String[40] = 'the party has won.';
  { unused }
  wonDuelMsgTail: Byte = $00;
  { unused; the bank's withdrawal fee message }
  withdrawalFeeMsg1: String[40] = 'the party makes a withdrawl. a small';
  { unused }
  withdrawalFeeMsg1Tail: Byte = $00;
  { unused; and its second line }
  withdrawalFeeMsg2: String[40] = 'fee has been assessed by the bank.';
  { unused }
  withdrawalFeeMsg2Tail: Byte = $00;
  { ends a fight that left treasure }
  partyWonMsg: String[40] = 'the party has found treasure';
  { unused }
  partyWonMsgTail: Byte = $00;
  { ends a fight that left none }
  noTreasureMsg: String[40] = 'the party has found no treasure';
  { unused }
  noTreasureMsgTail: Byte = $00;
  { starts the experience share line }
  eachReceivesText: String[40] = 'each character receives ';
  { unused }
  eachReceivesTextTail: Byte = $00;
  { and ends it }
  experiencePointsText: String[40] = 'experience points.';
  { unused }
  experiencePointsTextTail: Byte = $00;
  { warns that treasure is still on the ground }
  treasureLeftText1: String[40] = 'there is still treasure left. ';
  { unused }
  treasureLeftText1Tail: Byte = $00;
  { asks whether to go back for it }
  treasureLeftText2: String[40] = 'do you want to go back and claim it?';
  { unused }
  treasureLeftText2Tail: Byte = $00;
  { asks whether to cast a cure that is not needed }
  cureAnywayPrompt: String[40] = 'cast cure anyway? ';
  { unused }
  cureAnywayPromptTail: Byte = $00;
  { unused; asked whether to pay the temple }
  payForCurePrompt: String[40] = 'pay for cure? ';
  { unused }
  payForCurePromptTail: Byte = $00;
  { unused; followed the name of a cured character }
  isCuredMsg: String[40] = 'is cured.';
  { unused }
  isCuredMsgTail: Byte = $00;
  { follows the name of a character with no blindness to cure }
  notBlindMsg: String[40] = 'is not blind.';
  { unused }
  notBlindMsgTail: Byte = $00;
  { unused; no disease to cure }
  notDiseasedMsg: String[40] = 'is not diseased.';
  { unused }
  notDiseasedMsgTail: Byte = $00;
  { a character beyond raising }
  cannotRaiseMsg: String[40] = 'cannot be raised.';
  { unused }
  cannotRaiseMsgTail: Byte = $00;
  { a character the temple cannot help }
  beyondHelpMsg: String[40] = 'is beyond our help';
  { unused }
  beyondHelpMsgTail: Byte = $00;
  { no death to undo }
  notDeadMsg: String[40] = 'is not dead.';
  { unused }
  notDeadMsgTail: Byte = $00;
  { unused; no poison to cure }
  notPoisonedMsg: String[40] = 'is not poisoned.';
  { unused }
  notPoisonedMsgTail: Byte = $00;
  { no curse to lift }
  notCursedMsg: String[40] = 'is not cursed.';
  { unused }
  notCursedMsgTail: Byte = $00;
  { no petrification to undo }
  notStonedMsg: String[40] = 'is not stoned.';
  { unused }
  notStonedMsgTail: Byte = $00;
  { no drained levels to restore }
  noLostLevelsMsg: String[40] = 'has no lost levels.';
  { unused }
  noLostLevelsMsgTail: Byte = $00;
  { the temple's greeting after the character's name }
  howCanWeHelpPrompt: String[40] = ', how can we help you?';
  { unused }
  howCanWeHelpPromptTail: Byte = $00;
  { the empty prompt of a menu that asks nothing }
  emptyQuery: String[40] = '';
  { unused }
  emptyQueryTail: Byte = $00;
  { the title menu's prompt, the game and its version }
  titleText: String[40] = 'Treasures 1.00 ';
  { unused }
  titleTextTail: Byte = $00;
  { the spell menu's prompt }
  chooseSpellPrompt: String[40] = 'Choose Spell:';
  { unused }
  chooseSpellPromptTail: Byte = $00;
  { asks which kind of flame a spell makes }
  flameTypePrompt: String[40] = 'Flame type: ';
  { unused }
  flameTypePromptTail: Byte = $00;
  { the appraisal menu's prompt }
  appraiseQuery: String[40] = 'Appraise : ';
  { unused }
  appraiseQueryTail: Byte = $00;
  { the character menu's prompt }
  pickCharacterPrompt: String[40] = 'Pick Character ';
  { unused }
  pickCharacterPromptTail: Byte = $00;
  { the character modify menu's prompt }
  modifyQuery: String[40] = 'Modify : ';
  { unused }
  modifyQueryTail: Byte = $00;
  { the input device menu's prompt }
  inputQuery: String[40] = 'Init mouse/joystick: ';
  { unused }
  inputQueryTail: Byte = $00;
  { asks whether to give up a character whose disk is missing }
  loseCharMsg: String[40] = 'lose character? ';
  { unused }
  loseCharMsgTail: Byte = $00;
  { asks where to load a game from }
  fromText: String[40] = 'load from where? ';
  { unused }
  fromTextTail: Byte = $00;
  { asks which game to load }
  whichText: String[40] = 'load which game: ';
  { unused }
  whichTextTail: Byte = $00;
  { asks which slot to save into }
  saveWhichGamePrompt: String[40] = 'save which game: ';
  { unused }
  saveWhichGamePromptTail: Byte = $00;
  { asks whether the memorized spells are right }
  spellsOkPrompt: String[40] = 'spells OK? ';
  { unused }
  spellsOkPromptTail: Byte = $00;
  { asks whether to scribe the spells }
  scribeQuery: String[40] = 'scribe these spells? ';
  { unused }
  scribeQueryTail: Byte = $00;
  { the party order menu's prompt }
  orderQuery: String[40] = 'party order ';
  { unused }
  orderQueryTail: Byte = $00;
  { the game speed menu's prompt }
  speedQuery: String[40] = 'game speed: ';
  { unused }
  speedQueryTail: Byte = $00;
  { the aim menu's prompt }
  aimPromptAim: String[40] = 'aim: ';
  { unused }
  aimPromptAimTail: Byte = $00;
  { the manual aim cursor's prompt }
  aimPromptCursor: String[40] = '(use cursor keys) ';
  { unused }
  aimPromptCursorTail: Byte = $00;
  { asks whether to fight on }
  continueText: String[40] = 'continue battle? ';
  { unused }
  continueTextTail: Byte = $00;
  { the combat move prompt; the moves left follow }
  moveLeftText: String[40] = 'move/attack, move left = ';
  { unused }
  moveLeftTextTail: Byte = $00;
  { the item menu's prompt }
  itemsPrompt: String[40] = 'items : ';
  { unused }
  itemsPromptTail: Byte = $00;
  { unused; the take menu's prompt }
  takePrompt: String[40] = 'take: ';
  { unused }
  takePromptTail: Byte = $00;
  { the empty choice line of a list with no menu }
  blankMenuText: String[40] = '';
  { unused }
  blankMenuTextTail: Byte = $00;
  { the title menu's choice }
  playDemoMenu: String[40] = 'Play Demo';
  { unused }
  playDemoMenuTail: Byte = $00;
  { the yes/no menu }
  yesNoChoices: String[40] = 'Yes No';
  { unused }
  yesNoChoicesTail: Byte = $00;
  { a menu with Select alone }
  selectMenu: String[40] = 'Select';
  { unused }
  selectMenuTail: Byte = $00;
  { a menu with Select and Exit }
  selectExitMenu: String[40] = 'Select Exit';
  { unused }
  selectExitMenuTail: Byte = $00;
  { the cast choice }
  castMenu: String[40] = 'Cast';
  { unused }
  castMenuTail: Byte = $00;
  { the memorize choice }
  memorizeMenu: String[40] = 'Memorize';
  { unused }
  memorizeMenuTail: Byte = $00;
  { the keep choice }
  keepMenu: String[40] = 'Keep';
  { unused }
  keepMenuTail: Byte = $00;
  { the scribe choice }
  scribeMenu: String[40] = 'Scribe';
  { unused }
  scribeMenuTail: Byte = $00;
  { the learn choice }
  learnMenu: String[40] = 'Learn';
  { unused }
  learnMenuTail: Byte = $00;
  { the two kinds of flame }
  hotColdMenu: String[40] = 'Hot Cold';
  { unused }
  hotColdMenuTail: Byte = $00;
  { the appraisal menu }
  appraiseMenuText: String[40] = 'Gems Jewelry Exit';
  { unused }
  appraiseMenuTextTail: Byte = $00;
  { what can be done with an appraised gem or jewel }
  actionMenuText: String[40] = 'Sell Keep';
  { unused }
  actionMenuTextTail: Byte = $00;
  { the rest menu's time-setting choices }
  restMenu: String[40] = 'Rest Days Hours Mins Add Subtract Exit';
  { unused }
  restMenuTail: Byte = $00;
  { the character sheet's menu }
  menuLabels: String[80] = 'Items Spells Trade Deposit Drop Lay Cure Exit';
  { unused }
  menuLabelsTail: Byte = $00;
  { what can be done with an item }
  itemActionMenu: String[80] = 'Ready Use Trade Deposit Drop Halve Join Sell Id';
  { unused }
  itemActionMenuTail: Byte = $00;
  { the number adjusting menu }
  addSubtractKeepMenu: String[40] = 'Add Subtract Keep Exit';
  { unused }
  addSubtractKeepMenuTail: Byte = $00;
  { where a character or game is loaded from }
  characterSourceMenu: String[40] = 'Treasures Gateway Exit';
  { unused }
  characterSourceMenuTail: Byte = $00;
  { the add choice }
  addQuery: String[40] = 'Add';
  { unused }
  addQueryTail: Byte = $00;
  { unused; a menu with Change and Exit }
  changeExitMenu: String[40] = 'Change Exit';
  { unused }
  changeExitMenuTail: Byte = $00;
  { the missing disk menu }
  tryAnotherDiskMenu: String[40] = 'Ok Try another disk';
  { unused }
  tryAnotherDiskMenuTail: Byte = $00;
  { the save slot letters }
  driveLetterMenu: String[40] = 'A B C D E F G H I J';
  { unused }
  driveLetterMenuTail: Byte = $00;
  { the party order menu's choices }
  selectPlaceMenu: String[40] = 'Select Place Exit';
  { unused }
  selectPlaceMenuTail: Byte = $00;
  { the game speed menu }
  speedMenuItems: String[40] = 'Faster Slower Exit';
  { unused }
  speedMenuItemsTail: Byte = $00;
  { the adventuring menu, cut off at 40 characters }
  movementMenu: String[40] = 'Move Area Cast View Encamp Search Look G';
  { unused }
  movementMenuTail: Byte = $00;
  { a menu with Exit alone }
  exitMenu: String[40] = 'Exit';
  { unused }
  exitMenuTail: Byte = $00;
  { the combat menu }
  combatMenu: String[80] = 'Move Aim Use Cast Turn Guard Quick@Delay Bandage View Speed End Z';
  { unused }
  combatMenuTail: Byte = $00;
  { a menu with Done alone }
  doneMenu: String[40] = 'Done';
  { unused }
  doneMenuTail: Byte = $00;
  { the aim menu }
  aimMenu: String[40] = 'Next Prev Manual Target Center Exit';
  { unused }
  aimMenuTail: Byte = $00;
  { the manual aim cursor's choices }
  menuPromptCursor: String[40] = 'Target Exit';
  { unused }
  menuPromptCursorTail: Byte = $00;
  { the buy choice }
  buyMenu: String[40] = 'Buy';
  { unused }
  buyMenuTail: Byte = $00;
  { the shop menu }
  storeMenuItems: String[40] = 'Buy View Take Pool Share Appraise Exit';
  { unused }
  storeMenuItemsTail: Byte = $00;
  { clears a price line }
  blankPriceLine: String[30] = '                              ';
  { unused }
  blankPriceLineTail: Byte = $00;
  { the take choice }
  takeMenuText: String[40] = 'Take';
  { unused }
  takeMenuTextTail: Byte = $00;
  { unused; the money or items menu }
  moneyItemsMenu: String[40] = 'Money Items Exit';
  { unused }
  moneyItemsMenuTail: Byte = $00;
  { the treasure menu after a fight }
  treasureMenuText: String[40] = 'View Take Pool Share Detect Exit';
  { unused }
  treasureMenuTextTail: Byte = $00;
  { heads the temple's healing list }
  healHeading: String[40] = 'Heal';
  { unused }
  healHeadingTail: Byte = $00;
  { the temple menu }
  healBuildingMenu: String[40] = 'Heal View Repair Exit';
  { unused }
  healBuildingMenuTail: Byte = $00;
  { the vault menu }
  vaultMenuItems: String[40] = 'View Take Pool Money Items Exit';
  { unused }
  vaultMenuItemsTail: Byte = $00;
  { the icon editor's menus, by edit state }
  iconMenu: array[1..5] of String[45] = ('Parts 1st-color 2nd-color Size Exit', 'Head Weapon Exit',
    'Weapon Body Hair Face Shield Arm Leg Exit', 'Small Large Keep Exit', 'Next Prev Keep Exit');
  { the camp menu once the party holds the crown }
  campMenuWithCrown: String[40] = 'Save View Magic Rest Alter Fix Crown Ex';
  { the camp magic menu }
  campMagicMenuItems: String[40] = 'Cast Memorize Scribe Display Rest Exit';
  { the camp alter menu }
  campAlterMenuItems: String[40] = 'Order Drop Speed Icon Level Exit';
  { the difficulty levels of the alter menu's Level choice }
  classTitles: String[40] = 'Novice Squire Veteran Adept Champion';
  { the camp menu }
  campMenuText: String[40] = 'Save View Magic Rest Alter Fix C Exit';
  { unused }
  campMenuTextTail: Byte = $00;
  { unused; followed a difficulty name }
  levelSuffix: String[10] = ' Level';
  { unused }
  levelSuffixTail: Byte = $00;
  { Item-name parts; entry 122 is the automap password 'Gem'. }
  itemNameParts: array[1..181] of String[20] = (
    'Battle Axe', 'Hand Axe', 'Club', 'Dagger', 'Dart', 'Hammer', 'Javelin', 'Mace', 'Morning Star', 'Military Pick',
    'Awl Pike', 'Bolt', 'Scimitar', 'Spear', 'Quarter Staff', 'Bastard Sword', 'Broad Sword', 'Long Sword',
    'Short Sword', 'Two-Handed Sword', 'Trident', 'Composite Long Bow', 'Composite Short Bow', 'Long Bow', 'Short Bow',
    'Fine', 'Light Crossbow', 'Sling', 'Staff', 'Arrow', 'Leather', 'Ring', 'Scale', 'Chain', 'Banded', 'Plate',
    'Shield', 'Cleric', 'Scroll', 'Mage', 'Helm', 'Belt', 'Robe', 'Cloak', 'Boots', 'Ring', 'Mail', 'Armor',
    'Of Prot.', 'Bracers', 'Wand', 'Elixir', 'Potion', 'Youth', 'Ruby', 'Boulder', 'Dragon Breath', 'Displacement',
    'Eyes', 'Drow', 'Elfin Chain', 'Ice Storm', 'Saphire', 'Emerald', 'Wizardry', 'Hornet''s Nest', 'Fire Resistance',
    'Stone', 'Good Luck', 'Flail', 'Halberd', 'Gauntlets', 'Periapt', 'Health', 'Cursed', 'Blessed', 'Bundle of',
    'Ogre Power', 'Girdle', 'Giant Strength', 'Mirror', 'Necklace', 'Dragon', 'vs Giants', 'vorpal', 'cold resistance',
    'Diamond', 'Lightning', 'Fireballs', 'of', 'Vulnerability', 'Speed', 'Silver', 'Extra', 'Healing', 'Charming',
    'Fear', 'Magic Missiles', 'Missiles', '1 Spell', '2 Spells', '3 Spells', 'Paralyzation', 'Invisibility',
    'Cute Yellow Canary', 'AC 10', 'AC 6', 'AC 4', 'AC 3', 'AC 2', '+1', '+2', '+3', '+4', 'Broken', '-1', '-2', '-3',
    'Electrical Immunity', 'Gaze Resistance', 'Spiritual', 'Gem', 'Jewelry', 'Blinking', 'from evil', 'lucky paper',
    'of Icewind Dale', 'of the Glacier', 'of Stonecutting', 'of Defoliation', 'Sword', 'Splint', 'Leilon', 'Waterdeep',
    'Mintarn', 'Orlumbor', 'Daggerford', 'Neverwinter', 'Yartar', 'Longsaddle', 'Ruathym', 'Luskan', 'Mirabar', 'real',
    'authentic', 'battle-used', 'large', 'Farrberjik', 'furry', 'Black Crystal', 'Certificate', 'Golden', 'Bloodaxe',
    'Redshield', 'Shearhammer', 'Northhelm', 'tyrant''s trident', 'of stalking', 'squid shield', 'Redflame armor',
    'Seahelm', 'map', 'spell enhancing', 'striking', 'rod', 'stone to flesh', 'lined', 'firepot', 'flask', 'Kraken',
    'the', 'cold', 'firedock', 'treasure', 'oil', 'cold', 'MU Scroll', 'Normalcy', 'Farms', 'High Captains', 'Tunnels');
  { unused }
  itemNamePartsTail: Byte = $00;
  { the direction abbreviations, by facing 0..7 }
  directionNames: array[0..7] of String[2] = ('N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
  { the direction of a step by the signs of its row and column change; 8 is no step }
  stepDir: array[0..2, 0..2] of Byte = (($07, $00, $01), ($06, $08, $02), ($05, $04, $03));
  { unused }
  stepDirTail: array[0..4] of Byte = (
    $00, $08, $04, $02, $01);
  { each EGA plane's bit }
  egaPlaneBit: array[0..3] of Byte = (
    $01, $02, $04, $08);
  { the color pairs FillPicRect paints with }
  fillColorMap: Types.TColorMap = (
    $00, $11, $22, $12, $01, $21, $30, $33);
  { the colors a monster icon is remapped from }
  colorIdentity: Types.TColorTable = ($00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F);
  { and to: color 8 becomes 0 }
  colorDrop8: Types.TColorTable = ($00, $01, $02, $03, $04, $05, $06, $07, $00, $09, $0A, $0B, $0C, $0D,
    $0E, $0F);
  { the sound command that resets the driver }
  resetSoundId: Word = $00FF;
  { the sound command that silences it }
  soundOffId: Word = $0000;
  { the sound command that turns it back on }
  soundOnId: Word = $0001;
  { the sound effect commands }
  soundIds: array[0..13] of Word = ($0002, $0003, $0004, $0005, $0006, $0007, $0008, $0009, $000A, $000B, $000C, $000D,
    $000E, $000F);
  { the insert-disk prompt; the drive letter follows }
  diskPrompt: String[21] = 'Insert disk in drive ';
  { each symbol bank's first symbol }
  bankFirstTile: array[0..4] of Word = ($0000, $0100, $0200, $0300, $0314);
  { and its last }
  bankLastTile: array[0..4] of Word = ($00FF, $01FF, $02FF, $0313, $037B);
  { the column step for each direction, clockwise from north; 8 and 9 make no step }
  dirDx: array[0..9] of ShortInt = (0, 1, 1, 1, 0, -1, -1, -1, 0, 0);
  { the row step for each direction }
  dirDy: array[0..9] of ShortInt = (-1, -1, 0, 1, 1, 1, 0, -1, 0, 0);
  { CombatAi: terrain properties by terrain code, from 1. }
  terrain: array[1..69] of Types.TTerrain = (
    (cost: $FF; clear: $01; block: $02; code: $00), (cost: $FF; clear: $01; block: $02; code: $01),
    (cost: $FF; clear: $01; block: $02; code: $02), (cost: $FF; clear: $01; block: $02; code: $03),
    (cost: $01; clear: $01; block: $00; code: $04), (cost: $FF; clear: $01; block: $02; code: $05),
    (cost: $FF; clear: $01; block: $02; code: $06), (cost: $FF; clear: $01; block: $02; code: $07),
    (cost: $01; clear: $01; block: $00; code: $08), (cost: $FF; clear: $01; block: $02; code: $09),
    (cost: $01; clear: $01; block: $00; code: $0A), (cost: $FF; clear: $01; block: $02; code: $0B),
    (cost: $01; clear: $01; block: $00; code: $0C), (cost: $FF; clear: $01; block: $02; code: $0D),
    (cost: $01; clear: $01; block: $00; code: $0E), (cost: $FF; clear: $01; block: $02; code: $0F),
    (cost: $01; clear: $01; block: $00; code: $10), (cost: $FF; clear: $01; block: $02; code: $11),
    (cost: $FF; clear: $01; block: $02; code: $12), (cost: $FF; clear: $01; block: $02; code: $13),
    (cost: $FF; clear: $01; block: $02; code: $14), (cost: $FF; clear: $01; block: $02; code: $15),
    (cost: $01; clear: $01; block: $00; code: $16), (cost: $01; clear: $01; block: $00; code: $17),
    (cost: $FF; clear: $01; block: $02; code: $18), (cost: $02; clear: $02; block: $00; code: $26),
    (cost: $01; clear: $01; block: $00; code: $0E), (cost: $01; clear: $01; block: $00; code: $0D),
    (cost: $01; clear: $01; block: $00; code: $0C), (cost: $01; clear: $01; block: $00; code: $14),
    (cost: $01; clear: $01; block: $00; code: $15), (cost: $FF; clear: $01; block: $02; code: $00),
    (cost: $FF; clear: $01; block: $02; code: $01), (cost: $FF; clear: $01; block: $02; code: $02),
    (cost: $FF; clear: $01; block: $02; code: $03), (cost: $FF; clear: $01; block: $02; code: $04),
    (cost: $01; clear: $01; block: $00; code: $05), (cost: $01; clear: $01; block: $00; code: $06),
    (cost: $01; clear: $01; block: $00; code: $07), (cost: $01; clear: $01; block: $00; code: $08),
    (cost: $01; clear: $01; block: $00; code: $09), (cost: $FF; clear: $01; block: $02; code: $0A),
    (cost: $FF; clear: $01; block: $02; code: $0B), (cost: $02; clear: $01; block: $00; code: $0C),
    (cost: $01; clear: $01; block: $00; code: $0D), (cost: $01; clear: $01; block: $00; code: $0E),
    (cost: $01; clear: $01; block: $00; code: $0F), (cost: $01; clear: $01; block: $00; code: $10),
    (cost: $01; clear: $01; block: $00; code: $11), (cost: $02; clear: $01; block: $00; code: $12),
    (cost: $02; clear: $01; block: $00; code: $13), (cost: $01; clear: $01; block: $00; code: $14),
    (cost: $01; clear: $01; block: $00; code: $15), (cost: $01; clear: $01; block: $00; code: $16),
    (cost: $FF; clear: $01; block: $00; code: $17), (cost: $FF; clear: $01; block: $00; code: $18),
    (cost: $FF; clear: $01; block: $00; code: $19), (cost: $01; clear: $01; block: $00; code: $1A),
    (cost: $01; clear: $01; block: $00; code: $1B), (cost: $01; clear: $01; block: $00; code: $1C),
    (cost: $01; clear: $00; block: $00; code: $1D), (cost: $01; clear: $00; block: $00; code: $1E),
    (cost: $FF; clear: $00; block: $00; code: $1F), (cost: $FF; clear: $01; block: $00; code: $20),
    (cost: $02; clear: $01; block: $00; code: $21), (cost: $01; clear: $01; block: $00; code: $22),
    (cost: $FF; clear: $01; block: $00; code: $23), (cost: $01; clear: $01; block: $00; code: $24),
    (cost: $01; clear: $01; block: $00; code: $25));
  { The cells of a combatant of size 1..5 as offsets from its own cell; dx -1: no such cell }
  iconDelta: array[1..5, 0..5] of Types.TIconDelta = (((dx: 0; dy: 0), (dx: -1; dy: -1), (dx: -1; dy: -1),
    (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)), ((dx: 0; dy: 0), (dx: 0; dy: 1), (dx: -1; dy: -1),
    (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)), ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: -1; dy: -1),
    (dx: -1; dy: -1), (dx: -1; dy: -1), (dx: -1; dy: -1)), ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1),
    (dx: 1; dy: 1), (dx: -1; dy: -1), (dx: -1; dy: -1)), ((dx: 0; dy: 0), (dx: 1; dy: 0), (dx: 0; dy: 1),
    (dx: 1; dy: 1), (dx: 2; dy: 0), (dx: 2; dy: 1)));
  { the effect ids that mean helpless }
  helplessEffects: array[1..4] of Byte = ($1F, $33, $34, $35);
  { the effect ids that mean diseased }
  diseaseEffects: array[1..4] of Byte = ($1F, $22, $2B, $2C);
  { the effects a fight's end removes from each party member }
  postCombatEffects: array[1..17] of Byte =
    ($03, $0B, $15, $17, $1B, $23, $1F, $33, $34, $35, $78, $76, $6F, $6A, $4D, $9C,
    $2A);
  { unused }
  postCombatEffectsTail: Byte = $00;
  { starts an effect report after the creature's name }
  isText: String[11] = 'is ';
  { unused }
  notWord: String[11] = 'not ';
  { reports a heal }
  healedWord: String[11] = 'Healed';
  { unused }
  affectedWord: String[11] = 'Affected';
  { unused }
  unaffectedWord: String[11] = 'Unaffected';
  { reports a protection spell }
  protectedWord: String[11] = 'Protected';
  { unused }
  protectedFromWord: String[21] = 'Protected from ';
  { starts the giant strength announcement after the creature's name }
  gainsText: String[11] = 'gains ';
  { 0: 'Yes' in MenuCore.YesNoMenu's 'Yes No' menu }
  yesChoice: Byte = $00;
  { 1: 'No' }
  noChoice: Byte = $01;
  { the cursor key each keypad digit 1..9 stands for }
  modifyKeys: array[0..8] of Char = (#$4F, #$50, #$51, #$4B, #$20, #$4D, #$47, #$48, #$49);
  { unused }
  modifyKeysTail: Byte = $00;
  { the arrow key a click on the screen stands for, by its row and column }
  directionGrid: array[3..13, 3..13] of Char = ((#$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48),
    (#$4B, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$4D),
    (#$4B, #$4B, #$48, #$48, #$48, #$48, #$48, #$48, #$48, #$4D, #$4D),
    (#$4B, #$4B, #$4B, #$48, #$48, #$48, #$48, #$48, #$4D, #$4D, #$4D),
    (#$4B, #$4B, #$4B, #$4B, #$48, #$48, #$48, #$4D, #$4D, #$4D, #$4D),
    (#$4B, #$4B, #$4B, #$4B, #$4B, #$48, #$4D, #$4D, #$4D, #$4D, #$4D),
    (#$4B, #$4B, #$4B, #$4B, #$50, #$50, #$50, #$4D, #$4D, #$4D, #$4D),
    (#$4B, #$4B, #$4B, #$50, #$50, #$50, #$50, #$50, #$4D, #$4D, #$4D),
    (#$4B, #$4B, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$4D, #$4D),
    (#$4B, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$4D),
    (#$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50, #$50));
  { unused }
  directionGridTail: Byte = $00;
  { the eight cells around a cloud's center, as directions, then the center }
  patchDirections: array[1..9] of Byte = ($08, $02, $03, $04, $05, $06, $07, $00, $01);
  { unused }
  patchDirectionsTail: Byte = $00;
  { the spell names, indexed by spell id }
  spellNames: array[1..126] of String[34] = ('Bless', 'Curse', 'Cure Light Wounds', 'Cause Light Wounds',
    'Detect Magic', 'Protection From Evil', 'Protection from Good', 'Resist Cold', 'Burning Hands', 'Charm Person',
    'Detect Magic', 'Enlarge', 'Reduce', 'Friends', 'Magic Missile', 'Protection From Evil', 'Protection From Good',
    'Read Magic', 'Shield', 'Shocking Grasp', 'Sleep', 'Find Traps', 'Hold Person', 'Resist Fire',
    'Silence, 15'' Radius', 'Slow Poison', 'Snake Charm', 'Spiritual Hammer', 'Detect Invisibility', 'Invisibility',
    'Knock', 'Mirror Image', 'Ray of Enfeeblement', 'Stinking Cloud', 'Strength', 'Heal', 'Cure Blindness',
    'Cause Blindness', 'Cure Disease', 'Cause Disease', 'Dispel Magic', 'Prayer', 'Remove Curse', 'Bestow Curse',
    'Blink', 'Dispel Magic', 'Fireball', 'Haste', 'Hold Person', 'Invisibility, 10'' Radius', 'Lightning Bolt',
    'Protection From Evil, 10'' Radius', 'Protection From Good, 10'' Radius', 'Protection From Normal Missiles', 'Slow',
    'Harm', 'Potion Of Speed', 'Cure Serious Wounds', 'Potion Of Frost', 'Javelin Of Lightning', 'Wand Of Paralyzation',
    'Potion Of Healing', 'Elixir Of Youth', 'Necklace Of Missiles', 'Wand Of Magic Missiles', 'Cause Serious Wounds',
    'Neutralize Poison', 'Poison', 'Protection Evil, 10'' Radius', 'Sticks to Snakes', 'Cure Critical Wounds',
    'Cause Critical Wounds', 'Dispel Evil', 'Flame Strike', 'Raise Dead', 'Slay Living', 'Detect Magic', 'Entangle',
    'Faerie Fire', 'Invisibility to Animals', 'Charm Monsters', 'Confusion', 'Dimension Door', 'Fear', 'Fire Shield',
    'Fumble', 'Ice Storm', 'Minor Globe Of Invulnerability', 'Remove Curse', 'Barkskin', 'Cloud Kill', 'Cone of Cold',
    'Feeblemind', 'Hold Monsters', 'Scroll of Protection', 'Charm Person Or Mammal', 'Potion Of Invisibility',
    'Cure Light Wounds', 'Potion Of Extra Healing', 'Bestow Curse', 'Blade Barrier', 'Restoration', 'Energy Drain',
    'Destruction', 'Resurrection', 'Cure Disease', 'Neutralize Poison', 'Hold Animal', 'Prot. from Fire', 'Death Spell',
    'Disintegrate', 'Globe of Invulnerability', 'Stone to Flesh', 'Flesh to Stone', 'Delayed Blast Fireball',
    'Mass Invisibility', 'Power Word Stun', 'Fire Touch', 'Iron Skin', 'Mass Charm', 'Otto''s Irr. Dance', 'Mind Blank',
    'Power Word Blind', 'Meteor Swarm', 'Power Word Kill', 'Monster Summoning');
  { the spells by id: level, targeting, saving throw, effect, when it can be cast, casting time and AI use }
  spellTable: array[1..127] of Types.TSlotRule = (
    { 1 Bless }
    (spellBand: 0; spellLevel: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; area: 10; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 1; whenCast: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 2 Curse }
    (spellBand: 0; spellLevel: 1; rangeBase: 6; rangePerLevel: 0; durBase: 6; durPerLevel: 0; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 2; whenCast: 1; castTime: 10; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 3 Cure Light Wounds }
    (spellBand: 0; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 4 Cause Light Wounds }
    (spellBand: 0; spellLevel: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 5; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 5 Detect Magic }
    (spellBand: 0; spellLevel: 1; rangeBase: 3; rangePerLevel: 0; durBase: 10; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 5; whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 6 Protection From Evil }
    (spellBand: 0; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 8; whenCast: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 7 Protection from Good }
    (spellBand: 0; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 9; whenCast: 2; castTime: 4; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 8 Resist Cold }
    (spellBand: 0; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 10; whenCast: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 9 Burning Hands }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 10 Charm Person }
    (spellBand: 2; spellLevel: 1; rangeBase: 12; rangePerLevel: 0; durBase: 60; durPerLevel: 60; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 11; whenCast: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 11 Detect Magic }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 5; whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 12 Enlarge }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 12; whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 13 Reduce }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 1; saveType: 4; effectId: 12; whenCast: 2; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 14 Friends }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 14; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 15 Magic Missile }
    (spellBand: 2; spellLevel: 1; rangeBase: 6; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 16 Protection From Evil }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 8; whenCast: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 17 Protection From Good }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 9; whenCast: 2; castTime: 1; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 18 Read Magic }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 16; whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 19 Shield }
    (spellBand: 2; spellLevel: 1; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 5; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 17; whenCast: 2; castTime: 1; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 20 Shocking Grasp }
    (spellBand: 2; spellLevel: 1; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 21 Sleep }
    (spellBand: 2; spellLevel: 1; rangeBase: 3; rangePerLevel: 4; durBase: 0; durPerLevel: 5; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 53; whenCast: 1; castTime: 1; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 22 Find Traps }
    (spellBand: 0; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 30; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 19; whenCast: 0; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 23 Hold Person }
    (spellBand: 0; spellLevel: 2; rangeBase: 6; rangePerLevel: 0; durBase: 4; durPerLevel: 1; area: 6; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 52; whenCast: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 24 Resist Fire }
    (spellBand: 0; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 20; whenCast: 2; castTime: 5; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 25 Silence, 15' Radius }
    (spellBand: 0; spellLevel: 2; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 31; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 21; whenCast: 1; castTime: 5; aiPriority: 2; offensive: 1; aiRadius: 1),
    { 26 Slow Poison }
    (spellBand: 0; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 22; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 27 Snake Charm }
    (spellBand: 0; spellLevel: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 240; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 51; whenCast: 1; castTime: 5; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 28 Spiritual Hammer }
    (spellBand: 0; spellLevel: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 23; whenCast: 2; castTime: 5; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 29 Detect Invisibility }
    (spellBand: 2; spellLevel: 2; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 5; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 24; whenCast: 2; castTime: 2; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 30 Invisibility }
    (spellBand: 2; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 25; whenCast: 2; castTime: 2; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 31 Knock }
    (spellBand: 2; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 32 Mirror Image }
    (spellBand: 2; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 28; whenCast: 2; castTime: 2; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 33 Ray of Enfeeblement }
    (spellBand: 2; spellLevel: 2; rangeBase: 1; rangePerLevel: 1; durBase: 0; durPerLevel: 1; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 29; whenCast: 1; castTime: 2; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 34 Stinking Cloud }
    (spellBand: 2; spellLevel: 2; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 0;
     saveEffect: 3; saveType: 0; effectId: 30; whenCast: 1; castTime: 2; aiPriority: 4; offensive: 1; aiRadius: 1),
    { 35 Strength }
    (spellBand: 2; spellLevel: 2; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 60; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 38; whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 36 Heal }
    (spellBand: 0; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 37 Cure Blindness }
    (spellBand: 0; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 38 Cause Blindness }
    (spellBand: 0; spellLevel: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 33; whenCast: 1; castTime: 10; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 39 Cure Disease }
    (spellBand: 0; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 100; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 40 Cause Disease }
    (spellBand: 0; spellLevel: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 34; whenCast: 1; castTime: 100; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 41 Dispel Magic }
    (spellBand: 0; spellLevel: 3; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 9; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 42 Prayer }
    (spellBand: 0; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 49; whenCast: 2; castTime: 6; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 43 Remove Curse }
    (spellBand: 0; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 44 Bestow Curse }
    (spellBand: 0; spellLevel: 3; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 36; whenCast: 1; castTime: 6; aiPriority: 2; offensive: 1; aiRadius: 0),
    { 45 Blink }
    (spellBand: 2; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 37; whenCast: 1; castTime: 1; aiPriority: 4; offensive: 0; aiRadius: 0),
    { 46 Dispel Magic }
    (spellBand: 2; spellLevel: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 1),
    { 47 Fireball }
    (spellBand: 2; spellLevel: 3; rangeBase: 10; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 48 Haste }
    (spellBand: 2; spellLevel: 3; rangeBase: 6; rangePerLevel: 0; durBase: 3; durPerLevel: 1; area: 10; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 39; whenCast: 2; castTime: 3; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 49 Hold Person }
    (spellBand: 2; spellLevel: 3; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 7; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 52; whenCast: 1; castTime: 3; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 50 Invisibility, 10' Radius }
    (spellBand: 2; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 9; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 25; whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 51 Lightning Bolt }
    (spellBand: 2; spellLevel: 3; rangeBase: 4; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 3; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 52 Protection From Evil, 10' Radius }
    (spellBand: 2; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 45; whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 53 Protection From Good, 10' Radius }
    (spellBand: 2; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 46; whenCast: 2; castTime: 3; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 54 Protection From Normal Missiles }
    (spellBand: 2; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 41; whenCast: 2; castTime: 3; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 55 Slow }
    (spellBand: 2; spellLevel: 3; rangeBase: 9; rangePerLevel: 4; durBase: 3; durPerLevel: 1; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 42; whenCast: 1; castTime: 3; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 56 Harm }
    (spellBand: 0; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 10; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 57 Potion Of Speed }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 39; whenCast: 2; castTime: 0; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 58 Cure Serious Wounds }
    (spellBand: 0; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 59 Potion Of Frost }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 113; whenCast: 2; castTime: 0; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 60 Javelin Of Lightning }
    (spellBand: 3; spellLevel: 6; rangeBase: 10; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 61 Wand Of Paralyzation }
    (spellBand: 3; spellLevel: 6; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 0; effectId: 52; whenCast: 1; castTime: 0; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 62 Potion Of Healing }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 63 Elixir Of Youth }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 7; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 0; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 64 Necklace Of Missiles }
    (spellBand: 3; spellLevel: 6; rangeBase: 7; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 0; aiPriority: 7; offensive: 1; aiRadius: 3),
    { 65 Wand Of Magic Missiles }
    (spellBand: 3; spellLevel: 6; rangeBase: 12; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 0; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 66 Cause Serious Wounds }
    (spellBand: 0; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 7; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 67 Neutralize Poison }
    (spellBand: 0; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 7; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 68 Poison }
    (spellBand: 0; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 0; effectId: 0; whenCast: 1; castTime: 7; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 69 Protection Evil, 10' Radius }
    (spellBand: 0; spellLevel: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 10; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 45; whenCast: 2; castTime: 7; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 70 Sticks to Snakes }
    (spellBand: 0; spellLevel: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 3; whenCast: 1; castTime: 7; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 71 Cure Critical Wounds }
    (spellBand: 0; spellLevel: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 8; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 72 Cause Critical Wounds }
    (spellBand: 0; spellLevel: 5; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 0; whenCast: 1; castTime: 8; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 73 Dispel Evil }
    (spellBand: 0; spellLevel: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 32; whenCast: 1; castTime: 8; aiPriority: 5; offensive: 0; aiRadius: 0),
    { 74 Flame Strike }
    (spellBand: 0; spellLevel: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 75 Raise Dead }
    (spellBand: 0; spellLevel: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 76 Slay Living }
    (spellBand: 0; spellLevel: 5; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 0; whenCast: 1; castTime: 10; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 77 Detect Magic }
    (spellBand: 1; spellLevel: 1; rangeBase: 3; rangePerLevel: 0; durBase: 12; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 5; whenCast: 2; castTime: 3; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 78 Entangle }
    (spellBand: 1; spellLevel: 1; rangeBase: 8; rangePerLevel: 0; durBase: 10; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 0; whenCast: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 79 Faerie Fire }
    (spellBand: 1; spellLevel: 1; rangeBase: 8; rangePerLevel: 0; durBase: 0; durPerLevel: 4; area: 5; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 71; whenCast: 1; castTime: 3; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 80 Invisibility to Animals }
    (spellBand: 1; spellLevel: 1; rangeBase: 255; rangePerLevel: 0; durBase: 10; durPerLevel: 1; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 69; whenCast: 2; castTime: 4; aiPriority: 1; offensive: 1; aiRadius: 0),
    { 81 Charm Monsters }
    (spellBand: 2; spellLevel: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 5; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 11; whenCast: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 82 Confusion }
    (spellBand: 2; spellLevel: 4; rangeBase: 12; rangePerLevel: 0; durBase: 2; durPerLevel: 1; area: 11; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 35; whenCast: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 83 Dimension Door }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 12; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 84 Fear }
    (spellBand: 2; spellLevel: 4; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 8; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 111; whenCast: 1; castTime: 4; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 85 Fire Shield }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 2; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 4; aiPriority: 7; offensive: 0; aiRadius: 0),
    { 86 Fumble }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 1; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 27; whenCast: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 87 Ice Storm }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 4; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 88 Minor Globe Of Invulnerability }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 16; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 63; whenCast: 2; castTime: 4; aiPriority: 6; offensive: 0; aiRadius: 0),
    { 89 Remove Curse }
    (spellBand: 2; spellLevel: 4; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 4; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 90 Barkskin }
    (spellBand: 1; spellLevel: 2; rangeBase: 1; rangePerLevel: 0; durBase: 4; durPerLevel: 1; area: 240; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 13; whenCast: 2; castTime: 3; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 91 Cloud Kill }
    (spellBand: 2; spellLevel: 5; rangeBase: 2; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 92 Cone of Cold }
    (spellBand: 2; spellLevel: 5; rangeBase: 6; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 5; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 93 Feeblemind }
    (spellBand: 2; spellLevel: 5; rangeBase: 16; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 68; whenCast: 1; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 94 Hold Monsters }
    (spellBand: 2; spellLevel: 5; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 1; area: 7; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 52; whenCast: 1; castTime: 5; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 95 Scroll of Protection }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 73; whenCast: 2; castTime: 10; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 96 Charm Person Or Mammal }
    (spellBand: 1; spellLevel: 2; rangeBase: 8; rangePerLevel: 0; durBase: 60; durPerLevel: 60; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 11; whenCast: 1; castTime: 4; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 97 Potion Of Invisibility }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 25; whenCast: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 98 Cure Light Wounds }
    (spellBand: 1; spellLevel: 2; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 4; aiPriority: 2; offensive: 0; aiRadius: 0),
    { 99 Potion Of Extra Healing }
    (spellBand: 3; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 0; aiPriority: 1; offensive: 0; aiRadius: 0),
    { 100 Bestow Curse }
    (spellBand: 2; spellLevel: 4; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 36; whenCast: 1; castTime: 4; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 101 Blade Barrier }
    (spellBand: 0; spellLevel: 6; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 3; area: 9; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 0; whenCast: 1; castTime: 9; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 102 Restoration }
    (spellBand: 0; spellLevel: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 103 Energy Drain }
    (spellBand: 0; spellLevel: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 3; aiPriority: 8; offensive: 1; aiRadius: 0),
    { 104 Destruction }
    (spellBand: 0; spellLevel: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 10; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 105 Resurrection }
    (spellBand: 0; spellLevel: 7; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 10; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 106 Cure Disease }
    (spellBand: 1; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 107 Neutralize Poison }
    (spellBand: 1; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 0; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 108 Hold Animal }
    (spellBand: 1; spellLevel: 3; rangeBase: 8; rangePerLevel: 0; durBase: 0; durPerLevel: 2; area: 7; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 52; whenCast: 1; castTime: 5; aiPriority: 4; offensive: 1; aiRadius: 0),
    { 109 Prot. from Fire }
    (spellBand: 1; spellLevel: 3; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 119; whenCast: 2; castTime: 5; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 110 Death Spell }
    (spellBand: 2; spellLevel: 6; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 6; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 111 Disintegrate }
    (spellBand: 2; spellLevel: 6; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 0; whenCast: 1; castTime: 6; aiPriority: 8; offensive: 1; aiRadius: 0),
    { 112 Globe of Invulnerability }
    (spellBand: 2; spellLevel: 6; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 57; whenCast: 2; castTime: 1; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 113 Stone to Flesh }
    (spellBand: 2; spellLevel: 6; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 2; castTime: 6; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 114 Flesh to Stone }
    (spellBand: 2; spellLevel: 6; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 65; whenCast: 1; castTime: 6; aiPriority: 7; offensive: 1; aiRadius: 0),
    { 115 Delayed Blast Fireball }
    (spellBand: 2; spellLevel: 7; rangeBase: 10; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 11; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 9; offensive: 1; aiRadius: 0),
    { 116 Mass Invisibility }
    (spellBand: 2; spellLevel: 7; rangeBase: 0; rangePerLevel: 4; durBase: 0; durPerLevel: 0; area: 10; targeting: 3;
     saveEffect: 0; saveType: 4; effectId: 25; whenCast: 2; castTime: 7; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 117 Power Word Stun }
    (spellBand: 2; spellLevel: 7; rangeBase: 0; rangePerLevel: 2; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 106; whenCast: 1; castTime: 1; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 118 Fire Touch }
    (spellBand: 2; spellLevel: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 121; whenCast: 2; castTime: 6; aiPriority: 4; offensive: 0; aiRadius: 0),
    { 119 Iron Skin }
    (spellBand: 2; spellLevel: 5; rangeBase: 0; rangePerLevel: 0; durBase: 0; durPerLevel: 1; area: 0; targeting: 1;
     saveEffect: 0; saveType: 4; effectId: 122; whenCast: 2; castTime: 5; aiPriority: 3; offensive: 0; aiRadius: 0),
    { 120 Mass Charm }
    (spellBand: 2; spellLevel: 8; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 9; targeting: 0;
     saveEffect: 1; saveType: 4; effectId: 11; whenCast: 1; castTime: 8; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 121 Otto's Irr. Dance }
    (spellBand: 2; spellLevel: 8; rangeBase: 255; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 118; whenCast: 1; castTime: 5; aiPriority: 5; offensive: 1; aiRadius: 0),
    { 122 Mind Blank }
    (spellBand: 2; spellLevel: 8; rangeBase: 3; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 4; targeting: 2;
     saveEffect: 0; saveType: 4; effectId: 123; whenCast: 2; castTime: 1; aiPriority: 0; offensive: 0; aiRadius: 0),
    { 123 Power Word Blind }
    (spellBand: 2; spellLevel: 8; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 10; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 124 Meteor Swarm }
    (spellBand: 2; spellLevel: 9; rangeBase: 4; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 2; saveType: 4; effectId: 0; whenCast: 1; castTime: 9; aiPriority: 3; offensive: 1; aiRadius: 0),
    { 125 Power Word Kill }
    (spellBand: 2; spellLevel: 9; rangeBase: 0; rangePerLevel: 1; durBase: 0; durPerLevel: 0; area: 9; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 6; offensive: 1; aiRadius: 0),
    { 126 Monster Summoning }
    (spellBand: 2; spellLevel: 9; rangeBase: 9; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 0; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 9; aiPriority: 0; offensive: 1; aiRadius: 0),
    { 127 }
    (spellBand: 2; spellLevel: 4; rangeBase: 4; rangePerLevel: 0; durBase: 0; durPerLevel: 0; area: 8; targeting: 0;
     saveEffect: 0; saveType: 4; effectId: 0; whenCast: 1; castTime: 1; aiPriority: 0; offensive: 1; aiRadius: 0));
  { GameTime: clockScales[i] is the modulus of clock component i }
  clockScales: Types.TClock = (10, 10, 6, 24, 30, 12, 100);
  { 60 - THAC0, by class and level }
  thac0Tbl: array[0..6, 0..21] of Byte = (($28, $28, $28, $28, $2A, $2A, $2A, $2C, $2C, $2C, $2E,
    $2E, $2E, $30, $30, $30, $32, $32, $32, $33, $33, $33), ($28, $28, $28, $28, $2A, $2A, $2A,
    $2C, $2C, $2C, $2E, $2E, $2E, $30, $30, $30, $32, $32, $32, $33, $33, $33), ($27, $28, $28,
    $2A, $2A, $2C, $2C, $2E, $2E, $30, $30, $32, $32, $34, $34, $36, $36, $38, $38, $38, $38,
    $38), ($28, $28, $28, $2A, $2A, $2C, $2C, $2E, $2E, $30, $30, $32, $32, $34, $34, $36, $36,
    $38, $38, $38, $38, $38), ($28, $28, $28, $2A, $2A, $2C, $2C, $2E, $2E, $30, $30, $32, $32,
    $34, $34, $36, $36, $38, $38, $38, $38, $38), ($27, $28, $28, $28, $28, $28, $29, $29, $29,
    $29, $29, $2C, $2C, $2C, $2C, $2C, $2F, $2F, $2F, $2F, $2F, $31), ($28, $28, $28, $28, $28,
    $29, $29, $29, $29, $2C, $2C, $2C, $2C, $2E, $2E, $2E, $2E, $30, $30, $30, $30, $32));
  { by class: the bit a class holds in a character's classMask }
  classMaskBit: array[0..6] of Byte = (
    $02, $10, $08, $40, $40, $01, $04);
  { unused }
  classMaskBitTail: Byte = $00;
  { Each class's bit in a mask of classes; cleric and druid share a bit, and class 7 has none }
  classBits: array[0..7] of Byte = ($02, $02, $08, $10, $20, $01, $04, $00);
  { unused }
  levelUpClassBitTail: array[0..8] of Byte = ($10, $10, $10, $20, $20, $20, $40, $40, $40);

{ Hit dice by class. }
const
  { by class: the level from which a character stops rolling hit dice }
  hitDiceLevelCap: array[0..6] of Byte = (
    $0A, $0F, $0A, $0A, $0B, $0C, $0B);
  { unused }
  hitDiceLevelCapTail: Byte = $00;
  { by class: the hit dice rolled at first level; each later level rolls one }
  firstLevelHitDice: array[0..6] of Byte = (
    $01, $01, $01, $01, $02, $01, $01);
  { unused }
  firstLevelHitDiceTail: Byte = $00;
  { Each class's hit die, d8 d8 d10 d10 d8 d4 d6 }
  classHitDie: array[0..6] of Byte = (8, 8, 10, 10, 8, 4, 6);

{ Icon colors, thief skills, experience past the eleventh level, race limits, classes and starting ages, aging, class
  requirements and alignments, and the Constitution bonus. }
const
  { The palette slots a character icon's six colors go to }
  defIconColors: array[1..6] of Byte = (1, 2, 3, 4, 6, 7);
  { Thief skill percentages by level 1..18 (level 0 would read the two tables above) }
  thiefLevelSkills: array[1..18, 1..8] of Byte = (
    (30, 25, 20, 15, 10, 10, 85, 0), (35, 29, 25, 21, 15, 10, 86, 0), (40, 33, 30, 27, 20, 15, 87, 0),
    (45, 37, 35, 33, 25, 15, 88, 20),
    (50, 42, 40, 40, 31, 20, 90, 25), (55, 47, 45, 47, 37, 20, 92, 30), (60, 52, 50, 55, 43, 25, 94, 35),
    (65, 57, 55, 62, 49, 25, 96, 40),
    (70, 62, 60, 70, 56, 30, 98, 45), (80, 67, 65, 78, 63, 30, 99, 50), (90, 72, 70, 86, 70, 35, 99, 55),
    (100, 77, 75, 94, 77, 35, 99, 60),
    (105, 82, 80, 99, 85, 40, 99, 65), (110, 87, 85, 99, 93, 40, 99, 70), (115, 92, 90, 99, 99, 50, 100, 75),
    (125, 97, 95, 99, 99, 50, 100, 80),
    (125, 99, 99, 99, 99, 55, 100, 80), (130, 99, 99, 99, 99, 55, 100, 85));
  { Thief skill adjustments by race; a race above 5 reads on into the dexterity table }
  thiefRaceAdjustments: array[0..5, 1..8] of ShortInt = (
    (5, -5, 0, 5, 10, 5, 0, 0), (10, 0, 0, 0, 5, 0, 0, 0), (0, 10, 15, 0, 0, 0, -10, -5),
    (0, 5, 10, 5, 5, 10, -15, 0), (5, 5, 5, 10, 15, 5, -15, -5), (-5, 5, 5, 0, 0, 5, 5, -10));
  { Thief skill adjustments by Dexterity 9..19; a value outside reads the neighboring tables }
  thiefDexterityAdjustments: array[9..19, 1..5] of ShortInt = (
    (-15, -10, -10, -20, -10), (-19, -5, -10, -15, -5), (-5, 0, -5, -10, 0), (0, 0, 0, -5, 0),
    (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, 0, 0, 0, 0), (0, -5, 0, 0, 0),
    (5, 10, 0, 5, 5), (10, 15, 5, 10, 10), (15, 20, 10, 12, 12));
  { unused }
  thiefDexterityAdjustmentsTail: Byte = $00;
  { The experience each level past the eleventh costs, by class }
  xpIncrement: array[0..6] of LongInt = (225000, 750000, 250000, 350000, 325000, 375000, 220000);
  { The ability-score limits by race; each strength pair is by gender }
  raceLimits: array[0..5] of Types.TRaceLimits = (
    { Elf }
    (strMin: (3, 3); strMax: (18, 16); strExcMax: (75, 0); intMin: 8; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 7;
     dexMax: 19; conMin: 6; conMax: 18; chaMin: 8; chaMax: 18),
    { Half-Elf }
    (strMin: (3, 3); strMax: (18, 17); strExcMax: (90, 0); intMin: 4; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 6;
     dexMax: 18; conMin: 6; conMax: 18; chaMin: 3; chaMax: 18),
    { Dwarf }
    (strMin: (8, 8); strMax: (18, 17); strExcMax: (99, 0); intMin: 3; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3;
     dexMax: 17; conMin: 12; conMax: 19; chaMin: 3; chaMax: 16),
    { Gnome }
    (strMin: (6, 6); strMax: (18, 15); strExcMax: (50, 0); intMin: 7; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3;
     dexMax: 18; conMin: 8; conMax: 18; chaMin: 3; chaMax: 18),
    { Halfling }
    (strMin: (6, 6); strMax: (17, 14); strExcMax: (0, 0); intMin: 6; intMax: 18; wisMin: 3; wisMax: 17; dexMin: 8;
     dexMax: 18; conMin: 10; conMax: 19; chaMin: 3; chaMax: 18),
    { Human }
    (strMin: (3, 3); strMax: (18, 18); strExcMax: (100, 50); intMin: 3; intMax: 18; wisMin: 3; wisMax: 18; dexMin: 3;
     dexMax: 18; conMin: 3; conMax: 18; chaMin: 3; chaMax: 18));
  { By race: column 0 counts the classes the race may take, and the columns after it list them }
  raceClasses: array[0..5, 0..13] of ShortInt = ((7, 2, 5, 6, 13, 14, 15, 16, 0, 0, 0, 0, 0, 0),
    (13, 0, 2, 5, 6, 4, 8, 10, 9, 11, 13, 14, 15, 16), (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0), (3, 2, 6, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
    (6, 0, 2, 5, 6, 3, 4, 0, 0, 0, 0, 0, 0, 0));
  { A new character's starting age by race and single class }
  startAges: array[0..5, 0..6] of Types.TStartAge = (
    { Elf }
    ((base: 650; dice: 10; sides: 10), (base: 0; dice: 0; sides: 0), (base: 130; dice: 5; sides: 6),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 150; dice: 5; sides: 6),
     (base: 100; dice: 5; sides: 6)),
    { Half-Elf }
    ((base: 40; dice: 2; sides: 4), (base: 0; dice: 0; sides: 0), (base: 22; dice: 3; sides: 4),
     (base: 22; dice: 0; sides: 0), (base: 22; dice: 0; sides: 0), (base: 30; dice: 2; sides: 8),
     (base: 22; dice: 3; sides: 8)),
    { Dwarf }
    ((base: 250; dice: 2; sides: 20), (base: 0; dice: 0; sides: 0), (base: 40; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 75; dice: 3; sides: 6)),
    { Gnome }
    ((base: 300; dice: 3; sides: 12), (base: 0; dice: 0; sides: 0), (base: 60; dice: 5; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 100; dice: 2; sides: 12),
     (base: 80; dice: 5; sides: 4)),
    { Halfling }
    ((base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 20; dice: 3; sides: 4),
     (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0), (base: 0; dice: 0; sides: 0),
     (base: 40; dice: 2; sides: 4)),
    { Human }
    ((base: 18; dice: 1; sides: 4), (base: 18; dice: 1; sides: 4), (base: 15; dice: 1; sides: 4),
     (base: 17; dice: 1; sides: 4), (base: 20; dice: 1; sides: 4), (base: 24; dice: 2; sides: 4),
     (base: 18; dice: 1; sides: 4)));
  { By race: the ages at which the age adjustments to the ability scores begin }
  ageThresholds: array[0..5, 0..4] of Word = ((175, 550, 875, 1200, 1600), (40, 100, 175, 250, 325),
    (50, 150, 250, 350, 450), (90, 300, 450, 600, 750), (33, 68, 101, 144, 199), (20, 40, 60, 90, 120));
  { the ability-score minimums of each creatable class }
  classReqs: array[0..16] of array[0..5] of Byte = (($06, $06, $09, $00, $00, $06), ($00, $00, $0C, $00, $00, $0F),
    ($09, $00, $06, $06, $07, $06), ($0C, $09, $0D, $00, $09, $11), ($0D, $0D, $0E, $00, $0E, $06),
    ($00, $09, $06, $06, $00, $06), ($06, $06, $00, $09, $00, $06), ($0F, $00, $0F, $0F, $0B, $06),
    ($09, $00, $09, $00, $00, $06), ($09, $09, $09, $00, $00, $06), ($00, $0D, $0E, $00, $0E, $06),
    ($00, $09, $09, $00, $00, $06), ($00, $00, $09, $09, $00, $06), ($09, $09, $00, $00, $00, $06),
    ($09, $00, $00, $09, $00, $06), ($09, $09, $00, $09, $00, $06), ($00, $09, $00, $09, $00, $06));
  { Per creatable class id 0..16, the alignment count and up to nine alignments }
  createClassAlignments: array[0..16, 0..9] of Byte = ((9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (5, 1, 3, 4, 5, 7, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (1, 0, 0, 0, 0, 0, 0, 0, 0, 0), (3, 0, 3, 6, 0, 0, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (3, 0, 3, 6, 0, 0, 0, 0, 0, 0),
    (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8), (9, 0, 1, 2, 3, 4, 5, 6, 7, 8),
    (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0), (7, 1, 2, 3, 4, 5, 7, 8, 0, 0));
  { The hit-point bonus per level by Constitution }
  conBonusTable: array[3..25] of ShortInt = (-2, -1, -1, -1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2);

{ Level tables and saving throws. }
const
  { Per class: the experience needed for levels 2 through 11, then the spell slots by spell level for each character
    level }
  classLevelTable: array[0..6] of Types.TClassLevelTable = (
    { 0 cleric }
    (xp: (1501, 3001, 6001, 13001, 27501, 55001, 110001, 225001, 450001, 675001);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (3, 2, 0, 0, 0, 0, 0, 0, 0),
       (3, 3, 1, 0, 0, 0, 0, 0, 0),
       (3, 3, 2, 0, 0, 0, 0, 0, 0),
       (3, 3, 2, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 2, 0, 0, 0, 0, 0),
       (4, 4, 3, 2, 1, 0, 0, 0, 0),
       (4, 4, 3, 3, 2, 0, 0, 0, 0),
       (5, 4, 4, 3, 2, 1, 0, 0, 0),
       (6, 5, 5, 3, 2, 2, 0, 0, 0),
       (6, 6, 6, 4, 2, 2, 0, 0, 0),
       (6, 6, 6, 5, 3, 2, 0, 0, 0),
       (7, 7, 7, 5, 4, 2, 0, 0, 0),
       (7, 7, 7, 6, 5, 3, 1, 0, 0),
       (8, 8, 8, 6, 5, 3, 1, 0, 0),
       (8, 8, 8, 7, 6, 4, 1, 0, 0),
       (9, 9, 9, 7, 6, 4, 2, 0, 0),
       (9, 9, 9, 8, 7, 5, 2, 0, 0),
       (9, 9, 9, 9, 8, 6, 2, 0, 0),
       (9, 9, 9, 9, 9, 6, 3, 0, 0),
       (9, 9, 9, 9, 9, 7, 3, 0, 0),
       (9, 9, 9, 9, 9, 8, 3, 0, 0),
       (9, 9, 9, 9, 9, 8, 4, 0, 0),
       (9, 9, 9, 9, 9, 9, 4, 0, 0),
       (9, 9, 9, 9, 9, 9, 5, 0, 0),
       (9, 9, 9, 9, 9, 9, 6, 0, 0),
       (9, 9, 9, 9, 9, 9, 7, 0, 0))),
    { 1 druid }
    (xp: (-1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))),
    { 2 fighter }
    (xp: (2001, 4001, 8001, 18001, 35001, 70001, 125001, 250001, 500001, 750001);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))),
    { 3 paladin }
    (xp: (2751, 5501, 12001, 24001, 45001, 95001, 175001, 350001, 700001, 1050000);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (2, 2, 0, 0, 0, 0, 0, 0, 0),
       (2, 2, 1, 0, 0, 0, 0, 0, 0),
       (3, 2, 1, 0, 0, 0, 0, 0, 0),
       (3, 2, 1, 1, 0, 0, 0, 0, 0),
       (3, 3, 1, 1, 0, 0, 0, 0, 0),
       (3, 3, 2, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 1, 0, 0, 0, 0, 0),
       (3, 3, 3, 2, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0),
       (3, 3, 3, 3, 0, 0, 0, 0, 0))),
    { 4 ranger }
    (xp: (2251, 4501, 10001, 20001, 40001, 90001, 150001, 225001, 325001, 650000);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (1, 0, 0, 0, 1, 0, 0, 0, 0),
       (2, 0, 0, 0, 1, 0, 0, 0, 0),
       (2, 0, 0, 0, 2, 0, 0, 0, 0),
       (2, 1, 0, 0, 2, 0, 0, 0, 0),
       (2, 1, 0, 0, 2, 1, 0, 0, 0),
       (2, 2, 0, 0, 2, 1, 0, 0, 0),
       (2, 2, 0, 0, 2, 2, 0, 0, 0),
       (2, 2, 1, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0),
       (2, 2, 2, 0, 2, 2, 0, 0, 0))),
    { 5 magic-user }
    (xp: (2501, 5001, 10001, 22501, 40001, 60001, 90001, 135001, 250001, 375001);
     spellSlots: (
       (1, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 0, 0, 0, 0, 0, 0, 0, 0),
       (2, 1, 0, 0, 0, 0, 0, 0, 0),
       (3, 2, 0, 0, 0, 0, 0, 0, 0),
       (4, 2, 1, 0, 0, 0, 0, 0, 0),
       (4, 2, 2, 0, 0, 0, 0, 0, 0),
       (4, 3, 2, 1, 0, 0, 0, 0, 0),
       (4, 3, 3, 2, 0, 0, 0, 0, 0),
       (4, 3, 3, 2, 1, 0, 0, 0, 0),
       (4, 4, 3, 2, 2, 0, 0, 0, 0),
       (4, 4, 4, 3, 3, 0, 0, 0, 0),
       (4, 4, 4, 4, 4, 1, 0, 0, 0),
       (5, 5, 5, 4, 4, 2, 0, 0, 0),
       (5, 5, 5, 4, 4, 2, 1, 0, 0),
       (5, 5, 5, 5, 5, 2, 1, 0, 0),
       (5, 5, 5, 5, 5, 3, 2, 1, 0),
       (5, 5, 5, 5, 5, 3, 3, 2, 0),
       (5, 5, 5, 5, 5, 3, 3, 2, 1),
       (5, 5, 5, 5, 5, 3, 3, 3, 1),
       (5, 5, 5, 5, 5, 4, 3, 3, 2),
       (5, 5, 5, 5, 5, 4, 4, 4, 2),
       (5, 5, 5, 5, 5, 5, 4, 4, 3),
       (5, 5, 5, 5, 5, 5, 5, 5, 3),
       (5, 5, 5, 5, 5, 5, 5, 5, 4),
       (5, 5, 5, 5, 5, 5, 5, 5, 5),
       (6, 6, 6, 6, 5, 5, 5, 5, 5),
       (6, 6, 6, 6, 6, 6, 6, 5, 5),
       (6, 6, 6, 6, 6, 6, 6, 6, 6),
       (7, 7, 7, 7, 6, 6, 6, 6, 6))),
    { 6 thief }
    (xp: (1251, 2501, 5001, 10001, 20001, 42501, 70001, 110001, 160001, 220001);
     spellSlots: (
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0),
       (0, 0, 0, 0, 0, 0, 0, 0, 0))));
  { unused }
  classLevelTableTail: Byte = $00;
  { unused }
  classSavesLead: array[0..13] of Byte = ($03, $06, $03, $06, $05, $04, $05, $04, $05, $04, $02, $04, $02, $06);
  { The saving-throw targets by class, character level and save }
  classSaves: array[0..6, 1..21, 0..4] of Byte = (
    { Cleric }
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (2, 5, 6, 8, 7), (2, 5, 6, 8, 7)),
    { Druid }
    ((10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (10, 13, 14, 16, 15), (9, 12, 13, 15, 14), (9, 12, 13, 15, 14),
     (9, 12, 13, 15, 14), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (7, 10, 11, 13, 12), (6, 9, 10, 12, 11),
     (6, 9, 10, 12, 11), (6, 9, 10, 12, 11), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (5, 8, 9, 11, 10), (4, 7, 8, 10, 9),
     (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9), (4, 7, 8, 10, 9)),
    { Fighter }
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10), (5, 6, 7, 5, 8), (5, 6, 7, 5, 8), (4, 5, 6, 4, 7), (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6)),
    { Paladin }
    ((12, 13, 14, 15, 15), (12, 13, 14, 15, 15), (11, 12, 13, 14, 14), (11, 12, 13, 14, 14), (9, 9, 11, 11, 12),
     (9, 9, 11, 11, 12), (8, 9, 10, 10, 11), (9, 9, 10, 10, 11), (6, 7, 8, 7, 9), (6, 7, 8, 7, 9), (5, 6, 7, 6, 8),
     (5, 6, 7, 6, 8), (3, 4, 5, 3, 6), (3, 4, 5, 3, 6), (2, 3, 4, 2, 5), (2, 3, 4, 2, 5), (1, 2, 3, 2, 4),
     (1, 2, 3, 2, 4), (1, 2, 3, 2, 4), (1, 2, 3, 2, 4), (1, 2, 3, 2, 4)),
    { Ranger }
    ((14, 15, 16, 17, 17), (14, 15, 16, 17, 17), (13, 14, 15, 16, 16), (13, 14, 15, 16, 16), (11, 12, 13, 13, 14),
     (11, 12, 13, 13, 14), (10, 11, 12, 12, 13), (10, 11, 12, 12, 13), (8, 9, 10, 9, 11), (8, 9, 10, 9, 11),
     (7, 8, 9, 8, 10), (7, 8, 9, 8, 10), (5, 6, 7, 5, 8), (5, 6, 7, 5, 8), (4, 5, 6, 4, 7), (4, 5, 6, 4, 7),
     (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6), (3, 4, 5, 4, 6)),
    { Magic-user }
    ((14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12), (14, 13, 11, 15, 12),
     (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10), (13, 11, 9, 13, 10),
     (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (11, 9, 7, 11, 8), (10, 7, 5, 9, 6),
     (10, 7, 5, 9, 6), (10, 7, 5, 9, 6), (10, 7, 5, 9, 6), (10, 7, 5, 9, 6), (8, 5, 3, 7, 4)),
    { Thief }
    ((13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (13, 12, 14, 16, 15), (12, 11, 12, 15, 13),
     (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (12, 11, 12, 15, 13), (11, 10, 10, 14, 11), (11, 10, 10, 14, 11),
     (11, 10, 10, 14, 11), (11, 10, 10, 14, 11), (10, 9, 8, 13, 9), (10, 9, 8, 13, 9), (10, 9, 8, 13, 9),
     (10, 9, 8, 13, 9), (9, 8, 6, 12, 7), (9, 8, 6, 12, 7), (10, 9, 8, 13, 9), (9, 8, 6, 12, 7), (8, 7, 4, 11, 5)));

{ Level caps and training limits. }
const
  { the level cap by [race, class]; 0 bars the class and 40 is unlimited }
  raceCaps: array[0..5, 0..6] of Byte = (($00, $00, $07, $00, $00, $0B, $28), ($05, $00, $08, $00, $08, $08, $28),
    ($00, $00, $09, $00, $00, $00, $28), ($00, $00, $06, $00, $00, $00, $28), ($00, $00, $06, $00, $00, $00, $28),
    ($28, $00, $28, $28, $28, $28, $28));
  { by class: the highest level a character can train to }
  trainingLimits: array[0..6] of Byte = (
    $0A, $0C, $0B, $0B, $0B, $0B, $0B);

{ Area pictures, the mouse cursor, the joystick maps, packed color fill, the developer switches, picture and border
  pointers, the font, and combat, map and view flags. }
const
  { the area picture shown for each gameState pictureIndex; its readers do not check the index }
  areaPictureIds: array[0..5] of Byte = (
    $F0, $F1, $F2, $F2, $F5, $00);
  { the mouse cursor: the screen mask, then the cursor mask }
  cursorMask19: array[0..31] of Word = ($3FFF, $1FFF, $0FFF, $87FF, $A3FF, $E1FF, $F0FF, $F847,
    $FC23, $FE0F, $FF07, $F807, $FC43, $FFE0, $FFF9, $FFFF, $0000, $4000, $6000, $3000, $1800,
    $0C00, $0600, $0310, $0188, $00B0, $0030, $02F0, $0118, $000E, $0000, $0000);
  { the stick's direction for each band of its row and column, clockwise from north with 8 centered }
  joystickZoneMap: array[0..5, 0..5] of Byte = (($07, $07, $00, $00, $01, $01), ($07, $08, $08, $08,
    $08, $01), ($06, $08, $08, $08, $08, $02), ($06, $08, $08, $08, $08, $02), ($05, $08, $08,
    $08, $08, $03), ($05, $05, $04, $04, $03, $03));
  { the keypad key each stick direction stands for }
  joystickKeyMap: array[0..7] of Char = ('8', '9', '6', '3', '2', '1', '4', '7');
  { unused }
  joystickKeyMapTail: array[0..1] of Byte = (
    $20, $00);
  { a color repeated in both nibbles of a byte, for filling packed pixels }
  packedColorFill: array[0..15] of Byte = (
    $00, $11, $22, $33, $44, $55, $66, $77, $88, $99, $AA, $BB, $CC, $DD, $EE, $FF);
  { the developer switch, set from treasure.cfg; it opens the editors and the debug output }
  editorEnabled: Boolean = False;
  { unused }
  editorEnabledTail: Byte = $00;
  { the area's second big picture }
  extraPictureA: Types.PImage = nil;
  { the condition FxEngine.TriggerEffectsWithCondition is running; 28 or 255 around removals }
  currentCondition: Byte = $00;
  { the border pictures loaded: 1 the wilderness set, 2 the dungeon set }
  borderLoadState: Byte = $00;
  { the border's corner pictures }
  borderBankA: Types.PImage = nil;
  { its edge pictures }
  borderBankB: Types.PImage = nil;
  { the backdrop cleared boxes are restored from; nil clears to black }
  borderBackdrop: Types.PImage = nil;
  { the font TextRend draws from }
  gameFont: Types.PImage = nil;
  { DevMenu's combat switch }
  combatDisabled: Byte = $00;
  { the map editor's switch that marks squares with events }
  displayToggle: Byte = $00;
  { nonzero stops a missing picture or DAX block being asked for again; the map editor sets it while it loads walls }
  graphicsBusy: Byte = $00;
  { unused }
  graphicsBusyTail: Byte = $00;
  { the creature whose attack or spell the effect handlers are adjusting }
  effectCreature: Types.PCharacter = nil;
  { set to leave the camp menus }
  actionDone: Byte = $00;
  { brings the automap back after a monster display hid it: 2, then 1 as the 3-D view redraws, then the automap }
  overViewTransition: Byte = $00;
  { Ctrl-R's debug switch; with editorEnabled it prints picture and sequence names }
  debugToggle: Boolean = False;

implementation

end.
