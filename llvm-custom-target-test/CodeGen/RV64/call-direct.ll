; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

declare i64 @callee(i64, i64)
declare void @callee_void(i64)
declare i64 @callee10(i64, i64, i64, i64, i64, i64, i64, i64, i64, i64)

define i64 @call_const_args() {
; CHECK-LABEL: call_const_args:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: addi x10, x0, 42
; CHECK: addi x11, x0, 7
; CHECK: jal x1, callee
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  %r = call i64 @callee(i64 42, i64 7)
  ret i64 %r
}

define void @call_void_arg(i64 %a) {
; CHECK-LABEL: call_void_arg:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: jal x1, callee_void
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  call void @callee_void(i64 %a)
  ret void
}

; More than 8 integer arguments: the first 8 fit in x10-x17, the remaining 2
; overflow onto the stack (CC_RV64_LP64's CCAssignToStack<8, 8>).
define i64 @call_stack_arg() {
; CHECK-LABEL: call_stack_arg:
; CHECK: addi x2, x2, -32
; CHECK: sd x1, 24(x2)
; CHECK: addi x10, x0, 1
; CHECK: addi x11, x0, 2
; CHECK: addi x12, x0, 3
; CHECK: addi x13, x0, 4
; CHECK: addi x14, x0, 5
; CHECK: addi x15, x0, 6
; CHECK: addi x16, x0, 7
; CHECK: addi x17, x0, 8
; CHECK: addi [[V9:x[0-9]+]], x0, 9
; CHECK: addi [[V10:x[0-9]+]], x0, 10
; CHECK: sd [[V9]], 0(x2)
; CHECK: sd [[V10]], 8(x2)
; CHECK: jal x1, callee10
; CHECK: ld x1, 24(x2)
; CHECK: addi x2, x2, 32
; CHECK: jalr x0, 0(x1)
entry:
  %r = call i64 @callee10(i64 1, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7, i64 8, i64 9, i64 10)
  ret i64 %r
}

define i64 @formal_stack_arg(i64 %a0, i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5, i64 %a6, i64 %a7, i64 %a8, i64 %a9) {
; CHECK-LABEL: formal_stack_arg:
; CHECK: ld x10, 0(x2)
; CHECK: ld x11, 8(x2)
; CHECK: add x10, x10, x11
; CHECK: jalr x0, 0(x1)
entry:
  %sum = add i64 %a8, %a9
  ret i64 %sum
}

; A local variable plus a call in the same function: frame-size computation
; now has to combine local-variable space, the ra-spill slot, and call-frame
; overflow space all at once -- a combination no earlier test exercises.
define i64 @call_with_local() {
; CHECK-LABEL: call_with_local:
; CHECK: addi x2, x2, -32
; CHECK: sd x1, 24(x2)
; CHECK: addi [[V11:x[0-9]+]], x0, 11
; CHECK: addi [[V22:x[0-9]+]], x0, 22
; CHECK: addi x10, x0, 1
; CHECK: addi x11, x0, 2
; CHECK: sd [[V11]], 8(x2)
; CHECK: sd [[V22]], 16(x2)
; CHECK: jal x1, callee
; CHECK: ld [[L0:x[0-9]+]], 8(x2)
; CHECK: ld [[L1:x[0-9]+]], 16(x2)
; CHECK: add [[SUM0:x[0-9]+]], [[L0]], [[L1]]
; CHECK: add x10, [[SUM0]], x10
; CHECK: ld x1, 24(x2)
; CHECK: addi x2, x2, 32
; CHECK: jalr x0, 0(x1)
entry:
  %buf = alloca [2 x i64]
  %p0 = getelementptr [2 x i64], ptr %buf, i64 0, i64 0
  %p1 = getelementptr [2 x i64], ptr %buf, i64 0, i64 1
  store i64 11, ptr %p0
  store i64 22, ptr %p1
  %r = call i64 @callee(i64 1, i64 2)
  %v0 = load i64, ptr %p0
  %v1 = load i64, ptr %p1
  %sum0 = add i64 %v0, %v1
  %sum = add i64 %sum0, %r
  ret i64 %sum
}

; Two calls in one function with different stack-arg requirements (0 bytes,
; then 16 bytes): exercises computeMaxCallFrameSize actually taking the max
; across multiple ADJCALLSTACKDOWN instances, not just the first one.
define i64 @call_twice_different_stack() {
; CHECK-LABEL: call_twice_different_stack:
; CHECK: addi x2, x2, -112
; CHECK: sd x8, 104(x2)
; CHECK: sd x9, 96(x2)
; CHECK: sd x18, 88(x2)
; CHECK: sd x19, 80(x2)
; CHECK: sd x20, 72(x2)
; CHECK: sd x21, 64(x2)
; CHECK: sd x22, 56(x2)
; CHECK: sd x23, 48(x2)
; CHECK: sd x24, 40(x2)
; CHECK: sd x25, 32(x2)
; CHECK: sd x26, 24(x2)
; CHECK: sd x1, 16(x2)
; CHECK: addi [[C1:x[0-9]+]], x0, 1
; CHECK: addi [[C2:x[0-9]+]], x0, 2
; CHECK: addi [[C3:x[0-9]+]], x0, 3
; CHECK: addi [[C4:x[0-9]+]], x0, 4
; CHECK: addi [[C5:x[0-9]+]], x0, 5
; CHECK: addi [[C6:x[0-9]+]], x0, 6
; CHECK: addi [[C7:x[0-9]+]], x0, 7
; CHECK: addi [[C8:x[0-9]+]], x0, 8
; CHECK: addi [[C9:x[0-9]+]], x0, 9
; CHECK: addi [[C10:x[0-9]+]], x0, 10
; CHECK: addi x10, [[C1]], 0
; CHECK: addi x11, [[C2]], 0
; CHECK: jal x1, callee
; CHECK: addi [[R1:x[0-9]+]], x10, 0
; CHECK: sd [[C9]], 0(x2)
; CHECK: sd [[C10]], 8(x2)
; CHECK: addi x10, [[C1]], 0
; CHECK: addi x11, [[C2]], 0
; CHECK: addi x12, [[C3]], 0
; CHECK: addi x13, [[C4]], 0
; CHECK: addi x14, [[C5]], 0
; CHECK: addi x15, [[C6]], 0
; CHECK: addi x16, [[C7]], 0
; CHECK: addi x17, [[C8]], 0
; CHECK: jal x1, callee10
; CHECK: add x10, [[R1]], x10
; CHECK: ld x1, 16(x2)
; CHECK: ld x26, 24(x2)
; CHECK: ld x25, 32(x2)
; CHECK: ld x24, 40(x2)
; CHECK: ld x23, 48(x2)
; CHECK: ld x22, 56(x2)
; CHECK: ld x21, 64(x2)
; CHECK: ld x20, 72(x2)
; CHECK: ld x19, 80(x2)
; CHECK: ld x18, 88(x2)
; CHECK: ld x9, 96(x2)
; CHECK: ld x8, 104(x2)
; CHECK: addi x2, x2, 112
; CHECK: jalr x0, 0(x1)
entry:
  %r1 = call i64 @callee(i64 1, i64 2)
  %r2 = call i64 @callee10(i64 1, i64 2, i64 3, i64 4, i64 5, i64 6, i64 7, i64 8, i64 9, i64 10)
  %sum = add i64 %r1, %r2
  ret i64 %sum
}

; The result of one call used as an argument to the next: exercises the
; regmask/liveness bookkeeping across two back-to-back call sequences rather
; than each call existing in isolation.
define i64 @call_nested() {
; CHECK-LABEL: call_nested:
; CHECK: addi x2, x2, -16
; CHECK: sd x8, 8(x2)
; CHECK: sd x1, 0(x2)
; CHECK: addi x10, x0, 1
; CHECK: addi x11, x0, 2
; CHECK: addi x8, x0, 3
; CHECK: jal x1, callee
; CHECK: addi x11, x8, 0
; CHECK: jal x1, callee
; CHECK: ld x1, 0(x2)
; CHECK: ld x8, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  %inner = call i64 @callee(i64 1, i64 2)
  %outer = call i64 @callee(i64 %inner, i64 3)
  ret i64 %outer
}
