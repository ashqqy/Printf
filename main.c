extern void asm_exit (int return_code);
extern void asm_printf (const char* format, ...);

void _start() 
{
    char* str = "social credit";
    int num = -1;

    asm_printf("%b\n", num);

    asm_exit(0);
}
