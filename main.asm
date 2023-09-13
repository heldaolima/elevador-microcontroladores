.cseg

.equ ClockMHz = 16 ; Clock do microcontrolador 

.equ pino_display_andar = PD0 ; Pinos usados pelo BCD do display: PD0 a PD3
.equ pino_buzzer = PD4 ; Pino usado pelo buzzer
.equ pino_led = PD5; Pino usado pelo LED

.equ pino_interno_segundo = PB0 ; Pino usado pelo botão interno do segundo andar
.equ pino_interno_primeiro = PB1 ; Pino usado pelo botão interno do primeiro andar
.equ pino_interno_terreo = PB2 ; Pino usado pelo botão interno do térreo
.equ pino_abrir_porta = PB3 ; Pino usado pelo botão de abrir a porta
.equ pino_fechar_porta = PB4 ; Pino usado pelo botão de fechar a porta

.equ pino_externo_segundo = PC5 ; Pino usado pelo botão externo do segundo andar
.equ pino_externo_primeiro = PC4 ; Pino usado pelo botão externo do primeiro andar
.equ pino_externo_terreo = PC3 ;  Pino usado pelo botão externo do térreo

jmp reset
.org OC1Aaddr
jmp OCI1A_Interrupt

; Floor constants
#define GROUND_FLOOR 0
#define FIRST_FLOOR 1
#define SECOND_FLOOR 2

; Elevator status constants
#define IDLE 0 ; Stopped
#define GOING_UP 1 ; Going up
#define GOING_DOWN 2 ; Going down
#define WAITING_DOOR 3 ; Waiting for door

; Elevator call priorities constants
#define EXTERNAL_CALL 1 ; Lower priority
#define INTERNAL_CALL 2 ; Higher priority

; Elevator door constants 
#define DOOR_CLOSED 0
#define DOOR_OPEN 1;

.def temp = r16 ; Used for configuration
.def countSeconds = r17 ; Used to count seconds

; Floor and elevator
; (See elevator status constants)
.def currentFloor = r18 ; Used to save the current floor
.def calledFloor = r19 ; Used to save the last floor called
.def currentElevatorStatus = r20 ; Used to save elevator status

; Elevator priorities
.def calledGroundPriority = r21 ; Used to check ground floor priority
.def calledFirstPriority = r22 ; Used to check first floor priority
.def calledSecondPriority = r23 ; Used to check second floor priority

; Elevator door status
.def isDoorOpen = r24

; BEGIN Constants to configure the timer
; Retirado do slide "Semana 06 - Timers", página 19
#define TimerDelaySeconds 1 ; Seconds 
#define CLOCK 16.0e6 ; 16MHz Clock speed
#define TOP_LIMIT 65535
#define DELAY 1 ;seconds ;
.equ PRESCALE_DIV = 256
.equ PRESCALE = 0b100 ; 256 Prescale
.equ WGM = 0b0100 ; Waveform generation mode: CTC
; Ensure that the value if between 0 and 65535
.equ TOP = int(0.5 + ((CLOCK / PRESCALE_DIV) * DELAY))
.if TOP > 65535 ; TOP > TOP_LIMIT
.error "TOP is out of range"
.endif
; END Constants to configure the timer

; BEGIN Reset
reset:
  ; BEGIN Stack initialization
  ldi temp, low(RAMEND)
  out SPL, temp
  ldi temp, high(RAMEND)
  out SPH, temp
  ; END Stack initialization

  ldi temp, high(TOP) ; Carregando TOP em OCR1A
  sts OCR1AH, temp
  ldi temp, low(TOP)
  sts OCR1AL, temp

  ldi temp, ((WGM&0b11)<<WGM10) ; Carrega WGM e PreScale
  sts TCCR1A, temp 
  ldi temp, ((WGM>> 2) << WGM12)|(PRESCALE << CS10)
  sts TCCR1B, temp 

  lds temp, TIMSK1
  sbr temp, 1 <<OCIE1A
  sts TIMSK1, temp
  // END 1 second timer

  ; BEGIN Instancia a porta D usada para Display, Led e Buzzer
  ;               vvvv Pinos PD3 a PD0 (BCD)
  ldi temp, 0b00111111
  ;           ^^ Pinos PD5 e PD4 (LED e Buzzer)
  out DDRD, temp ; Seta a direção dos dados dos pinos

  ldi temp, 0b00000000
  out PORTD, temp ; Zera a saída das portas D
  ; END

  ; BEGIN instancia porta B para botões internos do elevador
  ldi temp, 0b00000000
  out DDRB, temp
  out PORTB, temp  
  ; END

  ; BEGIN instancia porta C para botões externos do elevador
  ldi temp, 0b00000000
  out DDRC, temp
  out PORTC, temp  
  ; END

  ;ldi countSeconds, 0
  ldi currentElevatorStatus, IDLE
  ldi currentFloor, GROUND_FLOOR
  ldi isDoorOpen, DOOR_CLOSED

  rjmp loop
; END Reset

; BEGIN OCI1A_Interrupt
; Referência: Slide Semana 06 - Timers
; Incrementa 'countSeconds' a cada 1 segundo
OCI1A_Interrupt:
  push r16				; Salva valor original
  in r16, SREG
  push r16				; Salva SREG
  ; tarefa da interrupção:
  inc countSeconds
  ; fim da tarefa
  pop r16				; Restaura SREG
  out SREG, r16
  pop r16				; Restaura R16 original
  reti
; END OCI1A_Interrupt

; BEGIN debounce
; Função para evitar o efeito "bounce" ao pressionar um botão
; Executa um delay de 20ms até considerar outro click do botão
; Referência: Slide Aula 08 - Interrupções
debounce:
  ;           clock(MHz)   delay(ms)
  ;               v           v
  ldi r31, byte3(16 * 1000 * 20 / 5)
  ldi r30, high (16 * 1000 * 20 / 5)
  ldi r29, low  (16 * 1000 * 20 / 5)

  subi r29, 1
  sbci r30, 0
  sbci r31, 0
  brcc pc-3

  ret
; END debounce

; BEGIN Loop
loop:
  ; Set Enable Interrupts 
  sei
  ; external buttons pressed
  sbic PINC, pino_externo_terreo
  rjmp ExternalButton_GroundFloor_Pressed
  
  sbic PINC, pino_externo_primeiro
  rjmp ExternalButton_FirstFloor_Pressed
  
  sbic PINC, pino_externo_segundo
  rjmp ExternalButton_SecondFloor_Pressed

  ; internal buttons pressed
  sbic PINB, pino_interno_terreo 
  rjmp InternalButton_GroundFloor_Pressed
  
  sbic PINB, pino_interno_primeiro
  rjmp InternalButton_FirstFloor_Pressed
  
  sbic PINB, pino_interno_segundo
  rjmp InternalButton_SecondFloor_Pressed

  sbic PINB, pino_abrir_porta 
  jmp OpenDoor_Pressed

  sbic PINB, pino_fechar_porta
  jmp CloseDoor_Pressed

  cpi isDoorOpen, DOOR_OPEN
  breq callWaitingRoutine

  cpi currentElevatorStatus, IDLE
  breq callIdleRoutine ; chamar rotina para elevador parado

  cpi currentElevatorStatus, GOING_UP
  breq callGoingUpRoutine ; chamar rotina para elevador subindo

  cpi currentElevatorStatus, GOING_DOWN
  breq callGoingDownRoutine ; chamar rotina para elevador descendo

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
  ldi currentElevatorStatus, IDLE ; reinsure it is idle
  jmp loop ; go back

WaitingRountine:
  sbi PORTD, pino_led
  cpi countSeconds, 5
  breq buzz
  rjmp noBuzz

  buzz:
    sbi PORTD, pino_buzzer

  noBuzz:
    cpi countSeconds, 10
    breq CloseDoor
    jmp loop
  
  CloseDoor:
    cbi PORTD, pino_buzzer
    cbi PORTD, pino_led
    ldi countSeconds, 0
	ldi isDoorOpen, DOOR_CLOSED
    ldi currentElevatorStatus, IDLE
    jmp loop

ExternalButton_GroundFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, GROUND_FLOOR ; ground floor was called
  cpi calledGroundPriority, INTERNAL_CALL ; checks if call has higher priority, keep going
  breq continueGround

  ldi calledGroundPriority, EXTERNAL_CALL  ; mark as external call, with lower priority

  continueGround:
    cpi currentElevatorStatus, IDLE ; I can only go if it is stopped
    breq StartElevator 

  rjmp loop


ExternalButton_FirstFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, FIRST_FLOOR
  cpi calledFirstPriority, INTERNAL_CALL
  breq continueFirst

  ldi calledFirstPriority, EXTERNAL_CALL

  continueFirst:
    cpi currentElevatorStatus, IDLE
    breq StartElevator

  rjmp loop

ExternalButton_SecondFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, SECOND_FLOOR
  cpi calledSecondPriority, INTERNAL_CALL
  breq continueSecond

  ldi calledSecondPriority, EXTERNAL_CALL

  continueSecond:
    cpi currentElevatorStatus, IDLE
    breq StartElevator

  rjmp loop

InternalButton_GroundFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, GROUND_FLOOR
  ldi calledGroundPriority, INTERNAL_CALL ; call has higher priority

  cpi currentElevatorStatus, IDLE ; start only if elevator is idle
  breq StartElevator
  rjmp loop

InternalButton_FirstFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, FIRST_FLOOR
  ldi calledFirstPriority, INTERNAL_CALL ; call has higher priority

  cpi currentElevatorStatus, IDLE ; start only if elevator is idle 
  breq StartElevator
  rjmp loop

InternalButton_SecondFloor_Pressed:
  rcall debounce	; wait 20ms
  ldi calledFloor, SECOND_FLOOR
  ldi calledSecondPriority, INTERNAL_CALL

  cpi currentElevatorStatus, IDLE
  breq StartElevator
  rjmp loop

OpenDoor_Pressed:
	rcall debounce

	cpi isDoorOpen, DOOR_OPEN
	breq keepDoorOpen
	jmp loop

	keepDoorOpen: ; segura a porta 
		sbic PINB, pino_abrir_porta
		rjmp OpenDoor_Pressed
	
	ldi countSeconds, 10
	jmp loop

CloseDoor_Pressed:
	rcall debounce
	cbi PORTD, pino_buzzer
    cbi PORTD, pino_led
    ldi countSeconds, 0
	ldi isDoorOpen, DOOR_CLOSED
    jmp loop

StartElevator:
  cp currentFloor, calledFloor ; checks if we are in the same floor as the one called
  breq sameFloor

  cp currentFloor, calledFloor ; checks if lower floor was called
  brlo lowerFloor

  cp currentFloor, calledFloor ; checks if higher floor was called
  brge higherFloor

  sameFloor:
    ldi currentElevatorStatus, IDLE ; if on the same floor, do nothing
    jmp loop
  
  lowerFloor:
    ldi currentElevatorStatus, GOING_UP
    jmp loop
  
  higherFloor:
    ldi currentElevatorStatus, GOING_DOWN
    jmp loop


goingUpRoutine:
    cpi countSeconds, 3
	breq continueGoToFloor
    jmp loop

  continueGoToFloor:
    cpi currentFloor, GROUND_FLOOR
    breq ArriveAtFirstFloor ; next stop is first floor

    cpi currentFloor, FIRST_FLOOR
    breq ArriveAtSecondFloor ; next stop is second floor

    jmp loop

; BEGIN ArriveAtGroundFloor
ArriveAtGroundFloor:
  ldi countSeconds, 0 ; restart timer
  ldi currentFloor, GROUND_FLOOR ; update current floor

  cpi calledGroundPriority, INTERNAL_CALL ; IF internal button to ground was pressed
  breq OpenGroundDoor                     ; THEN we open the door

  cpi calledGroundPriority, EXTERNAL_CALL ; IF external button to ground was pressed
  breq OpenGroundDoor                     ; THEN we open the door

  cpi calledFirstPriority, INTERNAL_CALL ; IF internal button to first floor was pressed
  breq GoToFirstFloor                    ; THEN we go there

  cpi calledFirstPriority, EXTERNAL_CALL ; IF external button to first floor was pressed
  breq GoToFirstFloor                    ; THEN we go there

  cpi calledSecondPriority, INTERNAL_CALL ; IF internal button to second floor was pressed
  breq GoToSecondFloor                    ; THEN we go there

  cpi calledSecondPriority, EXTERNAL_CALL ; IF external button to second floor was pressed
  breq GoToSecondFloor                    ; THEN we go there

  OpenGroundDoor:
	sbi PORTD, pino_led

; END ArriveAtGroundFloor

ArriveAtFirstFloor:
  ldi countSeconds, 0 ; restart timer
  ldi currentFloor, FIRST_FLOOR ; update current floor

  cpi calledFirstPriority, INTERNAL_CALL ; this floor higher priority: we can stop here
  breq OpenFirstFloor

  cpi calledSecondPriority, INTERNAL_CALL ; floor above has higher priority: we need to go there
  breq GoToSecondFloor

  cpi calledFirstPriority, EXTERNAL_CALL
  breq OpenFirstFloor

  cpi calledSecondPriority, EXTERNAL_CALL ; floor above has higher priority: we need to go there
  breq GoToSecondFloor

  cpi calledGroundPriority, INTERNAL_CALL
  breq goToGround

  cpi calledGroundPriority, EXTERNAL_CALL
  breq goToGround

  ldi calledFirstPriority, 0
  jmp idleRoutine  

  OpenFirstFloor:
    ldi calledFirstPriority, 0 ; first not pressed
    ldi isDoorOpen, DOOR_OPEN ; now we need to wait door to open
    out PORTD, currentFloor
    jmp loop

  GoToSecondFloor:
    ldi countSeconds, 0
	out PORTD, currentFloor
	ldi currentElevatorStatus, GOING_UP
    jmp loop

  goToGround:
    ldi countSeconds, 0
    ldi calledFirstPriority, 0
    ldi currentElevatorStatus, GOING_DOWN
    jmp loop  

ArriveAtSecondFloor:
    ldi countSeconds, 0 ; restart timer
    ldi currentFloor, SECOND_FLOOR ; update current floor

	cpi calledSecondPriority, INTERNAL_CALL
	breq OpenSecondFloor

	cpi calledSecondPriority, EXTERNAL_CALL
	breq OpenSecondFloor

    cpi calledFirstPriority, INTERNAL_CALL
    breq GoToFirstFloor

    cpi calledFirstPriority, EXTERNAL_CALL
    breq GoToFirstFloor

    cpi calledGroundPriority, INTERNAL_CALL
    breq goToGroundFromSecond

    cpi calledGroundPriority, EXTERNAL_CALL
    breq goToGroundFromSecond

    ldi calledSecondPriority, 0
    jmp idleRoutine

    OpenSecondFloor:
        ldi calledSecondPriority, 0 ; second not pressed
		ldi isDoorOpen, DOOR_OPEN
		out PORTD, currentFloor
        jmp loop

    GoToFirstFloor:
        ldi countSeconds, 0
        ldi calledSecondPriority, 0
        ldi currentElevatorStatus, GOING_DOWN
        jmp loop

    goToGroundFromSecond:
        ldi countSeconds, 0
        ldi calledSecondPriority, 0
        ldi currentElevatorStatus, GOING_DOWN
        jmp loop

goingDownRoutine:
  cpi countSeconds, 3 
  breq continueGoDown
  jmp loop

  continueGoDown:
    cpi currentFloor, SECOND_FLOOR
    breq ArriveAtFistFloorFromSecond

    cpi currentFloor, FIRST_FLOOR
    breq ArriveAtGroundFloorFromFirst

    jmp loop

ArriveAtGroundFloorFromFirst:
	ldi currentFloor, GROUND_FLOOR
	ldi countSeconds, 0 ; reseta timer

	cpi calledGroundPriority, INTERNAL_CALL ;prioridade maior
	breq openGroundFloor

	cpi calledGroundPriority, EXTERNAL_CALL
	breq openGroundFloor

	cpi calledFirstPriority, INTERNAL_CALL
	breq goUpFromGround

	cpi calledFirstPriority, EXTERNAL_CALL
	breq goUpFromGround

	cpi calledSecondPriority, INTERNAL_CALL
	breq goUpFromGround

	cpi calledSecondPriority, EXTERNAL_CALL
	breq goUpFromGround
	
	ldi calledGroundPriority, 0 ; reseta a prioirdade do terreo
	jmp idleRoutine

	openGroundFloor:
		ldi isDoorOpen, DOOR_OPEN
		ldi calledGroundPriority, 0
		ldi currentFloor, GROUND_FLOOR
		out PORTD, currentFloor   
		jmp loop

	goUpFromGround:
		ldi currentFloor, GROUND_FLOOR
		ldi countSeconds, 0
		out PORTD, currentFloor
		ldi calledGroundPriority, 0
		ldi currentElevatorStatus, GOING_UP
		jmp loop

ArriveAtFistFloorFromSecond:
  cpi calledFirstPriority, INTERNAL_CALL ; higher priority
  breq OpenFirstFloorDown

  cpi calledFirstPriority, EXTERNAL_CALL ; lower priority
  breq OpenFirstFloorDown

  cpi calledGroundPriority, INTERNAL_CALL ; ground has higher priority -> go there
  breq goDownToGroundFloor

  cpi calledGroundPriority, EXTERNAL_CALL
  breq goDownToGroundFloor

  cpi calledSecondPriority, INTERNAL_CALL
  breq goUpFromHere

  cpi calledSecondPriority, EXTERNAL_CALL
  breq goUpFromHere

  ldi currentFloor, FIRST_FLOOR
  ldi calledFirstPriority, 0
  ldi countSeconds, 0
  jmp idleRoutine

  OpenFirstFloorDown:
    ldi isDoorOpen, DOOR_OPEN
    ldi currentFloor, FIRST_FLOOR
    ldi calledFirstPriority, 0
    ldi countSeconds, 0
    out PORTD, currentFloor
	jmp loop

    goDownToGroundFloor:
      ldi countSeconds, 0
      ldi currentFloor, FIRST_FLOOR
      out PORTD, currentFloor
      jmp loop

    goUpFromHere:
      ldi currentFloor, FIRST_FLOOR
      ldi countSeconds, 0
	  out PORTD, currentFloor
      ldi calledFirstPriority, 0
      ldi currentElevatorStatus, GOING_UP
      jmp loop
