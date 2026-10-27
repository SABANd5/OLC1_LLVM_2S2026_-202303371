declare void @print_i32(i32)
declare void @print_f64(double)

define void @olc_program() {
entry:
  %t1 = fmul double 0x4039800000000000, 0x4010000000000000
  call void @print_f64(double %t1)
  ret void
}
