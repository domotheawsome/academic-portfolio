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
.def	speed = r23				; holds speed
.def	doneWaiting = r24		; store if waiting is done
.equ	WskrR = 0				; Right Whisker Input Bit
.equ	WskrL = 1				; Left Whisker Input Bit
.equ	EngEnR = 4				; Right Engine Enable Bit
.equ	EngEnL = 7				; Left Engine Enable Bit
.equ	EngDirR = 5				; Right Engine Direction Bit
.equ	EngDirL = 6				; Left Engine Direction Bit
.equ	WaitTime = 100
.equ	BotAddress = $64 ;(Enter your robot's address here (8 bits))
.equ	T1Val = $0BDD			;timer value to wait 1 second

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

.org	$003C
		rcall USARTRecieve
		reti
.org	$001C
		rcall secondElapsed
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
	;timer
	ldi mpr, (1<<WGM00 | 1<<WGM01 | 1<<COM01| 1<<COM00 | 1<<CS02 | 0<<CS01 | 0<<CS00)
    out TCCR0, mpr    ;fast PWM, inverse mode, 64 prescale
    ldi mpr, (1<<WGM20 | 1<<WGM21 | 1<<COM21| 1<<COM20 | 1<<CS22 | 0<<CS21 | 0<<CS20)
    out TCCR2, mpr
    ldi mpr, 0
	out OCR2, mpr
    out OCR0, mpr
	;enable 16 bit counter
    ldi mpr, $00
    out TCCR1A, mpr    ;normal operation on all 3 channels
    ldi mpr, 0b00000100    ;256 prescale, normal mode
    out TCCR1B, mpr
    ldi mpr, 0b00000000    ;disable TOIE interrupt initially
    out TIMSK, mpr
	ldi freezeCount, 0
	ldi speed, 0
	sei
		;Set the External Interrupt Mask
		;Set the Interrupt Sense Control to falling edge detection

	;Other

;***********************************************************
;*	Main Program
;***********************************************************
MAIN:
		;write speed to display
		ldi mpr, 17
		mul mpr, speed	;get waveform for corresponding speed
		out OCR2, r0	;set to duty cycle
		out OCR0, r0

		in mpr, PORTB	;get current value of OCR and state
		cbr mpr, $0F	;clear bottom nibble, wrtie speed
		or mpr, speed
		out PORTB, mpr	;reoutput

		in mpr, PIND

		sbrs mpr, 0		;if hit right whisker is not cleared, call hit right
		rcall HitRight		;if so, call it

		sbrs mpr, 1		;if hit left whisker is not cleared, call hit right
		rcall HitLeft		;if so, call it

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
	cpi mpr, 0b11001000	;if speed up command, execute it
	breq SpeedUp
	cpi mpr, 0b11111000	;if speed down, execute it
	breq SpeedDown		
	lsl mpr				;otherwise, lsl signal and display it
	out PORTB, mpr
	rjmp SKIP

SpeedUp:
	cpi speed, 15	;if speed isnt at max, increment
	breq SKIP
	inc speed
	rjmp SKIP

SpeedDown:
	cpi speed, 0	;if speed isnt at min, decrement
	breq SKIP
	dec speed
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

	ldi mpr, 0b10010000	;display halt signal
	out PORTB, mpr
	ldi waitcnt, WaitTime	;wait for 5 seconds
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait
	rcall Lab1Wait

	inc freezeCount		;check if frozen 3 times
FULLSTOP:
	cpi freezeCount, 3	;if frozen 3 times, infinite loop until reset
	breq FULLSTOP
	
	out PORTB, mpr2

	ldi mpr, 0b00000011		;reenable interrupts
	out EIMSK, mpr
	lds		mpr, UCSR1B	
	ori 	mpr, 0b00010000	;reenable reception
	sts		UCSR1B, mpr
	rjmp SKIP

SKIP:
	pop mpr
	ret

;----------------------------------------------------------------
; Sub:	secondElapsed
; Desc:	sets the done waiting register to 1
;----------------------------------------------------------------
secondElapsed:
	ldi doneWaiting, 1
	ldi mpr, $FF		;clear latched interrupts
	out TIFR, mpr
	ret

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

		; Move Backwards for a second
		in mpr2, PORTB		
		out		PORTB, speed
		rcall IntWait

		; Turn left for a second
		ldi		mpr, 0b01000000	; Turn Right
		or mpr, speed 
		out		PORTB, mpr
		rcall IntWait		

		; Resume previous motion
		out		PORTB, mpr2

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

		; Move Backwards for a second Move Backward
		out		PORTB, speed
		rcall IntWait

		; Turn left for a second
		ldi		mpr, 0b00100000	; Turn Left 
		or		mpr, speed
		out		PORTB, mpr
		rcall IntWait

		; Resume previous motion
		out		PORTB, mpr2
		
		lds		mpr, UCSR1B	
		ori 	mpr, 0b00010000	;reenable reception
		sts		UCSR1B, mpr

		pop mpr2
		pop mpr
		ret

;----------------------------------------------------------------
; Sub:	IntWait
; Desc:	uses interrupts to wait 1 second
;----------------------------------------------------------------
IntWait:	
		push mpr

		ldi mpr, 0b00000000			;disable timer
		out TIMSK, mpr
		ldi mpr, $FF		;clear latched interrupts
		out TIFR, mpr
		cli

		ldi mpr, high(T1Val)    ;load 1 sec delay into TCNT
        out TCNT1H, mpr
        ldi mpr, low(T1Val)
        out TCNT1L, mpr

		clr doneWaiting		;set done waiting flag to 0
		sei
		ldi mpr, 0b00000100			;enable timer interrupt
		out TIMSK, mpr
WAIT:
		cpi doneWaiting, 1		;wait until interrupt triggers
		brne WAIT		

		ldi mpr, 0b00000000			;disable timer again
		out TIMSK, mpr
		
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
