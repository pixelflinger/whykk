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

 	    text

	    jmp     init

        dc.l    'XBRA'
        dc.l    'Y2KF'
        dc.l    0
xbios:  move.l      xbios-4,a0
        jmp         (a0)


init:
	    move.l	    4(sp),a5        ; BASEPAGE
	    move.l	    #$100,d7        ; length of basepage
	    add.l	    12(a5),d7       ; text section size
	    add.l	    20(a5),d7       ; data section size
	    add.l	    28(a5),d7       ; bss section size
	    add.l	    #$401,d7        ; stack size
	    and.l	    #-2,d7          ; make sure we're multiple of 2

	    ; save the size we need for later use
	    move.l	    d7,size

        ; set our stack
        lea         (a5,d7),sp

        ; and shrink memory to what we need
	    move.l	    d7,-(sp)        ; new size
	    move.l	    a5,-(sp)        ; start address
	    clr.w	    -(sp)
	    move.w	    #$4a,-(sp)      ; Mshrink
	    trap	    #1              ; GEMDOS
	    lea	        12(sp),sp

        ; Query XBIOS vector
        move.l      #-1,-(sp)       ; Query
        move.w      #46,-(sp)       ; XBIOS vector
        move.w      #5,-(sp)        ; Setexc
        trap        #13             ; BIOS
        addq.l      #8,sp

        ; store old vector into our XBRA header
        lea         xbios(pc),a0        ; Our XBRA header
        move.l      d0,-4(a0)

        ; See if we're already installed
        move.l	    d0,a0               ; XBIOS vector
.next	cmp.l	    #'XBRA',-12(a0)     ; Check if it is a XBRA marker
        bne.b	    .not_installed      ; no, continue
        cmp.l	    #'Y2KF',-8(a0)      ; Check our XBRA marker
        beq.b	    .quit               ; we found us, stop
	    move.l	    -4(a0),a0           ; Check next vector in the chain
        bra.b	    .next

.not_installed
        ; Print a little success message
        pea         success_msg(pc)
        move.w      #$9,-(sp)
        trap        #1
        addq.l      #6,sp

        ; Install our XBRA at the head of the list.
        pea         xbios(pc)           ; Our XBIOS vector
        move.w      #46,-(sp)           ; XBIOS vector
        move.w      #5,-(sp)            ; Setexc
        trap        #13                 ; BIOS
        addq.l      #8,sp

        ; Terminate and stay resident (Ptermres)
        clr.w	    -(sp)
        move.l	    size,-(sp)
        move.w	    #$31,-(sp)
        trap	    #1

.quit
        ; print an error message
        pea         already_installed_msg(pc)
        move.w      #$9,-(sp)
        trap        #1
        addq.l      #6,sp

        ; Pterm0, quit right away
        clr.w	    -(sp)
        trap	    #1
        addq.l      #2,sp

size    dc.l 0

already_installed_msg
        dc.b    7, 'Already installed!', 13, 10, 0
success_msg
        dc.b    'Success!', 13, 10, 0
