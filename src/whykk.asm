;
;  Copyright (C) 2025 Mathias Agopian
;
;  Licensed under the Apache License, Version 2.0 (the "License");
;  you may not use this file except in compliance with the License.
;  You may obtain a copy of the License at
;
;       http://www.apache.org/licenses/LICENSE-2.0
;
;  Unless required by applicable law or agreed to in writing, software
;  distributed under the License is distributed on an "AS IS" BASIS,
;  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
;  See the License for the specific language governing permissions and
;  limitations under the License.
;

        include 'tos.i'

 	    text

	    jmp     init

; -----------------------------------------------------------------------------
; Macros for dealing with syscalls and XBRA
; -----------------------------------------------------------------------------

; generate a syscall stackframe
RTE_STACKFRAME macro
	    ; this emulates a "trap" stack frame
	    tst.w	    $59e.w
	    beq.s	    .short_stack_frame\@
	    clr.w       -(sp)
.short_stack_frame\@
	    move.l      \1,-(sp)
	    move.w      sr,-(sp)
        endm


; fallthrough the previous hook given a XBRA hook
XBRA_FALLTHROUGH macro
        move.l      (\1-4)(pc),-(sp)
        rts
        endm

XBRA_SYSCALL_FALLTHROUGH macro
        RTE_STACKFRAME #.return\@
	    XBRA_FALLTHROUGH \1
.return\@
        ; this is where the syscall's rte will return to
        endm

; -----------------------------------------------------------------------------
; XBIOS replacement (TSR)
; -----------------------------------------------------------------------------

        dc.l    'XBRA'
        dc.l    'WHYK'
        dc.l    0
xbios_hook:
        ; syscall parameters pointer returned in a0
	    btst	    #5,(sp)             ; check if we were called from supervisor
	    bne.s	    .get_params_super   ; yes, use sp
        ; User mode path
        move.l	    usp,a0              ; no, use usp
        bra.s       .got_params         ; continue to opcode check
.get_params_super:
        ; Supervisor mode path
        lea	        6(sp),a0            ; when using sp, we need to offset for the parameters
	    tst.w	    $59e.w              ; check for long/short stack frame
	    beq.s	    .got_params         ; branch if short
	    addq.w	    #2,a0               ; adjust for long stack frame (68010+)
.got_params:

        move.w      (a0),d0             ; Get opcode
        subi.w      #OpSettime,d0       ; Check for Settime (22) or Gettime (23)
        cmpi.w      #1,d0               ; Is the result 0 (Settime) or 1 (Gettime)?
        bls.s       .handle_hook        ; If lower or same, it's one of ours.

        ; Fallthrough for all other opcodes (most common path)
        XBRA_FALLTHROUGH xbios_hook

.handle_hook:
        ; At this point, d0 is either 0 or 1. The Z flag from the 'cmpi.w'
        ; is set if d0 was 1 (Gettime).
        beq.s       gettime_hook        ; If Z is set, it was Gettime.
        ; Fallthrough to settime_hook if Z is not set (d0 was 0).
settime_hook
        move.l      2(a0),d0            ; get settime's parameter

        ; calculate the offset to apply
        lea.l       yearOffset(pc),a0   ; our offset address
        move.l      d1,-(sp)            ; don't clobber anything
        move.l      d0,d1               ; preserve d0
        rol.l       #7,d1               ; move the year into low bits
        and.w       #$7F,d1             ; clear all other bits
        cmp.w       #(1999-1980),d1     ; check if year above 1999 is requested
        bhi.s       .y2k                ; yes, jump to offset calculation
        clr.l       (a0)                ; no, offset is zero
        bra.s       .fallthrough        ; continue with xbios
        ; Calculate a good offset to apply, must be multiple of 4 and less
        ; or equal to 20.
        ; We apply a 16 years offset every 16 years from 1980
        ; except between 1996-1999.
.y2k    and.l       #$0000FFF0,d1       ; floor((year - 1980) / 16) * 16
        ror.l       #7,d1               ; move the offset to its position
        move.l      d1,(a0)             ; store it for gettime()
        sub.l       d1,d0               ; and apply the settime() correction

        ; call settime() with the new parameters
.fallthrough
        move.l      (sp)+,d1            ; restore our clobbered registers
        ; call to the original settime
        movem.l     d3-d7/a3-a6,-(sp)       ; save all registers
        move.l      d0,-(sp)                ; write parameter on the stack
        suba.l      a5,a5                   ; TOS does this, so do we
        move.l      xbios_settime(pc),a0    ; Load original XBIOS settime addr
        jsr         (a0)                    ; call it
        addq.w      #4,sp                   ; correct stack
        movem.l     (sp)+,d3-d7/a3-a6       ; and restore registers
        rte

gettime_hook
        ; pretend we're doing a gettime call
	    move.w      #OpGettime,-(sp)
        XBRA_SYSCALL_FALLTHROUGH xbios_hook
        addq.w      #2,sp

        ; add back year offset
        add.l       yearOffset(pc),d0
        rte

; original XBIOS' settime hook
xbios_settime
            dc.l    0

; this is the data section of our resident program.
; It leaves in the text section!
yearOffset  dc.l    32<<25

; end of TSR
TSR_end
; *****************************************************************************
; End of TSR section
; *****************************************************************************


; -----------------------------------------------------------------------------
; Init sequence
; -----------------------------------------------------------------------------
init:
        ; call our main program
        bsr.s       main

        ; true: stay resident, false: return right away
        tst.w       d0
        beq.b       .exit

        ; Terminate and stay resident (Ptermres)
        lea.l       TSR_end(pc),a0   ; calculate how much memory we need to
	    suba.l      4(sp),a0         ; keep as (TSR_end - _basepage)
	    move.l      a0,d0
        Ptermres0   d0

.exit
        ; Pterm0, exit right away
        Pterm0

; -----------------------------------------------------------------------------
; Main program, install hooks
; -----------------------------------------------------------------------------

main:
        ; Per standard calling convention d2-d7/a2-a6 must be preserved
        ; or not used.

        ; Print welcome message
        lea.l   msg_welcome(pc),a0
        Cconws

        ; Query XBIOS vector
        Setexc      #XBIOS_VECTOR,-1

        ; store old vector into our XBRA header
        lea.l       xbios_hook(pc),a0   ; Our XBRA header
        move.l      d0,-4(a0)           ; This writes into the TEXT section!

        ; See if we're already installed
        move.l	    d0,a0               ; XBIOS vector
.next   cmp.l	    #'XBRA',-12(a0)     ; Check if it is a XBRA marker
        bne.b	    .install            ; no, continue
        cmp.l	    #'WHYK',-8(a0)      ; Check our XBRA marker
        beq.b	    .exit               ; we found us, stop
	    move.l	    -4(a0),a0           ; Get next vector in the chain
        bra.s	    .next

.install
        ; Get XBIOS' jumptable:
        ; Calling an unsupported XBIOS or BIOS call returns the function
        ; code in D0. Additionally the jumptable is also returned
        ; in A0. This is not an official behavior but works on all TOS versions.
        move.w      #$7FFF,-(sp)
        trap        #14
        addq.w      #2,sp

        ; TODO: we could use some heuristics to make sure we got the ROM's
        ;       `settime` and fail installation if we did not.

        ; retrieve the original settime hook
        move.l      (4*OpSettime)(a0),a2

        ; on TOS 2.xx and above skip the first two instructions of settime
        bsr.s       get_tos_version
        cmp.w       #$0200,d0
        bls.s       .store_settime_hook
        lea.l       16(a2),a2
.store_settime_hook
        ; store the effective settime hook
        lea.l       xbios_settime(pc),a0
        move.l      a2,(a0)

        ; Install our XBRA at the head of the list.
        Setexc      #XBIOS_VECTOR,xbios_hook(pc)

        ; no error, stay resident
        move.w      #1,d0
        rts

.exit
        ; print the already installed message
        lea.l   msg_already_installed(pc),a0
        Cconws

        ; no error, but don't stay resident
        clr.w       d0
        rts

; -----------------------------------------------------------------------------
; get_tos_version - returns the TOS version in d0
; -----------------------------------------------------------------------------
get_tos_version:
        Supexc  .tos(pc)
        rts
.tos    move.l  _sysbase,a0
        move.w  2(a0),d0
        rts

; -----------------------------------------------------------------------------
; data section
; -----------------------------------------------------------------------------
        even
        data

msg_welcome
        dc.b    'WHYKK v0.3.0 (c) 2025 Mathias Agopian', 13, 10, 0

msg_already_installed
        dc.b    7, 'Already installed.', 13, 10, 0
