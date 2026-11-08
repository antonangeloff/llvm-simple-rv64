; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @sext_i8_to_i64(i8 %a) {
; CHECK-LABEL: sext_i8_to_i64:
; CHECK: slli x10, x10, 56
; CHECK: srai x10, x10, 56
; CHECK: jalr x0, 0(x1)
entry:
  %v = sext i8 %a to i64
  ret i64 %v
}

define i64 @sext_i16_to_i64(i16 %a) {
; CHECK-LABEL: sext_i16_to_i64:
; CHECK: slli x10, x10, 48
; CHECK: srai x10, x10, 48
; CHECK: jalr x0, 0(x1)
entry:
  %v = sext i16 %a to i64
  ret i64 %v
}

define i64 @sext_i32_to_i64(i32 %a) {
; CHECK-LABEL: sext_i32_to_i64:
; CHECK: slli x10, x10, 32
; CHECK: srai x10, x10, 32
; CHECK: jalr x0, 0(x1)
entry:
  %v = sext i32 %a to i64
  ret i64 %v
}

define i64 @zext_i8_to_i64(i8 %a) {
; CHECK-LABEL: zext_i8_to_i64:
; CHECK: andi x10, x10, 255
; CHECK: jalr x0, 0(x1)
entry:
  %v = zext i8 %a to i64
  ret i64 %v
}

define i64 @zext_i16_to_i64(i16 %a) {
; CHECK-LABEL: zext_i16_to_i64:
; CHECK: lui [[MASK:x[0-9]+]], 16
; CHECK: addiw [[MASK]], [[MASK]], -1
; CHECK: and x10, x10, [[MASK]]
; CHECK: jalr x0, 0(x1)
entry:
  %v = zext i16 %a to i64
  ret i64 %v
}

define i64 @zext_i32_to_i64(i32 %a) {
; CHECK-LABEL: zext_i32_to_i64:
; CHECK: lui [[MASK:x[0-9]+]], 256
; CHECK: slli [[MASK]], [[MASK]], 12
; CHECK: addi [[MASK]], [[MASK]], -1
; CHECK: and x10, x10, [[MASK]]
; CHECK: jalr x0, 0(x1)
entry:
  %v = zext i32 %a to i64
  ret i64 %v
}

define i64 @zext_xor_i32_result(i32 %a, i32 %b) {
; CHECK-LABEL: zext_xor_i32_result:
; CHECK: xor x10, x10, x11
; CHECK: slli x10, x10, 32
; CHECK: srli x10, x10, 32
; CHECK: jalr x0, 0(x1)
entry:
  %r = xor i32 %a, %b
  %ext = zext i32 %r to i64
  ret i64 %ext
}
