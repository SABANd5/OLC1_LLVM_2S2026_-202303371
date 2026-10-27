#include "runtime.h"
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

static char output[256];
static size_t size;
void uart_putc(char c) { if (size + 1 < sizeof output) output[size++] = c; }

int main(void)
{
    print_i32(0);
    print_i32(INT32_MAX);
    print_i32(INT32_MIN);
    print_f64(2.5);
    print_f64(-0.0);
    print_f64(1.9996);
    print_f64(1000000.0);
    print_f64(NAN);
    output[size] = '\0';
    const char *expected = "0\r\n2147483647\r\n-2147483648\r\n2.500\r\n-0.000\r\n"
                           "2.000\r\nfuera_de_rango\r\nnan\r\n";
    if (strcmp(output, expected) != 0) {
        fputs("Falló la comparación del formato del runtime\n", stderr);
        return 1;
    }
    return 0;
}
