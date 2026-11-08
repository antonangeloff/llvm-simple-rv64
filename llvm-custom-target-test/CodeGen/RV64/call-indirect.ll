; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

define i64 @call_indirect(ptr %fp, i64 %a) {
; CHECK-LABEL: call_indirect:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: addi [[TARGET:x[0-9]+]], x10, 0
; CHECK: addi x10, x11, 0
; CHECK: jalr x1, 0([[TARGET]])
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  %r = call i64 %fp(i64 %a)
  ret i64 %r
}

define void @call_indirect_void(ptr %fp, i64 %a) {
; CHECK-LABEL: call_indirect_void:
; CHECK: addi x2, x2, -16
; CHECK: sd x1, 8(x2)
; CHECK: addi [[TARGET:x[0-9]+]], x10, 0
; CHECK: addi x10, x11, 0
; CHECK: jalr x1, 0([[TARGET]])
; CHECK: ld x1, 8(x2)
; CHECK: addi x2, x2, 16
; CHECK: jalr x0, 0(x1)
entry:
  call void %fp(i64 %a)
  ret void
}

; Function pointer loaded from memory rather than received directly as an
; argument - a distinct code path (G_LOAD producing the callee address)
; feeding the same indirect-call mechanism.
@fp_slot = global ptr null

define i64 @call_indirect_via_global(i64 %a) {
; CHECK-LABEL: call_indirect_via_global:
; CHECK: lui [[HI:x[0-9]+]], %hi(fp_slot)
; CHECK: addi [[HI]], [[HI]], %lo(fp_slot)
; CHECK: ld [[FP:x[0-9]+]], 0([[HI]])
; CHECK: jalr x1, 0([[FP]])
entry:
  %fp = load ptr, ptr @fp_slot
  %r = call i64 %fp(i64 %a)
  ret i64 %r
}
