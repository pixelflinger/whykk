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

; -----------------------------------------------------------------------------
; XBIOS replacement (TSR)
; -----------------------------------------------------------------------------

        dc.l    'XBRA'
        dc.l    'TKPR'
        dc.l    0
xbios_hook:
        lea         xbios_vecs(pc),a0
        XBRA_FALLTHROUGH xbios_hook

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
        movem.l     a2-a3,-(sp)

        ; Print welcome message
        lea.l      msg_welcome(pc),a0
        Cconws

        ; check TOS version
        jsr         get_tos_version(pc)
        cmp.w       #$0200,d0
        bls.w       .skip_installation

        ; Query XBIOS vector
        Setexc      #XBIOS_VECTOR,-1
        move.l      d0,a1               ; a1 = head of chain

        ; Find tail of XBRA chain, and check if we're already installed
        move.l      #0,a0               ; a0 = previous hook
.next   cmp.l	    #'XBRA',-12(a1)     ; is current an XBRA hook?
        bne.s       .found_tail         ; no, so we're at the end
        cmp.l	    #'TKPR',-8(a1)      ; is it our hook?
        beq.b	    .exit               ; yes, so exit
        move.l      a1,a0               ; save current as previous
        move.l      -4(a1),a1           ; move to next hook
        bra.s       .next

.found_tail:
        ; a0 = last XBRA hook (or 0 if list was empty)
        ; a1 = original XBIOS handler

        ; workaround TOS2.xx xbios settime
        move.l      a0,a3               ; save last XBRA hook
        lea.l       xbios_hook(pc),a2   ; a2 = our hook
        move.l      a1,-4(a2)           ; our_hook.next = original handler
        move.l      a2,a1               ; a1 = our hook
        move.l      -4(a1),a0           ; a0 = original handler
        add.l       #4,-4(a1)           ; skip first instruction
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

        ; Install our XBRA at the tail of the list.
        move.l      a3,a0               ; restore tail hook
        cmp.l       #0,a0
        bne.s       .patch_tail
        ; no tail, install at head
        Setexc      #XBIOS_VECTOR,xbios_hook(pc)
        bra.s       .install_done
.patch_tail:
        move.l      a2,-4(a0)

.install_done:
        ; no error, stay resident
        movem.l     (sp)+,a2-a3
        move.w      #1,d0
        rts

.exit
        ; print the already installed message
        lea.l      msg_already_installed(pc),a0
        bra.s       .print_and_exit

.skip_installation
       ; print the already installed message
        lea.l      msg_not_tos206(pc),a0

.print_and_exit
        Cconws
        ; no error, but don't stay resident
        movem.l     (sp)+,a2-a3
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
        data

msg_welcome
        dc.b    'TIMEKPR v1.0 (c) 2025 Mathias Agopian', 13, 10, 0

msg_already_installed
        dc.b    7, 'Already installed.', 13, 10, 0

msg_not_tos206
        dc.b    7, 'Not needed on this TOS.', 13, 10, 0

; -----------------------------------------------------------------------------
; bss section
; -----------------------------------------------------------------------------
        bss

xbios_vecs:
        ds.w    1
        ds.l    $80
