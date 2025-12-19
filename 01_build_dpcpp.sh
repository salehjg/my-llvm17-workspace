# help LLVM cmake to find libz of conda!
export LIBRARY_PATH=$CONDA_PREFIX/lib:$LIBRARY_PATH
export C_INCLUDE_PATH=$CONDA_PREFIX/include:$C_INCLUDE_PATH
export CPLUS_INCLUDE_PATH=$CONDA_PREFIX/include:$CPLUS_INCLUDE_PATH
export LDFLAGS="-L$CONDA_PREFIX/lib -Wl,-rpath,$CONDA_PREFIX/lib"
export LDFLAGS="-Wl,-rpath-link,$CONDA_PREFIX/lib $LDFLAGS"

source dpcpp_helper.sh
# conda activate py310_cuda11
mkdir -p dpcpp_build
# install cuda from the nivida channel.
build_dpcpp_cuda "dpcpp_build" "installdir" "/opt/cuda/" "gcc-12" "g++-12"
