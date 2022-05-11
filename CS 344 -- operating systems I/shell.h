#ifndef SHELL_H
#define SHELL_H

#define _POSIX_C_SOURCE        200809L

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <sys/types.h>
#include <unistd.h>
#include <signal.h>
#include <limits.h>
#include <sys/wait.h>
#include <dirent.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>

struct command 
{
	char * cmd;
	char * args[512]; // will recieve no more than 512 arg
	char * routput;
	char * rinput;
	int argStart;
	int argsEnd;
	bool comment;
	bool  background;
	int length;
};

typedef struct Process {
	pid_t pid;
	struct Process * next;
} process_t;

typedef struct Shell{
	process_t * head;
	int status; // hold the exit
	int terminating_signal; // hold the terminated signal
} shell_t;


void check_background_processes(shell_t * userShell);

int handle_sigstep();

int background_exec(struct command * cmdline);

int foreground_exec(struct command * cmdline);

char * resolve_redirect_filename(struct command * userCommand, bool input);

int do_redirect(struct command * userCommand, shell_t* userShell);

char * get_path(struct command * userCommand);

int do_exec(struct command * userCommand, shell_t *  userShell);

int do_status();

int do_cd(struct command * userCommand);

int do_exit(shell_t * userShell);

void do_foreground_fork(struct command * userCommand, shell_t * userShell);

void  do_background_fork(struct command * userCommand, shell_t * userShell);

int do_command(struct command * userCommand, shell_t * userShell);

struct command * var_expansion();

//int var_expansion_checker(char command, bool var_expan);

int comment_checker( char command );

struct command * parse_command(char * cmdline);

int show_prompt(shell_t* userShell);

#endif
