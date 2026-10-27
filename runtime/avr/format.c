#include "runtime.h"
#include <math.h>
#include <stdint.h>

/* Provisional format: one value per CRLF-terminated line. */
static void put_unsigned(uint32_t value)
{
    char digits[10];
    unsigned count = 0;
    do {
        digits[count++] = (char)('0' + value % 10);
        value /= 10;
    } while (value);
    while (count) uart_putc(digits[--count]);
}

void print_i32(int32_t value)
{
    uint32_t magnitude;
    if (value < 0) {
        uart_putc('-');
        /* Avoid negating INT32_MIN. */
        magnitude = (uint32_t)(-(value + 1)) + 1u;
    } else magnitude = (uint32_t)value;
    put_unsigned(magnitude);
    uart_putc('\r');
    uart_putc('\n');
}

void print_f64(double value)
{
    if (isnan(value)) {
        const char *s = "nan\r\n";
        while (*s) uart_putc(*s++);
        return;
    }
    if (signbit(value)) { uart_putc('-'); value = -value; }
    /* Bound the conversion to uint32_t; overflow and infinities are explicit. */
    if (value >= 1000000.0) {
        const char *s = "fuera_de_rango\r\n";
        while (*s) uart_putc(*s++);
        return;
    }
    uint32_t scaled = (uint32_t)(value * 1000.0 + 0.5);
    put_unsigned(scaled / 1000u);
    uart_putc('.');
    unsigned fraction = (unsigned)(scaled % 1000u);
    uart_putc((char)('0' + fraction / 100u));
    uart_putc((char)('0' + (fraction / 10u) % 10u));
    uart_putc((char)('0' + fraction % 10u));
    uart_putc('\r');
    uart_putc('\n');
}
