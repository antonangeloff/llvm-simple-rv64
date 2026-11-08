; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 | FileCheck %s

; Frame size past ADDI's 12-bit signed immediate range (outside [-2048, 2047]).
; emitPrologue/emitEpilogue materialize the frame size into a scratch register
; via the same LUI/ADDIW sequence selectConstant uses for wide G_CONSTANT
; values, then use a register-register SUB (prologue) / ADD (epilogue)
; against x2 instead of folding the immediate into ADDI. eliminateFrameIndex
; does the equivalent for the resulting out-of-range load/store offset, via a
; scavenged scratch register (not a fixed/reserved one).
;
; 300 x i64 = 2400 bytes for the alloca itself. Because the estimated stack
; size doesn't fit an 11-bit field, processFunctionBeforeFrameFinalized also
; reserves an 8-byte emergency scavenging spill slot (see RV64FrameLowering),
; which becomes a second frame object: 2400 + 8 = 2408, rounded up to the
; next multiple of 16 = 2416. The alloca's own object offset (-2400) plus
; this final FrameSize (2416) gives its load/store offset: 16.
;   isInt<12>(2416) is false -> wide path
;   immLui  = ((2416 + 0x800) >> 12) & 0xFFFFF = 1
;   immAddi = signext12(2416 - (1 << 12))      = -1680
;   check: (1 << 12) + (-1680) == 2416

define i64 @local_var_large_frame(i64 %a) {
; CHECK-LABEL: local_var_large_frame:
; CHECK: lui [[SCRATCH1:x[0-9]+]], 1
; CHECK: addiw [[SCRATCH1]], [[SCRATCH1]], -1680
; CHECK: sub x2, x2, [[SCRATCH1]]
; CHECK: sd x10, 16(x2)
; CHECK: ld x10, 16(x2)
; CHECK: lui [[SCRATCH2:x[0-9]+]], 1
; CHECK: addiw [[SCRATCH2]], [[SCRATCH2]], -1680
; CHECK: add x2, x2, [[SCRATCH2]]
entry:
  %slot = alloca [300 x i64]
  store i64 %a, ptr %slot
  %v = load i64, ptr %slot
  ret i64 %v
}
