; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i8 @ret_i8() {
; CHECK-LABEL: ret_i8:
; CHECK: addi x10, x0, 42
; CHECK: jalr x0, 0(x1)
  ret i8 42
}

define i16 @ret_i16() {
; CHECK-LABEL: ret_i16:
; CHECK: addi x10, x0, 42
; CHECK: jalr x0, 0(x1)
  ret i16 42
}

define i32 @ret_i32() {
; CHECK-LABEL: ret_i32:
; CHECK: addi x10, x0, 42
; CHECK: jalr x0, 0(x1)
  ret i32 42
}

define i64 @ret_i64() {
; CHECK-LABEL: ret_i64:
; CHECK: addi x10, x0, 42
; CHECK: jalr x0, 0(x1)
  ret i64 42
}
