#include "runtime.h"
#include <avr/io.h>

#ifndef F_CPU
#error F_CPU must be defined
#endif

/* USART0, U2X0=1, 115200 baud nominal at 16 MHz (actual ~117647). */
void uart_init(void)
{
    const uint16_t divisor = (uint16_t)((F_CPU + 4UL * 115200UL) / (8UL * 115200UL) - 1UL);
    UCSR0A = _BV(U2X0);
    UBRR0H = (uint8_t)(divisor >> 8);
    UBRR0L = (uint8_t)divisor;
    UCSR0B = _BV(TXEN0);
    UCSR0C = _BV(UCSZ01) | _BV(UCSZ00);
}

void uart_putc(char c)
{
    while (!(UCSR0A & _BV(UDRE0))) { }
    UDR0 = (uint8_t)c;
}
