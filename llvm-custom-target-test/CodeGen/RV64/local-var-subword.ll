; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Sub-word local vars: narrower load/store than the i64 case covered by
; local-var.ll

define i32 @local_var_i32(i32 %a) {
; CHECK-LABEL: local_var_i32:
; CHECK: addi x2, x2, -16
; CHECK: sw x10, 12(x2)
; CHECK: lw x10, 12(x2)
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i32
  store i32 %a, ptr %slot
  %v = load i32, ptr %slot
  ret i32 %v
}

define signext i16 @local_var_i16(i16 signext %a) {
; CHECK-LABEL: local_var_i16:
; CHECK: addi x2, x2, -16
; CHECK: sh x10, 14(x2)
; CHECK: lh x10, 14(x2)
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i16
  store i16 %a, ptr %slot
  %v = load i16, ptr %slot
  ret i16 %v
}

define signext i8 @local_var_i8(i8 signext %a) {
; CHECK-LABEL: local_var_i8:
; CHECK: addi x2, x2, -16
; CHECK: sb x10, 15(x2)
; CHECK: lb x10, 15(x2)
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i8
  store i8 %a, ptr %slot
  %v = load i8, ptr %slot
  ret i8 %v
}
