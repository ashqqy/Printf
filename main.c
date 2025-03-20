extern void asm_printf (const char* format, ...);

int main() 
{
    // buffer overflow
    asm_printf("%d %s %x %d%%%c%b\n", -1, "loveeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeef", 3802, 100, 33, 126);

    asm_printf("%d %s %x %d%%%c%b\n%d %s %a %d%%%c%b\n", -1, "love", 3802, 100, 33, 126, -1, "love", 3802, 100, 33, 126);
}
