; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

define i64 @select_i64(i1 %cond, i64 %a, i64 %b) {
; CHECK-LABEL: select_i64:
; CHECK: slli [[MASK:x[0-9]+]], x10, 63
; CHECK: srai [[MASK]], [[MASK]], 63
; CHECK: xori [[NOTMASK:x[0-9]+]], [[MASK]], -1
; CHECK: and x10, x11, [[MASK]]
; CHECK: and x11, x12, [[NOTMASK]]
; CHECK: or x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %r = select i1 %cond, i64 %a, i64 %b
  ret i64 %r
}

define i64 @select_min(i64 %a, i64 %b) {
; CHECK-LABEL: select_min:
; CHECK: slt [[COND:x[0-9]+]], x10, x11
; CHECK: slli [[COND]], [[COND]], 63
; CHECK: srai [[COND]], [[COND]], 63
; CHECK: xori [[NOTMASK:x[0-9]+]], [[COND]], -1
; CHECK: and x10, x10, [[COND]]
; CHECK: and x11, x11, [[NOTMASK]]
; CHECK: or x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %cmp = icmp slt i64 %a, %b
  %r = select i1 %cmp, i64 %a, i64 %b
  ret i64 %r
}
