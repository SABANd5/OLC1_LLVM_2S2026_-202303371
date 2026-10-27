target triple = "avr"
define i16 @suma(i16 %a, i16 %b) {
entry:
  %r = add i16 %a, %b
  ret i16 %r
}
