section .bss                ; uninitialized data section

BUF_LEN equ 128
buffer resb BUF_LEN

section .data

hex_table db "0123456789abcdef"

error_msg db "ERROR: Incorrect format", 10  ; '\n' = 10
ERROR_MSG_LEN equ $ - error_msg

section .text

global asm_printf
global asm_exit

;----------------------------------------------------
; Saves regs rcx and r11 before syscall
;----------------------------------------------------
%macro safe_syscall 0
    push rcx 
    push r11
    
    syscall

    pop r11 
    pop rcx
%endmacro

;----------------------------------------------------
; Input: rax - format ptr with offset to current byte
;        rdi - buffer ptr with offset
;----------------------------------------------------
%macro printf_from_format 0
    push rax
    mov rax, [rax]
    stosb
    pop rax
%endmacro

;----------------------------------------------------
; Input: rbp - stack ptr to currect arg
;        rdi - buffer ptr with offset
; Destr: rsi, rdi
;----------------------------------------------------
%macro printf_char 0
    mov rsi, rbp
    movsb
%endmacro

;----------------------------------------------------
; Input: rbp - stack ptr to currect arg
;        rdi - buffer ptr with offset
; Destr: rsi, rdi
;----------------------------------------------------
printf_str:
    mov rsi, [rbp]

.next_step:
    cmp [rsi], byte 0
    je .end
    movsb
    jmp .next_step

.end:
    ret

;----------------------------------------------------
; Input: eax - int32_t
;        rdi - buffer ptr with offset
;
; Destr: eax
;        rcx - digits counter, 
;        ebx - radix,  
;        edx - mod,
;        rdi - new buffer offset
;----------------------------------------------------
printf_dec:
    xor rcx, rcx

    cmp eax, 0
    jl .is_neg
    jmp .next_step

.is_neg:
    neg eax
    mov byte [rdi], '-'
    inc rdi

.next_step:
    mov ebx, 10
    xor edx, edx
    div ebx                 ; eax = edx:eax / ebx
;                           ; edx = edx:eax % ebx
    push rdx
    inc rcx
    cmp eax, 0
    jmp .next_step

.print_step:
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
; Input: eax - int32_t
;        rdi - buffer ptr with offset
;
; Destr: eax
;        rcx - digits counter
;        rdx - digit ascii code,  
;        rdi - new buffer offset
;----------------------------------------------------
printf_bin:
    mov rcx, 32d            ; 32d = n bits in number
    xor rdx, rdx

.skip_zeros:
    shl eax, 1
    jc .buffer_write        ; if (cf == 1) jmp
    loop .skip_zeros

    mov byte [rdi], '0'
    inc rdi
    ret

.buffer_write:
    adc rdx, 0              ; rdx = cf
    add rdx, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step

.next_step:
    xor rdx, rdx
    shl eax, 1
    adc rdx, 0              ; rdx = cf
    add rdx, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step

.end:
    ret

;----------------------------------------------------
; Input: eax - int32_t
;        rdi - buffer ptr with offset
;
; Destr: 
;----------------------------------------------------
printf_oct:
    mov rcx, 11d            ; 11d = n digits in number
    xor rdx, rdx

    mov edx, eax
    and edx, 11000000000000000000000000000000b
    shl eax, 2
    cmp edx, 0
    jne .buffer_write
    loop .skip_zeros

.skip_zeros:
    mov edx, eax
    and edx, 11100000000000000000000000000000b
    shl eax, 3
    cmp edx, 0
    jne .buffer_write
    loop .skip_zeros

    mov byte [rdi], '0'
    inc rdi
    ret

.buffer_write:
    cmp rcx, 11d
    je .no_skipped_zeros
    rol edx, 3h
    jmp .write_first

.no_skipped_zeros:
    rol edx, 2h

.write_first:
    add rdx, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step
    jmp .end

.next_step:
    mov edx, eax
    and edx, 11100000000000000000000000000000b
    shl eax, 3
    rol edx, 3d
    add edx, '0'
    mov [rdi], dl
    inc rdi
    loop .next_step

.end:
    ret

;----------------------------------------------------
;
; Input: rax - format ptr,
;        stack - other arguments
;
; Destr: 
;----------------------------------------------------
printf_main:
    mov rbp, rsp
    add rbp, 8              ; skip ret ptr printf_main func
;                           ;   rbp point to 1st arg in stack

    mov rdi, buffer

    dec rax
.next_step:
    inc rax
    cmp [rax], byte 0
    je .end_printf

    cmp [rax], byte '%'
    je .special_printf
    jmp .common_printf

.common_printf:
    printf_from_format
    jmp .next_step

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
;                            ; unused ascii <'a'
    dq .printf_other         ; unused 'a'
    dq .printf_b             ; 'b'
    dq .printf_c             ; 'c'
    dq .printf_d             ; 'd'
    dq .printf_other         ; unused 'e'
    ; dq .printf_double        ; 'f'
    dq .printf_other
    times 8 dq .printf_other ; unused 'g' - 'p'
    dq .printf_o             ; 'o'
    times 3 dq .printf_other ; unused 'p' - 'r'
    dq .printf_s             ; 's'
    times 4 dq .printf_other ; unused 't' - 'w'
    ; dq .printf_hex          ; 'x'
    dq .printf_other
;                            ; unused ascii >'x'
    
.printf_c:
    printf_char
    jmp .shift_stack

.printf_s:
    call printf_str
    jmp .shift_stack

.printf_d:
    push rax
    mov eax, [rbp]
    call printf_dec
    pop rax
    jmp .shift_stack

.printf_b:
    push rax
    mov eax, [rbp]
    call printf_bin
    pop rax
    jmp .shift_stack

.printf_o:
    push rax
    mov eax, [rbp]
    call printf_oct
    pop rax
    jmp .shift_stack

.printf_other:
    mov rax, 1              ; write
    mov rdi, 1              ; stdout
    mov rsi, error_msg  
    sub rdx, ERROR_MSG_LEN
    safe_syscall
    ret

.shift_stack:
    add rbp, 8
    jmp .next_step

.end_printf:
    mov rax, 1              ; write
    mov rdx, rdi            ; rdi - curr buffer ptr (with offset)
    sub rdx, buffer         ; rdx = buffer len
    mov rdi, 1              ; stdout
    mov rsi, buffer         
    safe_syscall
    ret

;----------------------------------------------------
; Push arguments passed via registers on stack 
;   and calls main printf function.
;
; Input: rdi - 1st arg (format),
;        rsi, rdx, rcx, r8, r9, stack - other arguments
;
; Destr: r10
;----------------------------------------------------
asm_printf:
    pop r10                 ; save return address

    push r9 
    push r8 
    push rcx 
    push rdx 
    push rsi

    mov rax, rdi            ; rax = format

    call printf_main

    pop rsi 
    pop rdx 
    pop rcx 
    pop r8 
    pop r9

    push r10                ; return return address :)
    ret

;----------------------------------------------------

asm_exit:
    mov rax, 60
    syscall 

;----------------------------------------------------
