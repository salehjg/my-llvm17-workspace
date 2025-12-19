#include "llvm/Analysis/LoopInfo.h"
#include "llvm/Analysis/ScalarEvolution.h"
#include "llvm/Analysis/ScalarEvolutionExpressions.h"
#include "llvm/IR/PassManager.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Passes/PassPlugin.h"   // <-- THIS IS THE MISSING ONE



using namespace llvm;

namespace {

class StaticTripCountPass : public PassInfoMixin<StaticTripCountPass> {
public:
  PreservedAnalyses run(Function &F, FunctionAnalysisManager &FAM) {
    auto &LI = FAM.getResult<LoopAnalysis>(F);
    auto &SE = FAM.getResult<ScalarEvolutionAnalysis>(F);

    for (Loop *L : LI) {
      analyzeLoop(L, SE);
    }

    return PreservedAnalyses::all();
  }

private:
  void analyzeLoop(Loop *L, ScalarEvolution &SE) {
    // ScalarEvolution gives the number of times the backedge is taken
    const SCEV *BackedgeTakenCount = SE.getBackedgeTakenCount(L);

    if (isa<SCEVCouldNotCompute>(BackedgeTakenCount)) {
      errs() << "Loop has non-static trip count\n";
      return;
    }

    // If it's a constant, we have a static trip count
    if (const auto *C = dyn_cast<SCEVConstant>(BackedgeTakenCount)) {
      uint64_t BackedgeTrips = C->getAPInt().getZExtValue();
      uint64_t TripCount = BackedgeTrips + 1;

      errs() << "Static loop trip count: " << TripCount << "\n";
    } else {
      errs() << "Loop has symbolic (non-constant) trip count\n";
    }

    // Recurse into nested loops
    for (Loop *SubL : L->getSubLoops()) {
      analyzeLoop(SubL, SE);
    }
  }
};

} // namespace

// Pass registration
llvm::PassPluginLibraryInfo getStaticTripCountPassPluginInfo() {
  return {
      LLVM_PLUGIN_API_VERSION, "StaticTripCountPass", LLVM_VERSION_STRING,
      [](PassBuilder &PB) {
        PB.registerPipelineParsingCallback(
            [](StringRef Name, FunctionPassManager &FPM,
               ArrayRef<PassBuilder::PipelineElement>) {
              if (Name == "static-trip-count") {
                FPM.addPass(StaticTripCountPass());
                return true;
              }
              return false;
            });
      }};
}

extern "C" LLVM_ATTRIBUTE_WEAK llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return getStaticTripCountPassPluginInfo();
}
