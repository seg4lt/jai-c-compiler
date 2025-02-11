UNAME_S := $(shell uname -s)
FILE_NAME := return_2

ifeq ($(UNAME_S),Darwin)
    CC = clang
else
    CC = gcc
endif

pp:
	$(CC) -E -P $(FILE_NAME).c -o $(FILE_NAME).i

asm: pp
	$(CC) -S -O -fno-asynchronous-unwind-tables -fcf-protection=none $(FILE_NAME).i
link: asm
	$(CC) $(FILE_NAME).s -o $(FILE_NAME)
	
clean:
	rm -f $(FILE_NAME).o $(FILE_NAME).s $(FILE_NAME).i

.PHONY: pp asm link clean
