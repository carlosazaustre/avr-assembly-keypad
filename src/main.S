#include <avr/io.h>

.org 0x00
rjmp setup

setup:
  .global main

main:
  ; -----------------------------------------
  ; Configuración inicial
  ; -----------------------------------------
  
  ; Configurar Port B como Salida (Leds)
  ldi r21, 0xFF
  out _SFR_IO_ADDR(DDRB), r21 
  
  ; Configurar Port D como Entrada y Salida (Teclado)
  ; Lineas Columna (Entrada) -> 0 (Parte Baja del Puerto) 4 bits menos significativos
  ; Lineas Fila (Salida) -> 1 (Parte Alta del Puerto) 4 bits mas significativos
  ldi r20, 0xF0             ; 1111 0000
  out _SFR_IO_ADDR(DDRD), r20

loop:
  ; -----------------------------------------
  ; Bucle Principal de detección
  ; -----------------------------------------
  ; Ponemos en 0 las lineas de las filas inicialmente
  ldi r20, 0x0F              ; 0000 1111
  out _SFR_IO_ADDR(PORTD), r20

wait_release:
  ; Nos aseguramos que todas las teclas hayan sido liberadas antes de comenzar 
  ; a detectar una nueva pulsación. 
  ; Esto evita que se procesen múltiples señales de una sola pulsación debido 
  ; a que el usuario mantenga la tecla presionada.
  nop                        ; NO Operation (Permite estabilizar voltajes)
  in r21, _SFR_IO_ADDR(PIND) ; Leer los pines de las columnas.
  andi r21, 0x0F             ; Aplicamos una máscara para quedarnos solo con los bits de las columnas
  cpi r21, 0x0F              ; Comparamos con 0x0F para verificar si no hay teclas presionadas. 
  breq wait_release          ; Si todos los bits están 'altos' significa que no hay teclas presionadas
                             ; Si no hay teclas presionadas, repetimos hasta que sean liberadas

wait_keypress:
  ; Detectamos cuanod una tecla es efectivamente presionada.
  nop
  in r21, _SFR_IO_ADDR(PIND) ; Leo el estado actual de las columnas
  andi r21, 0x0F             ; aplico de nueva la máscara para quedarnos con los bits de las columnas
  cpi r21, 0x0F              ; comparo si hay teclas pulsadas o no
  breq wait_keypress         ; Si aún no hay ninguna tecla presionada (todos los bits altos)
                             ; volvemos al inicio de `wait_keypress` para seguir esperando.
  
  ; El rebote (bounce) es un fenómeno común donde el contacto eléctrico "rebota" al presionar o soltar
  ; una tecla, generando múltiples señales transitorias que pueden interpretarse como pulsaciones múltiples.
  rcall delay                ; Retardo de aprox 20ms para manejar ese efecto

  ; Después del retardo, realizamos una segunda lectura y comparamos para confirmar que la tecla 
  ; sigue presionada y no fue un falso positivo debido al ruido o rebote.
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  breq wait_keypress        ; Si en esta segunda verificación no hay tecla presionada
                            ; volvemos al inicio de `wait_keypress`

  ; -----------------------------------------
  ; Escaneo de Filas y Columnas
  ; -----------------------------------------
  ; Activamos cada fila individualmente (poniendo a 0) de forma secuancial y leermos las columnas
  ; para identificar si alguna tecla en esa fila está presionada.
  ldi r21, 0b01111111       ; Activamos Fila 1 (Recuerda, poniendo a 0)
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND) ; Leo todas las columnas de la fila
  andi r21, 0x0F             ; Aplico máscara para ignorar las filas y leer solo las columnas
  cpi r21, 0x0F
  brne row1_col              ; Si no es igual, quiere decir que alguna columna tiene una tecla presionada
                             ; por tanto saltamos a la sección `row1_col` que implementa la lógica
                             ; específica para manejar la entrada de esa fila

  ldi r21, 0b10111111        ; Activamos Fila 2, el resto del código es igual
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row2_col

  ldi r21, 0b11011111         ; Activamos Fila 3
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row3_col

  ldi r21, 0b11101111         ; Activamos Fila 4
  out _SFR_IO_ADDR(PORTD), r21
  nop
  in r21, _SFR_IO_ADDR(PIND)
  andi r21, 0x0F
  cpi r21, 0x0F
  brne row4_col

  ; -----------------------------------------
  ; Localización del Dígito
  ; -----------------------------------------
  ; Cada etiqueta `rowX_col` maneja una fila específica.
  ; Cargamos en los registros R31:R30 (que forman el registro especial Z) el array/tabla
  ; de valores de los dígitos que corresponden a esa fila.
  ; Las direcciones de la memoria de programa son de 16 bits.
  ; en R31 están los bits más significativos de Z (8 bits)
  ; en R30 están los bits menos significativos de Z (8 bits)
  ; Z contendrá la dirección de memoria donde están almacenados estos valors.
  ; Z nos permite usarle como puntero para acceder al resto de posiciones de memoria consecutivas
row1_col:
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

; R21 contiene el estado de las columnas de la fila que tenemos activa.
; Cada bit en R21 representa una columna.
;
; Si desplazamos R21 a la derecha, estamos revisando de forma secuencial 
; cada columna para ver si esa columna (y por ende, la tecla correspondiente)
; está activa (presionada).
;
; El bit de una columna activa se lee como 0 (Activo Bajo), al desplazarlo a la derecha
; si llega ese 0 al bit del Carry Flag (del registro de estado SREG) indica que se ha 
; encontrado una columna activa.
; 
; y gracias a la instruccion BRCC (Branch if Carry Clear) significa que el bit que acabamos
; de comparar/examinar era un 0 indicando que hemos localizado el digito.
; 
; LPM (Load Program Memory) carga un byte de la memoria de programa utilizando la dirección apuntada por Z
; y Z+ incrementa automáticamente el puntero Z despues de la carga (Apunta a la siguiente dirección de memoria)
find_digit:
  lsr r21             ; Desplazamiento Lógico a la derecha de r21. Mueve el bit menos significativo al Carry Flag
  brcc digit_located  ; Salta Si el Carry Flag está limpio (es 0) despues del deplazamiento
  lpm r20, Z+         ; Cargar el siguiente dígito de la memoria e incrementa el puntero (Z) a la siguiente posición
  rjmp find_digit     ; Si no encuentra el digito, repite el proceso.

digit_located:
  lpm r20, Z                    ; Cargamos en r20 el valor del digito que tiene almacenado Z
  out _SFR_IO_ADDR(PORTB), r20  ; Lo mostramos en los LEDs del puerto B
  rjmp loop                     ; saltamos al principio del bucle para volver a poner a 0 las filas y
                                ; esperamos la próxima pulsacieon de teclas.

; Array/Tabla con los dígitos por filas, almacenados en memoria de manera secuencial
row1_digits: .byte 1,2,3,10
row2_digits: .byte 4,5,6,11
row3_digits: .byte 7,8,9,12
row4_digits: .byte 15,0,14,13

; Retardo de aproximadamente 20ms para controlar el rebote en las pulsaciones
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