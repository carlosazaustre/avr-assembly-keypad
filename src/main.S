#include <avr/io.h>

.org 0x00
rjmp setup

setup:
  .global main

main:
  ; Configurar Port B como Salida (Leds)
  ldi r21, 0xFF
  out _SFR_IO_ADDR(DDRB), r21 
  
  ; Configurar Port D como Entrada y Salida (Teclado)
  ; Lineas Columna (Entrada) -> 0 (Parte Baja del Puerto) 4 bits menos significativos
  ; Lineas Fila (Salida) -> 1 (Parte Alta del Puerto) 4 bits mas significativos
  ldi r20, 0xF0 ; 1111 0000
  out _SFR_IO_ADDR(DDRD), r20

gnd_rows:
  ; Poner en 0 las lineas de las filas
  ldi r20, 0x0F ; 0000 1111
  out _SFR_IO_ADDR(PORTD), r20

; Rebote (Debouncing)
wait_release:
  nop
  in r21, _SFR_IO_ADDR(PIND) ; Leer los pines de las columnas.
  andi r21, 0x0F             ; Aplicamos una máscara para quedarnos solo con los bits de las columnas
  cpi r21, 0x0F              ; Comparamos con 0x0F para verificar si no hay teclas presionadas
  breq wait_release          ; Si no hay teclas presionadas, esperar

wait_keypress:
  nop
  in r21, _SFR_IO_ADDR(PIND) ; Leo el estado actual de las columnas
  andi r21, 0x0F
  cpi r21, 0x0F
  breq wait_keypress        ; Tecla es pulsada? No, vuelve y chequea de nuevo
  
  rcall delay

  in r21, _SFR_IO_ADDR(PIND) ; Segundo chequeo de tecla pulsada que asegure si la 1a vez no 
                             ; no es erronea por ruido.
  andi r21, 0x0F
  cpi r21, 0x0F
  breq wait_keypress        ; Tecla es pulsada? No, vuelve y chequea de nuevo

  ; Empezamos a leer las columnas, fila por fila

  ldi r21, 0b01111111       ; A Cero, la fila 1
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND) ; Leo todas las columnas
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row1_col             ; Saltar a Fila 1, encuentra la columna

  ldi r21, 0b10111111     ; A cero, la fila 2
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row2_col

  ldi r21, 0b11011111 ; A cero la fila 3
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row3_col

  ldi r21, 0b11101111 ; A cero la fila 4
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row4_col

row1_col:
  ; Registro Z = R31:R30 . Z = row1_digits
  ldi r30, lo8(row1_digits)
  ldi r31, hi8(row1_digits)
  rjmp find_digit

row2_col:
  ldi r30, lo8(row2_digits)
  ldi r31, hi8(row2_digits)
  rjmp find_digit

row3_col:
  ldi r30, lo8(row3_digits)
  ldi r31, hi8(row3_digits)
  rjmp find_digit

row4_col:
  ldi r30, lo8(row4_digits)
  ldi r31, hi8(row4_digits)
  rjmp find_digit

find_digit:
  lsr r21             ; Desplazamiento Lógico a la derecha de r21 (La columna que estamos leyendo)
                      ; y mueve el bit menos significativo al Carry Flag
  brcc digit_located  ; Si el Carry Flag está limpio (es 0) despues del deplazamiento, significa que
                      ; hemos encontrado el dígito
  lpm r20, Z+         ; Cargar el siguiente dígito de la memoria e incrementa el puntero (Z) 
  rjmp find_digit     ; Si no encuentra el digito, repite el proceso.

digit_located:
  lpm r20, Z                    ; Cargamos en r20 el valor del digito que tiene almacenado Z
  out _SFR_IO_ADDR(PORTB), r20  ; Lo mostramos en los LEDs del puerto B
  rjmp gnd_rows                 ; saltamos al principio del bucle para volver a poner a 0 las filas y
                                ; esperamos la próxima pulsacieon de teclas.

row1_digits: .byte 1,2,3,10
row2_digits: .byte 4,5,6,11
row3_digits: .byte 7,8,9,12
row4_digits: .byte 15,0,14,13

delay:
    ldi   r21, 255
l6: ldi   r22, 255
l7: ldi   r23, 10
l8: dec   r23
    brne  l8
    dec   r22
    brne  l7
    dec   r21
    brne  l6
    ret