; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=static | FileCheck %s

; Global variable access using absolute addressing (static relocation model;
; the target defaults to PIC otherwise, so this needs to be requested
; explicitly). G_GLOBAL_VALUE lowers to the same LUI+ADDI shape used for
; G_CONSTANT/large-frame materialization, except the immediate halves are
; %hi/%lo relocations against the symbol rather than literal bits known at
; compile time. The fully-materialized address is then just a plain
; register, so it goes through the generic reg+0 load/store path (not a
; G_FRAME_INDEX-specific one).

@g = global i64 0

define i64 @read_global() {
; CHECK-LABEL: read_global:
; CHECK: lui [[HI:x[0-9]+]], %hi(g)
; CHECK: addi [[ADDR:x[0-9]+]], [[HI]], %lo(g)
; CHECK: ld x10, 0([[ADDR]])
entry:
  %v = load i64, ptr @g
  ret i64 %v
}

define void @write_global(i64 %a) {
; CHECK-LABEL: write_global:
; CHECK: lui [[HI:x[0-9]+]], %hi(g)
; CHECK: addi [[ADDR:x[0-9]+]], [[HI]], %lo(g)
; CHECK: sd x10, 0([[ADDR]])
entry:
  store i64 %a, ptr @g
  ret void
}
