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
        dc.l    'WHYK'
        dc.l    0
xbios_hook:
        ; syscall parameters pointer returned in a0
        bsr.w      get_syscall_params

        cmp.w       #OpSettime,(a0)
        beq.s       settime_hook

        cmp.w       #OpGettime,(a0)
        beq.s       gettime_hook

        XBRA_FALLTHROUGH xbios_hook

settime_hook
        move.l      2(a0),d0    ; get settime's parameter

        ; calculate the offset to apply
        move.l      d1,-(sp)            ; don't clobber anything
        move.l      d0,d1               ; preserve d0
        rol.l       #7,d1               ; move the year into low bits
        and.w       #$7F,d1             ; clear all other bits
        cmp.w       #(1999-1980),d1     ; check if year above 1999 is requested
        bhi.s       .y2k                ; yes, jump to offset calculation
        clr.l       (yearOffset)        ; no, offset is zero
        bra.s       .fallthrough        ; continue with xbios
        ; Calculate a good offset to apply, must be multiple of 4 and less
        ; or equal to 20.
        ; We apply a 16 years offset every 16 years from 1980
        ; except between 1996-1999.
.y2k    and.l       #$FFF0,d1           ; floor((year - 1980) / 16) * 16
        ror.l       #7,d1               ; move the offset to its position
        move.l      d1,(yearOffset)     ; store it for gettime()
        sub.l       d1,d0               ; and apply the settime() correction

        ; call settime() with the new parameters
.fallthrough
        move.l      (sp)+,d1            ; restore our clobbered registers
        move.l      d0,-(sp)
	    move.w      #OpSettime,-(sp)
        XBRA_SYSCALL_PREVIOUS_HOOK xbios_hook
        addq.w      #6,sp
        rte

gettime_hook
        ; pretend we're doing a gettime call
	    move.w      #OpGettime,-(sp)
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
yearOffset  dc.l    32<<25

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
        lea         (a5,d7.l),sp    ; set our stack

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
        lea.l   msg_welcome(pc),a0
        Cconws

        ; Query XBIOS vector
        Setexc      #XBIOS_VECTOR,-1

        ; store old vector into our XBRA header
        lea         xbios_hook(pc),a0   ; Our XBRA header
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
; data section
; -----------------------------------------------------------------------------
        data

msg_welcome
        dc.b    'WHYKK v1.0 (c) 2025 Mathias Agopian', 13, 10, 0

msg_already_installed
        dc.b    7, 'Already installed.', 13, 10, 0
