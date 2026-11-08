; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Plain register-register add: both operands already live in GPRs, so this
; should match the "" (register) form of the ALU_RR_RI multiclass directly.
define i64 @add_rr(i64 %a, i64 %b) {
; CHECK-LABEL: add_rr:
; CHECK: add x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = add i64 %a, %b
  ret i64 %r
}

; Register-register sub: SUB only has a register form (no SUBI exists in
; RV64InstrInfo.td - RISC-V does subtract-by-immediate via ADDI with a
; negated constant instead), so this is the direct, unambiguous case.
define i64 @sub_rr(i64 %a, i64 %b) {
; CHECK-LABEL: sub_rr:
; CHECK: sub x10, x10, x11
; CHECK: jalr x0, 0(x1)
  %r = sub i64 %a, %b
  ret i64 %r
}

; Add with an immediate that fits the 12-bit signed range the "I" form's
; i64immSExt12 PatLeaf accepts - this should fold straight into ADDI without
; ever materializing the constant in its own register.
define i64 @add_imm_fits(i64 %a) {
; CHECK-LABEL: add_imm_fits:
; CHECK: addi x10, x10, 100
; CHECK: jalr x0, 0(x1)
  %r = add i64 %a, 100
  ret i64 %r
}

; Add with an immediate outside the 12-bit range: i64immSExt12 won't match,
; so the constant has to be built by selectConstant's own LUI+ADDIW path
; first (same machinery ret-int-constant-wide.ll exercises for `ret`), then
; fed into the register-register ADD form. Register name for the temporary
; is left as a wildcard since the allocator's choice isn't predictable here.
define i64 @add_imm_overflow(i64 %a) {
; CHECK-LABEL: add_imm_overflow:
; CHECK: lui [[T:x[0-9]+]], 1
; CHECK: addiw [[T]], [[T]], 1816
; CHECK: add x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = add i64 %a, 5912
  ret i64 %r
}

; Sub with a constant subtrahend: there's no SUBI, but RV64PreLegalizerCombiner
; runs the generic sub_to_add combine pre-legalization, unconditionally
; rewriting `sub x, C` into `add x, -C` at the full i64 width (-50 negates to
; 50 with no overflow at that width) - which then lets i64immSExt12's
; ADDI-fold pattern fire on the result, same as add_imm_fits. No
; materialize-then-SUB here at all.
define i64 @sub_imm(i64 %a) {
; CHECK-LABEL: sub_imm:
; CHECK: addi x10, x10, -50
; CHECK: jalr x0, 0(x1)
  %r = sub i64 %a, 50
  ret i64 %r
}

; Edge case: the combine's negation happens at the full i64 width and always
; succeeds there, but that doesn't mean the *result* is small enough to fold
; into ADDI. `sub x, -2048` becomes `add x, 2048` - and 2048 is one past the
; 12-bit signed range (max 2047), so i64immSExt12 rejects it. This falls back
; to the same materialize-then-register-ADD path add_imm_overflow uses, just
; reached via sub_to_add instead of a directly-oversized add immediate. 2048
; is small enough that materialization is the single-step LUI+ADDIW case
; (same shape as ret_i32_boundary in ret-int-constant-wide.ll).
define i64 @sub_imm_negation_overflow(i64 %a) {
; CHECK-LABEL: sub_imm_negation_overflow:
; CHECK: lui [[T:x[0-9]+]], 1
; CHECK: addiw [[T]], [[T]], -2048
; CHECK: add x10, x10, [[T]]
; CHECK: jalr x0, 0(x1)
  %r = sub i64 %a, -2048
  ret i64 %r
}
