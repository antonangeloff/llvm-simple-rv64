; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Unwind info: emitPrologue/emitEpilogue adjust sp but currently emit no CFI
; directives alongside it, so .cfi_def_cfa_offset never reflects the frame.
; Expected once implemented: the CFA offset grows by the frame size right
; after the prologue's addi, and drops back to 0 right after the epilogue's.

define i64 @local_var_cfi(i64 %a) {
; CHECK-LABEL: local_var_cfi:
; CHECK: addi x2, x2, -16
; CHECK: .cfi_def_cfa_offset 16
; CHECK: sd x10, 8(x2)
; CHECK: ld x10, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: .cfi_def_cfa_offset 0
entry:
  %slot = alloca i64
  store i64 %a, ptr %slot
  %v = load i64, ptr %slot
  ret i64 %v
}
