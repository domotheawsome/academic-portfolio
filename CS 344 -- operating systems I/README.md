# CS 344: Operating Systems

Introduction to operating systems using UNIX as the case study. System calls and utilities, fundamentals of processes and interprocess communication.

Completed in Spring 2022. 

## Details:

This is a small shell clone written in C that implements a subset of features of well-known shells, such as bash. This program does the following:
<ol>
  <li>Provide a prompt for running commands</li>
<li>Handle blank lines and comments, which are lines beginning with the # character</li>
<li>Provide expansion for the variable $$</li>
<li>Execute 3 commands exit, cd, and status via code built into the shell</li>
<li>Execute other commands by creating new processes using a function from the exec family of functions</li>
<li>Support input and output redirection</li>
<li>Support running commands in foreground and background processes</li>
<li>Implement custom handlers for 2 signals, SIGINT and SIGTSTP</li>
</ol>

## To run the program:

make
run test script
