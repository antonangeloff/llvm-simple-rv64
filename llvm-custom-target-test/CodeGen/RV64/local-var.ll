; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Single local var: store then load back through the same slot.
define i64 @local_var_basic(i64 %a) {
; CHECK-LABEL: local_var_basic:
; CHECK: addi x2, x2, -16
; CHECK: sd x10, 8(x2)
; CHECK: ld x10, 8(x2)
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i64
  store i64 %a, ptr %slot
  %v = load i64, ptr %slot
  ret i64 %v
}

; Local var overwritten before being read, to force real memory semantics
; (not promotable to a register by anything running in this bare llc pipeline).
define i64 @local_var_overwrite(i64 %a, i64 %b) {
; CHECK-LABEL: local_var_overwrite:
; CHECK: addi x2, x2, -16
; CHECK: sd x10, 8(x2)
; CHECK: sd x11, 8(x2)
; CHECK: ld x10, 8(x2)
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i64
  store i64 %a, ptr %slot
  store i64 %b, ptr %slot
  %v = load i64, ptr %slot
  ret i64 %v
}

; Two separate local vars, to exercise stack layout/offsets for multiple
; frame objects in the same function.
define i64 @local_var_two(i64 %a, i64 %b) {
; CHECK-LABEL: local_var_two:
; CHECK: addi x2, x2, -16
; CHECK: sd x10, 8(x2)
; CHECK: sd x11, 0(x2)
; CHECK: ld x10, 8(x2)
; CHECK: ld x11, 0(x2)
; CHECK: add x10, x10, x11
; CHECK: addi x2, x2, 16
entry:
  %s1 = alloca i64
  %s2 = alloca i64
  store i64 %a, ptr %s1
  store i64 %b, ptr %s2
  %v1 = load i64, ptr %s1
  %v2 = load i64, ptr %s2
  %sum = add i64 %v1, %v2
  ret i64 %sum
}
