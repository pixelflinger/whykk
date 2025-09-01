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

; =============================================================================
; TOS System Definitions and Macros
; =============================================================================

; -----------------------------------------------------------------------------
; System variables
; -----------------------------------------------------------------------------

_sysbase        equ     $4f2

; -----------------------------------------------------------------------------
; GEMDOS functions
; -----------------------------------------------------------------------------
OpPterm0        equ     $00
OpCconws        equ     $09
OpPtermres      equ     $31
OpMshrink       equ     $4a
OpTgetdate      equ     $2a
OpTsetdate      equ     $2b
OpTgettime      equ     $2c
OpTsettime      equ     $2d

; -----------------------------------------------------------------------------
; BIOS functions
; -----------------------------------------------------------------------------
OpSetexc        equ     5

; -----------------------------------------------------------------------------
; XBIOS functions
; -----------------------------------------------------------------------------

OpSettime       equ     22
OpGettime       equ     23
OpSupexec       equ     38

; -----------------------------------------------------------------------------
; Exceptions vectors
; -----------------------------------------------------------------------------

XBIOS_VECTOR    equ     46

; -----------------------------------------------------------------------------
; GEMDOS macros
; -----------------------------------------------------------------------------

; void Cconws(const char* text_addr)
Cconws macro
    move.l  a0,-(sp)
    move.w  #OpCconws,-(sp)
    trap    #1
    addq.w  #6,sp
    endm

; void Pterm0()
Pterm0 macro
    clr.w   -(sp)
    trap    #1              ; Pterm0 is the default
    endm

; void Mshrink(void* addr_reg, long len_reg)
Mshrink macro
    move.l  \2,-(sp)
    move.l  \1,-(sp)
    clr.w   -(sp)
    move.w  #OpMshrink,-(sp)
    trap    #1
    lea     12(sp),sp
    endm

; void Ptermres(long len_reg) - terminates with retcode 0
Ptermres0 macro
    clr.w   -(sp)
    move.l  \1,-(sp)
    move.w  #OpPtermres,-(sp)
    trap    #1
    endm

Tsettime macro
    move.w  \1,-(sp)
    move.w  #OpTsettime,-(sp)
    trap    #1
    addq.w  #4,sp
    endm

Tsetdate macro
    move.w  \1,-(sp)
    move.w  #OpTsetdate,-(sp)
    trap    #1
    addq.w  #4,sp
    endm

Tgettime macro
    move.w  #OpTgettime,-(sp)
    trap    #1
    addq.w  #2,sp
    endm

Tgetdate macro
    move.w  #OpTgetdate,-(sp)
    trap    #1
    addq.w  #2,sp
    endm

; -----------------------------------------------------------------------------
; BIOS macros
; -----------------------------------------------------------------------------

; long Setexc(int vec_num, long vector_addr)
; Returns old vector in d0.
; NOTE: A vector_addr of -1 queries the current vector.
Setexc macro
    pea     \2
    move.w  \1,-(sp)
    move.w  #OpSetexc,-(sp)
    trap    #13
    addq.w  #8,sp
    endm

; -----------------------------------------------------------------------------
; XBIOS macros
; -----------------------------------------------------------------------------

Gettime macro
    move.w  #OpGettime,-(sp)
    trap    #14
    addq.w  #2,sp
    endm

Settime macro
    move.l  \1,-(sp)
    move.w  #OpSettime,-(sp)
    trap    #14
    addq.w  #6,sp
    endm

; int32_t Supexec( int32_t (*func)( ) );
Supexc macro
    pea       \1
    move.w    #OpSupexec,-(sp)
    trap      #14
    addq.l    #6,sp
    endm
