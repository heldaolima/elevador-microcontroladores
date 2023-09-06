jmp reset

.def temp = r16 ; used for configuration
.def countSeconds = r17 ; counts how many seconds have passed
.def currentFloor = r18 ; keeps the current floor of the elevator
.def calledFloor = r18
.def currentElevatorStatus = r19


; elevator status consts
#define IDLE 0 ; elevator stopped
#define GOING_DOWN 1 ; elevator is going up
#define GOING_UP 2 ; elevator is going down

; current floor consts 
#define GROUND_FLOOR 0
#define FIRST_FLOOR 1
#define SECOND_FLOOR 2

; BEGIN Consts for setting up the timer
#define TOP_LIMIT 65535
#define CLOCK 16 ; clock speed
#define TimerDelaySeconds 1 ; seconds 
.equ PRESCALE = 0b100 ; 256 prescale
.equ PRESCALE_DIV = 256
.equ WGM = 0b0100 ; Waveform generation mode: CTC
; ensure that the value if between 0 and 6535
.equ TOP = int(0.5 + ((CLOCK / PRESCALE_DIV) * DELAY))
.if TOP > TOP_LIMIT
.error "TOP is out of range"
.endif
; END Consts for setting up the timer

reset:
  
  ; BEGIN Stack initialization
  ldi temp low(RAMEND)
  out SPL, temp
  ldi temp, high(RAMEND)
  out SPH, temp
  ; END Stack initialization

  ;configure INT0 and INT1 sense
	ldi temp, (0b11 << ISC10) | (0b11 << ISC00) ;positive edge triggers
	sts EICRA, temp
	;enable int0, int1
	ldi temp, (1 << INT0) | (1 << INT1)
	out EIMSK, temp

  ldi countSeconds, 0
  ldi currentFloor, FIRST_FLOOR
  ldi currentElevatorStatus, IDLE

  rjmp loop
; end reset

loop: 
  sei ; enable interruptions

  ; let us suppose that this concerns first floor.
  
  ; external buttons pressed
  rjmp ExternalButton_GroundFloor_Pressed
  rjmp ExternalButton_FirstFloor_Pressed
  rjmp ExternalButton_SecondFloor_Pressed

  ; internal buttons pressed
  rjmp InternalButton_GroundFloor_Pressed
  rjmp InternalButton_FirstFloor_Pressed
  rjmp InternalButton_SecondFloor_Pressed

  cpi status, IDLE
  breq idleRoutine

  cpi status, GOING_UP
  breq goingUpRoutine

  cpi status, GOING_DOWN
  breq goingDownRoutine
  
  rjmp loop


ExternalButton_GroundFloor_Pressed:
  ldi calledFloor, GROUND_FLOOR
  nop

ExternalButton_FirstFloor_Pressed:
  ldi calledFloor, FIRST_FLOOR
  nop

ExternalButton_SecondFloor_Pressed:
  ldi calledFloor, SECOND_FLOOR
  nop


GetElevatorMoving:
  cp currentFloor, calledFloor ; checks if we are in the same floor as the one called
  breq sameFloor

  cp currentFloor, calledFloor ; checks if lower floor was called
  brlo lowerFloor

  cp currentFloor, calledFloor ; checks if higher floor was called
  brge higherFloor

  sameFloor:
    ldi status, IDLE ; if on the same floor, do nothing
    jmp loop
  
  lowerFloor:
    ldi status, GOING_UP
    jmp loop
  
  higherFloor:
    ldi status, GOING_DOWN
    jmp loop


goingUpRoutine:
  cpi currentFloor, GROUND_FLOOR 
  brne firstToSecondFloor

  cpi countSeconds, 6
  breq continueGroundToSecond
  jmp loop

  firstToSecondFloor:
    cpi countSeconds, 3
    breq continueFirstToSecond
    jmp loop

  continueGroundToSecond:
    nop
  
  continueFirstToSecond:
    nop


goingDownRoutine:
  cpi currentFloor, SECOND_FLOOR
  brne firstToGround

  cpi countSeconds, 6
  breq continueSecondToGround
  jmp loop

  firstToGround:
    cpi countSeconds, 3
    breq continueFirstToGround
    jmp loop

  continueSecondToGround:
    nop
  
  continueFirstToGround:
    nop

; timer interrupt: Increase countSeconds every second
timerInterruption: 
  push r17 ; a.k.a. countSeconds
  in r17, SREG
  push r17
  
  inc countSeconds

  pop r17
  out SREG, r17
  pop r17
  reti
