#include "runtime.h"

extern void olc_program(void);

int main(void)
{
    uart_init();
    olc_program();
    for (;;) { }
}
