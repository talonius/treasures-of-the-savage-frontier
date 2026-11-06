; ZeroFill clears a caller-supplied byte count, including heap and screen buffers.
; Far Pascal ABI: var dest; count: Word. Clobbers AX, BX, CX, DI, ES and flags.
; No bounds check: ES stays fixed when the 16-bit destination offset wraps.
CODE SEGMENT BYTE PUBLIC 'CODE'
 ASSUME CS:CODE
 PUBLIC ZeroFill

FarPointerBytes EQU 4
CountBytes EQU 2
CountOffset EQU FarPointerBytes
DestOffset EQU CountOffset + CountBytes
ParameterBytes EQU FarPointerBytes + CountBytes

ZeroFill:
 mov bx,sp                         ; Entry stack: far return, byte count, far destination.
 les di,ss:[bx+DestOffset]          ; ES:DI is the caller's untyped var destination.
 mov cx,ss:[bx+CountOffset]         ; Unsigned 16-bit byte count, not a destination extent.
 xor ax,ax                         ; Both the byte and word stores write zero.
 cld                               ; Forward stores; the caller's direction flag is not restored.
 shr cx,1                          ; Remaining word count; carry records an odd byte count.
 jnc ClearWords
 stosb                             ; For an odd count, clear the first byte before the words.
 jcxz Done                         ; A one-byte clear has no words left.
ClearWords:
 rep stosw                         ; A zero input count reaches here with CX=0 and writes nothing.
Done:
 retf ParameterBytes               ; Pop the far return and discard the six argument bytes.
CODE ENDS
END
