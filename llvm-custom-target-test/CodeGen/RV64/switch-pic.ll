; RUN: llc < %s -mtriple=riscv64 -march=simple-rv64 -relocation-model=pic | FileCheck %s

; Small, sparse switch - expected to lower as a chain of comparisons using
; already-supported G_ICMP/G_BRCOND, no jump table needed.
define i64 @switch_small(i64 %x) {
; CHECK-LABEL: switch_small:
; CHECK: addi x10, x0, 10
; CHECK: addi x10, x0, 20
; CHECK: addi x10, x0, 0
entry:
  switch i64 %x, label %default [
    i64 1, label %case1
    i64 2, label %case2
  ]
case1:
  ret i64 10
case2:
  ret i64 20
default:
  ret i64 0
}

; Larger, dense switch - crosses the jump-table threshold (G_BRJT). Entries
; are EK_LabelDifference32 under PIC, so the loaded value is a difference
; from the table's own base that gets added back before the indirect jump.
define i64 @switch_dense(i64 %x) {
; CHECK-LABEL: switch_dense:
; CHECK: addi [[LAST:x[0-9]+]], x0, 4
; CHECK: bltu [[LAST]], x10, [[DEFAULT:\.LBB[0-9]+_[0-9]+]]
; CHECK: auipc [[TBL:x[0-9]+]], %pcrel_hi([[JTI:\.LJTI[0-9]+_[0-9]+]])
; CHECK: addi [[TBL]], [[TBL]], %pcrel_lo
; CHECK: slli x10, x10, 2
; CHECK: add x10, [[TBL]], x10
; CHECK: lw x10, 0(x10)
; CHECK: add x10, x10, [[TBL]]
; CHECK: jalr x0, 0(x10)
; CHECK: [[DEFAULT]]:
; CHECK: addi x10, x0, 0
entry:
  switch i64 %x, label %default [
    i64 0, label %c0
    i64 1, label %c1
    i64 2, label %c2
    i64 3, label %c3
    i64 4, label %c4
  ]
c0:
  ret i64 100
c1:
  ret i64 101
c2:
  ret i64 102
c3:
  ret i64 103
c4:
  ret i64 104
default:
  ret i64 0
}

; Same dense switch, but the default destination is `unreachable` - this is
; the shape a frontend emits for a provably-exhaustive switch (e.g. a fully
; covered enum). This sets JumpTableHeader::FallthroughUnreachable, which
; skips the range-check guard (ICMP ugt + BRCOND) entirely: control should
; fall straight into the dispatch sequence with no bounds check at all.
define i64 @switch_dense_unreachable_default(i64 %x) {
; CHECK-LABEL: switch_dense_unreachable_default:
; CHECK-NOT: bltu
; CHECK: auipc [[TBL:x[0-9]+]], %pcrel_hi([[JTI:\.LJTI[0-9]+_[0-9]+]])
; CHECK: addi [[TBL]], [[TBL]], %pcrel_lo
; CHECK: slli [[IDX:x[0-9]+]], [[IDX]], 2
; CHECK: add [[IDX]], [[TBL]], [[IDX]]
; CHECK: lw [[IDX]], 0([[IDX]])
; CHECK: add [[IDX]], [[IDX]], [[TBL]]
; CHECK: jalr x0, 0([[IDX]])
entry:
  switch i64 %x, label %unreachable_default [
    i64 0, label %c0
    i64 1, label %c1
    i64 2, label %c2
    i64 3, label %c3
    i64 4, label %c4
  ]
c0:
  ret i64 100
c1:
  ret i64 101
c2:
  ret i64 102
c3:
  ret i64 103
c4:
  ret i64 104
unreachable_default:
  unreachable
}

; C-style fallthrough
define i64 @switch_dense_fallthrough(i64 %x) {
; CHECK-LABEL: switch_dense_fallthrough:
; CHECK: auipc [[TBL:x[0-9]+]], %pcrel_hi([[JTI:\.LJTI[0-9]+_[0-9]+]])
; CHECK: addi [[TBL]], [[TBL]], %pcrel_lo
; CHECK: slli [[IDX:x[0-9]+]], [[IDX]], 2
; CHECK: add [[IDX]], [[TBL]], [[IDX]]
; CHECK: lw [[IDX]], 0([[IDX]])
; CHECK: add [[IDX]], [[IDX]], [[TBL]]
; CHECK: jalr x0, 0([[IDX]])
; CHECK: addi x10, x0, 101
; CHECK: jalr x0, 0(x1)
; c0 is folded away entirely - the table's first two entries (index 0 and
; index 1) both point straight at c1's block.
; CHECK: [[JTI]]:
; CHECK-NEXT: .long [[C1TARGET:\.LBB[0-9]+_[0-9]+]]-[[JTI]]
; CHECK-NEXT: .long [[C1TARGET]]-[[JTI]]
entry:
  switch i64 %x, label %default [
    i64 0, label %c0
    i64 1, label %c1
    i64 2, label %c2
    i64 3, label %c3
    i64 4, label %c4
  ]
c0:
  br label %c1
c1:
  ret i64 101
c2:
  ret i64 102
c3:
  ret i64 103
c4:
  ret i64 104
default:
  ret i64 0
}
