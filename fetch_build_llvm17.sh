#!/usr/bin/env bash
set -euo pipefail

echo "make sure you have gcc-12 and g++-12 (install them from AUR)"
export CC=gcc-12
export CXX=g++-12
export AR=ar-12
export RANLIB=ranlib-12
export LD=ld-12

required="cmake ninja python git gcc binutils zlib libxml2 libedit unzip wget"
missing=$(pacman -T $required || true)
if [[ -n "${missing:-}" ]]; then
    echo "Error: The following required packages are NOT installed:"
    echo "$missing"
    exit 1
fi
echo "All dependencies are installed."

# Use an absolute install dir under the current working directory
llvm_installdir_abs_path="$(pwd)/llvm17_installdir"

# Clean and recreate install directory
rm -rf "${llvm_installdir_abs_path}"
mkdir -p "${llvm_installdir_abs_path}"

# Fetch sources
rm -f llvmorg-17.0.6.zip
rm -rf llvm-project-llvmorg-17.0.6
wget https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-17.0.6.zip
unzip llvmorg-17.0.6.zip

# Configure and build
cd llvm-project-llvmorg-17.0.6
mkdir -p build
cd build

# disable sanitizers
cmake -G Ninja ../llvm \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang;clang-tools-extra;lld" \
  -DLLVM_TARGETS_TO_BUILD="X86" \
  -DLLVM_ENABLE_TERMINFO=OFF \
  -DCMAKE_INSTALL_PREFIX="${llvm_installdir_abs_path}" \
  -DLLVM_ENABLE_RUNTIMES=""

ninja -j"$(nproc)"
ninja install

echo "The built binaries are under llvm-project-llvmorg-17.0.6/build/bin"
echo "Installed under ${llvm_installdir_abs_path}"

# Generate environment setup script at repository root
cd ../../
cat > ${llvm_installdir_abs_path}/set_envs.sh <<'EOF'
#!/usr/bin/env bash
# Source this file to add the local LLVM install to your environment.
# Usage: source ./set_envs.sh

# Resolve this script directory to support sourcing from anywhere
_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

_install_dir="${_script_dir}/llvm17_installdir"

# Prepend bin to PATH if not already present
case ":$PATH:" in
  *":${_install_dir}/bin:"*) ;;
  *) export PATH="${_install_dir}/bin:${PATH}";;
esac

# Prepend lib to LD_LIBRARY_PATH if not already present
# Use lib64 if present, else lib
_lib_dir="${_install_dir}/lib"
if [[ -d "${_install_dir}/lib64" ]]; then
  _lib_dir="${_install_dir}/lib64"
fi

case ":${LD_LIBRARY_PATH-}:" in
  *":${_lib_dir}:"*) ;;
  *)
    if [[ -n "${LD_LIBRARY_PATH-}" ]]; then
      export LD_LIBRARY_PATH="${_lib_dir}:${LD_LIBRARY_PATH}"
    else
      export LD_LIBRARY_PATH="${_lib_dir}"
    fi
    ;;
esac

echo "LLVM environment set:"
echo "  PATH=${PATH}"
echo "  LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
EOF

chmod +x ${llvm_installdir_abs_path}/set_envs.sh
echo "Generated ./set_envs.sh. To use, run: source ./set_envs.sh"
