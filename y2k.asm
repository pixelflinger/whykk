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
; XBIOS replacement (TSR)
; -----------------------------------------------------------------------------

        dc.l    'XBRA'
        dc.l    'Y2KF'
        dc.l    0
xbios_hook:
        ; we push the fallthrough address on the stack so that we don't have
        ; to use any registers. Some badly written apps rely on this!
        move.l      (xbios_hook-4)(pc),-(sp)
        rts

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
        ; Install our XBRA at the head of the list.
        Setexc      #XBIOS_VECTOR,xbios_hook(pc)

        ; Print a little success message
        Cconws      .success_msg(pc)

        ; no error, stay resident
        move.w      #1,d0
        rts

.exit
        ; print the already installed message
        Cconws      .already_installed_msg(pc)

        ; no error, but don't stay resident
        clr.w       d0
        rts


.already_installed_msg
        dc.b    7, 'Already installed!', 13, 10, 0

.success_msg
        dc.b    'Success!', 13, 10, 0
