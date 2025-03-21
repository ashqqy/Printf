section .rodata

; WARNING! 
; Buffer length cannot be less than 32
; Buffer length must be divisible by 8, because buffer stored on stack
BUF_LEN equ 32

; 3d because skip 2 saved regs on stack and return addr
BYTES_BETWEEN_ARGS_AND_STACK equ 3d * 8d 

; (rbp - FIRST_ARG_OFFSET) = first arg on stack ptr      
FIRST_ARG_OFFSET equ 6d * 8d 

; (rbp - BUFFER_BEGIN_OFFSET) = buffer begin ptr
BUFFER_BEGIN_OFFSET equ FIRST_ARG_OFFSET + BYTES_BETWEEN_ARGS_AND_STACK + BUF_LEN

LEN_DEC_INT32  equ 11d              ; 10 bytes of ascii number + 1 byte sign
LEN_BIN_UINT32 equ 32d              ; 32 bytes of ascii number
LEN_OCT_UINT32 equ 11d              ; 11 bytes of ascii number
LEN_HEX_UINT32 equ 8d               ; 8 bytes  of ascii number
LEN_CHAR       equ 1d               ; 1 byte   of ascii char

hex_table db "0123456789abcdef"

error_msg db 10, "ERROR: Incorrect format", 10  ; '\n' = 10
ERROR_MSG_LEN equ $ - error_msg

jump_table:
;                                                       ; unused ascii <'a'
    dq                     printf_main.printf_other     ; unused 'a'
    dq                     printf_bin                   ; 'b'
    dq                     printf_main.printf_c         ; 'c'
    dq                     printf_dec                   ; 'd'
    times 'n' - 'e' + 1 dq printf_main.printf_other     ; unused 'e' - 'n'
    dq                     printf_oct                   ; 'o'
    times 'r' - 'p' + 1 dq printf_main.printf_other     ; unused 'p' - 'r'
    dq                     printf_str                   ; 's'
    times 'w' - 't' + 1 dq printf_main.printf_other     ; unused 't' - 'w'
    dq                     printf_hex                   ; 'x'
;                                                       ; unused ascii >'x'

section .text

global asm_printf

;----------------------------------------------------

%macro shift_param 0
    inc rsi
%endmacro

;----------------------------------------------------
; Input:  rax       - format ptr with offset to current byte,
;         rbp + rdi - buffer ptr with offset.
;
; Destr:  rcx, rdx.
;
; Output: rbp + rdi - new buffer offset.
;----------------------------------------------------
%macro printf_from_format 0
    check_buf LEN_CHAR

    mov dl, [rax]
    mov [rbp + rdi], dl
    inc rdi

%endmacro

;----------------------------------------------------
; Input:  rbp + rsi * 8d - stack ptr to currect arg,
;         rbp + rdi      - buffer ptr with offset.
;
; Destr:  rcx
;
; Output: rbp + rsi * 8d - next arg,
;         rbp + rdi      - new buffer offset.
;----------------------------------------------------
%macro printf_char 0
    check_buf LEN_CHAR

    mov dl, [rbp + rsi * 8]
    mov [rbp + rdi], dl
    inc rdi

    shift_param
%endmacro

;----------------------------------------------------
; Input:  %1 - string ptr.
;
; Output: rcx - strlen.
;----------------------------------------------------
%macro count_strlen 1
    push rdi
    push rax

    mov rdi, %1                     ; string ptr
    xor rcx, rcx        
    not rcx                         ; cx = max_value
    xor al, al                      ; al = '\0'
    repne scasb                     ; while (symb != \0) cx-=1
    not ecx     
    dec ecx                         ; remove '\0'

    pop rax
    pop rdi
%endmacro

;----------------------------------------------------
; Input: rbp + rdi - curr buffer ptr (with offset)
;
; Destr: rax, rdx, rdi, rsi 
;----------------------------------------------------
%macro out_buffer 0
    mov rax, 1                          ; write
    
    mov rdx, BUFFER_BEGIN_OFFSET
    add rdx, rdi                        ; rdx = buf size

    mov rdi, 1                          ; stdout

    mov rsi, rbp
    sub rsi, BUFFER_BEGIN_OFFSET

    safe_syscall
%endmacro

;----------------------------------------------------
; Input:  1st arg - required space
;         rbp + rsi * 8d - string ptr (if macro called from printf_str)
;
; Output: rbp + rdi - new buffer ptr
;
; Destr:  rcx, rdx
;----------------------------------------------------
%macro check_buf 1
    mov rdx, rdi                    ; rdx = free space
    neg rdx
    sub rdx, FIRST_ARG_OFFSET + BYTES_BETWEEN_ARGS_AND_STACK  

    cmp rdx, %1                     ; if (free space >= required space)
    jge %%buf_ok                    ;  return;

    push rax                        ; else
    push rsi                        ;  printf (buffer)
    out_buffer                      
    pop rsi
    pop rax
    mov rdi, BUFFER_BEGIN_OFFSET    ; rdi = buffer start
    neg rdi

%%buf_ok:
%endmacro

;----------------------------------------------------

%macro check_big_str 1
    cmp %1, BUF_LEN                 ; if (required space <= buf_len)
    jle %%end                       ;  return;

%%big_str:                          ; else syscall; (printf str separately)
    push rax
    push rsi                        
    out_buffer                      ; printf (buffer)
    pop rsi
    push rsi

    mov rax, 1                      ; write
    mov rdx, %1                     ; rdx = requiered space
    mov rdi, 1                      ; stdout
                                    
    neg rsi                         ; rsi = string ptr  (rsi = [rbp + rsi * 8d])
    shl rsi, 3                      ; ^
    neg rsi                         ; |
    add rsi, rbp                    ; |
    mov rsi, [rsi]                  ; |

    safe_syscall                    

    pop rsi
    pop rax
    mov rdi, BUFFER_BEGIN_OFFSET
    neg rdi                         ; rdi = buffer start

    shift_param
    jmp printf_main.parce
%%end:
%endmacro

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
; Push arguments passed via registers on stack,
;  sets start of stack frame to rbp,
;   calls main printf function.
;
; Input: rdi - 1st arg (format),
;        rsi, rdx, rcx, r8, r9, stack - other arguments.
;
; Destr: r10 - return address.
;        r11 - old rbp
;----------------------------------------------------
asm_printf:
    mov r11, rbp                    ; save rbp
    pop r10                         ; save return address

    mov rbp, rsp                    ; stack frame begin

    push r9                         ; push params on stack
    push r8 
    push rcx 
    push rdx
    push rsi
    push rdi

    push rbx                        ; save rbx
    push r11                        ; save rbp (r11 = rbp)

    call printf_main

    pop rbp
    pop rbx

    pop rdi
    pop rsi 
    pop rdx 
    pop rcx 
    pop r8 
    pop r9

    push r10                        ; return return address :)
    ret

;----------------------------------------------------
; Main printf function. Parces format and printf string.
;
; Input: rbp - stack frame begin,
;        arguments on stack.
;
; Destr: rax, rbx, rcx, rdx, rdi, rsi
;----------------------------------------------------
printf_main:
    mov rsi, FIRST_ARG_OFFSET / 8d  
    neg rsi                         ; set (rbp + rsp * 8d) to first argument on stack

    sub rsp, BUF_LEN                ; allocate space for buffer

    mov rdi, BUFFER_BEGIN_OFFSET    ; set (rbp + rdi) to buffer begin
    neg rdi                         ; 

    mov rax, [rbp + rsi * 8]        ; rax = format
    inc rsi                         ; (rbp + rsi * 8d) = 2nd arg

    dec rax
.parce:                             ; parce format string
    inc rax
    cmp [rax], byte 0               ; while ([rax] != '\0') parce
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
    jmp [jump_table + rbx * 8h]

.printf_other:
    cmp [rax], byte '%'
    jne .printf_error
    printf_from_format
    jmp .parce

.printf_c:
    printf_char
    jmp .parce

.printf_error:
    mov rax, 1                      ; write
    mov rdi, 1                      ; stdout
    mov rsi, error_msg              ; msg about incorrect specifier
    mov rdx, ERROR_MSG_LEN
    safe_syscall
    add rsp, BUF_LEN
    ret

.end_printf:
    out_buffer      
    add rsp, BUF_LEN
    ret

;----------------------------------------------------
; Input:  rbp - stack ptr to currect arg,
;         rdi - buffer ptr with offset.
;
; Destr:  rcx, rdx, rsi.
;
; Output: rdi - new buffer offset.
;----------------------------------------------------
printf_str:
    count_strlen [rbp + rsi * 8d]    ; rcx = strlen
    check_big_str rcx
    check_buf rcx

    mov rcx, [rbp + rsi * 8d]

.next_step:
    cmp [rcx], byte 0
    je .end
    mov dl, [rcx]
    mov [rbp + rdi], dl
    inc rcx
    inc rdi
    jmp .next_step

.end:
    shift_param
    jmp printf_main.parce

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

    push rax
    mov eax, [rbp + rsi * 8d]

    cmp eax, 0
    jl .is_neg
    jmp .next_step

.is_neg:
    neg eax
    mov byte [rbp + rdi], '-'
    inc rdi

.next_step:                         ; push digits on stack
    mov ebx, 10
    xor edx, edx
    div ebx                         ; eax = edx:eax / ebx
;                                   ; edx = edx:eax % ebx
    push rdx
    inc rcx
    cmp eax, 0
    je .print_step
    jmp .next_step

.print_step:                        ; pop digits and move to buffer
    cmp rcx, 0
    je .end
    pop rax
    add eax, '0'
    mov [rbp + rdi], al
    inc rdi
    dec rcx
    jmp .print_step

.end:
    pop rax
    shift_param                      ; inc rsi
    jmp printf_main.parce

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

    push rax
    mov eax, [rbp + rsi * 8d]

    xor rdx, rdx

.skip_zeros:
    shl eax, 1                      ; if (most significant bit eax = 1) cf = 1
;                                   ;  else cf = 0
    jc .buffer_write                ; if (cf == 1) jmp
    loop .skip_zeros

    mov byte [rbp + rdi], '0'       ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    jmp .end

.buffer_write:
    adc dl, 0                       ; dl = cf
    add dl, '0'                     ; dl = '0' or dl = '1'
    mov [rbp + rdi], dl             ; buffer[rdi++] = dl
    inc rdi
    loop .next_step
    jmp .end

.next_step:
    xor dl, dl
    shl eax, 1
    adc dl, 0
    add dl, '0'
    mov [rbp + rdi], dl
    inc rdi
    loop .next_step

.end:
    pop rax
    shift_param
    jmp printf_main.parce

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

    push rax
    mov eax, [rbp + rsi * 8d]

.first_oct_digit:                   ; process first 2 bits apart, because 32 % 3 = 2
    mov edx, eax                    ; EXAMPLE: edx = 0b1110...0000
    rol edx, 2                      ; edx = 0b10...000011
    and dl, 0b11                    ; edx = 0b00...000011 (first 2 bits of eax in dl)
    shl eax, 2                      ; delete first 2 bits from eax
    cmp dl, 0                       ; if (dl == 0) not print this symb
    jne .buffer_write
    loop .skip_zeros

.skip_zeros:
    mov edx, eax
    rol edx, 3
    and dl, 0b111                   ; dl = next 3 bits
    shl eax, 3                      ; delete 3 bits from eax
    cmp dl, 0
    jne .buffer_write
    loop .skip_zeros

    mov byte [rbp + rdi], '0'       ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    jmp .end

.buffer_write:
    add edx, '0'
    mov [rbp + rdi], dl
    inc rdi
    loop .next_step
    jmp .end

.next_step:
    mov edx, eax
    rol edx, 3
    and dl, 0b111                   ; dl = next 3 bits
    shl eax, 3                      ; delete 3 bits from eax
    add dl, '0'                     ; dl = ascii of digit
    mov [rbp + rdi], dl             ; buffer[rdi++] = dl
    inc rdi
    loop .next_step

.end:
    pop rax
    shift_param
    jmp printf_main.parce

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

    push rax
    mov eax, [rbp + rsi * 8d]

.skip_zeros:
    mov edx, eax 
    rol edx, 4                      
    and edx, 0b1111                 ; edx = next 4 bits
    shl eax, 4                      ; delete 4 bits from eax
    cmp edx, 0                      ; if (edx == 0) not print this symb
    jne .buffer_write
    loop .skip_zeros

    mov byte [rbp + rdi], '0'       ; if (all bits == 0) buffer[rdi++] = '0'
    inc rdi
    jmp .end

.buffer_write:
    mov dl, byte [hex_table + rdx]
    mov [rbp + rdi], dl
    inc rdi
    loop .next_step
    jmp .end

.next_step:
    mov edx, eax
    rol edx, 4                  
    and edx, 0b1111                 ; edx = next 4 bits
    shl eax, 4                      ; delete 4 bits from eax
    mov dl, byte [hex_table + rdx]
    mov [rbp + rdi], dl             ; buffer[rdi++] = *(hex_table + edx)
    inc rdi
    loop .next_step

.end:
    pop rax
    shift_param
    jmp printf_main.parce

;----------------------------------------------------
