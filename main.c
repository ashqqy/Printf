extern void asm_exit (int return_code);
extern void asm_printf (const char* format, ...);

void _start() 
{
    asm_printf("%d %s %x %d%%%c%b\n", -1, "love", 3802, 100, 33, 126);

    asm_exit(0);
}
