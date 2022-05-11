.PHONY: smallsh tar run clean

smallsh: shell.c shell.h
	gcc -g --std=c99 -o smallsh shell.c 
	
shelltest: shelltest.c shell.c shell.h
	gcc --std=c99 -o shelltest shelltest.c shell.c

tar: smallsh shelltest
	tar -czvf assign3.tar shell.c shell.h Makefile shell

run:
	./shell

clean:
	rm smallsh
all: clean smallsh

