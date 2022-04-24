;***********************************************************
;*
;*	This is the RECEIVE skeleton file for Lab 8 of ECE 375
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
.def	addressReg = r17		;stores if the code is correct or not
.def	waitcnt = r18			;wait count reg
.def	ilcnt = r19				;inner loop count reg
.def	olcnt = r20				;outer loop count reg
.def	mpr2 = r21				;second mpr
.def	freezeCount = r22		;count times it has frozen
.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
.equ	WaitTime = 100
.equ	BotAddress = $64 ;(Enter your robot's address here (8 bits))

;/////////////////////////////////////////////////////////////
;These macros are the values to make the TekBot Move.
;/////////////////////////////////////////////////////////////
.equ	MovFwd =  (1<<EngDirR|1<<EngDirL)	;0b01100000 Move Forward Action Code
.equ	MovBck =  $00						;0b00000000 Move Backward Action Code
.equ	TurnR =   (1<<EngDirL)				;0b01000000 Turn Right Action Code
.equ	TurnL =   (1<<EngDirR)				;0b00100000 Turn Left Action Code
.equ	Halt =    (1<<EngEnR|1<<EngEnL)		;0b10010000 Halt Action Code

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

.org	$0002
		rcall HitRight
		reti
.org	$0004
		rcall HitLeft
		reti
.org	$003C
		rcall USARTRecieve
		reti
;Should have Interrupt vectors for:
;- Left whisker
;- Right whisker
;- USART receive

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
	ldi mpr, (1<<RXCIE1|1<<RXEN1|0<<UCSZ12)
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
	ldi mpr, 0b00001010
	sts EICRA, mpr
	ldi mpr, 0b00000011
	out EIMSK, mpr
	ldi freezeCount, 0
	sei
		;Set the External Interrupt Mask
		;Set the Interrupt Sense Control to falling edge detection

	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
	;TODO: ???
		rjmp	MAIN

;***********************************************************
;*	Functions and Subroutines
;***********************************************************
;----------------------------------------------------------------
; Sub:	USARTRecieve
; Desc: checks if the USART signal is an address or a command. If it was
;		an address, it check if it matches the hard coded address.
;		if it was a command, it displays it on the board if the last
;		address was the matching address
;----------------------------------------------------------------
USARTRecieve:
	push mpr

	lds mpr, UDR1
	sbrs mpr, 7			;if it starts with a 0, then check if valid address
	rjmp CHECK_ADDRESS	;else, perform an operation
	rjmp PERFORM_OP

PERFORM_OP:
	cpi addressReg, 1	;LSL if the signal left, then display on lights
	brne SKIP1
	cpi mpr, 0b11111000
	breq TRANSMIT_FREEZE
	lsl mpr
	out PORTB, mpr
	rjmp SKIP

CHECK_ADDRESS:
	cpi mpr, 0b01010101
	breq FREEZE
	cpi mpr, BotAddress	;check if address matches
	ldi addressReg, 0	;set boolean addressreg to 0 if it doesnt
	brne SKIP
	ldi addressReg, 1
SKIP1:	
	rjmp SKIP

FREEZE:
	lds		mpr, UCSR1B	
	andi 	mpr, 0b11101111	;disable reception
	sts		UCSR1B, mpr
	ldi mpr, 0b00000000		;disable interrupts
	out EIMSK, mpr

	in mpr2, PORTB

	ldi mpr, 0b11110000		;display halt signal
	out PORTB, mpr
	ldi waitcnt, WaitTime	;wait for 5 seconds
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait

	inc freezeCount		;check if frozen 3 times
FULLSTOP:
	cpi freezeCount, 3
	breq FULLSTOP		;if frozen 3 times, infinite loop until reset
	
	out PORTB, mpr2

	ldi mpr, 0b00000011		;reenable interrupts
	out EIMSK, mpr
	lds		mpr, UCSR1B	
	ori 	mpr, 0b00010000	;reenable reception
	sts		UCSR1B, mpr
	rjmp SKIP

TRANSMIT_FREEZE:
	;set to transmitter, turn off reciever
	ldi mpr, (0<<TXCIE1|1<<TXEN1|0<<UDRIE1|0<<UCSZ12|0<<RXEN1)
	sts UCSR1B, mpr

DeploySignal:
	lds		mpr, UCSR1A	;check if transmit is available
	sbrs	mpr, UDRE1
	rjmp	DeploySignal	;if not, go back

	;transmit bot code
	ldi mpr, 0b01010101	;send freeze code to usart
	sts		UDR1, mpr

DoneSending:
	lds		mpr, UCSR1A	;check if transmit is available
	sbrs	mpr, TXC1
	rjmp	DoneSending	;if not, go back

	ldi waitcnt, 10
	rcall Lab1Wait

	;set back to recieve
	ldi mpr, (1<<RXCIE1|1<<RXEN1|0<<UCSZ12|0<<TXEN1)
	sts UCSR1B, mpr
	rjmp SKIP
SKIP:
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

;----------------------------------------------------------------
; Sub:	HitLeft
; Desc:	moves back for 1 second, turns right for 1 second, then resume
;	previous motion all while ignoring usart interrupts
;----------------------------------------------------------------
HitLeft:
		;get previous state
		push mpr
		push mpr2

		lds		mpr, UCSR1B	
		andi 	mpr, 0b11101111	;disable reception
		sts		UCSR1B, mpr
		in mpr2, PORTB
		; Move Backwards for a second
		ldi		mpr, 0b00000000	; Move Backward
		out		PORTB, mpr
		ldi		waitcnt, WaitTime	; Wait for 1 second
		rcall	Lab1Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, 0b01000000	; Turn Right 
		out		PORTB, mpr
		ldi		waitcnt, WaitTime	; Wait for 1 second
		rcall	Lab1Wait			; Call wait function

		; Resume previous motion
		out		PORTB, mpr2
		ldi mpr, $FF
		out EIFR, mpr	;clear latched interupts

		lds		mpr, UCSR1B	
		ori 	mpr, 0b00010000	;reenable reception
		sts		UCSR1B, mpr

		pop mpr2
		pop mpr
		ret

;----------------------------------------------------------------
; Sub:	HitRight
; Desc:	moves back for 1 second, turns left for 1 second, then resume
;	previous motion all while ignoring usart interrupts
;----------------------------------------------------------------
HitRight:

		push mpr
		push mpr2

		lds		mpr, UCSR1B	
		andi 	mpr, 0b11101111	;disable reception
		sts		UCSR1B, mpr
		in mpr2, PORTB	;get previous state

		; Move Backwards for a second
		ldi		mpr, 0b00000000	; Move Backward
		out		PORTB, mpr
		ldi		waitcnt, WaitTime	; Wait for 1 second
		rcall	Lab1Wait			; Call wait function

		; Turn left for a second
		ldi		mpr, 0b00100000	; Turn Left 
		out		PORTB, mpr
		ldi		waitcnt, WaitTime	; Wait for 1 second
		rcall	Lab1Wait			; Call wait function

		; Resume previous motion
		out		PORTB, mpr2
		ldi		mpr, $FF
		out		EIFR, mpr	;clear latched interupts
		
		lds		mpr, UCSR1B	
		ori 	mpr, 0b00010000	;reenable reception
		sts		UCSR1B, mpr

		pop mpr2
		pop mpr
		ret