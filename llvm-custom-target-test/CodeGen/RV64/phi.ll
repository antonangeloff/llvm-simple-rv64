; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @phi_add(i64 %a, i64 %b, i1 %cond) {
; CHECK-LABEL: phi_add:
; CHECK: bne x12, x0, [[JOIN:\.LBB[0-9]+_[0-9]+]]
; CHECK: addi x10, x11, 0
; CHECK: [[JOIN]]:
; CHECK: addi x10, x10, 1
entry:
  br i1 %cond, label %t, label %f
t:
  br label %join
f:
  br label %join
join:
  %r = phi i64 [ %a, %t ], [ %b, %f ]
  %r2 = add i64 %r, 1
  ret i64 %r2
}
