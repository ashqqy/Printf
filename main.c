extern void asm_exit (int return_code);
extern void asm_printf (const char* format, ...);

void _start() 
{
    // char* str = "sosal";
    char symb = '?';

    asm_printf("sosal%c\n", symb);

    asm_exit(0);
}
