; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=pic | FileCheck %s

; Global variable access using PC-relative addressing (PIC relocation
; model). G_GLOBAL_VALUE lowers to AUIPC+ADDI instead of LUI+ADDI: the hi
; part is PC-relative (%pcrel_hi) rather than absolute (%hi), so it must be
; paired with a local anchor label marking the auipc's own address --
; %pcrel_lo on the addi refers back to that label, not to the symbol
; directly, since the relocation is relative to the auipc instruction's
; address rather than to a known link-time constant.

@g = global i64 0

define i64 @read_global() {
; CHECK-LABEL: read_global:
; CHECK: [[LABEL:\.L[a-zA-Z0-9_]+]]:
; CHECK-NEXT: auipc [[HI:x[0-9]+]], %pcrel_hi(g)
; CHECK: addi [[ADDR:x[0-9]+]], [[HI]], %pcrel_lo([[LABEL]])
; CHECK: ld x10, 0([[ADDR]])
entry:
  %v = load i64, ptr @g
  ret i64 %v
}

define void @write_global(i64 %a) {
; CHECK-LABEL: write_global:
; CHECK: [[LABEL:\.L[a-zA-Z0-9_]+]]:
; CHECK-NEXT: auipc [[HI:x[0-9]+]], %pcrel_hi(g)
; CHECK: addi [[ADDR:x[0-9]+]], [[HI]], %pcrel_lo([[LABEL]])
; CHECK: sd x10, 0([[ADDR]])
entry:
  store i64 %a, ptr @g
  ret void
}
