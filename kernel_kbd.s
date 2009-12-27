; program: kernel_kbd
; Words related to the keyboard driver

; License: GPL
; José Dinuncio <jdinunci@uc.edu.ve>, 12/2009.

%include "forth.h"
%include "kernel_words.h"
%include "kernel_video.h"

extern keymap
%define KEYMAP keymap

[BITS 32]
%define _KEY_STAT_CAPS 0x01
%define _KEY_STAT_SHIFT 0x02

; variable: KEY_STATUS
;   Store the status of CAPS, SHIFT and CONTROL keys.
defvar KEY_STATUS, KEY_STATUS, 0, 0

; function: KBD_FLAGS
;   Returns the keyboard status code.
;
; Stack:
;   -- kbd_status
defword  KBD_FLAGS, KBD_FLAGS, 0
        LITN 0x64
        dd INB
        dd EXIT

; function: KBD_BUFFER_FULL
;   true if there is a scancode waiting to be readed
;
; Stack:
;   -- bool
defword  KBD_BUFFER_FULL, KBD_BUFFER_FULL, 0
        dd KBD_FLAGS
        LITN 1
        dd AND
        dd EXIT

; function: KBD_SCANCODE_NOW
;   Returns the scancode readed on the keyboard at this moment.
;
; Stack:
;   -- scancode
defword  KBD_SCANCODE_NOW, KBD_SCANCODE_NOW, 0
        LITN 0x60
        dd INB
        dd EXIT

; function: KBD_SCANCODE
; Waits for a key pressed and returns its sacancode.
;
; Stack:
; -- scancode
defword  KBD_SCANCODE, KBD_SCANCODE, 0
        begin
        dd KBD_BUFFER_FULL
        until
        dd KBD_SCANCODE_NOW
        LITN 0xFF
        dd AND
        dd EXIT


; function _TX_KEY_STATUS
;   Test and XOR the KEY_STATUS variable.
;
;   If the scancode is equal to the given test, makes an XOR
;   between KEY_STATUS and flags.
;
; stack:
;   scancode test flag --
defword  _TX_KEY_STATUS, _TX_KEY_STATUS, 0
        dd NROT
        dd EQU
        if
        dd KEY_STATUS
        dd FETCH
        dd XOR
        dd KEY_STATUS
        dd STORE
        else
        dd DROP
        then
        dd EXIT

; function: _UPDATE_KEY_STATUS
;   Updates the KBD_FLAGS variable according with the scancode given.
;
; Stack:
;   scancode --
defword  _UPDATE_KEY_STATUS, _UPDATE_KEY_STATUS, 0
        ;  TODO - XOR could fail in some cases. Set o clear the bit.
        dd DUP
        LITN 58
        LITN _KEY_STAT_CAPS
        dd _TX_KEY_STATUS
        ;  CAPS   down
        dd DUP
        LITN 42
        LITN _KEY_STAT_SHIFT
        dd _TX_KEY_STATUS
        ;  LSHIFT down
        dd DUP
        LITN 170
        LITN _KEY_STAT_SHIFT
        dd _TX_KEY_STATUS
        ;  LSHIFT up
        dd DUP
        LITN 54
        LITN _KEY_STAT_SHIFT
        dd _TX_KEY_STATUS
        ;  RSHIFT down
        dd DUP
        LITN 182
        LITN _KEY_STAT_SHIFT
        dd _TX_KEY_STATUS
        ;  RSHIFT up

        dd DROP
        dd EXIT

; stack:
;   scancode -- bool
defword  _KEY_DOWN?, _KEY_DOWN, 0
        LITN 0x80
        dd AND
        dd ZEQU
        dd EXIT

; function: SC>C (SCANCODE2CHAR)
;   Converts a scancode to an ASCII character.
; 
;   If the scancode correspond to keyup or to a non-character
;   it returns 0
;
; stack:
;   scancode -- char
defword  SC>C, SCANCODE2CHAR, 0
        dd DUP
        dd _KEY_DOWN
        if
        LITN 4
        dd MUL
        dd KEY_STATUS
        dd FETCH
        dd ADD
        LITN KEYMAP
        dd ADD
        dd FETCHBYTE
        else
        LITN 0
        then
        dd EXIT

; function: GETCHAR
;   Waits for a key to be pressed and then returns its ASCII code.
;
; Stack:
;   -- c
defword  GETCHAR, GETCHAR, 0
        LITN 0
        begin
        dd DROP
        dd KBD_SCANCODE
        dd DUP
        dd _UPDATE_KEY_STATUS
        dd SCANCODE2CHAR
        dd DUP
        until
        dd EXIT


;THIS IS CODE FORM retro8 by crc
;			
; function: IN
; Returns the key pressed
;
; Stack:
; -- char
;
; Parameters:
; key - ASCII char of the key pressed.
;defcode IN ,IN ,0 ; TESTED_OK
;		call sys_key
;		NEXT

;THIS IS CODE FORM retro8 by crc
;	rewrite it? some day?		
;sys_key:
; 	xor   ebx,ebx  		; Show the coursor
;	mov   bl,[var_CURSOR_POS_X]				     
;	mov   ecx,ebx
;	mov   bl,[var_CURSOR_POS_Y]				      
;	mov   eax,80
;	mul   bx
;	add   eax,ecx				       
;    mov   edx,0x3d4 
;	mov   ecx,eax
;	mov   al,15
;	out   dx,al
;	mov   eax,ecx
;	inc   edx
;	out   dx,al
;	mov   al,14
;	dec   edx
;	out   dx,al
;	mov   eax,ecx
;	mov   al,ah
;	inc   edx
;	out   dx,al			; Show the coursor end
;	xor eax,eax	        ;  clear eax
;.1:	in al,64h		;  Is any data waiting?
;	test al,1	        ;  Is character = ASCII 0?
;	jz .1		        ;  Yes? Try again
;	in al,60h	        ;  Otherwise, read scancode
;	xor edx,edx	        ;  edx: 0=make, 1=break
;	test al,80h	        ;  Is character = HEX 80h?
;	jz .2		        ;  Skip the next line
;	inc edx 	        ;  Update edx
;.2:	 and al,7Fh		;  Filters to handle
;	cmp al,39h	        ;  the ignored keys
;	  ja .1 	        ;  We just try another key
;	mov ecx,[board]         ;  Load the keymap
;	mov al,[ecx+eax]        ;  Get the key ASCII char
;	  or al,al		        ;  Is is = 0?
;	js .shift		        ;  No, use CAPITALS
;	jz .1		        ;  Ignore 0's
;	or dl,dl		        ;  Filter for break code
;	jnz .1		        ;  Ignore break code
;	;THIS IS CODE FORM retro8 by crc  END
;	mov dword [var_KEYBUFF],eax
;	   ; echo
;        push    eax
;        push    ebx
;        push    ecx
;        cmp		al,0x08 ;don't display BS
;        jbe .3
;        cmp		al,0x0D ;don't display CR
;        jbe .3
;        and     eax,0x000000FF
;        or      eax,[var_SCREEN_COLOR]
;        mov     ecx,eax
;        mov     eax,[var_CURSOR_POS_X]
;        inc dword [var_CURSOR_POS_X]
;        mov     ebx,[var_CURSOR_POS_Y]
;     	push    ebx
;        imul    ebx,[video_width]
;        add     eax,ebx
;        shl     eax,1
;        add     eax,[video_base]
;        pop     ebx
;        mov     [eax],cx
;.3:
;       
;        pop     ecx
;        pop     ebx
;        pop     eax
;	ret

;THIS IS CODE FORM retro8 by crc	
;.shift:  mov ecx,[edx*4 + .shifts]	 ;  Load the CAPITAL keymap
;	mov [board],ecx 	        ;  Store into BOARD pointer
;	jmp .1			  ;  And try again
;.shifts dd shift,alpha
;board dd alpha
alpha:
  db  0, 27,"1234567890-=", 8	        ;00-0E
  db  9, "qwertyuiop[]", 10	        ;0F-1C
  db  0, "asdfghjkl;'`"		        ;1D-29
  db -1, "\zxcvbnm,./", -1,"+",0,32,-2    ;2A-3A
shift:
  db  0,27,"!@#$%^&*()_+",8	        ;00-0E
  db  9,"QWERTYUIOP{}",10	        ;0F-1C
  db  0,'ASDFGHJKL:"~'		        ;1D-29
  db -1,"|ZXCVBNM<>?",-1,"=",0,32,-2    ;2A-3A



