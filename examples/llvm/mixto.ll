declare void @print_i32(i32)
declare void @print_f64(double)

define void @olc_program() {
entry:
  %t1 = add i32 8, 4
  %t2 = sdiv i32 %t1, 2
  %t3 = fadd double 0x3FB999999999999A, 0x4004000000000000
  %t4 = fmul double %t3, 0x4008000000000000
  call void @print_i32(i32 %t2)
  call void @print_f64(double %t4)
  ret void
}
