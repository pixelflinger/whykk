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
; GEMDOS functions
; -----------------------------------------------------------------------------
Pterm0          equ     $00
Cconws          equ     $09
Ptermres        equ     $31
Mshrink         equ     $4a

; -----------------------------------------------------------------------------
; BIOS functions
; -----------------------------------------------------------------------------
Setexc          equ     5
XBIOS_VEC       equ     46

; -----------------------------------------------------------------------------
; High-level system call macros
; -----------------------------------------------------------------------------

; -----------------------------------------------------------------------------
; GEMDOS macros
; -----------------------------------------------------------------------------

; void Cconws(const char* text_addr)
Cconws macro
    pea     \1
    move.w  #Cconws,-(sp)
    trap    #1
    addq.l  #6,sp
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
    move.w  #Mshrink,-(sp)
    trap    #1
    lea     12(sp),sp
    endm

; void Ptermres(long len_reg) - terminates with retcode 0
Ptermres macro
    clr.w   -(sp)
    move.l  \1,-(sp)
    move.w  #Ptermres,-(sp)
    trap    #1
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
    move.w  #Setexc,-(sp)
    trap    #13
    addq.l  #8,sp
    endm