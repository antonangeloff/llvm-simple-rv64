; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Pure passthrough: the incoming X10 and the required return register are
; the same, so the formal-arg copy and the return copy should coalesce away
; entirely - no ADDI, no COPY, just the bare return.
define i64 @identity(i64 %a) {
; CHECK-LABEL: identity:
; CHECK-NOT: addi
; CHECK: jalr x0, 0(x1)
  ret i64 %a
}

; %a arrives in X10, %b arrives in X11, but the return value must be in X10 -
; this can't coalesce away, so it needs a genuine cross-register move.
define i64 @second(i64 %a, i64 %b) {
; CHECK-LABEL: second:
; CHECK: addi x10, x11, 0
; CHECK: jalr x0, 0(x1)
  ret i64 %b
}

; CC_RV64_LP64 promotes i32 args to i64, so the incoming value in X10 is wider
; than the formal argument's own type - this exercises the copy-then-truncate
; path in assignValueToReg, and separately asks whether lowerReturn's bare
; COPY back into X10 does anything correct with the now-i32-typed value.
; No exact instruction sequence asserted here on purpose - the open question
; is whether this selects/builds cleanly at all, not yet what's optimal.
define i32 @identity32(i32 %a) {
; CHECK-LABEL: identity32:
; CHECK: jalr x0, 0(x1)
  ret i32 %a
}

; CC_RV64_LP64 assigns the first 8 i64 args to X10-X17; the 9th overflows to the
; stack (CCAssignToStack<8, 8>), forcing getStackAddress/assignValueToAddress
; to actually run for the first time. This is expected to fail outright right
; now, not just produce a suboptimal sequence: there's no load instruction
; (LD/LW-equivalent) defined anywhere in RV64InstrInfo.td, so the G_LOAD this
; path builds has no pattern to select into and no legalizer rule either.
define i64 @ninth(i64 %a0, i64 %a1, i64 %a2, i64 %a3, i64 %a4, i64 %a5,
                   i64 %a6, i64 %a7, i64 %a8) {
; CHECK-LABEL: ninth:
; CHECK: ld x10, {{[0-9]+}}(x2)
; CHECK: jalr x0, 0(x1)
  ret i64 %a8
}
