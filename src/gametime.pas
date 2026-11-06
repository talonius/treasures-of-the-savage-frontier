{ GameTime -- resting and the game clock. AdvanceTime advances the clock and times out the party's spell effects;
  CampRest runs the rest menu and the rest itself: healing, finishing memorized and scribed spells, and rolling for an
  interruption. }
{$O+,F+,S+,R-,V-,B-,I-,A+}
unit GameTime;

interface

uses Types, Crt, GDConsts, GDVars, C_Keys, C_Ifc, C_Spell, Border, TextRend, GameIo, Magic, FxEngine, CharHlp,
  MenuCore;

{ Advances the game clock one unit at a time, carrying each component into the next, then ages the party's timed effects
  by the same span.
  @param(amount Number of units.)
  @param(tUnit Clock component counted: 1 minutes, 2 tens of minutes, 3 hours, 4 days, 5 months, 6 years.) }
procedure AdvanceTime(amount: Byte; tUnit: ShortInt);

{ Rests the party for the rest time. Interactive, it first runs the rest menu, redraws the rest time now and then and
  asks whether to stop when a key is pressed. Each five-minute step advances the clock, heals the party once a day,
  carries spell memorizing and scribing forward, and, once per rest period of the zone, rolls the zone's interruption
  chance. Silent rest skips the menu, the redraws and the key check.
  @param(interactive True to show the menu and the rest time.)
  @returns(True when a wandering encounter interrupted the rest.) }
function CampRest(interactive: Boolean): Boolean;

implementation

{ Convert (count, tUnit) to the clock's smallest unit, then age the effect lists of flagged party members in steps of at
  most 10, removing expired effects with FxEngine.RemoveEffect under no trigger condition; a member stays flagged while
  any timed effect remains. While camping only flagged members are aged and the call returns at once if none is flagged;
  otherwise every flag is forced on first.
  @param(count The number of units.)
  @param(tUnit The clock component counted.) }
procedure TimeOutEffects(count: Byte; tUnit: ShortInt);
var
  u: ShortInt;
  i: Byte;
  step: Byte;
  total: Word;
  cur: Types.PCharacter;
  e: Types.PEffect;
  nxt: Types.PEffect;
begin
  if GDVars.locState.current <> C_Ifc.CAMPING then
    FillChar(GDVars.effectFlags, SizeOf(GDVars.effectFlags), 1)
  else begin
    i := 0;
    repeat
      Inc(i);
    until (i > GDVars.gameState^.partySize) or (GDVars.effectFlags[i] <> 0);
    if GDVars.effectFlags[i] = 0 then Exit;
  end;
  total := count;
  u := tUnit;
  while u > 1 do begin
    total := GDConsts.clockScales[Pred(u)] * total;
    u := Pred(u);
  end;
  while total > 0 do begin
    if total > 10 then step := 10 else step := total;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if GDVars.effectFlags[i] <> 0 then begin
        GDVars.effectFlags[i] := 0;
        e := Types.PCharacter(cur)^.effects;
        while e <> nil do
          if e^.duration = 0 then
            e := e^.next
          else if step < e^.duration then begin
            Dec(e^.duration, step);
            GDVars.effectFlags[i] := 1;
            e := e^.next;
          end else begin
            GDConsts.currentCondition := 255;
            nxt := e^.next;
            FxEngine.RemoveEffect(cur, e^.id, e);
            e := nxt;
          end;
        while e <> nil do begin
          if e^.duration > 0 then GDVars.effectFlags[i] := 1;
          e := e^.next;
        end;
      end;
      Inc(i);
      cur := cur^.next;
    end;
    if total > 10 then Dec(total, 10) else total := 0;
  end;
end;

{ Carries each clock component that has reached its limit into the next one. A year rollover ages every party member by
  one year and notes that aging happened.
  @param(clock The clock to normalize.) }
procedure ValidateClock(var clock: Types.TClock);
var
  i: ShortInt;
  cur: Types.PCharacter;
begin
  for i := 0 to 6 do
    if clock[i] >= GDConsts.clockScales[i] then
      if i <> 6 then begin
        Inc(clock[Succ(i)]);
        clock[i] := clock[i] - GDConsts.clockScales[i];
      end else begin
        cur := GDVars.partyHead;
        while cur <> nil do begin
          Inc(Types.PCharacter(cur)^.age);
          cur := cur^.next;
        end;
        clock[6] := clock[6] - GDConsts.clockScales[6];
        GDVars.agingFlag := 1;
      end;
end;

{ Normalizes the rest time, folds its months into days and caps it at 99 days. }
procedure ValidateRestTime;
begin
  GameTime.ValidateClock(GDVars.restClock);
  if GDVars.restClock[5] > 0 then begin
    Inc(GDVars.restClock[4], GDConsts.clockScales[4] * GDVars.restClock[5]);
    GDVars.restClock[5] := 0;
    if GDVars.restClock[4] > 99 then GDVars.restClock[4] := 99;
  end;
end;

procedure AdvanceTime(amount: Byte; tUnit: ShortInt);
var
  clock: Types.TClock;
  i: ShortInt;
  j: Byte;
begin
  for i := 0 to 6 do
    clock[i] := GDVars.gameState^.gbvm[i + 5];
  for j := 1 to amount do begin
    Inc(clock[tUnit]);
    GameTime.ValidateClock(clock);
  end;
  for i := 0 to 6 do
    GDVars.gameState^.gbvm[i + 5] := clock[i];
  GameTime.TimeOutEffects(amount, tUnit);
end;

{ Takes a span off the rest time, borrowing from the larger components as needed; when there is nothing left to borrow,
  the rest time is cleared. Nothing happens when no days, hours or minutes are left.
  @param(count Number of units.)
  @param(tUnit Clock component counted.) }
procedure DecrementRestTime(count: Byte; tUnit: ShortInt);
var
  j: ShortInt;
  k: ShortInt;
begin
  if (GDVars.restClock[4] <> 0) or (GDVars.restClock[3] <> 0) or (GDVars.restClock[2] <> 0) or
      (GDVars.restClock[1] <> 0) then begin
    while count > GDVars.restClock[tUnit] do begin
      j := Succ(tUnit);
      while (GDVars.restClock[j] = 0) and (j < 5) do
        j := Succ(j);
      if j = 5 then begin
        GameIo.ZeroFill(GDVars.restClock, SizeOf(GDVars.restClock));
        count := 0;
      end else
        for k := j downto Succ(tUnit) do begin
          Dec(GDVars.restClock[k]);
          Inc(GDVars.restClock[Pred(k)], GDConsts.clockScales[Pred(k)]);
        end;
    end;
    Dec(GDVars.restClock[tUnit], count);
    GameTime.ValidateRestTime;
  end;
end;

{ Formats a number with at least two digits, keeping the first two.
  @param(v The number.)
  @returns(The digits, with a leading zero below 10.) }
function TwoDigitStr(v: Byte): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := TextRend.ByteToString(v);
  if v < 10 then s := '0' + s;
  TwoDigitStr := Copy(s, 1, 2);
end;

{ Shows the rest time as days, hours and minutes on the message line, the selected field in white.
  @param(hl Clock component shown in white: 2 minutes, 3 hours, 4 days; 0 for none.) }
procedure DisplayRestTime(hl: ShortInt);
var
  i: ShortInt;
  colors: array[0..6] of Word;
  x: Byte;
begin
  for i := 0 to 6 do
    colors[i] := 10;
  colors[hl] := 15;
  TextRend.DisplayString(1, 17, LightGreen, Black, 'Rest Time:');
  x := 11;
  for i := 4 downto 3 do begin
    TextRend.DisplayStringClear(x + 1, 17, colors[i], Black, GameTime.TwoDigitStr(GDVars.restClock[i]));
    TextRend.DisplayStringClear(x + 1 + 2, 17, LightGreen, Black, ':');
    Inc(x, 3);
  end;
  TextRend.DisplayStringClear(x + 1, 17, colors[2], Black,
                              GameTime.TwoDigitStr(10 * GDVars.restClock[2] + GDVars.restClock[1]));
end;

{ The rest-time menu: Days, Hours or Mins picks the field, and picking the field already chosen adds one to it (five for
  minutes); Add and Subtract change it too. Up arrow is Add, down arrow is Subtract, left and right are ignored and any
  other extended key exits.
  @returns(True when the player chooses Rest.) }
function CampRestMenu: Boolean;
var
  choice: Byte;
  ch: Char;
  sel: ShortInt;
begin
  GDVars.horizChoice := 1;
  CampRestMenu := False;
  sel := 2;
  repeat
    GameTime.DisplayRestTime(sel);
    MenuCore.ResetMenuSlots(6);
    choice := Ord(MenuCore.MenuHorizontal(GDConsts.emptyQuery, GDConsts.restMenu, Byte(True), Byte(False)));
    if GDVars.menuReturnedKey then begin
      ch := Char(choice);
      case ch of
        C_Keys.UP: choice := 4;
        C_Keys.DOWN: choice := 5;
        C_Keys.RIGHT, C_Keys.LEFT: choice := $FF;
      else
        choice := 6;
      end;
    end;
    case choice of
      0: CampRestMenu := True;
      1: if sel <> 4 then
           sel := 4
         else begin
           Inc(GDVars.restClock[sel]);
           GameTime.ValidateRestTime;
         end;
      2: if sel <> 3 then
           sel := 3
         else begin
           Inc(GDVars.restClock[sel]);
           GameTime.ValidateRestTime;
         end;
      3: if sel <> 2 then
           sel := 2
         else begin
           Inc(GDVars.restClock[1], 5);
           GameTime.ValidateRestTime;
         end;
      4: begin
             if sel = 2 then
               Inc(GDVars.restClock[1], 5)
             else
               Inc(GDVars.restClock[sel]);
             GameTime.ValidateRestTime;
           end;
      5: begin
             if sel = 2 then
               GameTime.DecrementRestTime(5, 1)
             else
               GameTime.DecrementRestTime(1, sel);
             GameTime.ValidateRestTime;
           end;
    end;
  until (choice = 6) or (choice = 0);
end;

{ Counts one five-minute rest step; once a day of steps has passed, restores a hit point to each party member, shows
  "The Whole Party Is Healed" and pauses, redrawing the party when anyone was healed.
  @param(interactive True to redraw the rest time first.) }
procedure CheckRestingHeal(interactive: Boolean);
var
  healed: Boolean;
  cur: Types.PCharacter;
begin
  Inc(GDVars.healTicks);
  if GDVars.healTicks >= 288 then begin
    healed := False;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if FxEngine.RestoreHitPoints(cur, 1, False) then healed := True;
      cur := cur^.next;
    end;
    if interactive then GameTime.DisplayRestTime(0);
    TextRend.DisplayString(1, 19, LightGreen, Black, 'The Whole Party Is Healed');
    if healed then CharHlp.DisplayParty(GDVars.curChar);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
    GDVars.healTicks := 0;
  end;
end;

{ Finishes the first spell a character is still memorizing, or finds the level of the next one. Nothing happens while
  Fix is running.
  @param(cr The character; one out of play has nothing pending.)
  @param(done False to finish the first pending spell, announce it and set the flag; True to look up the next one.)
  @returns(The level of the next pending spell when the flag was True; 0 otherwise or when nothing is pending.) }
function CheckMemorizeDone(cr: Types.PCharacter; var done: Boolean): Byte;
var
  lvl: Byte;
  i: Byte;
begin
  if GDVars.fixBusy <> 0 then begin
    CheckMemorizeDone := 0;
    Exit;
  end;
  lvl := 0;
  i := 0;
  if cr^.inPlay <> 0 then
    while (i <= 140) and (lvl = 0) do begin
      if cr^.memorized[i] > C_Spell.ID_MASK then
        if done then
          lvl := GDConsts.spellTable[cr^.memorized[i] and C_Spell.ID_MASK].spellLevel
        else begin
          Dec(cr^.memorized[i], C_Spell.PENDING_FLAG);
          GameTime.DisplayRestTime(0);
          Magic.PrintCastSpellMsg(cr, 'has memorized', cr^.memorized[i]);
          done := True;
        end;
      Inc(i);
    end;
  CheckMemorizeDone := lvl;
end;

{ Does for scribing what CheckMemorizeDone does for memorizing: scribes the first pending spell from a character's
  readable scrolls into the spell book, or finds the level of the next one. Note: while Fix is running it returns at
  once with the result unset.
  @param(cr The character.)
  @param(done False to scribe the first pending spell, announce it and set the flag; True to look up the next one.)
  @returns(The level of the next pending spell when the flag was True; 0 otherwise or when nothing is pending.) }
function CheckScribeDone(cr: Types.PCharacter; var done: Boolean): Byte;
var
  j: Byte;
  sp: Byte;
  lvl: Byte;
  it: Types.PItem;
  { Unused in this version; see the other implementations of this routine. }
  found: Boolean;
begin
  if GDVars.fixBusy <> 0 then begin
    { Note: this exit skips the result store, so the result is left unset. }
    Exit;
  end;
  lvl := 0;
  found := False;
  it := cr^.items;
  while (it <> nil) and (lvl = 0) do begin
    j := 1;
    if Magic.ItemReadable(it) then
      while (j <= 3) and (lvl = 0) do begin
        if it^.spells[j] > C_Spell.PENDING_FLAG then begin
          found := True;
          if done then
            lvl := GDConsts.spellTable[it^.spells[j] and C_Spell.ID_MASK].spellLevel
          else begin
            sp := it^.spells[j] and C_Spell.ID_MASK;
            cr^.knownSpells[sp] := 1;
            Magic.RemoveSpellFromScroll(cr, it, sp);
            GameTime.DisplayRestTime(0);
            Magic.PrintCastSpellMsg(cr, 'has scribed', sp);
            done := True;
          end;
        end;
        Inc(j);
      end;
    it := it^.next;
  end;
  CheckScribeDone := lvl;
end;

{ Counts down each party member's spell-preparation timer; when it runs out and the member's preparation wait is over,
  the next spell being scribed or else memorized is finished and the timer restarts at three times the following spell's
  level. }
procedure AdvanceSpellPrep;
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharacter;
  done: Boolean;
begin
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    if GDVars.prepTimer[i] > 0 then Dec(GDVars.prepTimer[i]);
    if (GDVars.prepTimer[i] = 0) and (Types.PCharacter(cur)^.spellPrep = 0) then begin
      done := False;
      lvl := GameTime.CheckScribeDone(cur, done);
      if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
      GDVars.prepTimer[i] := lvl * 3;
    end;
    cur := cur^.next;
    Inc(i);
  end;
end;

{ Counts rest steps; every twelfth step, each party member's preparation wait drops by one, and when it reaches zero the
  member's spell-preparation timer starts at three times the level of the next spell to scribe or memorize.
  @param(tick The step counter, kept by the caller.) }
procedure AdvanceSpellPrepBase(var tick: Byte);
var
  i: Byte;
  lvl: Byte;
  cur: Types.PCharacter;
  done: Boolean;
begin
  Inc(tick);
  if tick >= 12 then begin
    tick := 0;
    i := 1;
    cur := GDVars.partyHead;
    while cur <> nil do begin
      if Types.PCharacter(cur)^.spellPrep > 0 then begin
        Dec(Types.PCharacter(cur)^.spellPrep);
        if Types.PCharacter(cur)^.spellPrep = 0 then begin
          done := True;
          lvl := GameTime.CheckScribeDone(cur, done);
          if lvl = 0 then lvl := GameTime.CheckMemorizeDone(cur, done);
          GDVars.prepTimer[i] := lvl * 3;
        end;
      end;
      cur := cur^.next;
      Inc(i);
    end;
  end;
end;

function CampRest(interactive: Boolean): Boolean;
var
  cur: Types.PCharacter;
  { Unused in this version; see the other implementations of this routine. }
  member: Pointer;
  { Unused in this version; see the other implementations of this routine. }
  memberCount: Byte;
  i: Byte;
  tick: Byte;
  cnt: Byte;
  stop: Boolean;
  { Unused in this version; see the other implementations of this routine. }
  interrupted: Boolean;
begin
  CampRest := False;
  interrupted := False;
  i := 1;
  cur := GDVars.partyHead;
  while cur <> nil do begin
    GDVars.prepTimer[i] := 0;
    Inc(i);
    cur := cur^.next;
  end;
  FillChar(GDVars.effectFlags, SizeOf(GDVars.effectFlags), 1);
  tick := 0;
  cnt := 0;
  if interactive then begin
    Border.EraseBox(1, 17, 38, 22);
    GameTime.DisplayRestTime(0);
  end;
  GDVars.noBorder := 1;
  if interactive then
    stop := not GameTime.CampRestMenu
  else
    stop := False;
  while (not stop) and
      ((GDVars.restClock[4] > 0) or (GDVars.restClock[3] > 0) or (GDVars.restClock[2] > 0) or
       (GDVars.restClock[1] > 0)) do begin
    if interactive and GameIo.InputPending then begin
      GameTime.DisplayRestTime(0);
      if MenuCore.YesNoMenu('Stop Resting? ', GDConsts.yesChoice) = GDConsts.yesChoice then
        stop := True
      else
        TextRend.ClearStatusLine;
    end;
    if not stop then begin
      GameTime.DecrementRestTime(5, 1);
      Inc(cnt);
      if interactive and (cnt >= 5) then begin
        GameTime.DisplayRestTime(0);
        cnt := 0;
      end;
      GameTime.AdvanceTime(5, 1);
      GameTime.CheckRestingHeal(interactive);
      GameTime.AdvanceSpellPrep;
      GameTime.AdvanceSpellPrepBase(tick);
      if GDVars.gameState^.restPeriod > 0 then begin
        Inc(GDVars.restTicks);
        if GDVars.restTicks >= GDVars.gameState^.restPeriod then begin
          GDVars.restTicks := 0;
          if FxEngine.RollDice(1, 100) <= GDVars.gameState^.interruptPct then begin
            CharHlp.ClearMessageWindow;
            GameTime.DisplayRestTime(0);
            TextRend.DisplayString(1, 19, White, Black, 'Your repose is suddenly interrupted!');
            stop := True;
            CampRest := True;
            TextRend.PauseOnly;
          end;
        end;
      end;
    end;
  end;
  Border.EraseBox(1, 17, 38, 22);
  GDVars.noBorder := 0;
end;

begin
end.
