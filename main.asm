jmp reset

; Floor constants
#define FIRST_FLOOR 1
#define GROUND_FLOOR 0
#define SECOND_FLOOR 2

; Elevator status constants
#define IDLE 0 ; Stopped
#define GOING_UP 1 ; Going up
#define GOING_DOWN 2 ; Going down
#define WAITING_DOOR 3 ; Waiting for door

; Elevator call priorities constants
#define EXTERNAL_CALL 1 ; Lower priority
#define INTERNAL_CALL 2 ; Higher priority

.def temp = r16 ; Used for configuration
.def countSeconds = r17 ; Used to count seconds

; Floor and elevator
; (See elevator status constants)
.def currentFloor = r18 ; Used to save the current floor
.def calledFloor = r19 ; Used to save the last floor called
.def currentElevatorStatus = r20 ; Used to save elevator status

; Elevator priorities
.def calledFirstPriority = r21 ; Used to check first floor priority
.def calledGroundPriority = r20 ; Used to check ground floor priority
.def calledSecondPriority = r22 ; Used to check second floor priority

; BEGIN Constants to configure the timer
#define TimerDelaySeconds 1 ; Seconds 
#define CLOCK 16 ; Clock speed
#define TOP_LIMIT 65535

.equ PRESCALE_DIV = 256
.equ PRESCALE = 0b100 ; 256 Prescale
.equ WGM = 0b0100 ; Waveform generation mode: CTC
; Ensure that the value if between 0 and 6535
.equ TOP = int(0.5 + ((CLOCK / PRESCALE_DIV) * DELAY))
.if TOP > TOP_LIMIT
.error "TOP is out of range"
.endif
; END Constants to configure the timer

; BEGIN Reset
reset:
  ; BEGIN Stack initialization
  ldi temp low(RAMEND)
  out SPL, temp
  ldi temp, high(RAMEND)
  out SPH, temp
  ; END Stack initialization

  ; Configure external interrupts (INT0 and INT1)
  ; Configure for positive edge-triggered use
	ldi temp, (0b11 << ISC10) | (0b11 << ISC00)
	sts EICRA, temp
	
  ; Enable INT0 and INT1
	ldi temp, (1 << INT0) | (1 << INT1)
	out EIMSK, temp

  ldi countSeconds, 0
  ldi calledFloor, GROUND_FLOOR
  ldi currentFloor, GROUND_FLOOR
  ldi currentElevatorStatus, IDLE

  ldi calledFirstPriority, 0
  ldi calledGroundPriority, 0
  ldi calledSecondPriority, 0

  rjmp loop
; END Reset


; BEGIN Loop
loop:
  ; Set Enable Interrupts 
  sei

  ; let us suppose that this concerns first floor.
  
  ; external buttons pressed
  rjmp ExternalButton_GroundFloor_Pressed
  rjmp ExternalButton_FirstFloor_Pressed
  rjmp ExternalButton_SecondFloor_Pressed

  ; internal buttons pressed
  rjmp InternalButton_GroundFloor_Pressed
  rjmp InternalButton_FirstFloor_Pressed
  rjmp InternalButton_SecondFloor_Pressed

  cpi currentElevatorStatus, IDLE
  breq callIdleRoutine ; chamar rotina para elevador parado

  cpi currentElevatorStatus, GOING_UP
  breq callGoingUpRoutine ; chamar rotina para elevador subindo

  cpi currentElevatorStatus, GOING_DOWN
  breq callGoingDownRoutine ; chamar rotina para elevador descendo

  cpi currentElevatorStatus, WAITING_DOOR
  breq callWaitingRoutine

  callIdleRoutine:
    jmp idleRoutine
  
  callGoingUpRoutine:
    jmp goingUpRoutine
  
  callGoingDownRoutine:
    jmp goingDownRoutine
  
  callWaitingRoutine:
    jmp WaitingRountine

  rjmp loop
; END Loop

idleRoutine:
  ldi countSeconds, 0 ; no time should pass if elevator is idle
  ldi status, IDLE ; reinsure it is idle
  jmp loop ; go back

WaitingRountine:
  ; LED goes here

  cpi countSeconds, 5
  breq buzz
  rjmp noBuzz

  buzz:
    ; Buzzer goes here

  noBuzz:
    cpi count, 10
    breq CloseDoor
    jmp loop
  
  CloseDoor:
    ; LED
    ; BUZZ
    ldi countSeconds, 0
    jmp loop

ExternalButton_GroundFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, GROUND_FLOOR ; ground floor was called
  cpi calledGroundPriority, INTERNAL_CALL ; checks if call has higher priority, keep going
  breq continueGround

  ldi calledGroundPriority, EXTERNAL_CALL  ; mark as external call, with lower priority

  continueGround:
    cpi currentElevatorStatus, IDLE ; I can only go if it is stopped
    breq StartElevator 

  rjmp loop


ExternalButton_FirstFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, FIRST_FLOOR
  cpi calledFirstPriority, INTERNAL_CALL
  breq continueFirst

  ldi calledFirstPriority, EXTERNAL_CALL

  continueFirst:
    cpi currentElevatorStatus, IDLE
    breq StartElevator

  rjmp loop

ExternalButton_SecondFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, SECOND_FLOOR
  cpi calledSecondPriority, INTERNAL_CALL
  breq continueSecond

  ldi calledSecondPriority, EXTERNAL_CALL

  continueSecond:
    cpi currentElevatorStatus, IDLE
    breq StartElevator

  rjmp loop

InternalButton_GroundFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, GROUND_FLOOR
  ldi calledGroundPriority, INTERNAL_CALL ; call has higher priority

  cpi currentElevatorStatus, IDLE ; start only if elevator is idle
  breq StartElevator
  rjmp loop

InternalButton_FirstFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, FIRST_FLOOR
  ldi calledFirstPriority, INTERNAL_CALL ; call has higher priority

  cpi currentElevatorStatus, IDLE ; start only if elevator is idle 
  breq StartElevator
  rjmp loop

InternalButton_SecondFloor_Pressed:
  ; debounce goes here
  ; led goes here
  ldi calledFloor, SECOND_FLOOR
  ldi calledSecondPriority, INTERNAL_CALL

  cpi currentElevatorStatus, IDLE
  breq StartElevator
  rjmp loop


StartElevator:
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
    cpi countSeconds, 3 
    rjmp continueGoToFloor
    jmp loop
    

  continueGoToFloor:
    cpi currentFloor, GROUND_FLOOR
    breq ArriveAtFirstFloor ; next stop is first floor

    cpi currentFloor, FIRST_FLOOR
    breq ArriveAtSecondFloor ; next stop is second floor

    jmp loop

ArriveAtFirstFloor:
  ldi countSeconds, 0 ; restart timer
  ldi currentFloor, FIRST_FLOOR ; update current floor

  cpi calledFirstPriority, INTERNAL_CALL ; this floor higher priority: we can stop here
  breq OpenFirstFloor

  cpi calledSecondPriority, INTERNAL_CALL ; floor above has higher priority: we need to go there
  breq GoToSecondFloor

  cpi calledFirstPriority, EXTERNAL_CALL
  breq OpenFirstFloor

  cpi calledGroundPriority, INTERNAL_CALL
  breq goToGround

  cpi calledGroundPriority, EXTERNAL_CALL
  breq goToGround

  ldi calledFirstPriority, 0
  jmp idleRoutine  

  OpenFirstFloor:
    ldi calledFirstPriority, 0 ; first not pressed
    ldi currentElevatorStatus, WAITING_DOOR ; now we need to wait door to open
    ; LED goes here: display current floor
    jmp loop

  GoToSecondFloor:
    ldi count, 0
    ; LED goes here
    jmp loop

  goToGround:
    ldi countSeconds, 3
    ldi calledFirstPriority, 0
    ldi currentElevatorStatus, GOING_DOWN
    jmp loop  


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
