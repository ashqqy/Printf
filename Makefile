built:
	nasm -f elf64 -o print.o print.asm
	gcc -nostdlib -o main main.c print.o

clean:
	rm -f *.o main
