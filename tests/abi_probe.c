#include <stdint.h>
_Static_assert(sizeof(double) == 8, "double must be 64 bits");
volatile double captured_f64;
volatile int32_t captured_i32;

__attribute__((noinline, used)) void print_f64(double value) { captured_f64 = value; }
__attribute__((noinline, used)) void print_i32(int32_t value) { captured_i32 = value; }
__attribute__((noinline, used)) void gcc_calls(void)
{
    print_f64(2.5);
    print_i32(19088743);
}
