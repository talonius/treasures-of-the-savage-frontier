; KERN sound-command interface linked into SoundDrv by {$L SOUNDDRV.OBJ}.
; Probes the interrupt handler signature, polls busy status, and submits a
; command in the caller's data segment. Owns no data storage.
CODE SEGMENT BYTE PUBLIC 'CODE'
 ASSUME CS:CODE, DS:CODE     ; Assembler assumptions do not load runtime DS.
WordBytes EQU 2
FarPointerBytes EQU 2 * WordBytes
CommandOffsetArg EQU WordBytes + FarPointerBytes ; Saved BP followed by the far return address.
KernInterrupt EQU 66h
KernVectorOffset EQU KernInterrupt * FarPointerBytes
KernSendSelector EQU 0688h
KernPollSelector EQU 0689h
KernSignatureDistance EQU 06h                    ; KERN begins six bytes before the handler.
KernSignatureKE EQU 454Bh                        ; Little-endian "KE".
KernSignatureRN EQU 4E52h                        ; Little-endian "RN".
SubmissionReported EQU 1                         ; Send's result is discarded by its Pascal procedure caller.
SignatureFound EQU 1                              ; Boolean AL=True after the signature match.
 PUBLIC DriverDispatch
 PUBLIC DriverBusy
 PUBLIC DriverPresent
DriverDispatch:
 push bp
 mov bp,sp
 push es
 push ds
 push si
 push di
 cld                        ; Leaves DF clear even when AX=0; the caller's DF is not restored.
 or ax,ax                   ; Incoming AX gates submission, not the stack argument.
 jz DriverSendDone          ; AX=0 skips the interrupt and remains zero.
 mov ax,KernSendSelector     ; KERN command-submission selector.
 mov si,[bp+CommandOffsetArg] ; SS frame Word; command DS remains the caller's data segment.
 int KernInterrupt          ; Handler must return with a balanced interrupt frame.
 mov ax,SubmissionReported   ; Reports submission, discarding the handler's AX result.
DriverSendDone:
 pop di
 pop si
 pop ds
 pop es
 pop bp
 retf WordBytes             ; Far return discards the Word argument; Pascal declares a procedure.
DriverBusy:
 push bp
 mov bp,sp
 mov ax,KernPollSelector     ; Busy query; unsaved registers depend on the external handler.
 int KernInterrupt          ; Handler must return with a balanced interrupt frame.
 pop bp
 retf                       ; Return AL unchanged; SoundCommand treats nonzero AL as busy.
DriverPresent:
 push bp
 mov bp,sp
 call DriverReadyProbe      ; Far Pascal Boolean wrapper around the near probe.
 pop bp
 retf
DriverReadyProbe:
 push bp
 mov bp,sp
 push ds
 push si
 mov si,KernVectorOffset     ; IVT far pointer for the KERN interrupt.
 xor ax,ax
 mov ds,ax                  ; Segment zero addresses the real-mode vector table.
 lds si,[si]                ; Read the far handler pointer into DS:SI.
 or si,si                   ; Reject a zero offset even if the segment is nonzero.
 jz DriverNotReady
 sub si,KernSignatureDistance ; Offset arithmetic wraps; nonzero offsets below six are not rejected.
 cmp word ptr [si],KernSignatureKE ; Test "KE" in the installed handler's segment.
 jne DriverNotReady
 cmp word ptr [si+WordBytes],KernSignatureRN ; Test "RN"; the two bytes before the handler are untested.
 jne DriverNotReady
 mov ax,SignatureFound       ; Signature found: AX=1, hence Boolean AL=True.
DriverReadyReturn:
 pop si
 pop ds
 pop bp
 ret
DriverNotReady:
 xor ax,ax                  ; Missing signature or zero offset: Boolean AL=False.
 jmp short DriverReadyReturn
CODE ENDS
END
