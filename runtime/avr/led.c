#include "runtime.h"
#include <avr/io.h>

/* Arduino Mega D13 / built-in LED is ATmega2560 PB7. */
void olc_led13_on(void)
{
    DDRB |= _BV(DDB7);
    PORTB |= _BV(PORTB7);
}
