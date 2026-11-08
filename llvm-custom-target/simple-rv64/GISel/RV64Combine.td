include "llvm/Target/GlobalISel/Combine.td"

def RV64PreLegalizerCombiner : GICombiner<
    "RV64PreLegalizerCombinerImpl", [sub_to_add]> {
}