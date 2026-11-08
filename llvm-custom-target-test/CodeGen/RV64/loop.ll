; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @sum_to_n(i64 %n) {
; CHECK-LABEL: sum_to_n:
; CHECK: addi [[SUM:x[0-9]+]], x0, 0
; CHECK: addi [[I:x[0-9]+]], [[SUM]], 0
; CHECK: [[LOOP:\.LBB[0-9]+_[0-9]+]]:
; CHECK: add [[SUM]], [[SUM]], [[I]]
; CHECK: addi [[I]], [[I]], 1
; CHECK: blt [[I]], x10, [[LOOP]]
; CHECK: addi x10, [[SUM]], 0
; CHECK: jalr x0, 0(x1)
entry:
  br label %loop
loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %sum = phi i64 [ 0, %entry ], [ %sum.next, %loop ]
  %sum.next = add i64 %sum, %i
  %i.next = add i64 %i, 1
  %cond = icmp slt i64 %i.next, %n
  br i1 %cond, label %loop, label %done
done:
  ret i64 %sum.next
}
