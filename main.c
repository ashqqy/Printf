extern void asm_printf (const char* format, ...);

int main() 
{
    // simple 1
    asm_printf ("%s", "abx5\n\n");

    // simple 2
    asm_printf("%d %s %x %d%%%c%b\n\n", -1, "love", 3802, 100, 33, 126);

    // big string
    asm_printf("%d %s %x %d%%%c%b\n\n", -1, "loveeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeef", 3802, 100, 33, 126);

    // buffer overflow
    asm_printf("%d %s %x %d%%%c%b\n%d %s %x %d%%%c%b %o\n\n", -1, "love", 3802, 100, 33, 126, -1, "love", 3802, 100, 33, 126, 8);

    // negative numbers
    asm_printf ("%d %b %o %x\n\n", -1, -1, -1, -1);
}
