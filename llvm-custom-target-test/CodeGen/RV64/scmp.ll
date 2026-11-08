; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

declare i64 @llvm.scmp.i64.i64(i64, i64)
declare i64 @llvm.ucmp.i64.i64(i64, i64)

define i64 @scmp_value(i64 %a, i64 %b) {
; CHECK-LABEL: scmp_value:
entry:
  %r = call i64 @llvm.scmp.i64.i64(i64 %a, i64 %b)
  ret i64 %r
}

define i64 @ucmp_value(i64 %a, i64 %b) {
; CHECK-LABEL: ucmp_value:
entry:
  %r = call i64 @llvm.ucmp.i64.i64(i64 %a, i64 %b)
  ret i64 %r
}
