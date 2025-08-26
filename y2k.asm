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
xbios:  move.l      xbios-4,a0
        jmp         (a0)

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
        lea         (a5,d7),sp      ; set our stack

        ; and shrink memory to what we need
        Mshrink     a5,d7

        ; call our main program
        jsr         main

        ; #0: stay resident, #1: return right away
        tst.l       d0
        bne.b       .quit

        ; Terminate and stay resident (Ptermres)
        Ptermres    d7

.quit
        ; Pterm0, quit right away
        Pterm0

; -----------------------------------------------------------------------------
; Main program, install hooks
; -----------------------------------------------------------------------------

main:
        ; Query XBIOS vector
        Setexc      #XBIOS_VEC,-1

        ; store old vector into our XBRA header
        lea         xbios(pc),a0        ; Our XBRA header
        move.l      d0,-4(a0)

        ; See if we're already installed
        move.l	    d0,a0               ; XBIOS vector
.next   cmp.l	    #'XBRA',-12(a0)     ; Check if it is a XBRA marker
        bne.b	    .not_installed      ; no, continue
        cmp.l	    #'Y2KF',-8(a0)      ; Check our XBRA marker
        beq.b	    .quit               ; we found us, stop
	    move.l	    -4(a0),a0           ; Get next vector in the chain
        bra.b	    .next

.not_installed
        ; Print a little success message
        Cconws      .success_msg(pc)

        ; Install our XBRA at the head of the list.
        Setexc      #XBIOS_VEC,xbios(pc)

        ; no error
        clr.l       d0
        rts

.quit
        ; print an error message
        Cconws      .already_installed_msg(pc)

        ; no error, but don't stay resident
        move.l      #1,d0
        rts

.already_installed_msg
        dc.b    7, 'Already installed!', 13, 10, 0

.success_msg
        dc.b    'Success!', 13, 10, 0
