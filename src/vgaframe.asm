CODE    SEGMENT BYTE PUBLIC             ; VGA frame delta XOR and encoded-stream expansion.
        ASSUME  CS:CODE
        PUBLIC  XorFrame, ExpandRleFrame

FarPointerBytes EQU     4
WordBytes       EQU     2
FirstArg        EQU     06h             ; Saved BP and FAR return precede Pascal's last argument.

XorCountArg     EQU     FirstArg
XorKeyArg       EQU     XorCountArg+WordBytes
XorDstArg       EQU     XorKeyArg+FarPointerBytes
XorSrcArg       EQU     XorDstArg+FarPointerBytes
XorArgsBytes    EQU     XorSrcArg+FarPointerBytes-FirstArg

RleEncodedArg   EQU     FirstArg
RleDstArg       EQU     RleEncodedArg+WordBytes
RleSrcArg       EQU     RleDstArg+FarPointerBytes
RleArgsBytes    EQU     RleSrcArg+FarPointerBytes-FirstArg
RleLiteralMax   EQU     7Fh             ; Controls 00h..7Fh precede control+1 literal bytes.
RleCountBase    EQU     256             ; Repeat base before subtracting the control and adding one.

XorFrame PROC FAR                      ; (src, dst, key: Pointer; count: Word); dst may equal src or key.
        push    bp
        mov     bp,sp
        cld                            ; Both leaves return with DF clear; BP and caller DS survive.
        mov     dx,ds                  ; DX holds caller DS while the key and destination change DS.
        les     si,[bp+XorSrcArg]       ; ES:SI keeps src fixed across the per-byte DS reloads.
        mov     cx,[bp+XorCountArg]     ; A zero count processes 65536 bytes through LOOP's decrement.
        mov     bx,0                   ; BX indexes the three buffers; offset sums wrap within each segment.
        mov     ax,0
XorByte:
        mov     al,es:[bx+si]           ; Read src before writing dst; shifted overlap can alter later input.
        lds     di,[bp+XorKeyArg]       ; DS:DI = key for this byte.
        xor     al,[bx+di]
        lds     di,[bp+XorDstArg]       ; DS:DI = dst for this byte.
        mov     [bx+di],al
        inc     bx
        loop    XorByte
        mov     ds,dx
        pop     bp
        ret     XorArgsBytes           ; FAR return removes the pointer and count arguments.
XorFrame ENDP

ExpandRleFrame PROC FAR                 ; (src, dst: Pointer; encodedBytes: Word); no decoded-size limit.
        push    bp
        mov     bp,sp
        cld                            ; String operations advance offsets without normalizing segments.
        mov     dx,ds
        lds     si,[bp+RleSrcArg]       ; DS:SI = encoded stream.
        les     di,[bp+RleDstArg]       ; ES:DI = expanded pixels; overlapping src can change later reads.
        mov     bx,0                   ; BX accounts for encoded bytes, independently of the wrapping SI.
        mov     ax,0                   ; AH stays zero while AL holds controls or repeated pixels.
NextPacket:
        cmp     bx,[bp+RleEncodedArg]   ; Zero length emits nothing; a complete run may cross this limit.
        jae     ExpandDone
        cmp     byte ptr [si],RleLiteralMax
        ja      RepeatRun
        mov     al,[si]
        add     bx,ax
        inc     bx
        inc     bx                     ; Account for one control plus control+1 literal bytes, modulo 65536.
        mov     cx,ax
        inc     cx                     ; Literal output count = control+1.
        inc     si
        rep     movsb                  ; Forward DS:SI -> ES:DI; input and output offsets may wrap.
        jmp     NextPacket
RepeatRun:
        inc     bx
        inc     bx                     ; A repeat consumes one control and one pixel byte.
        mov     cx,RleCountBase
        mov     al,[si]
        sub     cx,ax
        inc     cx                     ; Repeat output count = 257-control, including 129 for 80h.
        inc     si
        lodsb                          ; Read the repeated pixel once from DS:SI.
        rep     stosb                  ; Emit it to ES:DI; encoded accounting can wrap before termination.
        jmp     NextPacket
ExpandDone:
        mov     ds,dx                  ; ES, AX, BX, CX, DX, SI, DI and arithmetic flags are not preserved.
        pop     bp
        ret     RleArgsBytes
ExpandRleFrame ENDP
CODE    ENDS
        END
