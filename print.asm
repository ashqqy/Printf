section .text

;----------------------------------------------------
; Saves regs rcx and r11 before syscall
;----------------------------------------------------
%macro safe_syscall 0
    push rcx r11
    syscall
    pop r11 rcx
%endmacro

;----------------------------------------------------
;
; Input:
; Output:
; Destr: 
;----------------------------------------------------
print_char:


;----------------------------------------------------
;
; Input: rax - format,
;        stack - other arguments
; Output:
; Destr: 
;----------------------------------------------------
print_main:


;----------------------------------------------------
; Push arguments passed via registers on stack 
;   and calls main print function.
; Input: rdi - 1st arg (format),
;        rsi, rdx, rcx, r8, r9, stack - other arguments
; Output:
; Destr: r10
;----------------------------------------------------
print:
    pop r10                     ; save return address
    push r9 r8 rcx rdx rsi  
    mov rax, rdi                ; rax = format

    call print_main

    pop rsi rdx rcx r8 r9
    push r10                    ; return return address :)
    ret
