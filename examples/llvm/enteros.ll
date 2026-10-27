declare void @print_i32(i32)
declare void @print_f64(double)

define void @olc_program() {
entry:
  %t1 = add i32 10, 20
  %t2 = sub i32 20, 5
  %t3 = mul i32 %t1, %t2
  call void @print_i32(i32 %t3)
  ret void
}
