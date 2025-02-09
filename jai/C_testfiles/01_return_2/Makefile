UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
    CC = clang
else
    CC = gcc
endif

run:
	$(CC) -S -O -fno-asynchronous-unwind-tables -fcf-protection=none return_2.c
