extern void asm_exit (int return_code);
extern void asm_printf (const char* format, ...);

void _start() 
{
    char* str = "social credit";
    int num = -1000;

    asm_printf("%d %s\n", num, str);

    asm_exit(0);
}
