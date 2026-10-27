#ifndef OLC_AVR_RUNTIME_H
#define OLC_AVR_RUNTIME_H
#include <stdint.h>
void uart_init(void);
void uart_putc(char c);
void print_i32(int32_t value);
void print_f64(double value);
#endif
