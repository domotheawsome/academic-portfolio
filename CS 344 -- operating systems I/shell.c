
/******************************************************************
** Program: meshorea_program3.c
** Author: Ariel Meshorer
** Date: 05/03/2022
** Description: depending on user input, processes files and creates
		directories for with txt files for movie year and title
		information.
** Input: no input provided on command line, separate user input
	  given depending on the state.
** Output: output is printed to the terminal depending on user input.
	   directories are created with year.txt files with movie
           title information. 
*******************************************************************/
#define _POSIX_C_SOURCE        200809L

#include "shell.h" // including .h file



static struct sigaction SIGINT_action = {0}, SIGTSTP_action = {0};
// declaring sigaction struct for the signals
static int ctrlz = 0;
// declaring global variable to handle ctrlz signal



/*******************************************************************
** Function: handle_sigtstp()
** Description: handles the sigtstp signal, or ctrl-z.
** Parameters: int signo
** Pre-conditions: takes in the signal signo
** Post-conditions: returns void. prints one of two messages to the 
		    console.
********************************************************************/



void handle_sigtstp(int signo) {
	if (ctrlz == 0) { // checking if ctrl-z called previously
		printf("Entering foreground-only mode (& is now ignored)\n");
		fflush(stdout);
		//char * message  = "\nEntering foreground-only mode (& is now ignored)\n";
		//write(STDOUT_FILENO, message, 50);
		//fflush(stdout);
		ctrlz = 1; //sets ctrlz flag
	} else {
		printf("Exiting foreground-only mode\n"); fflush(stdout);
		//char * message  = "\nExiting foreground-only mode\n";
		//write(STDOUT_FILENO, message, 50);
		//fflush(stdout);
		ctrlz = 0; // resets ctrl-z
	}
}


/*******************************************************************
** Function: handle_sigint()
** Description: handles the ctrl-c signal.
** Parameters: int signo
** Pre-conditions: takes in the signal
** Post-conditions: returns void. prints message to the screen.
********************************************************************/
void handle_sigint(int signo)
{
    //printf("\nCaught signal in foreground process %d\n", sig);
	char* message = "\n";
	write(STDOUT_FILENO, message, 1);	
	fflush(stdout);
}
/*******************************************************************
** Function: resolve_redirect_filename()
** Description: handles states for i/o redirection in foreground/
		background processes.
** Parameters: struct command * userCommand, bool input
** Pre-conditions: takes in the userCommand struct and if the input
		  is true.
** Post-conditions: returns correct file to write output/read input
********************************************************************/
char * resolve_redirect_filename(struct command * userCommand, bool input) {
	if (!userCommand->background) { // checking if foreground process
		if(input) { // input
			return userCommand->rinput;
		} else { // output
			return userCommand->routput;
		}
	} else { // background process
		if(input) { // input
			if(userCommand->rinput == NULL) {
				return "/dev/null";
			} else {
				return userCommand->rinput;
			}
		} else { // output
			if(userCommand->routput == NULL){
				return "/dev/null";
			} else {
				return userCommand->routput;
			}
		}
	}
}
/*******************************************************************
** Function: do_redirect()
** Description: performs the i/o redirection functionality.
** Parameters: struct command * userCommand, shell_t * userShell
** Pre-conditions: takes the userCommand and userShell struct
** Post-conditions: returns if i/o redirection was successful
********************************************************************/
int do_redirect(struct command * userCommand, shell_t *  userShell) {
	bool input = false;
	// checking if i/o redirection should be done. 0 to return.
	if (!userCommand->background &&
		userCommand->routput == NULL && 
		userCommand->rinput == NULL) {
		return 0;
 	}

	// getting correct files/ file paths
	char * inputFileName = resolve_redirect_filename(userCommand, true);
	char * outputFileName = resolve_redirect_filename(userCommand, false);
	
	// i/o handling for output
	// taken from the process i/o exploration module
	if(outputFileName != NULL) {
		errno = 0;
		int outputFD = open(outputFileName, O_WRONLY | O_CREAT | O_TRUNC, 0644);
		// error handling for fd
		if ( outputFD == -1) {
			printf("cannot open %s for output\n", outputFileName);
			userShell->status = 1;
			return errno;
		}
		// written to terminal
		int result = dup2(outputFD, 1);
		if (result == -1) {			
			userShell->status = 1;
			return errno;
		}
		
	}
	// i/o handling for input	
	if ( inputFileName != NULL) {
		errno = 0;
		int inputFD = open(inputFileName, O_RDONLY);
		if ( inputFD == -1) {
			printf("cannot open %s for input\n", inputFileName);
			userShell->status = 1;			
			return errno;
		}
		// written to terminal
		
		int result = dup2(inputFD, 0);
		if (result == -1) {
			userShell->status = 1;			
			return errno;
		}
		
	}
	// return 0 when complete
	return 0;
}

/*******************************************************************
** Function: get_path()
** Description: gets the path for execvp()
** Parameters: struct command * userCommand
** Pre-conditions: takes the user Command struct
** Post-conditions: returns the correct path for exec
********************************************************************/
char * get_path(struct command * userCommand) {// /bin
	char * path = getenv("PATH");
	char buff[2056];
	strcpy(buff, path);
	char* list[512];
	list[0] = strtok(buff, ":");
	int i = 0;
	// slicing the directory list
	while(list[i] != NULL ) {
		list[++i] = strtok(NULL, ":");		
	}
	
	int length = i;

	// searcing through the directory to find the correct path
	for (i = 0 ; i < length ; i++) {
		DIR * currDir = opendir(list[i]);
		struct dirent *aDir;
		while(currDir) {
			errno = 0;
			if ((aDir = readdir(currDir)) !=NULL) {
				// do not care about local dir
				if (strcmp(aDir->d_name,".") == 0) {
					continue;
				}
				if (strcmp(aDir->d_name,"..") == 0) {
					continue;
				}			
				if (strcmp(aDir->d_name, userCommand->args[0]) == 0) {
					closedir(currDir);		
					return list[i];
				}	
			} else {
				break;				
			}			
		}
	}
	// returning if no directory/path exists
	printf("%s: no such file or directory\n",userCommand->cmd);
	exit(1);
}
/*******************************************************************
** Function: do_exec()
** Description: completes the exec command functionality, searches
		through execvp()
** Parameters: struct command * userCommand, shell_t * userShell
** Pre-conditions: takes in the userCommand and userShell
** Post-conditions: returns nothing, performs the exec command
********************************************************************/
int do_exec(struct command * userCommand, shell_t * userShell) {
	//printf("usercommand: %s", userCommand->cmd);
	int length = userCommand->argsEnd - userCommand->argStart;	
	//char * path = get_path(userCommand);
	userCommand->args[userCommand->argsEnd+1] = NULL;
	// returning the correct command
	int status = execvp(userCommand->cmd, userCommand->args);
	// error handling if execvp failed
	if (status  == -1) {
		perror("process did not terminate");
		userShell->status = 1;
		exit(1);
	}
	return 0;
}

/*******************************************************************
** Function: do_status()
** Description: returns the exit status or terminating signal of 
		the last foreground process
** Parameters: shell_t * userShell
** Pre-conditions: takes in the userShell to access the status
** Post-conditions: returns nothing, prints the status to the terminal
********************************************************************/
int do_status(shell_t * userShell) {
	if (userShell->terminating_signal != -1) {
		printf("terminated by signal %d\n",userShell->terminating_signal); fflush(stdout);	
	} else {
		printf("exit value %d\n",userShell->status); fflush(stdout);
	}
	return 0;
}

/*******************************************************************
** Function: do_cd()
** Description: performs the cd functionality, moves to a different
		directory in the path
** Parameters: struct command * userCommand
** Pre-conditions: takes in the userCommand struct to get the dir
		   to cd into
** Post-conditions: returns nothing, moves the shell to the correct 
		    dir
********************************************************************/
int do_cd(struct command * userCommand) {
	char buf[PATH_MAX]; 
	errno = 0;
	char * currentpath = getcwd(buf, sizeof(buf)); // getting current path
	// error handling for path
	if (currentpath == NULL) {
		return errno;
	}
	// getting homepath
	char * homepath = getenv("HOME");
	if (homepath == NULL) {
		perror("getcwd() error,cannot find HOME");
		return 1;
	}

	//end testing
	if(userCommand->args[1] == NULL) {
		errno = 0;
		int err = chdir(homepath); // changing directory
		// error handling for directory
		if (err != 0) {
			perror("chdir() error");	
			return errno;
		}
	} else {
		int err = chdir(userCommand->args[1]);	// changing dir	
		// error handling for dir		
		if (err != 0) {
			perror("chdir() error");	
			return errno;
		}
	}

	errno = 0;
	// getting current path
	currentpath = getcwd(buf, sizeof(buf));
	if (currentpath == NULL) {
		perror("getcwd() error");	
		return errno;
	}	
	
	return 0;
}


/*******************************************************************
** Function: do_exit()
** Description: exits the shell and kills all running background 
		processes
** Parameters: shell_t userShell
** Pre-conditions: takes the user shell, which stores an array 
		   of the running background PIDs
** Post-conditions: returns 0, exits the function
********************************************************************/
int do_exit(shell_t * userShell) {
	process_t * temp = userShell->head;	
	// killing each background process in linked list
	while(temp!=NULL) {
		kill(temp->pid, SIGKILL);	
		temp = temp->next;		
	}
	exit(0);	
	return 0;
}

/*******************************************************************
** Function: do_foreground_fork()
** Description: performs forking for the foreground processes.
** Parameters: struct command * userCommand, shell_t * userShell
** Pre-conditions: takes in the userCommand struct and the userShell
		   struct to 
** Post-conditions: returns the exit status or terminating signal
********************************************************************/
void do_foreground_fork(struct command * userCommand, shell_t * userShell) {
	// foreground = no &
	int status;
	pid_t pid = fork(); // performing the fork
	pid_t w; // temp pid
	userShell->terminating_signal = -1; //init the field
	if ( pid == 0) { // child process
		sigaction(SIGTSTP, &SIGTSTP_action, NULL); //handling ctrl-z	
		// performing redirect
		int redirect = do_redirect(userCommand, userShell); // performing redirect
		// if redirect succesful, perform the exec
		if (redirect == 0) {
			do_exec(userCommand, userShell);
			exit(0);
		// exit with exit status 1
		} else {
			exit(1);
		}			
	} else {
		do {
	// set temp pid
            w = waitpid(pid, &status, WUNTRACED | WCONTINUED);
            //if (w == -1) {
            //    perror("waitpid");
            //    exit(EXIT_FAILURE);
            //}
           // check until exit status/terminating signal is not -1
        } while (!WIFEXITED(status) && !WIFSIGNALED(status));
		// handle exit status
		if ( WIFEXITED(status)) {
			int exit_status = WEXITSTATUS(status);
			//setting exit status			
			userShell->status = exit_status;
//			do_status();
			//exit(exit_status);
		// handle terminating signal
		} else {
			int sig = WTERMSIG(status);
			fprintf(stderr, "terminated by signal %d\n", sig);
			// setting terminating signal
			userShell->terminating_signal = sig;
//			do_status();
			//exit(sig);
		}
	}
}

/*******************************************************************
** Function: do_background_fork()
** Description: performs forking for the foreground processes
** Parameters: struct command * userCommand, shell_t * userShell
** Pre-conditions: takes the userCommand struct and userShell struct
** Post-conditions: appends a node to the linked list with the
		    running background pid, returns functionality 
		   immeaditely to the user
********************************************************************/
void  do_background_fork(struct command * userCommand, shell_t * userShell) {
	errno = 0;
	pid_t w;
	int status;	
	pid_t pid = fork(); // perform fork
	if (pid == -1) { // fork failed
		userShell->status = errno;
		printf("failed to fork\n");
		fflush(stdout);

	} else if ( 0 == pid) { //child
		// signal handling for ctrl-z	
		sigaction(SIGTSTP, &SIGTSTP_action, NULL);
		// signal handling for ctrl-c
		SIGINT_action.sa_handler = SIG_DFL;
		sigaction(SIGINT, &SIGINT_action, NULL);
		int child_pid = getpid(); // child process
		//printf("background pid is %d\n",child_pid); fflush(stdout);
		// performing redirect
		int redirect_status = do_redirect(userCommand, userShell);
		// error handling for redirect
		if (redirect_status != 0) {
			printf("redirect failed %d\n",redirect_status);
			fflush(stdout);
			exit(1);
		} else {
			// performing exec
			do_exec(userCommand, userShell);
			userShell->status = 0;
			exit(0);
		}
	} else { // parent
		//pid = getpid();
		// saving background processes into a linked list
		printf("background pid is %d\n",pid); fflush(stdout);
		process_t * node = (process_t *)malloc(sizeof(process_t));
		node->pid = pid;
		node->next = userShell->head;
		userShell->head = node;
		userShell->status = 0;
		check_background_processes(userShell);
		/*
		int result = waitpid(pid, &status, WNOHANG); // WNOHANG for background
		if (result != 0) {
			if ( WIFEXITED(status)) {
				int exit_status = WEXITSTATUS(status);			
				userShell->status = exit_status;
				fprintf(stdout, "%d\n", exit_status); fflush(stdout);
				
			} else {
				int sig = WTERMSIG(status);
				fprintf(stderr, "terminated by %d\n", sig); fflush(stdout);
				userShell->terminating_signal = sig;
				fprintf(stdout, "%d\n", sig);
				
			}
		}
		*/
		

	}
}

/*******************************************************************
** Function: do_command()
** Description: direct shell to corresponding functionality from
** Parameters: struct command * userCommand, shell_t * userShell
** Pre-conditions: takes userCommand struct and userShell struct to
		   get user command
** Post-conditions: returns 0 if successful, directs shell to correct
		    function
********************************************************************/
int do_command(struct command * userCommand, shell_t * userShell) {
	// can you declare the is/do methods like in c++
	// printf("ctrlz: %d\n", ctrlz);	
	// in background only mode
	if (ctrlz == 1) {
		userCommand->background = false;
	}
	if (userCommand->cmd == NULL) {
		return 0;
	} else if (!strcmp(userCommand->cmd, "exit")) {	
		return do_exit(userShell);
	} else if (!strcmp(userCommand->cmd, "cd")) {
		return do_cd(userCommand);
	} else if (!strcmp(userCommand->cmd, "status")) {
		return do_status(userShell);
	} else {
		if (userCommand->background == true){
			do_background_fork(userCommand, userShell);	
		} else {
			do_foreground_fork(userCommand, userShell);			
		}			
	}
	return 0;
}


/*******************************************************************
** Function: is_comment()
** Description: checking for comments
** Parameters: char command
** Pre-conditions: takes the first char of the command line
** Post-conditions: returns if the user entered a command or not
********************************************************************/
int is_comment( char command ) {
	if( command == '#'){
		return 1;
	}
	return 0;
}

/*******************************************************************
** Function: parse_command()
** Description: parses the user command and sorts into the userCommand
		struct 
** Parameters: char * cmdline
** Pre-conditions: takes in the user commandline
** Post-conditions: returns a complete struct with user input
********************************************************************/
struct command * parse_command(char * cmdline) {
	// creating struct
	struct command *userCommand = (struct command *) malloc(sizeof(struct command));
   	// initializing struct
	userCommand->cmd = NULL;
   	userCommand->routput = NULL;
   	userCommand->rinput  = NULL;
   	userCommand->argStart = 1; //
   	userCommand->argsEnd  = 0;
   	userCommand->background = false;
   	userCommand->comment    = false;
   	userCommand->length     = 0;
	// checking if comment
   	if ( is_comment(cmdline[0]) == 1) {
		userCommand->comment    = true;
		return userCommand;
	}	

// cmd = arg[0]
// arguments = arg[argStart] -> arg[argEnd]
	char buff[512];
	strcpy(buff, cmdline);
	bool var_expan = false;

	int i = 0;


	// tokenizing commands into one arg array
	userCommand->args[0] = strtok(buff, " ");
	// tokenizing command into argument
	while(userCommand->args[i] != NULL ) {
		userCommand->args[++i] = strtok(NULL, " ");
	}
	// saving length of args array
	userCommand->length = i;
	// storing command
	userCommand->cmd = userCommand->args[0];
	int argCounter = 0;
	bool endOfArg = false;
	bool setArgEnd = false;
	// sorting args array into respective fields
	for(int i = userCommand->argStart; i < userCommand->length ; i++) {
		argCounter++;
		// if there is an input file specified
		if(strcmp(userCommand->args[i], "<") == 0) {
			userCommand->rinput = userCommand->args[i+1];
			if(userCommand->argsEnd == 0) {
				if (!setArgEnd) {
					userCommand->argsEnd = i - 1;
					setArgEnd = true;
				}
			}
		}
		// if there is an output file specified
		if(strcmp(userCommand->args[i], ">") == 0) {
			userCommand->routput = userCommand->args[i+1];
			if(userCommand->argsEnd == 0 ) {
				if(!setArgEnd) {
					userCommand->argsEnd = i - 1;
					setArgEnd = true;
				}
			}
		}	
		// if the process should run in the background
		if(strcmp(userCommand->args[i], "&") == 0) {
			if(userCommand->argsEnd == 0) {
				if(!setArgEnd) {
					userCommand->argsEnd = i - 1;
					setArgEnd = true;
				}
			}
			userCommand->background = true;
		}	
	}

	// if we do not have any special char, assign the args end to the number of args.
	if(userCommand->routput == NULL && userCommand->rinput == NULL && !userCommand->background && userCommand->argsEnd == 0) {
		userCommand->argsEnd = argCounter;
	}

	// if you dont find any arguments, then you set it to -1.
	//
	//for( int j = userCommand->argStart ; j <= userCommand->argsEnd ; j++) {
	//	printf("arguments: %s\n", userCommand->args[j]);
	//}	
	
	// argsEnd is where the arguments of the command ends
	//printf("cmd: %s\n", userCommand->cmd);
	//printf("routput: %s\n", userCommand->routput);
	//printf("rinput: %s\n", userCommand->rinput);
	//printf("background: %d\n", userCommand->background);
/*
	if (userCommand->args[1] != NULL) {
		userCommand = var_expansion(userCommand);
	}
*/	

	//printf("argstart: %d\n", userCommand->argStart);
	//printf("argend: %d\n", userCommand->argsEnd);
	// performing var expansion
	for (int k = userCommand->argStart ;  k <= userCommand->argsEnd ; k++) {
		var_expan = false;
		for(int l = 0 ; l < strlen(userCommand->args[k]) ; l++) {
			//printf("%c\n", userCommand->args[k][l]);
			if( userCommand->args[k][l] == '$' && userCommand->args[k][l] == '$') {
				userCommand->args[k][l] = '\0';
				//userCommand->args[k][l+1] = '\0';
				//char buff2[80];
				userCommand->args[k][l+1], getpid();
				sprintf(userCommand->args[k], "%s%d", userCommand->args[k], getpid());	
				// come up with temporary variable	
			//puts(userCommand->args[k]);
			}
		}
		
	}
	// return user command struct
	return userCommand;
}



/*******************************************************************
** Function: check_background_processes()
** Description: checking if any background processes exit, printing
		their exit status
** Parameters: shell_t userShell
** Pre-conditions: takes the userShell struct
** Post-conditions: returns void, prints the exit status, terminating
	            signal to the terminal
********************************************************************/

void check_background_processes(shell_t * userShell) {
	// iterate on the shell and check if the process existed
	pid_t pid;
	int child_status;
	// waiting on exit status
	while ((pid = waitpid(-1,&child_status,WNOHANG)) > 0 ) {
		// terminating signal
		if (WIFSIGNALED(child_status)) {
			int sig = WTERMSIG(child_status);
			printf("background pid %d is done: terminated by signal %d\n",pid,sig); fflush(stdout);
			userShell->terminating_signal = sig;
		// exit status
		} else {
			int status = WEXITSTATUS(child_status);
			printf("background pid %d is done\n",pid); fflush(stdout);
			userShell->status = status;
			do_status(userShell);
		}
	}
	
	

}


/*******************************************************************
** Function: show_prompt()
** Description: takes in the user input and parses/calls the command
		menu
** Parameters: shell_t * userShell
** Pre-conditions: takes in the userShell
** Post-conditions: returns 0 if successful, calls the do_command
		    to complete the rest of the program
********************************************************************/
int show_prompt(shell_t * userShell) {
	char * command; (char *)malloc(sizeof(char) * 2048);
	//char command[2048];
	bool exit = true;
	while(exit == true) {
		command = (char *)malloc(sizeof(char) * 2048);
		// if not foreground only mode, check background processes.
		if (ctrlz == 0) {
			check_background_processes(userShell);
		}
		// printing command line
		printf(": "); fflush(stdout);	// printing semicolon
		char *status = fgets(command, 2048, stdin);// recieving input
		// error handling for status; if null, exit
		if ( status != NULL) {
			command[strcspn(command, "\n")] = '\0'; // removing /n
			struct command * userCommand = parse_command(command); // storing user struct
			do_command(userCommand, userShell); // performing command
			free(userCommand);
		}
	}
	//free(command);
	return 0;
}


/*******************************************************************
** Function: main()
** Description: calls the program, initializes signal handling
** Parameters: int argv, char ** argc[]
** Pre-conditions: takes in nothing
** Post-conditions: returns EXIT_SUCCESS if successful
********************************************************************/
int main(int argv, char ** argc[]) {

//	ignoring sigint
	SIGINT_action.sa_handler = handle_sigint;
	// block all catchable signals while handle_sigint is running
	sigfillset(&SIGINT_action.sa_mask);
	// no flags set
 	SIGINT_action.sa_flags = 0;
	sigaction(SIGINT, &SIGINT_action, NULL);


//	ignoring sigtstp
	SIGTSTP_action.sa_handler = handle_sigtstp;
	// block all catchable signals while handle_sigint is running
	sigfillset(&SIGTSTP_action.sa_mask);
	// no flags set
	SIGTSTP_action.sa_flags = 0;
	sigaction(SIGTSTP, &SIGTSTP_action, NULL);

	// initalize userShell
	shell_t * userShell = (shell_t *)malloc(sizeof(shell_t));
	userShell->status = 0;
	userShell->terminating_signal = -1;
	// until program is exited
	while(1) {
		show_prompt(userShell);
	}
	return EXIT_SUCCESS;
}


