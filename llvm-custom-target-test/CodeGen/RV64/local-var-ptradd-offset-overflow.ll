; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

define i64 @large_constant_gep_offset() {
; CHECK-LABEL: large_constant_gep_offset:
; CHECK: lui [[FS:x[0-9]+]], 1
; CHECK: addiw [[FS]], [[FS]], -1680
; CHECK: sub x2, x2, [[FS]]
; CHECK: addi x10, x0, 42
; CHECK: lui [[ADDR0:x[0-9]+]], 1
; CHECK: addiw [[ADDR0]], [[ADDR0]], -1760
; CHECK: add [[ADDR0]], [[ADDR0]], x2
; CHECK: sd x10, 0([[ADDR0]])
; CHECK: lui [[ADDR1:x[0-9]+]], 1
; CHECK: addiw [[ADDR1]], [[ADDR1]], -1760
; CHECK: add [[ADDR1]], [[ADDR1]], x2
; CHECK: ld x10, 0([[ADDR1]])
; CHECK: lui [[FS2:x[0-9]+]], 1
; CHECK: addiw [[FS2]], [[FS2]], -1680
; CHECK: add x2, x2, [[FS2]]
; CHECK: jalr x0, 0(x1)
entry:
  %arr = alloca [300 x i64]
  %p = getelementptr [300 x i64], ptr %arr, i64 0, i64 290
  store i64 42, ptr %p
  %v = load i64, ptr %p
  ret i64 %v
}
