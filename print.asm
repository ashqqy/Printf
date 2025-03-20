; TODO stack frame only bp (bp + di*8 = args) (bp - si = buf)
section .rodata

; WARNING! 
; Buffer length cannot be less than 32
; Buffer length must be divisible by 8
BUF_LEN equ 32

LEN_DEC_INT32  equ 11d          ; 10 bytes of ascii number + 1 byte sign
LEN_BIN_UINT32 equ 32d          ; 32 bytes of ascii number
LEN_OCT_UINT32 equ 11d          ; 11 bytes of ascii number
LEN_HEX_UINT32 equ 8d           ; 8 bytes  of ascii number
LEN_CHAR       equ 1d

hex_table db "0123456789abcdef"

error_msg db 10, "ERROR: Incorrect format", 10  ; '\n' = 10
ERROR_MSG_LEN equ $ - error_msg

section .text

global asm_printf

;----------------------------------------------------
; Saves regs rcx and r11 before syscall.
;----------------------------------------------------
%macro safe_syscall 0
    push rcx 
    push r11
    
    syscall

    pop r11 
    pop rcx
%endmacro


;----------------------------------------------------
; Input:  %1 - string ptr.
;
; Output: rcx - strlen.
;----------------------------------------------------
%macro count_strlen 1
    push rdi
    push rax

    mov rdi, %1                 ; string ptr
    xor rcx, rcx        
    not rcx                     ; cx = max_value
    xor al, al                  ; al = '\0'
    repne scasb                 ; while (symb != \0) cx-=1
    not ecx     
    dec ecx                     ; remove '\0'

    pop rax
    pop rdi
%endmacro

;----------------------------------------------------
; Input: rdi - curr buffer ptr (with offset)
;----------------------------------------------------
%macro out_buffer 0
    mov rax, 1                  ; write
    mov rdx, rdi                ; rdi - curr buffer ptr (with offset)
    sub rdx, r11                ; rdx = buffer len
    cmp rdx, 0
    je %%end
    mov rdi, 1                  ; stdout
    mov rsi, r11         
    safe_syscall
%%end:
%endmacro

;----------------------------------------------------
; Input:  1st arg - required space
;         rsi - string ptr (if macro called from printf_str)
;
; Output: rdi - new buffer ptr
;
; Destr:  rcx, rdx
;----------------------------------------------------
%macro check_buf 1
    mov rcx, %1

    mov rdx, r11                ; rdi - curr buffer ptr (with offset)   
    add rdx, BUF_LEN 
    sub rdx, rdi                ; rdx = free space

    cmp rdx, rcx                ; if (free space >= required space)
    jge %%buf_ok                ;  return;

    push rax                    ; else
    push rsi                    ;  printf (buffer)
    out_buffer                      
    pop rsi
    pop rax
    mov rdi, r11                ;  rdi = buffer start

    cmp rcx, BUF_LEN            ; if (required space <= buf_len)
    jle %%buf_ok                ;  return;

%%big_str:                      ; else
    push rax                    ;  syscall; (printf str separately)
    push rdi

    mov rax, 1                  ; write
    mov rdx, rcx                ; rdx = requiered space
    mov rdi, 1                  ; stdout
    safe_syscall                ; rsi = string ptr 

    pop rdi
    pop rax

    jmp printf_str.end

%%buf_ok:
%endmacro

;----------------------------------------------------
; Input:  rax - format ptr with offset to current byte,
;         rdi - buffer ptr with offset.
;
; Destr:  rcx, rdx.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
%macro printf_from_format 0
    check_buf LEN_CHAR

    push rax
    mov rax, [rax]
    stosb
    pop rax
%endmacro

;----------------------------------------------------
; Input:  rbp - stack ptr to currect arg,
;         rdi - buffer ptr with offset.
;
; Destr:  rcx, rdx, rsi.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
%macro printf_char 0
    check_buf LEN_CHAR

    mov rsi, rbp
    movsb
%endmacro

;----------------------------------------------------
; Input:  rbp - stack ptr to currect arg,
;         rdi - buffer ptr with offset.
;
; Destr:  rcx, rdx, rsi.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_str:
    mov rsi, [rbp]
    count_strlen rsi            ; rcx = strlen
    check_buf rcx

.next_step:
    cmp [rsi], byte 0
    je .end
    movsb
    jmp .next_step

.end:
    ret

;----------------------------------------------------
; Input:  eax - int32_t,
;         rdi - buffer ptr with offset.
;
; Destr:  eax,
;         rcx - digits counter + check_buf, 
;         ebx - radix,  
;         rdx - mod + check_buf.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_dec:
    check_buf LEN_DEC_INT32
    xor rcx, rcx

    cmp eax, 0
    jl .is_neg
    jmp .next_step

.is_neg:
    neg eax
    mov byte [rdi], '-'
    inc rdi

.next_step:                     ; push digits on stack
    mov ebx, 10
    xor edx, edx
    div ebx                     ; eax = edx:eax / ebx
;                               ; edx = edx:eax % ebx
    push rdx
    inc rcx
    cmp eax, 0
    je .print_step
    jmp .next_step

.print_step:                    ; pop digits and move to buffer
    cmp rcx, 0
    je .end
    pop rax
    add eax, '0'
    stosb
    dec rcx
    jmp .print_step

.end:
    ret

;----------------------------------------------------
; Input:  eax - uint32_t,
;         rdi - buffer ptr with offset.
;
; Destr:  eax,
;         rcx - digits counter + check_buf,
;         rdx - digit ascii code + check_buf.

; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_bin:
    check_buf LEN_BIN_UINT32
    mov rcx, LEN_BIN_UINT32
    xor rdx, rdx

.skip_zeros:
    shl eax, 1                  ; if (most significant bit eax = 1) cf = 1
;                               ;  else cf = 0
    jc .buffer_write            ; if (cf == 1) jmp
    loop .skip_zeros

    mov byte [rdi], '0'         ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    ret

.buffer_write:
    adc dl, 0                   ; dl = cf
    add dl, '0'                 ; dl = '0' or dl = '1'
    mov [rdi], dl               ; buffer[rdi++] = dl
    inc rdi
    loop .next_step
    ret

.next_step:
    xor dl, dl
    shl eax, 1
    adc dl, 0
    add dl, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step

.end:
    ret

;----------------------------------------------------
; Input:  eax - uint32_t,
;         rdi - buffer ptr with offset.
;
; Destr:  eax,
;         rcx - digits counter + check buf,
;         rdx - digit ascii code + check_buf.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_oct:
    check_buf LEN_OCT_UINT32
    mov rcx, LEN_OCT_UINT32

.first_oct_digit:               ; process first 2 bits apart, because 32 % 3 = 2
    mov edx, eax                ; EXAMPLE: edx = 0b1110...0000
    rol edx, 2                  ; edx = 0b10...000011
    and dl, 0b11                ; edx = 0b00...000011 (first 2 bits of eax in dl)
    shl eax, 2                  ; delete first 2 bits from eax
    cmp dl, 0                   ; if (dl == 0) not print this symb
    jne .buffer_write
    loop .skip_zeros

.skip_zeros:
    mov edx, eax
    rol edx, 3
    and dl, 0b111               ; dl = next 3 bits
    shl eax, 3                  ; delete 3 bits from eax
    cmp dl, 0
    jne .buffer_write
    loop .skip_zeros

    mov byte [rdi], '0'         ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    ret

.buffer_write:
    add edx, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step
    ret

.next_step:
    mov edx, eax
    rol edx, 3
    and dl, 0b111               ; dl = next 3 bits
    shl eax, 3                  ; delete 3 bits from eax
    add dl, '0'                 ; dl = ascii of digit
    mov [rdi], dl               ; buffer[rdi++] = dl
    inc rdi
    loop .next_step

.end:
    ret

;----------------------------------------------------
; Input:  eax - uint32_t,
;         rdi - buffer ptr with offset.
;
; Destr:  eax,
;         rcx - digits counter + check_buf,
;         rdx - digit ascii code + check_buf.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_hex:
    check_buf LEN_HEX_UINT32
    mov rcx, LEN_HEX_UINT32

.skip_zeros:
    mov edx, eax 
    rol edx, 4                      
    and edx, 0b1111              ; edx = next 4 bits
    shl eax, 4                   ; delete 4 bits from eax
    cmp edx, 0                   ; if (edx == 0) not print this symb
    jne .buffer_write
    loop .skip_zeros

    mov byte [rdi], '0'          ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    ret

.buffer_write:
    mov dl, byte [hex_table + rdx]
    mov [rdi], dl
    inc rdi
    loop .next_step
    ret

.next_step:
    mov edx, eax
    rol edx, 4                  
    and edx, 0b1111              ; edx = next 4 bits
    shl eax, 4                   ; delete 4 bits from eax
    mov dl, byte [hex_table + rdx]
    mov [rdi], dl                ; buffer[rdi++] = *(hex_table + edx)
    inc rdi
    loop .next_step

.end:
    ret

;----------------------------------------------------
; Main printf function. Parces format and output string.
;
; Input: arguments in stack.
;
; Destr: rax, rbx, rcx, rdx, rdi, rsi, rbp
;----------------------------------------------------
printf_main:
    mov rbp, rsp                ; skip ret ptr printf_main func and saved registers (rbx, rbp)
    add rbp, 8*4                ;  rbp point to 1st arg in stack

    sub rsp, BUF_LEN
    mov rdi, rsp
    mov r11, rdi                ; save begin of buffer in r11

    mov rax, [rbp]              ; rax = format
    add rbp, 8                  ; rbp = 2nd arg

    dec rax
.parce:                         ; parce format string
    inc rax
    cmp [rax], byte 0           ; while ([rax] != '\0') parce
    je .end_printf

    cmp [rax], byte '%'
    je .special_printf
    jmp .common_printf

.common_printf:
    printf_from_format
    jmp .parce

.special_printf:
    inc rax
    cmp [rax], byte 'a'
    jl .printf_other
    cmp [rax], byte 'x'
    jg .printf_other
    movzx rbx, byte [rax]
    sub rbx, 'a'
    jmp [.jump_table + rbx * 8h]

.jump_table:
;                                           ; unused ascii <'a'
    dq .printf_other                        ; unused 'a'
    dq .printf_b                            ; 'b'
    dq .printf_c                            ; 'c'
    dq .printf_d                            ; 'd'
    dq .printf_other                        ; unused 'e'
    dq .printf_other                        ; unused 'f'
    times 'n' - 'g' + 1 dq .printf_other    ; unused 'g' - 'n'
    dq .printf_o                            ; 'o'
    times 'r' - 'p' + 1 dq .printf_other    ; unused 'p' - 'r'
    dq .printf_s                            ; 's'
    times 'w' - 't' + 1 dq .printf_other    ; unused 't' - 'w'
    dq .printf_x                            ; 'x'
;                                           ; unused ascii >'x'
    
.printf_c:
    printf_char
    jmp .shift_param

.printf_s:
    call printf_str
    jmp .shift_param

.printf_d:
    push rax
    mov eax, [rbp]
    call printf_dec
    pop rax
    jmp .shift_param

.printf_b:
    push rax
    mov eax, [rbp]
    call printf_bin
    pop rax
    jmp .shift_param

.printf_o:
    push rax
    mov eax, [rbp]
    call printf_oct
    pop rax
    jmp .shift_param

.printf_x:
    push rax
    mov eax, [rbp]
    call printf_hex
    pop rax
    jmp .shift_param


.printf_other:
    cmp [rax], byte '%'
    jne .printf_error
    printf_from_format
    jmp .parce

.printf_error:
    mov rax, 1                  ; write
    mov rdi, 1                  ; stdout
    mov rsi, error_msg          ; msg about incorrect specifier
    mov rdx, ERROR_MSG_LEN
    safe_syscall
    add rsp, BUF_LEN
    ret

.shift_param:
    add rbp, 8
    jmp .parce

.end_printf:
    add rsp, BUF_LEN
    out_buffer         
    ret

;----------------------------------------------------
; Push arguments passed via registers on stack 
;   and calls main printf function.
;
; Input: rdi - 1st arg (format),
;        rsi, rdx, rcx, r8, r9, stack - other arguments.
;
; Destr: r10 - return address.
;----------------------------------------------------
asm_printf:
    pop r10                     ; save return address

    push r9                     ; push params on stack
    push r8 
    push rcx 
    push rdx 
    push rsi
    push rdi

    push rbx                    ; save regs
    push rbp
    push r11

    call printf_main

    pop r11
    pop rbp
    pop rbx

    pop rdi
    pop rsi 
    pop rdx 
    pop rcx 
    pop r8 
    pop r9

    push r10                    ; return return address :)
    ret

;----------------------------------------------------
