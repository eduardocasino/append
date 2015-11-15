; FreeDOS APPEND
; Copyright (c) 2004 Eduardo Casino <casino_e@terra.es>
;
; This program is free software; you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation; either version 2 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program; if not, write to the Free Software
; Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
;
; 04-06-01  casino_e@terra.es   First version
; 04-06-03  casino_e@terra.es   Add note to help stating that when /E is used,
;                               no paths that can appear on the command line.
; 13-06-03  Eric Auer           Make older versions of nasm happy
;

%ifdef NEW_NASM
        cpu     8086
%endif

segment         code
; ===========================================================================
; RESIDENT PART
; ===========================================================================
%include        "useful.mac"
%include        "environ.asm"
%include        "cmdline.asm"
%include        "int2f.asm"
%include        "int21.asm"

cmd_id          db      6               ; 6, "APPEND"
append_prefix   db      "APPEND="
append_path     times 0x80 db 0

append_state    dw      0011000000000001b
;                       ||||\_________/|
;                       ||||     |     +- 0     set if APPEND enabled
;                       ||||     +------- 1-11  reserved
;                       |||+------------- 12    (DOS 5.0) set if APPEND
;                       |||                        applies directory search
;                       |||                        even if a drive has been
;                       |||                        specified
;                       ||+-------------- 13    set if /PATH flag active
;                       |+--------------- 14    set if /E flag active
;                       |                          (environment var APPEND
;                       |                           exists)
;                       +---------------- 15    set if /X flag active
;
APPEND_ENABLED  equ     0000000000000001b
APPEND_SRCHDRV  equ     0001000000000000b
APPEND_SRCHPTH  equ     0010000000000000b
APPEND_ENVIRON  equ     0100000000000000b
APPEND_EXTENDD  equ     1000000000000000b


NoAppend        db      13, "No Append", 13, 10, '$'
Invalid         db      13, "Invalid switch  - ", '$'
TooMany         db      13, "Too many parameters -  ", '$'
NotAllw         db      13, "Parameter value not allowed -  ", '$'

Help    db      13, "FreeDOS APPEND. Enables programs to open data files in "
        db              "specified directories as", 13, 10
        db              "                if the files were in the current "
        db              "directory.", 13, 10
        db      13, "(C) 2004 Eduardo Casino, under the terms of the GNU "
        db              "GPL, Version 2", 13, 10, 10
        db      "Syntax:", 13, 10, 10
        db      "  APPEND [[drive:]path[", 59, "...]] [/X[:ON|:OFF]] "
        db              "[/PATH:ON|/PATH:OFF] [/E]", 13, 10
        db      "  APPEND ", 59, 13, 10, 10
        db      "    [drive:]path Drive and directory to append."
        db              13, 10
        db      "    /X[:ON]      Extend APPEND to "
        db              "searches and command execution.", 13, 10
        db      "    /X:OFF       Applies APPEND only to "
        db              "requests to open files.", 13, 10
        db      "                 Defaults to /X:OFF", 13, 10
        db      "    /PATH:ON     Search appended directories for file "
        db              "requests that already", 13, 10
        db      "                 include a path.  This is the default "
        db              "setting.", 13, 10
        db      "    /PATH:OFF    Switches off /PATH:ON.", 13, 10
        db      "    /E           Stores the appended directory "
        db              "list in the environment.", 13, 10
        db      "                 /E may be used only in the first invocation "
        db      "of APPEND. You", 13, 10
        db      "                 can not include any paths on the same "
        db      "command line as /E.", 13, 10, 10
        db      "  APPEND ", 59, " clears the list of appended "
        db              "directories.", 13, 10
        db      "  APPEND without parameters displays the list of appended "
        db              "directories.", 13, 10, '$'

end_resident:
; ================== END OF RESIDENT CODE ================================


..start:
                mov     ax, data
                mov     ds, ax
                mov     ax, stack
                mov     ss, ax
                mov     sp, stacktop

                mov     ax, 0xB710      ; Check if we're already installed
                mov     dx, 0x0000
                int     0x2F

                cmp     dx, 0x0000      ; Not installed
                je      install

                cmp     dl, 5           ; Check installed version
                jne     wrong
                cmp     dh, 0
                je      installed

wrong:          mov     dx, WrongAppend
                mov     ah, 0x09
                int     0x21
                jmp     quit

installed:      mov     dx, WrnInstalled
                mov     ah, 0x09
                int     0x21

quit:           mov     ax, 0x4C01      ; Exit, errorlevel 1
                int     0x21

install:        mov     ah, 0x51        ; Get PSP pointer
                int     0x21

                call    get_environ     ; Get PARENT environment
                                        
                ; Parse command line parameters.
                ;
                mov     es, bx          ; ES:SI to command line
                mov     si, 0x80
                xor     cx, cx
                mov     cl, [es:si]     ; Length of command line
                inc     si
                call    parse_cmds
                jc      quit
                
                push    bx

                ; Free some bytes, release environment
                ;
                mov     bx,[es:0x2C]    ; Segment of environment
                mov     al,0x49         ; Free memory
                mov     es,bx
                int     0x21

                push    ds              ; Set DS for installing new handlers
                push    cs
                pop     ds

                ; Get vect to original int2f handler
                ;
                mov     ax, 0x352F
                int     0x21            ; get vector to ES:BX
                mov     ax, es
                mov     [cs:old_int2f], bx
                mov     [cs:old_int2f+2], ax

                ; Now, install new int2f handler
                ;
                mov     ax, 0x252F
                mov     dx, int2f
                int     0x21            ; DS:DX -> new interrupt handler

                ; Get vect to original int21 handler
                ;
                mov     ax, 0x3521
                int     0x21            ; get vector to ES:BX
                mov     ax, es
                mov     [cs:old_int21], bx
                mov     [cs:old_int21+2], ax

                ; Now, install new int21 handler
                ;
                mov     ax, 0x2521
                mov     dx, int21
                int     0x21            ; DS:DX -> new interrupt handler

                pop     ds              ; Restore DS

                mov     byte [cs:p_flags], RESIDENT     ; Set resident flag
                                                        ; and clean the rest

                ; Terminate and stay resident
                ;
                pop     bx
                mov     dx, end_resident+15
                mov     cl, 4
                shr     dx, cl          ; Convert to paragraphs
                push    cs
                pop     cx
                add     dx, cx
                sub     dx, bx          ;  (CS - PSP) + ((res. offset + 15)/4)

                mov     ax, 0x3100      ; Errorlevel 0
                int     0x21


segment         data

WrnInstalled    db      13, "APPEND already installed", 13, 10, '$'
WrongAppend     db      13, "Incorrect APPEND version", 13, 10, '$'


segment         stack   stack

                resb    256

stacktop:
