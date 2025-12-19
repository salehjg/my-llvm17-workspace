# 1. How to build
```bash
source ../../llvm17_installdir/set_envs.sh
clion .
# then build StaticTripCountPass
```

# 2. How to use it
```bash
# use ll
clang++ -O1 -emit-llvm -S ../test.cpp -o test.ll
opt -load-pass-plugin=./StaticTripCountPass.so \
    -passes=static-trip-count \
    test.ll

# or use bitcode
clang++ -O1 -emit-llvm -c ../test.cpp -o test.bc
opt -load-pass-plugin=./StaticTripCountPass.so \
    -passes=static-trip-count \
    test.bc
```