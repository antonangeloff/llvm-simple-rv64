; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Address-of-local: the frame index feeds a plain return value instead of
; being folded directly into a load/store's base+offset, exercising
; selectFrameIndex rather than selectStore/selectLoad.
;
; %slot is used twice (store and ret), so IRTranslator creates a single
; G_FRAME_INDEX and caches/reuses that vreg for both uses, placed at the
; first use site - hence the address ADDI lands before the store, not after.
; The materialized address then needs a separate copy into the ABI return
; register x10 (printed as "addi rd, rs, 0", RISC-V's usual move idiom),
; since this minimal -O0 pipeline has no copy-coalescing/peephole pass to
; fold that away.

define ptr @local_var_addr(i64 %a) {
; CHECK-LABEL: local_var_addr:
; CHECK: addi x2, x2, -16
; CHECK: addi [[ADDR:x[0-9]+]], x2, 8
; CHECK: sd x10, 8(x2)
; CHECK: addi x10, [[ADDR]], 0
; CHECK: addi x2, x2, 16
entry:
  %slot = alloca i64
  store i64 %a, ptr %slot
  ret ptr %slot
}
