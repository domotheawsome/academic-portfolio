;***********************************************************
;*
;*	This is the TRANSMIT skeleton file for Lab 8 of ECE 375
;*
;*	 Author: Jordan Brantner and Ariel Meshorer
;*	   Date: 3/8/22
;*
;***********************************************************

.include "m128def.inc"			; Include definition file

;***********************************************************
;*	Internal Register Definitions and Constants
;***********************************************************
.def	mpr = r16				; Multi-Purpose Register
.def	mpr2 = r17
.def	waitcnt = r18			;wait count reg
.def	ilcnt = r19				;inner loop count reg
.def	olcnt = r20				;outer loop count reg

.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit

.equ	BotAddress = $64;(Enter your robot's address here (8 bits))
; Use these action codes between the remote and robot
; MSB = 1 thus:
; control signals are shifted right by one and ORed with 0b10000000 = $80
.equ	MovFwd =  ($80|1<<(EngDirR-1)|1<<(EngDirL-1))	;0b10110000 Move Forward Action Code
.equ	MovBck =  ($80|$00)								;0b10000000 Move Backward Action Code
.equ	TurnR =   ($80|1<<(EngDirL-1))					;0b10100000 Turn Right Action Code
.equ	TurnL =   ($80|1<<(EngDirR-1))					;0b10010000 Turn Left Action Code
.equ	Halt =    ($80|1<<(EngEnR-1)|1<<(EngEnL-1))		;0b11001000 Halt Action Code
.equ	WaitTime = 1
.equ	BaudVal = 832
;***********************************************************
;*	Start of Code Segment
;***********************************************************
.cseg							; Beginning of code segment

;***********************************************************
;*	Interrupt Vectors
;***********************************************************
.org	$0000					; Beginning of IVs
		rjmp 	INIT			; Reset interrupt
.org	$0046					; End of Interrupt Vectors

;***********************************************************
;*	Program Initialization
;***********************************************************
INIT:
	;Stack Pointer (VERY IMPORTANT!!!!)
	ldi mpr, low(RAMEND)
	out SPL, mpr
	ldi mpr, high(RAMEND)
	out SPH, mpr
	;I/O Ports
	ldi mpr, $00
	out DDRD, mpr	;initialize port D for input
	ldi mpr, $FF
	out PORTD, mpr	;enable pull up resistors
	out DDRB, mpr	;initialize port B for output
	;USART1
	ldi mpr, (0<<UMSEL1 | 0<<UPM10 | 0<<UPM11 | 1<<USBS1 | 1<<UCSZ11 | 1<<UCSZ10)
	sts UCSR1C, mpr
	ldi mpr, (0<<TXCIE1|1<<TXEN1|0<<UDRIE1|0<<UCSZ12)
	sts UCSR1B, mpr
	ldi mpr, (1<<U2X1)	;enable double data rate
	sts UCSR1A, mpr
	ldi mpr, low(BaudVal)
	sts UBRR1L, mpr
	ldi mpr, high(BaudVal)
	sts UBRR1H, mpr
		;Set baudrate at 2400bps
		;Enable receiver and enable receive interrupts
		;Set frame format: 8 data bits, 2 stop bits
	;External Interrupts
		;Set the External Interrupt Mask
		;Set the Interrupt Sense Control to falling edge detection

	;Other
	ldi mpr, 1

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		in mpr, PIND

		mov mpr2, mpr			;get PIND
		andi mpr2, 0b00000001	;check if forwards
		breq MOVE_FORWARD		;if so, jump to forwards branch

		mov mpr2, mpr
		andi mpr2, 0b00000010	;poll for backwards
		breq MOVE_BACKWARDS

		mov mpr2, mpr
		andi mpr2, 0b01000000	;poll for halt
		breq STOP

		mov mpr2, mpr
		andi mpr2, 0b10000000	;poll for freeze
		breq FREEZE

		mov mpr2, mpr
		andi mpr2, 0b00100000	;poll for turn left
		breq TURN_LEFT

		mov mpr2, mpr
		andi mpr2, 0b00010000	;poll for right
		breq TURN_RIGHT

		rjmp	MAIN

MOVE_FORWARD:
		ldi mpr, 0b10110000		;load mpr with respective code
		rcall DeploySignal		;call deploy signal to send code
		rjmp	MAIN			;resume polling
MOVE_BACKWARDS:
		ldi mpr, 0b10000000		;deploy back signal
		rcall DeploySignal
		rjmp	MAIN
TURN_RIGHT:
		ldi mpr, 0b10100000		;deploy right signal
		rcall DeploySignal
		rjmp	MAIN
TURN_LEFT:
		ldi mpr, 0b10010000		;deploy left signal
		rcall DeploySignal
		rjmp	MAIN
FREEZE:
		ldi mpr, 0b11111000		;deploy freeze signal
		rcall DeploySignal
		rjmp	MAIN
STOP:
		ldi mpr, 0b11001000		;deploy stop signal
		rcall DeploySignal
		rjmp	MAIN
		


;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;Deploy Signal outputs the bot address out to USART, and then
;outputs the signal stored in mpr to the USARt to create a full
;16 bit packet
DeploySignal:
		push mpr
		push mpr2
Retry:
		lds		mpr2, UCSR1A	;check if transmit is available
		sbrs	mpr2, UDRE1
		rjmp	Retry	;if not, go back

		;transmit bot code
		ldi mpr2, BotAddress	;send Bot code to usard
		sts		UDR1, mpr2

		ldi waitcnt, WaitTime	;wait 10 ms to separate bot address and data packets
		rcall Lab1Wait

TRANSMIT_INSTRUCTION:
		lds		mpr2, UCSR1A	;check if bot code has been sent
		sbrs	mpr2, UDRE1
		rjmp	TRANSMIT_INSTRUCTION
		sts		UDR1, mpr		;send 8 bit command to usart

		pop mpr2
		pop mpr
		ret

;----------------------------------------------------------------
; Sub:	Lab1Wait
; Desc:	A wait loop that is 16 + 159975*waitcnt cycles or roughly 
;		waitcnt*10ms.  Just initialize wait for the specific amount 
;		of time in 10ms intervals. Here is the general eqaution
;		for the number of clock cycles in the wait loop:
;			((3 * ilcnt + 3) * olcnt + 3) * waitcnt + 13 + call
;----------------------------------------------------------------
Lab1Wait:
		push	waitcnt			; Save wait register
		push	ilcnt			; Save ilcnt register
		push	olcnt			; Save olcnt register

Loop:	ldi		olcnt, 224		; load olcnt register
OLoop:	ldi		ilcnt, 237		; load ilcnt register
ILoop:	dec		ilcnt			; decrement ilcnt
		brne	ILoop			; Continue Inner Loop
		dec		olcnt		; decrement olcnt
		brne	OLoop			; Continue Outer Loop
		dec		waitcnt		; Decrement wait 
		brne	Loop			; Continue Wait loop	

		pop		olcnt		; Restore olcnt register
		pop		ilcnt		; Restore ilcnt register
		pop		waitcnt		; Restore wait register
		ret				; Return from subroutine
