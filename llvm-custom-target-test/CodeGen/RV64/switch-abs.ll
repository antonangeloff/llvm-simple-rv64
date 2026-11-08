; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

define i64 @switch_dense_abs(i64 %x) {
; CHECK-LABEL: switch_dense_abs:
; CHECK: addi [[LAST:x[0-9]+]], x0, 4
; CHECK: bltu [[LAST]], x10, [[DEFAULT:\.LBB[0-9]+_[0-9]+]]
; CHECK: auipc [[TBL:x[0-9]+]], %pcrel_hi([[JTI:\.LJTI[0-9]+_[0-9]+]])
; CHECK: addi [[TBL]], [[TBL]], %pcrel_lo
; CHECK: slli x10, x10, 3
; CHECK: add x10, [[TBL]], x10
; CHECK: ld x10, 0(x10)
; CHECK: jalr x0, 0(x10)
; CHECK: [[DEFAULT]]:
; CHECK: addi x10, x0, 0
entry:
  switch i64 %x, label %default [
    i64 0, label %c0
    i64 1, label %c1
    i64 2, label %c2
    i64 3, label %c3
    i64 4, label %c4
  ]
c0:
  ret i64 100
c1:
  ret i64 101
c2:
  ret i64 102
c3:
  ret i64 103
c4:
  ret i64 104
default:
  ret i64 0
}
