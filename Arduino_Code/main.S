#define __SFR_OFFSET 0x00
#include "avr/io.h"

.equ FL_GO,       0
.equ FL_P1WIN,    1
.equ FL_P2WIN,    2
.equ FL_FALSE,    3

.equ EE_HS_L,     0x00
.equ EE_HS_H,     0x01
.equ EE_HS2_L,    0x02
.equ EE_HS2_H,    0x03

.equ I2C_FREQ_DIV, 32
.equ LCD_ADDR,    0x20 
.equ LCD_BL,      0x08
.equ LCD_EN,      0x04
.equ LCD_RW,      0x02
.equ LCD_RS,      0x01

.equ BAUD_DIV,    51

.global main

main:
    LDI   R16, hi8(RAMEND)
    OUT   SPH, R16
    LDI   R16, lo8(RAMEND)
    OUT   SPL, R16

    LDI   R16, 0b11110011
    OUT   DDRD, R16
    LDI   R16, 0x00
    OUT   PORTD, R16

    IN    R16, PORTD
    ORI   R16, (1<<PD2)|(1<<PD3)
    OUT   PORTD, R16

    LDI   R16, (1<<PB0)
    OUT   DDRB, R16
    LDI   R16, 0x00
    OUT   PORTB, R16

    LDI   R16, 0
    STS   UBRR0H, R16
    LDI   R16, BAUD_DIV
    STS   UBRR0L, R16
    LDI   R16, (1<<TXEN0)
    STS   UCSR0B, R16
    LDI   R16, (1<<UCSZ01)|(1<<UCSZ00)
    STS   UCSR0C, R16

    LDI   R16, (1<<REFS0)
    STS   ADMUX, R16
    LDI   R16, (1<<ADEN)|(1<<ADPS2)|(1<<ADPS1)
    STS   ADCSRA, R16

    LDI   R16, 0
    STS   TCCR1A, R16
    STS   TCCR1B, R16

    LDI   R16, I2C_FREQ_DIV
    STS   TWBR, R16
    LDI   R16, 0
    STS   TWSR, R16
    LDI   R16, (1<<TWEN)
    STS   TWCR, R16

    RCALL delay_100ms
    RCALL lcd_init

    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_title)
    LDI   ZH, hi8(str_title)
    RCALL lcd_print_pgm

    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_subtitle)
    LDI   ZH, hi8(str_subtitle)
    RCALL lcd_print_pgm

    LDI   ZL, lo8(str_serial_init)
    LDI   ZH, hi8(str_serial_init)
    RCALL uart_print_pgm

    RCALL delay_2s

    RCALL adc_read
    MOV   R4, R0
    MOV   R5, R1
    MOV   R16, R4
    TST   R16
    BRNE  seed_ok
    MOV   R16, R5
    TST   R16
    BRNE  seed_ok
    LDI   R16, 0xAC
    MOV   R4, R16
    LDI   R16, 0xE1
    MOV   R5, R16
seed_ok:

    CLR   R23
    CLR   R24
    CLR   R25
    CLR   R19

game_loop:
    CPI   R24, 3
    BRNE  gl_chk_p2
    RJMP  game_over_p1
gl_chk_p2:
    CPI   R25, 3
    BRNE  gl_chk_done
    RJMP  game_over_p2
gl_chk_done:

    RCALL show_round_status
    RCALL delay_1s

    IN    R16, PORTD
    ORI   R16, 0b11110000
    OUT   PORTD, R16
    SBI   PORTB, PB0

    RCALL delay_1s

    RCALL leds_off
    RCALL delay_1s

    CLR   R19

    RCALL delay_100ms
    SBI   PORTD, PD4
    RCALL delay_1s_poll
    CPI   R22, 0
    BREQ  nofs_1
    RJMP  false_start_detected
nofs_1:

    RCALL delay_100ms
    SBI   PORTD, PD5
    RCALL delay_1s_poll
    CPI   R22, 0
    BREQ  nofs_2
    RJMP  false_start_detected
nofs_2:

    RCALL delay_100ms
    SBI   PORTD, PD6
    RCALL delay_1s_poll
    CPI   R22, 0
    BREQ  nofs_3
    RJMP  false_start_detected
nofs_3:

    RCALL delay_100ms
    SBI   PORTD, PD7
    RCALL delay_1s_poll
    CPI   R22, 0
    BREQ  nofs_4
    RJMP  false_start_detected
nofs_4:

    RCALL delay_100ms
    SBI   PORTB, PB0
    RCALL delay_1s_poll
    CPI   R22, 0
    BREQ  nofs_5
    RJMP  false_start_detected
nofs_5:

    RCALL random_delay_poll
    CPI   R22, 0
    BREQ  nofs_6
    RJMP  false_start_detected
nofs_6:

    RJMP  fs_ok6                 

fs_ok6:
    RCALL leds_off
    RCALL show_go_ui

    LDI   R16, 0
    STS   TCNT1H, R16
    STS   TCNT1L, R16
    LDI   R16, (1<<CS12)|(1<<CS10)
    STS   TCCR1B, R16

    SBR   R19, (1<<FL_GO)
    CLR   R28
    CLR   R29

wait_button:
    SBIS  PIND, PD2
    RJMP  p1_pressed
    SBIS  PIND, PD3
    RJMP  p2_pressed

    LDS   R28, TCNT1L
    LDS   R29, TCNT1H

    CPI   R29, 0xB7
    BRLO  wait_button
    CPI   R29, 0xB7
    BREQ  check_timer_hi
    RJMP  timeout_nopress

check_timer_hi:
    CPI   R28, 0x1B
    BRLO  wait_button
    RJMP  timeout_nopress

p1_pressed:
    LDI   R16, 0
    STS   TCCR1B, R16
    
    LDS   R28, TCNT1L
    LDS   R29, TCNT1H

    CBR   R19, (1<<FL_GO)
    SBR   R19, (1<<FL_P1WIN)
    INC   R24
    RCALL process_win_p1
    RJMP  round_done

p2_pressed:
    LDI   R16, 0
    STS   TCCR1B, R16

    LDS   R28, TCNT1L
    LDS   R29, TCNT1H

    CBR   R19, (1<<FL_GO)
    SBR   R19, (1<<FL_P2WIN)
    INC   R25
    RCALL process_win_p2
    RJMP  round_done

timeout_nopress:
    LDI   R16, 0
    STS   TCCR1B, R16

    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_timeout)
    LDI   ZH, hi8(str_timeout)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_timeout)
    LDI   ZH, hi8(str_ser_timeout)
    RCALL uart_print_pgm
    RCALL delay_2s
    RJMP  round_done

show_go_ui:
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_go)
    LDI   ZH, hi8(str_go)
    RCALL lcd_print_pgm
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_press)
    LDI   ZH, hi8(str_press)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_go)
    LDI   ZH, hi8(str_ser_go)
    RCALL uart_print_pgm
    RET

false_start_detected:
    LDI   R16, 0
    STS   TCCR1B, R16
    RCALL leds_off
    RCALL delay_1s  

    CPI   R22, 1
    BREQ  jump_false_p1
    RJMP  false_p2

jump_false_p1:
    RJMP  false_p1

false_p1:
    INC   R25
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_false_p1)
    LDI   ZH, hi8(str_false_p1)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_false1)
    LDI   ZH, hi8(str_ser_false1)
    RCALL uart_print_pgm
    RJMP  false_done

false_p2:
    INC   R24
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_false_p2)
    LDI   ZH, hi8(str_false_p2)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_false2)
    LDI   ZH, hi8(str_ser_false2)
    RCALL uart_print_pgm

false_done:
    RCALL wait_release_all
    RCALL delay_2s

round_done:
    INC   R23
    CLR   R19
    RCALL delay_1s
    RJMP  game_loop

game_over_p1:
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_p1_wins)
    LDI   ZH, hi8(str_p1_wins)
    RCALL lcd_print_pgm
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_best_of5)
    LDI   ZH, hi8(str_best_of5)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_p1wins)
    LDI   ZH, hi8(str_ser_p1wins)
    RCALL uart_print_pgm
    RCALL delay_1s
    RJMP  restart_game

game_over_p2:
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_p2_wins)
    LDI   ZH, hi8(str_p2_wins)
    RCALL lcd_print_pgm
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_best_of5)
    LDI   ZH, hi8(str_best_of5)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_p2wins)
    LDI   ZH, hi8(str_ser_p2wins)
    RCALL uart_print_pgm
    RCALL delay_1s

restart_game:
    RCALL delay_3s
    CLR   R23
    CLR   R24
    CLR   R25
    CLR   R19
    RJMP  game_loop

process_win_p1:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    MOV   R16, R28
    MOV   R17, R29
    LDI   R18, 16
    RCALL div16_by8
    LDI   R20, 0x80
    PUSH  R16
    PUSH  R17
    MOV   R16, R20
    RCALL lcd_cmd
    POP   R17
    POP   R16
    LDI   ZL, lo8(str_p1_react)
    LDI   ZH, hi8(str_p1_react)
    RCALL lcd_print_pgm
    LDI   R20, 0xC0
    PUSH  R16
    PUSH  R17
    MOV   R16, R20
    RCALL lcd_cmd
    POP   R17
    POP   R16
    RCALL lcd_print_u16_ms
    LDI   ZL, lo8(str_ser_p1react)
    LDI   ZH, hi8(str_ser_p1react)
    RCALL uart_print_pgm
    RCALL uart_print_u16
    RCALL check_highscore_p1
    RCALL delay_2s
    POP   R18
    POP   R17
    POP   R16
    RET

process_win_p2:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    MOV   R16, R28
    MOV   R17, R29
    LDI   R18, 16
    RCALL div16_by8
    LDI   R20, 0x80
    PUSH  R16
    PUSH  R17
    MOV   R16, R20
    RCALL lcd_cmd
    POP   R17
    POP   R16
    LDI   ZL, lo8(str_p2_react)
    LDI   ZH, hi8(str_p2_react)
    RCALL lcd_print_pgm
    LDI   R20, 0xC0
    PUSH  R16
    PUSH  R17
    MOV   R16, R20
    RCALL lcd_cmd
    POP   R17
    POP   R16
    RCALL lcd_print_u16_ms
    LDI   ZL, lo8(str_ser_p2react)
    LDI   ZH, hi8(str_ser_p2react)
    RCALL uart_print_pgm
    RCALL uart_print_u16
    RCALL check_highscore_p2
    RCALL delay_2s
    POP   R18
    POP   R17
    POP   R16
    RET

show_round_status:
    PUSH  R16
    LDI   R16, 0x01
    RCALL lcd_cmd
    RCALL delay_2ms
    LDI   R16, 0x80
    RCALL lcd_cmd
    LDI   ZL, lo8(str_round)
    LDI   ZH, hi8(str_round)
    RCALL lcd_print_pgm
    MOV   R16, R23
    SUBI  R16, -'1'
    RCALL lcd_write_char
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_p1colon)
    LDI   ZH, hi8(str_p1colon)
    RCALL lcd_print_pgm
    MOV   R16, R24
    SUBI  R16, -'0'
    RCALL lcd_write_char
    LDI   R16, ' '
    RCALL lcd_write_char
    LDI   ZL, lo8(str_p2colon)
    LDI   ZH, hi8(str_p2colon)
    RCALL lcd_print_pgm
    MOV   R16, R25
    SUBI  R16, -'0'
    RCALL lcd_write_char
    LDI   ZL, lo8(str_ser_round)
    LDI   ZH, hi8(str_ser_round)
    RCALL uart_print_pgm
    MOV   R16, R23
    SUBI  R16, -'1'
    RCALL uart_write_char
    LDI   R16, 0x0D
    RCALL uart_write_char
    LDI   R16, 0x0A
    RCALL uart_write_char
    POP   R16
    RET

check_highscore_p1:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    LDI   R26, EE_HS_L
    CLR   R27
    RCALL eeprom_read
    MOV   R18, R0
    LDI   R26, EE_HS_H
    RCALL eeprom_read
    MOV   R19, R0
    CPI   R18, 0xFF
    BREQ  hs1_save
    CPI   R19, 0xFF
    BREQ  hs1_save
    CP    R17, R19
    BRLO  hs1_save
    BRNE  hs1_no_save
    CP    R16, R18
    BRSH  hs1_no_save
hs1_save:
    LDI   R26, EE_HS_L
    CLR   R27
    MOV   R0, R16
    RCALL eeprom_write
    LDI   R26, EE_HS_H
    MOV   R0, R17
    RCALL eeprom_write
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_new_hs)
    LDI   ZH, hi8(str_new_hs)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_newhs)
    LDI   ZH, hi8(str_ser_newhs)
    RCALL uart_print_pgm
    RCALL delay_1s
hs1_no_save:
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

check_highscore_p2:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    LDI   R26, EE_HS2_L
    CLR   R27
    RCALL eeprom_read
    MOV   R18, R0
    LDI   R26, EE_HS2_H
    RCALL eeprom_read
    MOV   R19, R0
    CPI   R18, 0xFF
    BREQ  hs2_save
    CPI   R19, 0xFF
    BREQ  hs2_save
    CP    R17, R19
    BRLO  hs2_save
    BRNE  hs2_no_save
    CP    R16, R18
    BRSH  hs2_no_save
hs2_save:
    LDI   R26, EE_HS2_L
    CLR   R27
    MOV   R0, R16
    RCALL eeprom_write
    LDI   R26, EE_HS2_H
    MOV   R0, R17
    RCALL eeprom_write
    LDI   R16, 0xC0
    RCALL lcd_cmd
    LDI   ZL, lo8(str_new_hs)
    LDI   ZH, hi8(str_new_hs)
    RCALL lcd_print_pgm
    LDI   ZL, lo8(str_ser_newhs)
    LDI   ZH, hi8(str_ser_newhs)
    RCALL uart_print_pgm
    RCALL delay_1s
hs2_no_save:
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

eeprom_read:
    SBIC  EECR, EEPE
    RJMP  eeprom_read
    OUT   EEARL, R26
    OUT   EEARH, R27
    SBI   EECR, EERE
    IN    R0, EEDR
    RET

eeprom_write:
    CLI
    SBIC  EECR, EEPE
    RJMP  eeprom_write
    OUT   EEARL, R26
    OUT   EEARH, R27
    OUT   EEDR, R0
    SBI   EECR, EEMPE
    SBI   EECR, EEPE
    SEI
    RET

adc_read:
    LDS   R16, ADCSRA
    ORI   R16, (1<<ADSC)
    STS   ADCSRA, R16
adc_wait:
    LDS   R16, ADCSRA
    SBRC  R16, ADSC
    RJMP  adc_wait
    LDS   R0, ADCL
    LDS   R1, ADCH
    RET

lfsr_next:
    MOV   R16, R4
    ANDI  R16, 1
    TST   R16
    BREQ  lfsr_shift
    LDI   R17, 0x00
    EOR   R4, R17
    LDI   R17, 0xB4
    EOR   R5, R17
lfsr_shift:
    LSR   R5
    ROR   R4
    RET

random_delay_800ms:
    PUSH  R20
    PUSH  R21
    PUSH  R22
    RCALL lfsr_next
    MOV   R20, R16
    ANDI  R20, 0x4F
rdm_loop:
    RCALL delay_5ms
    DEC   R20
    BRNE  rdm_loop
    LDI   R20, 120
rdm_base:
    RCALL delay_5ms
    DEC   R20
    BRNE  rdm_base
    POP   R22
    POP   R21
    POP   R20
    RET

random_delay_3s:
    PUSH  R20
    PUSH  R21
    RCALL lfsr_next
    MOV   R20, R16
    ANDI  R20, 0x7F
    LDI   R21, 200
rd3s_base:
    RCALL delay_5ms
    DEC   R21
    BRNE  rd3s_base
rd3s_rand:
    RCALL delay_5ms
    RCALL delay_5ms
    RCALL delay_5ms
    DEC   R20
    BRNE  rd3s_rand
    POP   R21
    POP   R20
    RET

leds_off:
    IN    R16, PORTD
    ANDI  R16, 0b00001111
    OUT   PORTD, R16
    CBI   PORTB, PB0
    RET

wait_release_all:
    IN    R16, PIND
    ANDI  R16, (1<<PD2)|(1<<PD3)
    CPI   R16, (1<<PD2)|(1<<PD3)
    BRNE  wait_release_all
    RCALL delay_50ms
    RET

div16_by8:
    PUSH  R18
    PUSH  R19
    CLR   R19
    LDI   R20, 16
div_loop:
    LSL   R16
    ROL   R17
    ROL   R19
    CP    R19, R18
    BRLO  div_next
    SUB   R19, R18
    INC   R16
div_next:
    DEC   R20
    BRNE  div_loop
    POP   R19
    POP   R18
    RET

lcd_print_u16_ms:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    MOV   R18, R16
    MOV   R19, R17
    LDI   R20, 0
lcd_100:
    CPI   R19, 0
    BRNE  lcd_100sub
    CPI   R18, 100
    BRLO  lcd_done100
lcd_100sub:
    SUBI  R18, 100
    SBCI  R19, 0
    INC   R20
    RJMP  lcd_100
lcd_done100:
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL lcd_write_char
    LDI   R20, 0
lcd_10:
    CPI   R18, 10
    BRLO  lcd_done10
    SUBI  R18, 10
    INC   R20
    RJMP  lcd_10
lcd_done10:
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL lcd_write_char
    MOV   R20, R18
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL lcd_write_char
    LDI   R16, 'm'
    RCALL lcd_write_char
    LDI   R16, 's'
    RCALL lcd_write_char
    LDI   R16, ' '
    RCALL lcd_write_char
    LDI   R16, ' '
    RCALL lcd_write_char
    POP   R20
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

uart_print_u16:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    PUSH  R19
    PUSH  R20
    MOV   R18, R16
    MOV   R19, R17
    LDI   R20, 0
up_100:
    CPI   R19, 0
    BRNE  up_100s
    CPI   R18, 100
    BRLO  up_done100
up_100s:
    SUBI  R18, 100
    SBCI  R19, 0
    INC   R20
    RJMP  up_100
up_done100:
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL uart_write_char
    LDI   R20, 0
up_10:
    CPI   R18, 10
    BRLO  up_done10
    SUBI  R18, 10
    INC   R20
    RJMP  up_10
up_done10:
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL uart_write_char
    MOV   R20, R18
    SUBI  R20, -'0'
    MOV   R16, R20
    RCALL uart_write_char
    LDI   R16, 'm'
    RCALL uart_write_char
    LDI   R16, 's'
    RCALL uart_write_char
    LDI   R16, 0x0D
    RCALL uart_write_char
    LDI   R16, 0x0A
    RCALL uart_write_char
    POP   R20
    POP   R19
    POP   R18
    POP   R17
    POP   R16
    RET

uart_write_char:
    PUSH  R17
uwc_wait:
    LDS   R17, UCSR0A
    SBRS  R17, UDRE0
    RJMP  uwc_wait
    STS   UDR0, R16
    POP   R17
    RET

uart_print_pgm:
    PUSH  R16
    PUSH  R0
upr_loop:
    LPM   R0, Z+
    TST   R0
    BREQ  upr_done
    MOV   R16, R0
    RCALL uart_write_char
    RJMP  upr_loop
upr_done:
    POP   R0
    POP   R16
    RET

i2c_start:
    LDI   R16, (1<<TWINT)|(1<<TWSTA)|(1<<TWEN)
    STS   TWCR, R16
i2c_start_wait:
    LDS   R16, TWCR
    SBRS  R16, TWINT
    RJMP  i2c_start_wait
    RET

i2c_stop:
    LDI   R16, (1<<TWINT)|(1<<TWSTO)|(1<<TWEN)
    STS   TWCR, R16
    RET

i2c_write:
    STS   TWDR, R16
    LDI   R16, (1<<TWINT)|(1<<TWEN)
    STS   TWCR, R16
i2c_write_wait:
    LDS   R16, TWCR
    SBRS  R16, TWINT
    RJMP  i2c_write_wait
    RET

pcf_write:
    PUSH  R16
    RCALL i2c_start
    LDI   R16, (LCD_ADDR<<1)
    RCALL i2c_write
    POP   R16
    RCALL i2c_write
    RCALL i2c_stop
    RET

lcd_send_nibble:
    PUSH  R16
    PUSH  R17
    MOV   R17, R16
    ANDI  R17, 0xF1
    ORI   R17, LCD_BL
    MOV   R16, R17
    ORI   R16, LCD_EN
    RCALL pcf_write
    RCALL delay_1ms
    MOV   R16, R17
    RCALL pcf_write
    RCALL delay_1ms
    POP   R17
    POP   R16
    RET

lcd_write_byte:
    PUSH  R16
    PUSH  R17
    PUSH  R18
    MOV   R18, R16
    ANDI  R16, 0xF0
    TST   R17
    BREQ  lwb_cmd_hi
    ORI   R16, LCD_RS
lwb_cmd_hi:
    RCALL lcd_send_nibble
    MOV   R16, R18
    SWAP  R16
    ANDI  R16, 0xF0
    TST   R17
    BREQ  lwb_cmd_lo
    ORI   R16, LCD_RS
lwb_cmd_lo:
    RCALL lcd_send_nibble
    POP   R18
    POP   R17
    POP   R16
    RET

lcd_cmd:
    PUSH  R17
    LDI   R17, 0
    RCALL lcd_write_byte
    POP   R17
    RET

lcd_write_char:
    PUSH  R17
    LDI   R17, 1
    RCALL lcd_write_byte
    POP   R17
    RET

lcd_print_pgm:
    PUSH  R16
    PUSH  R0
lpp_loop:
    LPM   R0, Z+
    TST   R0
    BREQ  lpp_done
    MOV   R16, R0
    RCALL lcd_write_char
    RJMP  lpp_loop
lpp_done:
    POP   R0
    POP   R16
    RET

lcd_init:
    RCALL delay_100ms
    LDI   R16, 0x30
    LDI   R17, 0
    RCALL lcd_send_nibble
    RCALL delay_5ms
    LDI   R16, 0x30
    RCALL lcd_send_nibble
    RCALL delay_1ms
    LDI   R16, 0x30
    RCALL lcd_send_nibble
    RCALL delay_1ms
    LDI   R16, 0x20
    RCALL lcd_send_nibble
    RCALL delay_1ms
    LDI   R16, 0x28
    RCALL lcd_cmd
    RCALL delay_1ms
    LDI   R16, 0x0C
    RCALL lcd_cmd
    RCALL delay_1ms
    LDI   R16, 0x01
    RCALL lcd_cmd
    RCALL delay_2ms
    LDI   R16, 0x06
    RCALL lcd_cmd
    RCALL delay_1ms
    RET

check_btn_poll:
    SBIS  PIND, PD2
    RJMP  cbp_p1
    SBIS  PIND, PD3
    RJMP  cbp_p2
    LDI   R22, 0
    RET
cbp_p1:
    LDI   R22, 1
    RET
cbp_p2:
    LDI   R22, 2
    RET

delay_1s_poll:
    PUSH  R20
    PUSH  R21
    LDI   R22, 0
    LDI   R21, 200
d1sp_lp:
    RCALL check_btn_poll
    CPI   R22, 0
    BRNE  d1sp_end
    RCALL delay_5ms
    DEC   R21
    BRNE  d1sp_lp
d1sp_end:
    POP   R21
    POP   R20
    RET

random_delay_poll:
    PUSH  R20
    PUSH  R21
    LDI   R22, 0
    RCALL lfsr_next
    MOV   R20, R16
    ANDI  R20, 0x7F
    LDI   R21, 200
rdp_base:
    RCALL check_btn_poll
    CPI   R22, 0
    BRNE  rdp_end
    RCALL delay_5ms
    DEC   R21
    BRNE  rdp_base
rdp_rand:
    RCALL check_btn_poll
    CPI   R22, 0
    BRNE  rdp_end
    RCALL delay_5ms
    RCALL check_btn_poll
    CPI   R22, 0
    BRNE  rdp_end
    RCALL delay_5ms
    RCALL check_btn_poll
    CPI   R22, 0
    BRNE  rdp_end
    RCALL delay_5ms
    DEC   R20
    BRNE  rdp_rand
rdp_end:
    POP   R21
    POP   R20
    RET

delay_1ms:
    PUSH  R20
    PUSH  R21
    LDI   R20, 8
    LDI   R21, 250
d1ms_l1:
    NOP
    NOP
    DEC   R21
    BRNE  d1ms_l1
    DEC   R20
    BRNE  d1ms_l1
    POP   R21
    POP   R20
    RET

delay_2ms:
    RCALL delay_1ms
    RCALL delay_1ms
    RET

delay_5ms:
    PUSH  R20
    LDI   R20, 5
d5ms_lp:
    RCALL delay_1ms
    DEC   R20
    BRNE  d5ms_lp
    POP   R20
    RET

delay_50ms:
    PUSH  R20
    LDI   R20, 50
d50ms_lp:
    RCALL delay_1ms
    DEC   R20
    BRNE  d50ms_lp
    POP   R20
    RET

delay_100ms:
    PUSH  R20
    LDI   R20, 100
d100ms_lp:
    RCALL delay_1ms
    DEC   R20
    BRNE  d100ms_lp
    POP   R20
    RET

delay_150ms:
    PUSH  R20
    LDI   R20, 150
d150ms_lp:
    RCALL delay_1ms
    DEC   R20
    BRNE  d150ms_lp
    POP   R20
    RET

delay_1s:
    PUSH  R20
    LDI   R20, 10
d1s_lp:
    RCALL delay_100ms
    DEC   R20
    BRNE  d1s_lp
    POP   R20
    RET

delay_2s:
    RCALL delay_1s
    RCALL delay_1s
    RET

delay_3s:
    RCALL delay_1s
    RCALL delay_1s
    RCALL delay_1s
    RET

str_title:
    .ascii "  F1 RACE GAME  "
    .byte  0
str_subtitle:
    .ascii " Best of 5 Rnds "
    .byte  0
str_go:
    .ascii ">>> GO! <<<     "
    .byte  0
str_press:
    .ascii "PRESS YOUR BTN! "
    .byte  0
str_round:
    .ascii "  ROUND "
    .byte  0
str_p1colon:
    .ascii "P1:"
    .byte  0
str_p2colon:
    .ascii "P2:"
    .byte  0
str_p1_react:
    .ascii "P1 WINS! Time:  "
    .byte  0
str_p2_react:
    .ascii "P2 WINS! Time:  "
    .byte  0
str_false_p1:
    .ascii "P1 FALSE START! "
    .byte  0
str_false_p2:
    .ascii "P2 FALSE START! "
    .byte  0
str_timeout:
    .ascii "NO RESPONSE...  "
    .byte  0
str_p1_wins:
    .ascii "** P1 CHAMPION**"
    .byte  0
str_p2_wins:
    .ascii "** P2 CHAMPION**"
    .byte  0
str_best_of5:
    .ascii "  BEST OF FIVE  "
    .byte  0
str_new_hs:
    .ascii "** NEW RECORD **"
    .byte  0
str_serial_init:
    .ascii "F1 Race Game Init OK\r\n"
    .byte  0
str_ser_go:
    .ascii "[GO] Reaction phase started\r\n"
    .byte  0
str_ser_timeout:
    .ascii "[TIMEOUT] No button press\r\n"
    .byte  0
str_ser_false1:
    .ascii "[FALSE] P1 false start! P2 gets point\r\n"
    .byte  0
str_ser_false2:
    .ascii "[FALSE] P2 false start! P1 gets point\r\n"
    .byte  0
str_ser_p1react:
    .ascii "[P1 WIN] Reaction time: "
    .byte  0
str_ser_p2react:
    .ascii "[P2 WIN] Reaction time: "
    .byte  0
str_ser_p1wins:
    .ascii "[GAME OVER] Player 1 is Champion!\r\n"
    .byte  0
str_ser_p2wins:
    .ascii "[GAME OVER] Player 2 is Champion!\r\n"
    .byte  0
str_ser_round:
    .ascii "[ROUND] Starting round "
    .byte  0
str_ser_newhs:
    .ascii "== New high score saved! ==\r\n"
    .byte  0