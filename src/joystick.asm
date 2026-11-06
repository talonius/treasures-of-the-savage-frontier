; PC game-port timing reader shared by Joystick and Startup; owns no Pascal storage.
; ReadJoystick(joy: Byte; var xRaw, yRaw: Word; var buttons: Byte): Boolean;
; FAR Pascal call: AL returns Boolean; failure can leave partial output writes. BP and DS survive.
; Note: the Y-settle carry branch jumps into xStore, so it overwrites X and shifts AH again.
CODE    SEGMENT BYTE PUBLIC
        ASSUME  CS:CODE
        PUBLIC  ReadJoystick

FirstJoystick   EQU     1              ; Accepted joystick selector, passed in a Word-sized stack slot.
LastJoystick    EQU     2              ; Select the second port axis pair.
Joystick1XMask  EQU     01h            ; Port bit 0; shifting twice selects joystick 2 X, bit 2.
GamePort        EQU     201h           ; Analog axes in bits 0..3; active-low buttons in bits 4..7.
GamePortStrobe  EQU     0FFh           ; Writing the port starts the axis timing interval.
AxisSettleCount EQU     8191           ; Subtract the measured Word count before the busy wait.
ButtonShift     EQU     4              ; Move the inverted button nibble into bits 0..3.
ArgButtons      EQU     06h            ; SS:BP-relative far pointer to the caller's Byte.
ArgYRaw         EQU     0Ah            ; SS:BP-relative far pointer to the caller's Y Word.
ArgXRaw         EQU     0Eh            ; SS:BP-relative far pointer to the caller's X Word.
ArgJoy          EQU     12h            ; Low byte of the joystick selector's Word stack slot.
ArgumentBytes   EQU     ArgJoy+2-ArgButtons ; Contiguous pointer slots plus the Word selector, removed by RETF.

ReadJoystick    PROC FAR
        push    bp
        mov     bp,sp                  ; BP anchors parameters in SS; DS is left untouched.
        cmp     byte ptr [bp+ArgJoy],FirstJoystick
        jz      selectAxisMask
        cmp     byte ptr [bp+ArgJoy],LastJoystick
        jz      selectAxisMask
        mov     al,0                   ; Invalid selector: False, with outputs untouched.
        pop     bp
        ret     ArgumentBytes
selectAxisMask:
        mov     ah,Joystick1XMask      ; AH holds the selected X-axis discharge mask.
        xor     bx,bx                  ; Dead clear: startXSample overwrites BX.
        cmp     byte ptr [bp+ArgJoy],LastJoystick
        jnz     startXSample
        shl     ah,1
        shl     ah,1                   ; Joystick 2 X is bit 2.
startXSample:
        mov     bx,1                   ; BX counts X polls, wrapping as a Word.
        xor     cx,cx                  ; LOOP from zero permits 65,536 unsuccessful polls.
        mov     al,GamePortStrobe
        mov     dx,GamePort            ; DX retains the port for the later reads and strobe.
        out     dx,al                  ; Start the X timing interval.
xLoop:
        in      al,dx
        not     al                     ; A fallen axis bit becomes set for TEST.
        test    al,ah                  ; Test the selected X bit.
        jnz     xDone                  ; The matching poll's count is already in BX.
        inc     bx                     ; Count the unsuccessful poll, with 16-bit wrap.
        loop    xLoop                  ; CX bounds the wait independently of BX.
        mov     al,0                   ; X timeout: False before writing an output.
        pop     bp
        ret     ArgumentBytes
xDone:
        mov     cx,AxisSettleCount
        sub     cx,bx                  ; Unsigned subtraction uses the wrapped sample count.
        jc      xStore                 ; Count above the budget skips this settle wait.
        loop    $                      ; A zero remainder still executes 65,536 iterations.
xStore:
        les     di,[bp+ArgXRaw]        ; Load the caller's X destination from SS:BP into ES:DI.
        mov     es:[di],bx             ; Commit the X Word; later failure leaves it written.
        shl     ah,1                   ; Advance the selected mask; the first pass selects Y.
        xor     cx,cx
selectedBitReadyLoop:
        in      al,dx
        not     al
        test    al,ah                  ; Wait for the selected bit to fall, normally Y.
        jnz     startSelectedSample
        loop    selectedBitReadyLoop
        mov     al,0                   ; Selected-bit timeout: False; X may already be written.
        pop     bp
        ret     ArgumentBytes
startSelectedSample:
        mov     bx,1
        xor     cx,cx
        mov     al,GamePortStrobe      ; Reload the port-write value after IN overwrote AL.
        out     dx,al                  ; Strobe the port again, normally to measure Y.
selectedBitSampleLoop:
        in      al,dx
        not     al
        test    al,ah
        jnz     selectedBitDone
        inc     bx
        loop    selectedBitSampleLoop
        mov     al,0                   ; Sample timeout: False; retain the earlier X write.
        pop     bp
        ret     ArgumentBytes
selectedBitDone:
        mov     cx,AxisSettleCount
        sub     cx,bx
        jc      xStore                 ; Quirk: overwrite X with this count and advance AH again.
        loop    $
        les     di,[bp+ArgYRaw]
        mov     es:[di],bx             ; Commit Y before attempting the final readiness wait.
        shr     ah,1                   ; Return to the preceding input mask, normally X.
        xor     cx,cx
previousBitReadyLoop:
        in      al,dx                  ; This read supplies both readiness and the button nibble.
        not     al                     ; Fallen axes and pressed buttons become set bits.
        test    al,ah                  ; Wait for the preceding input bit to fall after the latest strobe.
        jnz     storeButtons
        loop    previousBitReadyLoop
        mov     al,0                   ; Final timeout: False; X/Y remain written, buttons untouched.
        pop     bp
        ret     ArgumentBytes
storeButtons:
        mov     cx,ButtonShift
        shr     al,cl                  ; Pack pressed buttons for both joysticks into the low nibble.
        les     di,[bp+ArgButtons]
        mov     es:[di],al             ; Bits 0/1 are joystick 1 buttons; bits 2/3 are joystick 2.
        mov     al,1
        pop     bp
        ret     ArgumentBytes
ReadJoystick    ENDP
CODE    ENDS
        END
