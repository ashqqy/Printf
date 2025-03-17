section .bss                ; uninitialized data section

BUF_LEN equ 128
buffer resb BUF_LEN

section .data

; jump_table dq case_0, case_1, case_2

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
printf_from_format:
    push rax
    mov rax, [rax]
    stosb
    pop rax
    ret

;----------------------------------------------------
; Input: 
;----------------------------------------------------
printf_char:
    movsb
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

    mov rdi, buffer

    dec rax
.next_iter:
    inc rax
    cmp [rax], byte 0
    je .end_printf

    cmp [rax], byte '%'
    je .special_printf
    jmp .default_printf

.special_printf:
    inc rax
    cmp [rax], byte 'c'
    je .printf_byte

.printf_byte:
    mov rsi, rbp
    call printf_char
    jmp .shift_stack

.default_printf:
    call printf_from_format
    jmp .next_iter

.shift_stack:
    add rbp, 8
    jmp .next_iter

.end_printf:
    mov rax, 1              ; write
    mov rdx, rdi            ; rdi - curr buffer ptr (with offset)
    sub rdx, buffer         ; rdx = buffer len
    mov rdi, 1              ; stdout
    mov rsi, buffer         
    syscall
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
