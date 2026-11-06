{ SaveLoad -- saving and loading characters, parties and the vault. It has three storage modes (GDVars.storageMode). 0
  is the legacy format in the second configured directory (configLine2): *.guy characters with .swg items and .fx
  effects, and savgam?.dat parties, converted on load. 1 is this game's saves in the first (configLine1): <name>.pc
  characters with .thg items and .efx effects, savgam?.pty parties whose members are CHRDAT?n.sav, and vault?.dat. 2 is
  the transfer slot in the game directory, letter Z, which loading deletes. }
{$F+,O+,S+,A+,R-,V-,B-,I-}
unit SaveLoad;
interface
uses Types, Crt, GDConsts, GDVars, C_Keys, C_Video, C_Npc, C_Ifc, C_Effect, C_Race, Dos,
  FxEngine, CharHlp, ClassCal, MenuCore, Portrait, View3D, MapTiles, Border, Blit, TextRend, GameIo, DaxIo, ZeroFree;

type TResourceName = String[8];

{ Lists the characters that can join the party from the current storage. NPCs and characters already in the party are
  left out. Both lists stay nil when the save directory is not ready.
  @param(rawNameList Receives the names stored in the files, padded to 15 characters, as a menu list.)
  @param(displayNameList Receives the matching file names, in step with rawNameList.) }
procedure LoadCharlist(var rawNameList, displayNameList: Pointer);

{ Checks that the current mode's directory is reachable. While a floppy drive holds the disk labelled SECRET it asks for
  the save disk. A missing directory is created (on a floppy after asking, and asking for the save disk on No): the save
  directory in save mode, the other configured directory otherwise, transfer mode included. Another error asks for the
  save disk and retries on a floppy, and on a hard drive reports the directory missing and returns False.
  @returns(False when a hard-disk directory cannot be reached, True otherwise.) }
function CheckSaveDir: Boolean;

{ Builds the current character's combat icon in its order slot from its head and body pictures.
  @param(applyColorMap True recolors the icon with the character's icon colors.) }
procedure LoadCharIconAnim(applyColorMap: Boolean);

{ Deletes the character's .pc, .thg and .efx files from the save directory.
  @param(characterData The character.) }
procedure DeleteCharacterFiles(characterData: Pointer);

{ Writes a character to the save directory, or to the transfer directory in transfer mode: the record to a .pc file (or
  resourceName.sav for a saved game), its items to .thg, and its effects to .efx. Checks for room first, offering
  another disk, and asks before overwriting a .pc file, letting the player pick a new name that also becomes the
  character's name.
  @param(characterData The character record.)
  @param(resourceName The saved game's file name, or empty for a character saved on its own.) }
procedure SaveChar(characterData: Pointer; resourceName: TResourceName);

{ Load characterFileName, and the item and effect files of the same stem, into characterData. Legacy mode reads the old
  422-byte record, moves its fields to their places, maps byte $AD's codes, and converts items (ValidateItem) and
  effects (RemapLegacyType); transfer mode deletes each file once read. Then the character is recomputed (RecalcStats,
  RecalcAbility, class values). promptForDisk asks for the save disk rather than giving the load-disk message.
  @param(characterFileName The character's file name, extension included.)
  @param(characterData Receives the character, a Types.PCharacter.)
  @param(savedGame Unused.)
  @param(promptForDisk True picks the save-disk prompt over the alternate one.) }
procedure LoadChar(characterFileName: String; characterData: Pointer; savedGame, promptForDisk: Boolean);

{ Loads a monster: its record from MON1CHA.DAX, its effects from MON1SPC.DAX and its items from MON1ITM.DAX, taking the
  items from the item pool or the heap as asked. A missing monster is fatal. The monster's class mask becomes the sum of
  its classes' bits.
  @param(creatureId The monster's record.)
  @param(useSlotAllocator True takes the items from the item pool; False allocates them on the heap.)
  @param(characterData Receives the monster.) }
procedure LoadCreatureData(creatureId: Byte; useSlotAllocator: Boolean; characterData: Pointer);

{ Adds a monster to the party as an NPC with its picture as its icon, unless the party is full.
  @param(creatureId The monster's record.) }
procedure AddCreatureToParty(creatureId: Byte);

{ Loads a saved game. With vaultMode set, the transfer save (letter Z, whose files are deleted once read); otherwise the
  'Load from' menu (save or legacy directory) and a menu of the parties present (letters A..J). It reads the game state
  (a legacy party list starts at 12820 instead), the member list and each member (LoadChar; legacy NPCs are dropped),
  deletes the members' own save files (DeleteCharacterFiles), rebuilds their icons, and redraws the 3-D view or the area
  picture.
  @param(vaultMode Not #0 loads the transfer save instead of asking.) }
procedure LoadGame(vaultMode: Char);

{ Saves the game, first pruning the roster to the party size when asked. In vault mode it saves to the transfer slot
  under the letter Z; otherwise a menu picks a letter A..J. After the directory and free-space checks it writes
  savgam<letter>.pty (the game state, the location and the member names CHRDAT<letter>1..8) and each member, deleting
  the member's working files, and then the vault: tmpvault.dat becomes vault<letter>.dat when the vault changed, or the
  last save's vault is copied to this letter.
  @param(trimParty When set, first drops the characters beyond the party size.)
  @param(vaultMode When set, saves to the transfer slot instead of asking for a letter.) }
procedure SaveGame(trimParty, vaultMode: Byte);

{ Appends a character to the party, makes it current, gives it the first free order slot, and counts it in the party
  size; an NPC also has its class values recalculated. Note: with all eight order slots taken, the order slot is left at
  8.
  @param(characterData The character.) }
procedure AddCharToParty(characterData: Pointer);

{ Loads the vault's money and items for the vault's save letter, from tmpVault.dat while there are unsaved vault
  changes, appending the items to the treasure list. A transfer-directory vault file is deleted after reading.
  @param(hasMoney Set False. Note: it is never set True, even when the money is read.)
  @param(hasItems Receives True when an item was read.) }
procedure LoadVault(var hasMoney, hasItems: Boolean);

{ Writes the vault's money and items to a file, marks the vault as changed, and clears the encounter state. Note: when
  the disk lacks room it warns but still writes.
  @param(path The file.) }
procedure WriteVaultFile(path: String);
implementation
uses CharGen, C_Stat;
const
  { storageMode values }
  LEGACY_STORAGE = 0;
  SAVED_GAME_STORAGE = 1;
  TRANSFER_STORAGE = 2;
  { DosError codes }
  DOS_FILE_NOT_FOUND = 2;
  DOS_ACCESS_DENIED = 5;
  DOS_NO_MORE_FILES = 18;
type
  PLoadBytes = ^TLoadBytes;
  TLoadBytes = array[0..$5FF] of Byte;
  TNameTable = array[1..181] of String[20];
  PNameTable = ^TNameTable;

procedure LoadCharlist(var rawNameList, displayNameList: Pointer);

  { Appends each eligible character file matching fileMask to both lists in step. }
  procedure ScanSaveFiles(fileMask: Types.TStr80; nameOffset, markerOffset, expectedSize: Word; var rawNameList,
                          displayNameList: Pointer);
  var
    rawNode: Types.PItemRec;
    rawTail: Types.PItemRec;
    displayNode: Types.PItemRec;
    displayTail: Types.PItemRec;
    rosterChar: Types.PCharacter; searchResult: SearchRec; bytesRead: Word; charFile: file;
    { Unused in this version; see the other implementations of this routine. }
    searchPath: Types.TStr80;
    marker: Byte;
    { Unused in this version; see the other implementations of this routine. }
    entryName: String[16];
    { Unused in this version; see the other implementations of this routine. }
    entryNameTail: Word;
  begin
    rawNode := nil; displayNode := nil;
    FindFirst(fileMask, 0, searchResult);
    while DosError = 0 do begin
      if GDVars.storageMode = SaveLoad.SAVED_GAME_STORAGE then
        Assign(charFile, GDVars.configLine1 + searchResult.Name)
      else Assign(charFile, GDVars.configLine2 + searchResult.Name);
      Reset(charFile, 1);
      if FileSize(charFile) = expectedSize then begin
        GetMem(rawNode, SizeOf(Types.TItemRec)); GetMem(displayNode, SizeOf(Types.TItemRec));
        GameIo.ZeroFill(rawNode^, SizeOf(Types.TItemRec));
        GameIo.ZeroFill(displayNode^, SizeOf(Types.TItemRec));
        Seek(charFile, nameOffset);
        BlockRead(charFile, rawNode^, 16, bytesRead);
        Seek(charFile, markerOffset);
        BlockRead(charFile, marker, SizeOf(marker));
        displayNode^.name := searchResult.Name;
        rawNode^.name := rawNode^.name + Copy(GDConsts.blankName, 1, 15 - Length(rawNode^.name));
        rosterChar := GDVars.partyHead;
        while (rosterChar <> nil) and
            (Copy(rawNode^.name, 1, 15) <>
             rosterChar^.name + Copy(GDConsts.blankName, 1, 15 - Length(rosterChar^.name))) do
          rosterChar := rosterChar^.next;
        if (marker > $7F) or (rosterChar <> nil) then begin
          FreeMem(rawNode, SizeOf(Types.TItemRec)); FreeMem(displayNode, SizeOf(Types.TItemRec));
          rawNode := nil; displayNode := nil
        end;
        if rawNode <> nil then begin
          if rawNameList = nil then begin
            rawNameList := rawNode; rawTail := Types.PItemRec(rawNameList);
            displayNameList := displayNode; displayTail := Types.PItemRec(displayNameList)
          end else begin
            rawTail^.next := rawNode; rawTail := rawTail^.next;
            displayTail^.next := displayNode; displayTail := displayTail^.next
          end
        end
      end;
      Close(charFile); FindNext(searchResult)
    end
  end;
begin
  rawNameList := nil; displayNameList := nil;
  if not SaveLoad.CheckSaveDir then Exit;
  case GDVars.storageMode of
    SaveLoad.LEGACY_STORAGE: ScanSaveFiles(GDVars.configLine2 + '*.guy', GDConsts.nameOffsets[GDVars.storageMode],
                            GDConsts.markerOffsets[GDVars.storageMode], GDConsts.expectedFileSizes[GDVars.storageMode],
                                rawNameList,
                            displayNameList);
    SaveLoad.SAVED_GAME_STORAGE: ScanSaveFiles(GDVars.configLine1 + '*.pc', GDConsts.nameOffsets[GDVars.storageMode],
                          GDConsts.markerOffsets[GDVars.storageMode], GDConsts.expectedFileSizes[GDVars.storageMode],
                              rawNameList,
                          displayNameList)
  end
end;

function CheckSaveDir: Boolean;
var
  errorCode: Integer; searchResult: SearchRec; promptChoice: Byte;
  directoryPath: String;
begin
  CheckSaveDir := False;
  case GDVars.storageMode of
    SaveLoad.SAVED_GAME_STORAGE: directoryPath := GDVars.configLine1;
    SaveLoad.TRANSFER_STORAGE: directoryPath := GDVars.exeDir
  else directoryPath := GDVars.configLine2 end;
  repeat
    while (DaxIo.GetVolumeLabel(directoryPath[1]) = 'SECRET') and (directoryPath[1] < 'C') do
      TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + directoryPath[1] + ':');
    repeat
      FindFirst(Copy(directoryPath, 1, Length(directoryPath) - 1), Directory, searchResult);
      errorCode := DosError;
      case errorCode of
        0: ;
        SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES: begin
          if UpCase(directoryPath[1]) < 'C' then begin
            if GDVars.storageMode = SaveLoad.SAVED_GAME_STORAGE then
              promptChoice := MenuCore.YesNoMenu(GDConsts.askDriveMsgA + directoryPath[1] + GDConsts.driveQMsg,
                                                 GDConsts.yesChoice)
            else
              promptChoice := MenuCore.YesNoMenu(GDConsts.askDriveMsgB + directoryPath[1] + GDConsts.driveQMsg,
                                                 GDConsts.yesChoice);
            if promptChoice <> GDConsts.yesChoice then
              TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + directoryPath[1] + ':')
          end;
          if GDVars.storageMode = SaveLoad.SAVED_GAME_STORAGE then
            MkDir(Copy(GDVars.configLine1, 1, Length(GDVars.configLine1) - 1))
          else MkDir(Copy(GDVars.configLine2, 1, Length(GDVars.configLine2) - 1));
          errorCode := DosError
        end else
        if UpCase(directoryPath[1]) < 'C' then
          TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + directoryPath[1] + ':')
        else begin
          if GDVars.storageMode = SaveLoad.LEGACY_STORAGE then
            TextRend.DisplayAndPause(Yellow, Black, GDConsts.locateSsbMsg)
          else TextRend.DisplayAndPause(Yellow, Black, GDConsts.locatePodMsg);
          Exit
        end
      end
    until errorCode in [0, SaveLoad.DOS_ACCESS_DENIED]
  until errorCode in [0, SaveLoad.DOS_ACCESS_DENIED];
  CheckSaveDir := True
end;

{ Lays a head image over a body image: in masked display mode only the head's opaque pixels are copied, otherwise the
  pixels are ORed together, and the masks are combined.
  @param(sourceImage The head image.)
  @param(destinationImage The body image, which receives the result.) }
procedure MergeIcon(sourceImage, destinationImage: Types.PImage);
var
  { Unused in this version; see the other implementations of this routine. }
  count: Word;
  pixelIndex: Word;
begin
  for pixelIndex := 0 to sourceImage^.frameBytes - 1 do begin
    if GDVars.graphicsClass = C_Video.VM_VGA then begin
      if sourceImage^.data[pixelIndex] <> sourceImage^.colorKey then
        destinationImage^.data[pixelIndex] := sourceImage^.data[pixelIndex]
    end else
      destinationImage^.data[pixelIndex] := destinationImage^.data[pixelIndex] or sourceImage^.data[pixelIndex];
    if destinationImage^.mask <> nil then
      destinationImage^.mask^[pixelIndex] := destinationImage^.mask^[pixelIndex] and sourceImage^.mask^[pixelIndex]
  end
end;

procedure LoadCharIconAnim(applyColorMap: Boolean);
var
  { Unused in this version; see the other implementations of this routine. }
  animSlotLead: Byte;
  { Unused in this version; see the other implementations of this routine. }
  animSlot: Byte;
  { Unused in this version; see the other implementations of this routine. }
  frame: Byte;
  fromMap: Types.TColorTable;
  toMap: Types.TColorTable;
  colorIndex: Byte;
begin
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconSizeLetters[iconSize], iconHeadClass, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconSizeLetters[iconSize], iconBodyClass, icon);
    SaveLoad.MergeIcon(GDVars.iconSet[11, 0], GDVars.iconSet[icon, 0]);
    SaveLoad.MergeIcon(GDVars.iconSet[11, 1], GDVars.iconSet[icon, 1]);
    if applyColorMap then begin
      for colorIndex := 0 to 15 do begin
        fromMap[colorIndex] := colorIndex; toMap[colorIndex] := colorIndex
      end;
      for colorIndex := 1 to 6 do begin
        toMap[GDConsts.defIconColors[colorIndex]] := iconColors[colorIndex] and $0F;
        toMap[GDConsts.defIconColors[colorIndex] + 8] := (iconColors[colorIndex] and $F0) shr 4
      end;
      Blit.RemapPic(Types.TColorTable(fromMap), Types.TColorTable(toMap), 0, Byte(False),
                    Types.PImage(GDVars.iconSet[icon, 0]));
      Blit.RemapPic(Types.TColorTable(fromMap), Types.TColorTable(toMap), 0, Byte(False),
                    Types.PImage(GDVars.iconSet[icon, 1]))
    end
  end;
  MapTiles.FreeIconAnim(11);
  GameIo.DrainKeys
end;

procedure DeleteCharacterFiles(characterData: Pointer);
var
  directoryPath: Types.TStr80;
  { Unused in this version; see the other implementations of this routine. }
  fileBuf: array[1..128] of Byte;
begin
  directoryPath := GDVars.configLine1 + DaxIo.SanitizeFileName(Types.PCharacter(characterData)^.name);
  DaxIo.DeleteIfPresent(directoryPath + '.pc');
  DaxIo.DeleteIfPresent(directoryPath + '.thg');
  DaxIo.DeleteIfPresent(directoryPath + '.efx')
end;

procedure SaveChar(characterData: Pointer; resourceName: TResourceName);
var
  charFile: file; fileStem: String[40]; fileExtension: String[4];
  menuChoice: Byte;
  { Unused in this version; see the other implementations of this routine. }
  response: Byte;
  itemCursor: Types.PItem;
  effectCursor: Types.PEffect;
  { Unused in this version; see the other implementations of this routine. }
  list: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  cursor: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  nameBuf: array[1..12] of Byte;
  errorCode: Word;
  requiredBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  redraw: Byte;
  directoryPath: String;
begin
  if GDVars.storageMode <> SaveLoad.TRANSFER_STORAGE then begin
    GDVars.storageMode := SaveLoad.SAVED_GAME_STORAGE; directoryPath := GDVars.configLine1
  end else directoryPath := GDVars.exeDir;
  repeat
    if not SaveLoad.CheckSaveDir then Exit;
    requiredBytes := 0; Inc(requiredBytes, SizeOf(Types.TCharacter));
    if Types.PCharacter(characterData)^.items <> nil then begin
      itemCursor := Types.PItem(Types.PCharacter(characterData)^.items);
      while itemCursor <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TItem)); itemCursor := itemCursor^.next
      end
    end;
    if Types.PCharacter(characterData)^.effects <> nil then begin
      effectCursor := Types.PEffect(Types.PCharacter(characterData)^.effects);
      while effectCursor <> nil do begin
        Inc(requiredBytes, SizeOf(Types.TEffect)); effectCursor := effectCursor^.next
      end
    end;
    menuChoice := 0;
    if requiredBytes > DiskFree(Ord(UpCase(directoryPath[1])) - Ord('@')) then begin
      TextRend.DisplayAndPause(Yellow, Black, GDConsts.diskFullMsg);
      MenuCore.ResetMenuSlots(1);
      menuChoice := Ord(MenuCore.MenuHorizontal(GDConsts.loseCharMsg, GDConsts.tryAnotherDiskMenu, Byte(False),
                                                Byte(False)))
    end
  until menuChoice = 0;
  if Length(resourceName) = 0 then begin
    fileExtension := '.pc';
    fileStem := DaxIo.SanitizeFileName(DaxIo.SanitizeString(Types.PCharacter(characterData)^.name, '.'))
  end else begin fileExtension := '.sav'; fileStem := resourceName end;
  repeat
    Assign(charFile, directoryPath + fileStem + fileExtension);
    Reset(charFile, 1); errorCode := DosError;
    if not (errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND]) then begin
      if UpCase(directoryPath[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + directoryPath[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, Black, GDConsts.locatePodMsg);
        Close(charFile); Exit
      end
    end
  until (errorCode = 0) or (errorCode = SaveLoad.DOS_FILE_NOT_FOUND);
  Close(charFile); menuChoice := 1;
  while (menuChoice = 1) and (Length(resourceName) = 0) and
      DaxIo.FileExists(directoryPath + fileStem + fileExtension) do begin
    menuChoice := MenuCore.YesNoMenu(GDConsts.overwriteMsg + fileStem + GDConsts.qMarkMsg, GDConsts.noChoice);
    if menuChoice = 1 then begin
      fileStem := '';
      while fileStem = '' do
        fileStem := TextRend.ReadString(GDConsts.newFileMsg, LightGreen, Black, 8);
      Types.PCharacter(characterData)^.name := fileStem
    end
  end;
  Assign(charFile, directoryPath + fileStem + fileExtension);
  Rewrite(charFile, 1);
  BlockWrite(charFile, Types.PCharacter(characterData)^, SizeOf(Types.TCharacter));
  Close(charFile);
  DaxIo.DeleteIfPresent(directoryPath + fileStem + '.thg');
  if Types.PCharacter(characterData)^.items <> nil then begin
    Assign(charFile, directoryPath + fileStem + '.thg');
    Rewrite(charFile, 1);
    itemCursor := Types.PItem(Types.PCharacter(characterData)^.items);
    while itemCursor <> nil do begin
      BlockWrite(charFile, itemCursor^, SizeOf(Types.TItem));
      itemCursor := itemCursor^.next
    end;
    Close(charFile)
  end;
  DaxIo.DeleteIfPresent(directoryPath + fileStem + '.efx');
  if Types.PCharacter(characterData)^.effects <> nil then begin
    Assign(charFile, directoryPath + fileStem + '.efx');
    Rewrite(charFile, 1);
    effectCursor := Types.PEffect(Types.PCharacter(characterData)^.effects);
    while effectCursor <> nil do begin
      BlockWrite(charFile, effectCursor^, SizeOf(Types.TEffect));
      effectCursor := effectCursor^.next
    end;
    Close(charFile)
  end
end;

{ Upper-cases a string.
  @param(value The string.)
  @returns(The string in upper case.) }
function UpperString(value: String): String;
var i: Byte; result: String;
begin
  result := '';
  for i := 1 to Length(value) do result := result + UpCase(value[i]);
  UpperString := result
end;

{ Load bord.dax block 10, the legacy item-name table, into borderData; a size other than 5355 is fatal. }
procedure LoadBorder;
var sizeRead: Word;
begin
  DaxIo.LoadDaxRetrying('bord', '.dax', 10, sizeRead, GDConsts.borderData);
  if sizeRead <> 5355 then GDVars.fatalMessageHook('bord.dax,10 error')
end;

{ Free the legacy item-name table. }
procedure FreeBorder;
begin
  if GDConsts.borderData <> nil then ZeroFree.PrefixFree(GDConsts.borderData, 5355);
  GDConsts.borderData := nil
end;

{ Map a legacy item-name id to this game's: 0 stays, 210..212 become 0, and any other becomes the index of the matching
  name (case-insensitive) in this game's table. False when none matches.
  @param(value The item-name id, remapped in place.)
  @returns(False when the name has no counterpart.) }
function RemapBorder(var value: Byte): Boolean;
var i: Byte;
begin
  RemapBorder := True;
  if value = 0 then Exit;
  if value in [210, 211, 212] then begin value := 0; Exit end;
  for i := 1 to 181 do
    if SaveLoad.UpperString(GDConsts.itemNameParts[i]) =
        SaveLoad.UpperString(PNameTable(GDConsts.borderData)^[value]) then begin
      value := i; Exit
    end;
  RemapBorder := False
end;

{ Convert a legacy item: remap its three name ids, map its type (1..127) through legacyTypeMap, and unequip it. When a
  name or the type has no counterpart, or its effect is 98, it shows 'Cannot use <name>' and returns False.
  @param(item The item, converted in place.)
  @returns(True when the item can be used.) }
function ValidateItem(var item: Types.TItem): Boolean;
var
  itemMessage: String;
  nameIndex: Byte;

  { Report that the item cannot be used. }
  procedure CannotUse;
  begin
    GDVars.bottomMessageHook('Cannot use ' + itemMessage);
    TextRend.PauseOnly;
    TextRend.PauseOnly
  end;
begin
  ValidateItem := False;
  itemMessage := '';
  for nameIndex := 1 to 3 do
    if item.nameIds[nameIndex] <> 0 then
      itemMessage := PNameTable(GDConsts.borderData)^[item.nameIds[nameIndex]] + ' ' + itemMessage;
  for nameIndex := 1 to 3 do
    if not SaveLoad.RemapBorder(item.nameIds[nameIndex]) then begin
      CannotUse;
      Exit
    end;
  if not (item.itemType in [1..127]) then begin
    CannotUse;
    Exit
  end;
  item.itemType := GDConsts.legacyTypeMap[item.itemType];
  if item.itemType = 0 then begin
    CannotUse;
    Exit
  end;
  if item.effect = 98 then begin
    CannotUse;
    Exit
  end;
  item.equipped := 0;
  ValidateItem := True
end;

{ Map a legacy effect id to this game's: 18 to 7, 107 to 95, 124 to 18 and 134 to 105; 97, 26, 47, 48 and 8 keep theirs.
  False for any other, which is dropped.
  @param(value The effect id, remapped in place.)
  @returns(False when the effect is dropped.) }
function RemapLegacyType(var value: Byte): Boolean;
begin
  case value of
    97: begin value := C_Effect.CON_SPELL_SAVE_BONUS; RemapLegacyType := True end;
    26: begin value := C_Effect.DWARF_THAC0_BONUS; RemapLegacyType := True end;
    47: begin value := C_Effect.DWARF_GIANT_BONUS; RemapLegacyType := True end;
    48: begin value := C_Effect.GNOME_LARGE_MONSTER_BONUS; RemapLegacyType := True end;
    18: begin value := C_Effect.GNOME_THAC0_BONUS; RemapLegacyType := True end;
    107: begin value := C_Effect.RESIST_SLEEP_CHARM_90; RemapLegacyType := True end;
    124: begin value := C_Effect.RESIST_CHARM_30; RemapLegacyType := True end;
    8: begin value := C_Effect.PROTECTION_FROM_EVIL; RemapLegacyType := True end;
    134: begin value := 105; RemapLegacyType := True end
  else RemapLegacyType := False end
end;

procedure LoadChar(characterFileName: String; characterData: Pointer; savedGame, promptForDisk: Boolean);
var
  charFile: file;
  bytesRead: Word;
  itemTail: Types.PItem;
  itemBuf: Types.PItem;
  effTail: Types.PEffect;
  effBuf: Types.PEffect;
  diskPrompt: String[40];
  { Unused in this version; see the other implementations of this routine. }
  ignoredOpenResult: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  recordBuffer: array[1..292] of Byte;
  { Unused in this version; see the other implementations of this routine. }
  recordBufferTail: Byte;
  itemCount: Byte;
  directoryPath: String;
  itemExtension: String[4];
  effectExtension: String[4];
  legacyChar: PLoadBytes;
  recordSize: Word;
  { Unused in this version; see the other implementations of this routine. }
  fileOffset: LongInt;
begin
  case GDVars.storageMode of
    SaveLoad.SAVED_GAME_STORAGE: begin
      directoryPath := GDVars.configLine1; itemExtension := '.thg'; effectExtension := '.efx'
    end;
    SaveLoad.TRANSFER_STORAGE: begin
      directoryPath := GDVars.exeDir; itemExtension := '.thg'; effectExtension := '.efx'
    end else begin
    directoryPath := GDVars.configLine2; itemExtension := '.swg'; effectExtension := '.fx';
    SaveLoad.LoadBorder
  end end;
  if promptForDisk then diskPrompt := 'Put save disk in '
  else diskPrompt := GDConsts.diskPrompt;
  ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName, diskPrompt, 0, charFile);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  GameIo.ZeroFill(Types.PCharacter(characterData)^, SizeOf(Types.TCharacter));
  case GDVars.storageMode of
    SaveLoad.LEGACY_STORAGE: begin
      GetMem(legacyChar, 422);
      GameIo.ZeroFill(legacyChar^, 422);
      GameIo.ZeroFill(Types.PCharacter(characterData)^, SizeOf(Types.TCharacter));
      BlockRead(charFile, legacyChar^, 422, bytesRead);
      Close(charFile);
      Move(legacyChar^[0], PLoadBytes(characterData)^[0], 30);
      Move(legacyChar^[$72], PLoadBytes(characterData)^[$AB], 4);
      Move(legacyChar^[$76], PLoadBytes(characterData)^[$B0], $67);
      Move(legacyChar^[$DE], PLoadBytes(characterData)^[$131], 9);
      Move(legacyChar^[$E9], PLoadBytes(characterData)^[$13A], $0D);
      Move(legacyChar^[$F7], PLoadBytes(characterData)^[$147], 4);
      Move(legacyChar^[$103], PLoadBytes(characterData)^[$14B], $0D);
      Move(legacyChar^[$111], PLoadBytes(characterData)^[$158], 7);
      Move(legacyChar^[$119], PLoadBytes(characterData)^[$166], 1);
      Move(legacyChar^[$11B], PLoadBytes(characterData)^[$167], $0A);
      Move(legacyChar^[$126], PLoadBytes(characterData)^[$171], 5);
      Move(legacyChar^[$12B], PLoadBytes(characterData)^[$17B], 7);
      Move(legacyChar^[$132], PLoadBytes(characterData)^[$186], 5);
      Move(legacyChar^[$137], PLoadBytes(characterData)^[$18F], 5);
      Move(legacyChar^[$141], PLoadBytes(characterData)^[$19A], $0B);
      Move(legacyChar^[$14C], PLoadBytes(characterData)^[$1A6], $45);
      Move(legacyChar^[$195], PLoadBytes(characterData)^[$1ED], $11);
      case PLoadBytes(characterData)^[$AD] of
        2: PLoadBytes(characterData)^[$AD] := C_Race.ELF;
        4: PLoadBytes(characterData)^[$AD] := C_Race.HALF_ELF;
        1: PLoadBytes(characterData)^[$AD] := C_Race.DWARF;
        3: PLoadBytes(characterData)^[$AD] := C_Race.GNOME;
        5: PLoadBytes(characterData)^[$AD] := C_Race.HALFLING;
        7: PLoadBytes(characterData)^[$AD] := C_Race.HUMAN;
        0: PLoadBytes(characterData)^[$AD] := C_Race.MONSTER
      else PLoadBytes(characterData)^[$AD] := C_Race.MONSTER end;
      Types.PCharacter(characterData)^.items := nil;
      Types.PCharacter(characterData)^.effects := nil;
      Types.PCharacter(characterData)^.combatAddr := nil;
      Types.PCharacter(characterData)^.next := nil;
      PLoadBytes(characterData)^[$1A4] := 2;
      PLoadBytes(characterData)^[$1A5] := 2;
      FreeMem(legacyChar, 422)
    end;
    SaveLoad.SAVED_GAME_STORAGE, SaveLoad.TRANSFER_STORAGE: begin
      BlockRead(charFile, Types.PCharacter(characterData)^, SizeOf(Types.TCharacter), bytesRead);
      Close(charFile);
      if GDVars.storageMode = SaveLoad.TRANSFER_STORAGE then
        DaxIo.DeleteIfPresent(directoryPath + characterFileName);
      Types.PCharacter(characterData)^.items := nil;
      Types.PCharacter(characterData)^.effects := nil;
      Types.PCharacter(characterData)^.combatAddr := nil;
      Types.PCharacter(characterData)^.next := nil
    end
  end;
  Delete(characterFileName, Pos('.', characterFileName), 4);
  itemCount := 0;
  if DaxIo.FileExists(directoryPath + characterFileName + itemExtension) then begin
    GetMem(itemBuf, SizeOf(Types.TItem));
    ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName + itemExtension, diskPrompt, 0,
                                             charFile);
    recordSize := SizeOf(Types.TItem);
    if GDVars.storageMode = SaveLoad.LEGACY_STORAGE then begin
      repeat
        BlockRead(charFile, itemBuf^, recordSize, bytesRead);
        if (bytesRead = recordSize) and SaveLoad.ValidateItem(itemBuf^) then begin
          Inc(itemCount);
          if Types.PCharacter(characterData)^.items = nil then begin
            Types.PCharacter(characterData)^.items := GameIo.AllocSlot;
            itemTail := Types.PItem(Types.PCharacter(characterData)^.items)
          end else begin
            itemTail^.next := GameIo.AllocSlot;
            itemTail := itemTail^.next
          end;
          itemTail^ := itemBuf^; itemTail^.next := nil
        end
      until bytesRead <> recordSize
    end else begin
      repeat
        BlockRead(charFile, itemBuf^, recordSize, bytesRead);
        if bytesRead = recordSize then begin
          Inc(itemCount);
          if Types.PCharacter(characterData)^.items = nil then begin
            Types.PCharacter(characterData)^.items := GameIo.AllocSlot;
            itemTail := Types.PItem(Types.PCharacter(characterData)^.items)
          end else begin
            itemTail^.next := GameIo.AllocSlot;
            itemTail := itemTail^.next
          end;
          itemTail^ := itemBuf^; itemTail^.next := nil
        end
      until bytesRead <> recordSize
    end;
    Close(charFile);
    if GDVars.storageMode = SaveLoad.TRANSFER_STORAGE then
      DaxIo.DeleteIfPresent(directoryPath + characterFileName + itemExtension);
    FreeMem(itemBuf, SizeOf(Types.TItem))
  end;
  if DaxIo.FileExists(directoryPath + characterFileName + effectExtension) then begin
    GetMem(effBuf, SizeOf(Types.TEffect));
    ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + characterFileName + effectExtension, diskPrompt, 0,
                                             charFile);
    repeat
      BlockRead(charFile, effBuf^, SizeOf(Types.TEffect), bytesRead);
      if (bytesRead = SizeOf(Types.TEffect)) and
          ((GDVars.storageMode <> SaveLoad.LEGACY_STORAGE) or
           SaveLoad.RemapLegacyType(effBuf^.id)) then begin
        if Types.PCharacter(characterData)^.effects = nil then begin
          GetMem(Types.PCharacter(characterData)^.effects, SizeOf(Types.TEffect));
          effTail := Types.PEffect(Types.PCharacter(characterData)^.effects)
        end else begin
          GetMem(effTail^.next, SizeOf(Types.TEffect)); effTail := effTail^.next
        end;
        effTail^ := effBuf^; effTail^.next := nil
      end
    until bytesRead <> SizeOf(Types.TEffect);
    Close(charFile);
    if GDVars.storageMode = SaveLoad.TRANSFER_STORAGE then
      DaxIo.DeleteIfPresent(directoryPath + characterFileName + effectExtension);
    FreeMem(effBuf, SizeOf(Types.TEffect))
  end;
  SaveLoad.FreeBorder;
  GameIo.DrainKeys;
  CharHlp.RecalcStats(characterData);
  FxEngine.RecalcAbility(characterData, C_Stat.STRENGTH);
  ClassCal.RecalcClassStats(characterData)
end;

procedure LoadCreatureData(creatureId: Byte; useSlotAllocator: Boolean; characterData: Pointer);
var
  dataSize: Word;
  daxData: Types.PByteBuffer;
  dataOffset: Word;
  itemCursor: Types.PItem;
  effectCursor: Types.PEffect;
  archiveNumber: String[1];
  { Unused in this version; see the other implementations of this routine. }
  index: Byte;
  { Unused in this version; see the other implementations of this routine. }
  roll: Byte;
  classIndex: ShortInt;
begin
  archiveNumber := '1';
  DaxIo.LoadDax('MON' + archiveNumber + 'CHA', '.dax', creatureId, dataSize, daxData);
  if dataSize = 0 then begin
    GDVars.fatalMessageHook('Cannot load monster ' + GDVars.intToStringHook(creatureId))
  end;
  Move(daxData^, Types.PCharacter(characterData)^, SizeOf(Types.TCharacter));
  with Types.PCharacter(characterData)^ do begin
    items := nil; effects := nil; next := nil; combatAddr := nil
  end;
  ZeroFree.PrefixFree(daxData, dataSize);
  GDVars.suppressDiskPrompt := 1;
  DaxIo.LoadDax('MON' + archiveNumber + 'SPC', '.dax', creatureId, dataSize, daxData);
  if dataSize <> 0 then begin
    dataOffset := 0;
    GetMem(Types.PCharacter(characterData)^.effects, SizeOf(Types.TEffect));
    effectCursor := Types.PEffect(Types.PCharacter(characterData)^.effects);
    repeat
      Move(daxData^[dataOffset], effectCursor^, SizeOf(Types.TEffect));
      effectCursor^.next := nil;
      Inc(dataOffset, SizeOf(Types.TEffect));
      if dataOffset < dataSize then begin
        GetMem(effectCursor^.next, SizeOf(Types.TEffect));
        effectCursor := effectCursor^.next
      end
    until dataOffset >= dataSize;
    ZeroFree.PrefixFree(daxData, dataSize)
  end;
  DaxIo.LoadDax('MON' + archiveNumber + 'ITM', '.dax', creatureId, dataSize, daxData);
  if dataSize <> 0 then begin
    dataOffset := 0;
    if useSlotAllocator then
      Types.PCharacter(characterData)^.items := GameIo.AllocSlot
    else GetMem(Types.PCharacter(characterData)^.items, SizeOf(Types.TItem));
    itemCursor := Types.PItem(Types.PCharacter(characterData)^.items);
    repeat
      Move(daxData^[dataOffset], itemCursor^.itemType, 17);
      itemCursor^.next := nil;
      itemCursor^.inUse := 0;
      Inc(dataOffset, 17);
      if dataOffset < dataSize then begin
        if useSlotAllocator then itemCursor^.next := GameIo.AllocSlot
        else GetMem(itemCursor^.next, SizeOf(Types.TItem));
        itemCursor := itemCursor^.next
      end
    until dataOffset >= dataSize;
    ZeroFree.PrefixFree(daxData, dataSize)
  end;
  GDVars.suppressDiskPrompt := 0;
  GameIo.DrainKeys;
  with Types.PCharacter(characterData)^ do begin
    classMask := 0;
    for classIndex := 0 to 6 do
      if classLevels[classIndex] > 0 then
        Inc(classMask, GDConsts.classMaskBit[classIndex])
  end
end;

procedure AddCreatureToParty(creatureId: Byte);
var
  { Unused in this version; see the other implementations of this routine. }
  node: Pointer;
  newChar: Types.PCharacter;
begin
  if GDVars.gameState^.partySize > 7 then Exit;
  GetMem(newChar, SizeOf(Types.TCharacter));
  SaveLoad.LoadCreatureData(creatureId, True, newChar);
  SaveLoad.AddCharToParty(newChar);
  newChar^.npc := newChar^.npc or C_Npc.NON_PLAYER;
  newChar^.creatureId := creatureId;
  MapTiles.LoadIconAnim('CPIC', creatureId, newChar^.icon)
end;

procedure AddCharToParty(characterData: Pointer);
var
  partyCursor: Types.PCharacter;
  usedOrderSlots: array[0..7] of Byte;
begin
  Types.PCharacter(characterData)^.icon := 255;
  if GDVars.partyHead = nil then GDVars.partyHead := Types.PCharacter(characterData)
  else begin
    partyCursor := GDVars.partyHead;
    while partyCursor^.next <> nil do partyCursor := partyCursor^.next;
    partyCursor^.next := Types.PCharacter(characterData)
  end;
  GDVars.curChar := Types.PCharacter(characterData);
  GameIo.ZeroFill(usedOrderSlots, SizeOf(usedOrderSlots));
  partyCursor := GDVars.partyHead;
  while partyCursor <> nil do begin
    if partyCursor^.icon in [0..7] then
      usedOrderSlots[partyCursor^.icon] := 1;
    partyCursor := partyCursor^.next
  end;
  with GDVars.curChar^ do begin
    icon := 0;
    while (icon < 8) and (usedOrderSlots[icon] <> 0) do
      Inc(icon)
  end;
  Inc(GDVars.gameState^.partySize);
  if Types.PCharacter(characterData)^.npc > $7F then
    ClassCal.RecalcClassStats(characterData)
end;

procedure LoadGame(vaultMode: Char);
var
  characterNames: array[1..8] of String[40];
  partyFile: file;
  characterIndex: Byte;
  loadedChar: Types.PCharacter;
  characterFileName: String[40];
  bytesRead: Word;
  characterCount: Byte;
  { Unused in this version; see the other implementations of this routine. }
  ignoredOpenResult: Boolean;
  saveLetterIndex: Byte;
  menuSlotCount: Byte;
  menuChoice: Char;
  saveLetter: Char;
  { Unused in this version; see the other implementations of this routine. }
  menuQuery: String[20];
  characterExtension: String[4];
  partyExtension: String[4];
  nextEffect: Types.PEffect;
  nextItem: Types.PItem;
  directoryPath: String;
  { Unused in this version; see the other implementations of this routine. }
  vaultChoice: Byte;
  { Unused in this version; see the other implementations of this routine. }
  previousPictureId: Byte;
  { The party file's wall-set slot byte, read and discarded. }
  wallSetSlot: Byte;
begin
  Border.EraseBox(1, 1, 38, 22);
  if vaultMode <> #0 then begin
    GDVars.storageMode := SaveLoad.TRANSFER_STORAGE;
    partyExtension := '.pty'; characterExtension := '.sav';
    directoryPath := GDVars.exeDir
  end else begin
    MenuCore.ResetMenuSlots(2);
    menuChoice := MenuCore.MenuHorizontal(GDConsts.fromText, GDConsts.characterSourceMenu, 0, 0);
    case menuChoice of
      #0: begin
        GDVars.storageMode := SaveLoad.SAVED_GAME_STORAGE; directoryPath := GDVars.configLine1;
        partyExtension := '.pty'; characterExtension := '.sav'
      end;
      #1: begin
        GDVars.storageMode := SaveLoad.LEGACY_STORAGE; directoryPath := GDVars.configLine2;
        partyExtension := '.dat'; characterExtension := '.sav'
      end;
      #2: Exit
    else if GDVars.menuReturnedKey and (menuChoice = C_Keys.ESCAPE) then Exit end
  end;
  if not SaveLoad.CheckSaveDir then Exit;
  if vaultMode <> #0 then saveLetter := 'Z'
  else begin
    menuQuery := '';
    FillChar(GDVars.menuSlots, SizeOf(GDVars.menuSlots), 255);
    menuSlotCount := 0; saveLetterIndex := 0;
    for saveLetter := 'A' to 'J' do begin
      if DaxIo.FileExists(directoryPath + 'savgam' + saveLetter + partyExtension)
      then begin
        GDVars.menuSlots[menuSlotCount].optionId := saveLetterIndex;
        Inc(menuSlotCount)
      end;
      Inc(saveLetterIndex)
    end;
    if GDVars.menuSlots[0].optionId = 255 then Exit;
    repeat
      menuChoice := MenuCore.MenuHorizontal(GDConsts.whichText, GDConsts.driveLetterMenu, 0, 0);
      if GDVars.menuReturnedKey and (menuChoice = C_Keys.ESCAPE) then saveLetter := C_Keys.ESCAPE
      else saveLetter := Chr(Ord(menuChoice) + Ord('A'))
    until ((saveLetter in ['A'..'J']) and
           DaxIo.FileExists(directoryPath + 'savgam' + saveLetter + partyExtension)) or
        (saveLetter = C_Keys.ESCAPE);
    if saveLetter = C_Keys.ESCAPE then Exit
  end;
  ignoredOpenResult := DaxIo.OpenWithRetry(directoryPath + 'savgam' + saveLetter + partyExtension,
                                           'Put save disk in ' + directoryPath, 1, partyFile);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Loading...Please Wait');
  GDVars.loadedSavedGameFlag := Byte(GDVars.storageMode = SaveLoad.SAVED_GAME_STORAGE);
  previousPictureId := GDVars.gameState^.pictureIndex;
  if GDVars.storageMode <> SaveLoad.LEGACY_STORAGE then begin
    GDVars.pendingSaveLetter := saveLetter;
    BlockRead(partyFile, GDVars.gameState^, SizeOf(Types.TGameState), bytesRead);
    BlockRead(partyFile, GDVars.partyPos, SizeOf(GDVars.partyPos), bytesRead);
    BlockRead(partyFile, GDVars.locState.previous, SizeOf(GDVars.locState.previous), bytesRead);
    BlockRead(partyFile, GDVars.locState.current, SizeOf(GDVars.locState.current), bytesRead);
    FillChar(GDVars.wallSetCache, SizeOf(GDVars.wallSetCache), 0);
    BlockRead(partyFile, GDVars.wallSetCache[1].wallDefId, 1, bytesRead);
    BlockRead(partyFile, GDVars.wallSetCache[2].wallDefId, 1, bytesRead);
    BlockRead(partyFile, GDVars.wallSetCache[3].wallDefId, 1, bytesRead);
    GDVars.wallSetCache[1].symbolSlot := 0;
    GDVars.wallSetCache[2].symbolSlot := 1;
    GDVars.wallSetCache[3].symbolSlot := 2;
    BlockRead(partyFile, wallSetSlot, SizeOf(wallSetSlot), bytesRead)
  end else Seek(partyFile, 12820);
  BlockRead(partyFile, characterCount, SizeOf(characterCount), bytesRead);
  BlockRead(partyFile, characterNames, SizeOf(characterNames), bytesRead);
  Close(partyFile);
  if vaultMode <> #0 then DaxIo.DeleteIfPresent(directoryPath + 'savgam' + saveLetter + partyExtension);
  GDVars.loadComplete := 1; GDVars.gameState^.partySize := 0;
  for characterIndex := 1 to characterCount do begin
    characterFileName := DaxIo.SanitizeFileName(DaxIo.SanitizeString(characterNames[characterIndex], '.'));
    if DaxIo.FileExists(directoryPath + characterFileName + characterExtension)
    then begin
      GetMem(loadedChar, SizeOf(Types.TCharacter));
      SaveLoad.LoadChar(characterFileName + characterExtension, loadedChar, True, True);
      if (GDVars.storageMode = SaveLoad.LEGACY_STORAGE) and (loadedChar^.npc >= C_Npc.NON_PLAYER) then begin
        nextItem := Types.PItem(loadedChar^.items);
        while nextItem <> nil do begin
          nextItem := Types.PItem(loadedChar^.items)^.next;
          GameIo.FreeSlot(Pointer(loadedChar^.items));
          loadedChar^.items := nextItem
        end;
        nextEffect := Types.PEffect(loadedChar^.effects);
        while nextEffect <> nil do begin
          nextEffect := Types.PEffect(loadedChar^.effects)^.next;
          FreeMem(loadedChar^.effects, SizeOf(Types.TEffect));
          loadedChar^.effects := nextEffect
        end;
        FreeMem(loadedChar, SizeOf(Types.TCharacter))
      end else SaveLoad.AddCharToParty(loadedChar);
      if not SaveLoad.CheckSaveDir then Exit
    end
  end;
  loadedChar := GDVars.partyHead;
  while loadedChar <> nil do begin
    SaveLoad.DeleteCharacterFiles(loadedChar); loadedChar := loadedChar^.next
  end;
  GDVars.curChar := GDVars.partyHead;
  while GDVars.curChar <> nil do begin
    if GDVars.curChar^.npc >= C_Npc.ANIMATED_PLAYER then GDVars.curChar^.npc := 0;
    if GDVars.curChar^.npc < C_Npc.NON_PLAYER then SaveLoad.LoadCharIconAnim(True)
    else MapTiles.LoadIconAnim('CPIC', GDVars.curChar^.creatureId, GDVars.curChar^.icon);
    GDVars.curChar := GDVars.curChar^.next
  end;
  GDVars.curChar := GDVars.partyHead;
  if GDVars.storageMode <> SaveLoad.LEGACY_STORAGE then begin
    if GDVars.gameState^.location <> 0 then begin
      if GDVars.wallSetCache[1].wallDefId > 0 then begin
        View3D.Load3DMap(GDVars.gameState^.currentMap)
      end
    end else Portrait.LoadBigPic(GDConsts.areaPictureIds[GDVars.gameState^.pictureIndex])
  end;
  GameIo.DrainKeys;
  MenuCore.ClearBottomLine;
  GDVars.locState.current := C_Ifc.MAIN_MENU
end;

procedure SaveGame(trimParty, vaultMode: Byte);
var
  characterNames: array[1..8] of String[40];
  partyFile: file;
  { Unused in this version; see the other implementations of this routine. }
  pathBuffer: array[1..128] of Byte;
  characterCount: Byte;
  nextCharacter: Types.PCharacter;
  partyCursor: Types.PCharacter;
  characterNumber: String[1];
  vaultPath: String[80];
  hasMoney: Boolean;
  hasItems: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  overwrite: Boolean;
  menuChoice: Char;
  saveLetter: Char;
  errorCode: Word;
  requiredBytes: Word;
  savePath: String;
  { The party file's wall-set slot byte, written as 0. }
  wallSetSlot: Byte;

  { Totals the disk space the party's character records, items, and effects take. }
  function SaveSize: Word;
  var
    characterCursor: Types.PCharacter;
    itemCursor: Types.PItem;
    effectCursor: Types.PEffect;
    byteCount: Word;
  begin
    byteCount := 0; characterCursor := GDVars.partyHead;
    while characterCursor <> nil do begin
      Inc(byteCount, SizeOf(Types.TCharacter));
      if characterCursor^.items <> nil then begin
        itemCursor := Types.PItem(characterCursor^.items);
        while itemCursor <> nil do begin
          Inc(byteCount, SizeOf(Types.TItem)); itemCursor := itemCursor^.next
        end
      end;
      if characterCursor^.effects <> nil then begin
        effectCursor := Types.PEffect(characterCursor^.effects);
        while effectCursor <> nil do begin
          Inc(byteCount, SizeOf(Types.TEffect)); effectCursor := effectCursor^.next
        end
      end;
      characterCursor := characterCursor^.next
    end;
    SaveSize := byteCount
  end;
begin
  if trimParty <> 0 then begin
    characterCount := 0; partyCursor := GDVars.partyHead;
    while partyCursor <> nil do begin
      if characterCount >= GDVars.gameState^.partySize then begin
        nextCharacter := partyCursor^.next;
        CharGen.RemoveCreature(True, True); partyCursor := nextCharacter
      end else begin Inc(characterCount); partyCursor := partyCursor^.next end
    end
  end;
  if vaultMode <> 0 then begin
    saveLetter := 'Z'; GDVars.storageMode := SaveLoad.TRANSFER_STORAGE;
    savePath := GDVars.exeDir + 'savgam' + saveLetter
  end else begin
    repeat
      MenuCore.ResetMenuSlots(9);
      menuChoice := MenuCore.MenuHorizontal(GDConsts.saveWhichGamePrompt, GDConsts.driveLetterMenu, 0,
                                            Byte(GDVars.locState.current = C_Ifc.CAMPING))
    until (Ord(menuChoice) < 10) or (GDVars.menuReturnedKey and (Ord(menuChoice) = Ord(C_Keys.ESCAPE)));
    if Ord(menuChoice) > 9 then Exit;
    saveLetter := Chr(Ord(menuChoice) + Ord('A'));
    GDVars.storageMode := SaveLoad.SAVED_GAME_STORAGE;
    savePath := GDVars.configLine1 + 'savgam' + saveLetter
  end;
  if not SaveLoad.CheckSaveDir then Exit;
  if DaxIo.FileExists(savePath + '.pty') then requiredBytes := 0
  else requiredBytes := 1031;
  Inc(requiredBytes, SaveSize);
  if LongInt(requiredBytes) > DiskFree(Ord(UpCase(savePath[1])) - Ord('@')) then begin
    TextRend.DisplayAndPause(Yellow, Black, GDConsts.diskFullMsg); Exit
  end;
  repeat
    Assign(partyFile, savePath + '.pty');
    Rewrite(partyFile, 1); errorCode := DosError;
    if not (errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES]) then begin
      if UpCase(savePath[1]) < 'C' then
        TextRend.DisplayAndPause(Yellow, Black, 'Put save disk in ' + savePath[1] + ':')
      else begin
        TextRend.DisplayAndPause(Yellow, Black, GDConsts.locatePodMsg);
        Close(partyFile); Exit
      end
    end
  until errorCode in [0, SaveLoad.DOS_FILE_NOT_FOUND, SaveLoad.DOS_NO_MORE_FILES];
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, Black, 'Saving...Please Wait');
  BlockWrite(partyFile, GDVars.gameState^, SizeOf(Types.TGameState));
  BlockWrite(partyFile, GDVars.partyPos, SizeOf(GDVars.partyPos));
  BlockWrite(partyFile, GDVars.locState.previous, SizeOf(GDVars.locState.previous));
  BlockWrite(partyFile, GDVars.locState.current, SizeOf(GDVars.locState.current));
  BlockWrite(partyFile, GDVars.wallSetCache[1].wallDefId, 1);
  BlockWrite(partyFile, GDVars.wallSetCache[2].wallDefId, 1);
  BlockWrite(partyFile, GDVars.wallSetCache[3].wallDefId, 1);
  wallSetSlot := 0;
  BlockWrite(partyFile, wallSetSlot, SizeOf(wallSetSlot));
  characterCount := 0; partyCursor := GDVars.partyHead;
  if partyCursor = nil then
    TextRend.DisplayAndPause(Yellow, Black, 'WARNING: Problem Saving Characters');
  while (partyCursor <> nil) and (characterCount < 8) do begin
    Inc(characterCount); Str(characterCount, characterNumber);
    characterNames[characterCount] := 'CHRDAT' + saveLetter + characterNumber;
    partyCursor := partyCursor^.next
  end;
  BlockWrite(partyFile, characterCount, SizeOf(characterCount));
  BlockWrite(partyFile, characterNames, SizeOf(characterNames));
  Close(partyFile);
  partyCursor := GDVars.partyHead; characterCount := 0;
  while (partyCursor <> nil) and (characterCount < 8) do begin
    Inc(characterCount); Str(characterCount, characterNumber);
    SaveLoad.SaveChar(partyCursor, 'CHRDAT' + saveLetter + characterNumber);
    SaveLoad.DeleteCharacterFiles(partyCursor); partyCursor := partyCursor^.next
  end;
  if vaultMode <> 0 then vaultPath := GDVars.exeDir + 'vault' + saveLetter + '.dat'
  else vaultPath := GDVars.configLine1 + 'vault' + saveLetter + '.dat';
  if GDVars.vaultDirty <> 0 then begin
    DaxIo.DeleteIfPresent(vaultPath);
    DaxIo.RenameIfExists(GDVars.configLine1 + 'tmpvault.dat',
                         GDVars.configLine1 + 'vault' + saveLetter + '.dat')
  end else if GDVars.pendingSaveLetter <> saveLetter then begin
    SaveLoad.LoadVault(hasMoney, hasItems);
    if vaultMode <> 0 then vaultPath := GDVars.exeDir + 'vault' + saveLetter + '.dat'
    else vaultPath := GDVars.configLine1 + 'vault' + saveLetter + '.dat';
    SaveLoad.WriteVaultFile(vaultPath)
  end;
  GDVars.pendingSaveLetter := saveLetter;
  GDVars.vaultDirty := 0;
  GDVars.recentlySaved := 1;
  MenuCore.ClearBottomLine
end;

procedure LoadVault(var hasMoney, hasItems: Boolean);
var
  vaultFile: file;
  vaultPath: String;
  diskPrompt: String[40];
  { Unused in this version; see the other implementations of this routine. }
  errorCode: Word;
  itemBuffer: Types.PItem;
  bytesRead: Word;
  { Unused in this version; see the other implementations of this routine. }
  opened: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  vaultFunds: Word;
begin
  hasMoney := False; hasItems := False;
  if GDVars.vaultDirty <> 0 then
    vaultPath := GDVars.configLine1 + 'tmpVault.dat'
  else if GDVars.pendingSaveLetter = 'Z' then
    vaultPath := GDVars.exeDir + 'vault' + GDVars.pendingSaveLetter + '.dat'
  else
    vaultPath := GDVars.configLine1 + 'vault' + GDVars.pendingSaveLetter + '.dat';
  if not DaxIo.FileExists(vaultPath) then Exit;
  opened := DaxIo.OpenWithRetry(vaultPath, diskPrompt, 0, vaultFile);
  BlockRead(vaultFile, GDVars.pooledMoney, SizeOf(GDVars.pooledMoney), bytesRead);
  hasItems := False;
  GetMem(itemBuffer, SizeOf(Types.TItem));
  repeat
    BlockRead(vaultFile, itemBuffer^, SizeOf(Types.TItem), bytesRead);
    if bytesRead = SizeOf(Types.TItem) then begin
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItem));
        GDVars.treasureItems^ := itemBuffer^;
        GDVars.lastVaultItem := GDVars.treasureItems
      end else begin
        GetMem(GDVars.lastVaultItem^.next, SizeOf(Types.TItem));
        GDVars.lastVaultItem := GDVars.lastVaultItem^.next;
        GDVars.lastVaultItem^ := itemBuffer^
      end;
      hasItems := True
    end
  until bytesRead <> SizeOf(Types.TItem);
  Close(vaultFile);
  if GDVars.pendingSaveLetter = 'Z' then DaxIo.DeleteIfPresent(vaultPath);
  FreeMem(itemBuffer, SizeOf(Types.TItem))
end;

procedure WriteVaultFile(path: String);
var
  vaultFile: file;
  requiredBytes: Word;
  { Unused in this version; see the other implementations of this routine. }
  oldTail: Types.PItem;
begin
  requiredBytes := 0;
  Inc(requiredBytes, SizeOf(GDVars.pooledMoney));
  if GDVars.treasureItems <> nil then begin
    GDVars.lastVaultItem := GDVars.treasureItems;
    while GDVars.lastVaultItem <> nil do begin
      Inc(requiredBytes, SizeOf(Types.TItem));
      GDVars.lastVaultItem := GDVars.lastVaultItem^.next
    end
  end;
  DaxIo.DeleteIfPresent(path);
  if requiredBytes > DiskFree(Ord(UpCase(GDVars.configLine1[1])) - Ord('@')) then begin
    TextRend.DisplayAndPause(Yellow, Black, 'Can''t save.  No room on this disk.');
    TextRend.DisplayAndPause(Yellow, Black, 'Please insert another disk.')
  end;
  Assign(vaultFile, path);
  Rewrite(vaultFile, 1);
  BlockWrite(vaultFile, GDVars.pooledMoney, SizeOf(GDVars.pooledMoney));
  GDVars.lastVaultItem := GDVars.treasureItems;
  while GDVars.lastVaultItem <> nil do begin
    BlockWrite(vaultFile, GDVars.lastVaultItem^, SizeOf(Types.TItem));
    oldTail := GDVars.lastVaultItem;
    GDVars.lastVaultItem := GDVars.lastVaultItem^.next
  end;
  Close(vaultFile);
  GDVars.vaultDirty := 1;
  CharHlp.ClearEncounterState
end;
begin end.
