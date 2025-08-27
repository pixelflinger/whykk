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

; fallthrough the previous hook given a XBRA hook
XBRA_FALLTHROUGH macro
    move.l      (\1-4)(pc),-(sp)
    rts
    endm

; generate a syscall stackframe and call the previous hook given a XBRA hook
XBRA_SYSCALL_PREVIOUS_HOOK macro
	    ; this emulates a "trap" stack frame
	    tst.w	    $59e.w
	    beq.s	    .short_stack_frame\@
	    clr.w       -(sp)
.short_stack_frame\@
	    move.l      #.return\@,-(sp)
	    move.w      sr,-(sp)
	    XBRA_FALLTHROUGH \1
.return\@
    ; this is where the syscall's rte will return to
    endm

; -----------------------------------------------------------------------------
; XBIOS replacement (TSR)
; -----------------------------------------------------------------------------

        dc.l    'XBRA'
        dc.l    'Y2KF'
        dc.l    0
xbios_hook:
        ; syscall parameters pointer returned in a0
        bsr.w      get_syscall_params

        cmp.w       #OpSettime,(a0)
        beq.s       settime_hook

        cmp.w       #OpGettime,(a0)
        beq.s       gettime_hook

        lea         xbios_vecs(pc),a0
        XBRA_FALLTHROUGH xbios_hook

settime_hook
        move.l      2(a0),d0    ; get settime's parameter

        ; subtract year offset
        sub.l       (yearOffset),d0

        ; call settime() with the new parameters
        move.l      d0,-(sp)
	    move.w      #OpSettime,-(sp)
        lea         xbios_vecs(pc),a0
        XBRA_SYSCALL_PREVIOUS_HOOK xbios_hook
        addq.w      #6,sp
        rte

gettime_hook
        ; pretend we're doing a gettime call
	    move.w      #OpGettime,-(sp)
        lea         xbios_vecs(pc),a0
        XBRA_SYSCALL_PREVIOUS_HOOK xbios_hook
        addq.w      #2,sp

        ; add back year offset
        add.l       (yearOffset),d0
        rte

get_syscall_params:
	    btst	    #5,4(sp)        ; check if we were called from supervisor
	    bne.s	    .super          ; yes, use sp
        move	    usp,a0          ; no, use usp
        rts
.super  lea	        (6+4)(sp),a0    ; when using sp, we need to offset for
	    tst.w	    $59e.w          ; the parameters
	    beq.s	    .short
	    addq.w	    #2,a0
.short  rts

; this is the data section of our resident program.
; It leaves in the text section!
yearOffset  dc.l    40<<25

; -----------------------------------------------------------------------------
; Init sequence
; -----------------------------------------------------------------------------

init:
	    move.l	    4(sp),a5        ; BASEPAGE
	    move.l	    #$100,d7        ; length of basepage
	    add.l	    12(a5),d7       ; text section size
	    add.l	    20(a5),d7       ; data section size
	    add.l	    28(a5),d7       ; bss section size
	    add.l	    #$401,d7        ; stack size
	    and.l	    #-2,d7          ; make sure we're multiple of 2
        lea         (a5,d7.l),sp      ; set our stack

        ; and shrink memory to what we need
        Mshrink     a5,d7

        ; call our main program
        jsr         main

        ; true: stay resident, false: return right away
        tst.w       d0
        beq.b       .exit

        ; Terminate and stay resident (Ptermres)
        Ptermres0   d7

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
        Cconws      msg_welcome(pc)

        ; Query XBIOS vector
        Setexc      #XBIOS_VECTOR,-1

        ; store old vector into our XBRA header
        lea         xbios_hook(pc),a0   ; Our XBRA header
        move.l      d0,-4(a0)           ; This writes into the TEXT section!

        ; See if we're already installed
        move.l	    d0,a0               ; XBIOS vector
.next   cmp.l	    #'XBRA',-12(a0)     ; Check if it is a XBRA marker
        bne.b	    .install            ; no, continue
        cmp.l	    #'Y2KF',-8(a0)      ; Check our XBRA marker
        beq.b	    .exit               ; we found us, stop
	    move.l	    -4(a0),a0           ; Get next vector in the chain
        bra.s	    .next

.install

        ; TODO: this should be done on TOS2.xx only
        lea.l      xbios_hook(pc),a1
        move.l     -4(a1),a0    ; original xbios hook
        add.l       #4,-4(a1)   ; skip first instruction
        jsr         get_jump_table
        ; make a copy of the vector table
        lea         xbios_vecs(pc),a1
        move.w      (a0)+,d0
        move.w      d0,(a1)+
        sub.w       #1,d0
.copy   move.l      (a0)+,(a1)+
        dbra.w      d0,.copy
        ; skip 2 instructions in Settime
        lea         xbios_vecs(pc),a0
        add.l       #16,(OpSettime*4+2)(a0)

        ; Install our XBRA at the head of the list.
        Setexc      #XBIOS_VECTOR,xbios_hook(pc)

        ; Print a little success message
        Cconws      msg_success(pc)

        ; no error, stay resident
        move.w      #1,d0
        rts

.exit
        ; print the already installed message
        Cconws      msg_already_installed(pc)

        ; no error, but don't stay resident
        clr.w       d0
        rts

; -----------------------------------------------------------------------------
; get_jump_table - returns the address of the bios/xbios vector table
; input: a0 - address of the xbios handler
; output: a0 - address of the xbios vector table
;
; The first instruction of the xbios handle on TOS2.06 is
;    lea.l xbios_vecs(pc),a0
; We decode it to find xbios_vecs.
; -----------------------------------------------------------------------------
get_jump_table:
        move.l      d0,-(sp)
        addq.l      #2,a0           ; Add 2 to get the PC value
        move.w      (a0),d0         ; Read the 16-bit displacement
        ext.l       d0              ; Extend it
        add.l       d0,a0           ; And update A0 with the effective address
        move.l      (sp)+,d0
        rts

; -----------------------------------------------------------------------------
; data section
; -----------------------------------------------------------------------------
        data

msg_welcome
        dc.b    'Y2Kxxx v0.1a (c) 2025 Mathias Agopian | Apache 2.0 License', 13, 10, 0

msg_success
        dc.b    'Installed.', 13, 10, 0

msg_already_installed
        dc.b    7, 'Already installed.', 13, 10, 0

; -----------------------------------------------------------------------------
; bss section
; -----------------------------------------------------------------------------
        bss

xbios_vecs:
        ds.w    1
        ds.l    $80
