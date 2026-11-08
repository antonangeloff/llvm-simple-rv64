; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

declare void @llvm.va_start.p0(ptr)
declare void @llvm.va_end.p0(ptr)

; No fixed parameters: every integer argument register (x10-x17) is available
; for varargs and must be spilled in the prologue, immediately below entry sp
; per the RISC-V psABI.
define i64 @sum_two_varargs(...) {
; CHECK-LABEL: sum_two_varargs:
; CHECK: addi x2, x2, -80
; CHECK: addi [[BASE:x[0-9]+]], x2, 16
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: sd x10, 16(x2)
; CHECK: add [[P1:x[0-9]+]], [[BASE]], [[INC]]
; CHECK: sd x11, 24(x2)
; CHECK: add [[P2:x[0-9]+]], [[P1]], [[INC]]
; CHECK: sd x12, 8([[P1]])
; CHECK: add [[P3:x[0-9]+]], [[P2]], [[INC]]
; CHECK: sd x13, 8([[P2]])
; CHECK: add [[P4:x[0-9]+]], [[P3]], [[INC]]
; CHECK: sd x14, 8([[P3]])
; CHECK: add [[P5:x[0-9]+]], [[P4]], [[INC]]
; CHECK: sd x15, 8([[P4]])
; CHECK: add [[P6:x[0-9]+]], [[P5]], [[INC]]
; CHECK: sd x16, 8([[P5]])
; CHECK: sd x17, 8([[P6]])
; CHECK: sd [[BASE]], 8(x2)
; CHECK: ld [[CUR0:x[0-9]+]], 8(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: add [[CUR0]], [[CUR0]], [[ALIGNAMT]]
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: and [[CUR0]], [[CUR0]], [[MASK]]
; CHECK: add [[NEXT0:x[0-9]+]], [[CUR0]], [[INC]]
; CHECK: sd [[NEXT0]], 8(x2)
; CHECK: ld [[A:x[0-9]+]], 0([[CUR0]])
; CHECK: ld [[CUR1:x[0-9]+]], 8(x2)
; CHECK: add [[TMP1:x[0-9]+]], [[CUR1]], [[ALIGNAMT]]
; CHECK: and [[TMP1]], [[TMP1]], [[MASK]]
; CHECK: add [[NEXT1:x[0-9]+]], [[TMP1]], [[INC]]
; CHECK: sd [[NEXT1]], 8(x2)
; CHECK: ld [[B:x[0-9]+]], 0([[TMP1]])
; CHECK: add [[A]], [[A]], [[B]]
; CHECK: addi x2, x2, 80
; CHECK: jalr x0, 0(x1)
entry:
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  %a = va_arg ptr %args, i64
  %b = va_arg ptr %args, i64
  call void @llvm.va_end.p0(ptr %args)
  %r = add i64 %a, %b
  ret i64 %r
}

; One fixed parameter (x10): x11-x17 remain available for varargs and must be
; spilled; va_start's cursor should begin at x11's saved slot, not x10's.
define i64 @sum_after_one(i64 %count, ...) {
; CHECK-LABEL: sum_after_one:
; CHECK: addi x2, x2, -64
; CHECK: addi [[BASE:x[0-9]+]], x2, 8
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: sd x11, 8(x2)
; CHECK: add [[P1:x[0-9]+]], [[BASE]], [[INC]]
; CHECK: sd x12, 16(x2)
; CHECK: add [[P2:x[0-9]+]], [[P1]], [[INC]]
; CHECK: sd x13, 8([[P1]])
; CHECK: add [[P3:x[0-9]+]], [[P2]], [[INC]]
; CHECK: sd x14, 8([[P2]])
; CHECK: add [[P4:x[0-9]+]], [[P3]], [[INC]]
; CHECK: sd x15, 8([[P3]])
; CHECK: add [[P5:x[0-9]+]], [[P4]], [[INC]]
; CHECK: sd x16, 8([[P4]])
; CHECK: sd x17, 8([[P5]])
; CHECK: sd [[BASE]], 0(x2)
; CHECK: ld [[CUR0:x[0-9]+]], 0(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: add [[CUR0]], [[CUR0]], [[ALIGNAMT]]
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: and [[CUR0]], [[CUR0]], [[MASK]]
; CHECK: add [[NEXT0:x[0-9]+]], [[CUR0]], [[INC]]
; CHECK: sd [[NEXT0]], 0(x2)
; CHECK: ld [[A:x[0-9]+]], 0([[CUR0]])
; CHECK: ld [[CUR1:x[0-9]+]], 0(x2)
; CHECK: add [[TMP1:x[0-9]+]], [[CUR1]], [[ALIGNAMT]]
; CHECK: and [[TMP1]], [[TMP1]], [[MASK]]
; CHECK: add [[NEXT1:x[0-9]+]], [[TMP1]], [[INC]]
; CHECK: sd [[NEXT1]], 0(x2)
; CHECK: ld [[B:x[0-9]+]], 0([[TMP1]])
; CHECK: add [[A]], [[A]], [[B]]
; CHECK: addi x2, x2, 64
; CHECK: jalr x0, 0(x1)
entry:
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  %a = va_arg ptr %args, i64
  %b = va_arg ptr %args, i64
  call void @llvm.va_end.p0(ptr %args)
  %r = add i64 %a, %b
  ret i64 %r
}

; All eight integer argument registers already claimed by fixed parameters:
; nothing to spill, va_start should point straight at the incoming
; stack-argument area.
define i64 @sum_all_regs_used(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i64 %g, i64 %h, ...) {
; CHECK-LABEL: sum_all_regs_used:
; CHECK: addi [[BASE:x[0-9]+]], x2, 16
; CHECK: sd [[BASE]], 8(x2)
; CHECK: ld [[CUR0:x[0-9]+]], 8(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: add [[CUR0]], [[CUR0]], [[ALIGNAMT]]
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: and [[CUR0]], [[CUR0]], [[MASK]]
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: add [[NEXT0:x[0-9]+]], [[CUR0]], [[INC]]
; CHECK: sd [[NEXT0]], 8(x2)
; CHECK: ld [[V0:x[0-9]+]], 0([[CUR0]])
; CHECK: add x10, x10, [[V0]]
; CHECK: jalr x0, 0(x1)
entry:
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  %v0 = va_arg ptr %args, i64
  call void @llvm.va_end.p0(ptr %args)
  %r = add i64 %a, %v0
  ret i64 %r
}

declare i64 @sum_two_varargs_decl(...)

define i64 @call_sum_two(i64 %x, i64 %y) {
; CHECK-LABEL: call_sum_two:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: jal x1, sum_two_varargs_decl
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  %r = call i64 (...) @sum_two_varargs_decl(i64 %x, i64 %y)
  ret i64 %r
}

; Register-to-stack-overflow continuity: 6 fixed args claim x10-x15, leaving
; only x16-x17 (2 registers) for varargs. Reading 4 variadic values means the
; first 2 come from the register save area, but the last 2 must come from
; the caller's genuine stack-overflow area.
define i64 @sum_four_overflow(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, ...) {
; CHECK-LABEL: sum_four_overflow:
; CHECK: addi x2, x2, -32
; CHECK: sd x16, 16(x2)
; CHECK: sd x17, 24(x2)
; CHECK: addi [[BASE:x[0-9]+]], x2, 16
; CHECK: sd [[BASE]], 8(x2)
; CHECK: ld [[CUR0:x[0-9]+]], 8(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: add [[CUR0]], [[CUR0]], [[ALIGNAMT]]
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: and [[CUR0]], [[CUR0]], [[MASK]]
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: add [[NEXT0:x[0-9]+]], [[CUR0]], [[INC]]
; CHECK: sd [[NEXT0]], 8(x2)
; CHECK: ld [[V0:x[0-9]+]], 0([[CUR0]])
; CHECK: ld [[CUR1:x[0-9]+]], 8(x2)
; CHECK: add [[CUR1]], [[CUR1]], [[ALIGNAMT]]
; CHECK: and [[CUR1]], [[CUR1]], [[MASK]]
; CHECK: add [[NEXT1:x[0-9]+]], [[CUR1]], [[INC]]
; CHECK: sd [[NEXT1]], 8(x2)
; CHECK: ld [[V1:x[0-9]+]], 0([[CUR1]])
; CHECK: ld [[CUR2:x[0-9]+]], 8(x2)
; CHECK: add [[CUR2]], [[CUR2]], [[ALIGNAMT]]
; CHECK: and [[CUR2]], [[CUR2]], [[MASK]]
; CHECK: add [[NEXT2:x[0-9]+]], [[CUR2]], [[INC]]
; CHECK: sd [[NEXT2]], 8(x2)
; CHECK: ld [[V2:x[0-9]+]], 0([[CUR2]])
; CHECK: ld [[CUR3:x[0-9]+]], 8(x2)
; CHECK: add [[TMP3:x[0-9]+]], [[CUR3]], [[ALIGNAMT]]
; CHECK: and [[TMP3]], [[TMP3]], [[MASK]]
; CHECK: add [[NEXT3:x[0-9]+]], [[TMP3]], [[INC]]
; CHECK: sd [[NEXT3]], 8(x2)
; CHECK: ld [[V3:x[0-9]+]], 0([[TMP3]])
; CHECK: add [[V0]], [[V0]], [[V1]]
; CHECK: add [[V0]], [[V0]], [[V2]]
; CHECK: add [[V0]], [[V0]], [[V3]]
; CHECK: addi x2, x2, 32
; CHECK: jalr x0, 0(x1)
entry:
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  %v0 = va_arg ptr %args, i64
  %v1 = va_arg ptr %args, i64
  %v2 = va_arg ptr %args, i64
  %v3 = va_arg ptr %args, i64
  call void @llvm.va_end.p0(ptr %args)
  %s0 = add i64 %v0, %v1
  %s1 = add i64 %s0, %v2
  %s2 = add i64 %s1, %v3
  ret i64 %s2
}

declare i64 @sum_four_overflow_decl(i64, i64, i64, i64, i64, i64, ...)

define i64 @call_sum_four_overflow(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i64 %w, i64 %x, i64 %y, i64 %z) {
; CHECK-LABEL: call_sum_four_overflow:
; CHECK: addi x2, x2, -32
; CHECK: sd x1, 24(x2)
; CHECK: ld [[Y:x[0-9]+]], 32(x2)
; CHECK: ld [[Z:x[0-9]+]], 40(x2)
; CHECK: sd [[Y]], 0(x2)
; CHECK: sd [[Z]], 8(x2)
; CHECK: jal x1, sum_four_overflow_decl
; CHECK: ld x1, 24(x2)
; CHECK: addi x2, x2, 32
; CHECK: jalr x0, 0(x1)
entry:
  %r = call i64 (i64, i64, i64, i64, i64, i64, ...) @sum_four_overflow_decl(i64 %a, i64 %b, i64 %c, i64 %d, i64 %e, i64 %f, i64 %w, i64 %x, i64 %y, i64 %z)
  ret i64 %r
}

; va_arg inside a loop: a single static G_VAARG instruction executing a
; dynamically-unknown number of times (driven by the runtime value %count),
define i64 @sum_loop_varargs(i64 %count, ...) {
; CHECK-LABEL: sum_loop_varargs:
; CHECK: addi x2, x2, -64
; CHECK: addi [[BASE:x[0-9]+]], x2, 8
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: sd x11, 8(x2)
; CHECK: add [[P1:x[0-9]+]], [[BASE]], [[INC]]
; CHECK: sd x12, 16(x2)
; CHECK: add [[P2:x[0-9]+]], [[P1]], [[INC]]
; CHECK: sd x13, 8([[P1]])
; CHECK: add [[P3:x[0-9]+]], [[P2]], [[INC]]
; CHECK: sd x14, 8([[P2]])
; CHECK: add [[P4:x[0-9]+]], [[P3]], [[INC]]
; CHECK: sd x15, 8([[P3]])
; CHECK: add [[P5:x[0-9]+]], [[P4]], [[INC]]
; CHECK: sd x16, 8([[P4]])
; CHECK: sd x17, 8([[P5]])
; CHECK: addi [[SUM:x[0-9]+]], x0, 0
; CHECK: sd [[BASE]], 0(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: addi [[I:x[0-9]+]], [[SUM]], 0
; CHECK: jal x0, [[LOOP:.LBB[0-9_]+]]
; CHECK: [[LOOP]]:
; CHECK: ld [[CUR:x[0-9]+]], 0(x2)
; CHECK: add [[CUR]], [[CUR]], [[ALIGNAMT]]
; CHECK: and [[CUR]], [[CUR]], [[MASK]]
; CHECK: add [[NEXT:x[0-9]+]], [[CUR]], [[INC]]
; CHECK: sd [[NEXT]], 0(x2)
; CHECK: ld [[V:x[0-9]+]], 0([[CUR]])
; CHECK: addi [[I]], [[I]], 1
; CHECK: add [[SUM]], [[SUM]], [[V]]
; CHECK: blt [[I]], x10, [[LOOP]]
; CHECK: addi x10, [[SUM]], 0
; CHECK: addi x2, x2, 64
; CHECK: jalr x0, 0(x1)
entry:
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  br label %loop

loop:
  %i = phi i64 [ 0, %entry ], [ %i.next, %loop ]
  %sum = phi i64 [ 0, %entry ], [ %sum.next, %loop ]
  %v = va_arg ptr %args, i64
  %sum.next = add i64 %sum, %v
  %i.next = add i64 %i, 1
  %cond = icmp slt i64 %i.next, %count
  br i1 %cond, label %loop, label %exit

exit:
  call void @llvm.va_end.p0(ptr %args)
  ret i64 %sum.next
}

%Pair = type { i64, i64 }

define i64 @sum_struct_and_varargs(%Pair %p, ...) {
; CHECK-LABEL: sum_struct_and_varargs:
; CHECK: addi x2, x2, -64
; CHECK: addi [[BASE:x[0-9]+]], x2, 16
; CHECK: addi [[INC:x[0-9]+]], x0, 8
; CHECK: sd x12, 16(x2)
; CHECK: add [[P1:x[0-9]+]], [[BASE]], [[INC]]
; CHECK: sd x13, 24(x2)
; CHECK: add [[P2:x[0-9]+]], [[P1]], [[INC]]
; CHECK: sd x14, 8([[P1]])
; CHECK: add [[P3:x[0-9]+]], [[P2]], [[INC]]
; CHECK: sd x15, 8([[P2]])
; CHECK: add [[P4:x[0-9]+]], [[P3]], [[INC]]
; CHECK: sd x16, 8([[P3]])
; CHECK: sd x17, 8([[P4]])
; CHECK: sd [[BASE]], 8(x2)
; CHECK: ld [[CUR0:x[0-9]+]], 8(x2)
; CHECK: addi [[ALIGNAMT:x[0-9]+]], x0, 7
; CHECK: add [[CUR0]], [[CUR0]], [[ALIGNAMT]]
; CHECK: addi [[MASK:x[0-9]+]], x0, -8
; CHECK: and [[CUR0]], [[CUR0]], [[MASK]]
; CHECK: add [[NEXT0:x[0-9]+]], [[CUR0]], [[INC]]
; CHECK: sd [[NEXT0]], 8(x2)
; CHECK: ld [[V:x[0-9]+]], 0([[CUR0]])
; CHECK: add x10, x10, x11
; CHECK: add x10, x10, [[V]]
; CHECK: addi x2, x2, 64
; CHECK: jalr x0, 0(x1)
entry:
  %a = extractvalue %Pair %p, 0
  %b = extractvalue %Pair %p, 1
  %args = alloca ptr
  call void @llvm.va_start.p0(ptr %args)
  %v = va_arg ptr %args, i64
  call void @llvm.va_end.p0(ptr %args)
  %s0 = add i64 %a, %b
  %s1 = add i64 %s0, %v
  ret i64 %s1
}
