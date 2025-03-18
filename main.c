extern void asm_exit (int return_code);
extern void asm_printf (const char* format, ...);

void _start() 
{
    char* str = "social credit";
    int num = 51966;

    asm_printf("%x\n", num);

    asm_exit(0);
}
