#!/usr/bin/env bash
set -euo pipefail

# DPC++ (SYCL) with CUDA backend build helper
# Usage:
#   source this file, then call:
#     build_dpcpp_cuda [WORK_DIR] [INSTALL_DIR] [CUDAToolkit_ROOT] [CC] [CXX]
#
# Examples:
#   build_dpcpp_cuda "/tmp/dpcpp-work"
#   build_dpcpp_cuda "/tmp/dpcpp-work" "/opt/dpcpp-2022-09"
#   build_dpcpp_cuda "/tmp/dpcpp-work" "/opt/dpcpp-2022-09" "/usr/local/cuda-11.8"
#   build_dpcpp_cuda "/tmp/dpcpp-work" "/opt/dpcpp-2022-09" "/usr/local/cuda-11.8" "gcc-12" "g++-12"
#
# Notes:
# - Ensure you have a Conda environment with CUDA 11.8 activated before running.
# - This function performs sanity checks for required tools and compilers.
# - If INSTALL_DIR is provided, built artifacts are copied there and set_envs.sh is generated.

build_dpcpp_cuda() {
  # -------- Arguments --------
  local WORK_DIR="${1:-$(pwd)/dpcpp-work}"
  local INSTALL_DIR="${2:-}"
  local CUDAToolkit_ROOT_ARG="${3:-${CUDAToolkit_ROOT:-}}"
  local CC_ARG="${4:-${CC:-gcc-12}}"
  local CXX_ARG="${5:-${CXX:-g++-12}}"

  # -------- Configuration --------
  local URL="https://github.com/intel/llvm/archive/refs/tags/v6.2.1.zip"
  local ZIP_FILE="llvm-6.2.1.zip"
  local UNZIP_DIR="llvm-6.2.1"
  local BUILD_DIR="${UNZIP_DIR}/build"

  # -------- Sanity checks --------
  echo "[+] Performing sanity checks..."

  # Required tools
  local REQUIRED_TOOLS=(ninja make cmake zip unzip nvcc wget python3)
  local MISSING=()
  for t in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "${t}" >/dev/null 2>&1; then
      MISSING+=("${t}")
    fi
  done
  if (( ${#MISSING[@]} > 0 )); then
    echo "ERROR: Missing required tools in PATH: ${MISSING[*]}"
    echo "Please ensure all are installed and available."
    return 1
  fi

  # Check CC/CXX compilers availability
  for comp in "${CC_ARG}" "${CXX_ARG}"; do
    if ! command -v "${comp}" >/dev/null 2>&1; then
      echo "ERROR: Compiler not found in PATH: ${comp}"
      return 1
    fi
  done
  echo "[+] Using CC=${CC_ARG}, CXX=${CXX_ARG}"
  echo "[+] CC version: $("${CC_ARG}" --version | head -n1)"
  echo "[+] CXX version: $("${CXX_ARG}" --version | head -n1)"

  # Optional: verify CUDA version (expects 11.8)
  if nvcc --version | grep -q "release 11.8"; then
    echo "[+] Detected CUDA 11.8 via nvcc."
  else
    echo "WARNING: nvcc does not report CUDA 11.8. Proceeding, but build expects CUDA 11.8."
  fi

  # -------- Prepare work directory --------
  echo "[+] Using work directory: ${WORK_DIR}"
  mkdir -p "${WORK_DIR}"
  pushd "${WORK_DIR}" >/dev/null

  # -------- Download release archive --------
  if [[ ! -f "${ZIP_FILE}" ]]; then
    echo "[+] Zip file not found. Downloading..."
    wget -O "${ZIP_FILE}" "${URL}"
  else
    echo "[+] Zip file already exists. Skipping download."
  fi

  # Remove old unzipped directory if it exists
  if [[ -d "${UNZIP_DIR}" ]]; then
    echo "[+] Removing existing directory: ${UNZIP_DIR}"
    rm -rf "${UNZIP_DIR}"
  fi

  # Unzip
  echo "[+] Unzipping ${ZIP_FILE}..."
  unzip -q "${ZIP_FILE}"

  # -------- Build DPC++ with CUDA backend --------
  echo "[+] Configuring DPC++ (SYCL) with CUDA backend..."

  # Clean any previous build (especially _deps where OpenCL-Headers are fetched)
  if [[ -d "${BUILD_DIR}" ]]; then
    echo "[+] Removing existing build dir: ${BUILD_DIR}"
    rm -rf "${BUILD_DIR}"
  fi
  mkdir -p "${BUILD_DIR}"

  # Export compilers for CMake
  export CC="${CC_ARG}"
  export CXX="${CXX_ARG}"
  export CMAKE_POLICY_VERSION_MINIMUM=3.5

  # Pass CMake options using equals form, repeat --cmake-opt for each -D
  local CONFIGURE_ARGS=(
    "--cuda"
    "-o" "${BUILD_DIR}"
    "-t" "Release"
    "--cmake-opt=-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "--cmake-opt=-DCMAKE_C_COMPILER=${CC_ARG}"
    "--cmake-opt=-DCMAKE_CXX_COMPILER=${CXX_ARG}"
  )

  # If CUDA toolkit is in non-default location
  if [[ -n "${CUDAToolkit_ROOT_ARG}" ]]; then
    echo "[+] Using custom CUDAToolkit_ROOT: ${CUDAToolkit_ROOT_ARG}"
    CONFIGURE_ARGS+=("--cmake-opt=-DCUDA_Toolkit_ROOT=${CUDAToolkit_ROOT_ARG}")
  fi

  python3 "${UNZIP_DIR}/buildbot/configure.py" "${CONFIGURE_ARGS[@]}"

  echo "[+] Compiling DPC++..."
  python3 "${UNZIP_DIR}/buildbot/compile.py" -o "${BUILD_DIR}" -t deploy-sycl-toolchain -j"$(nproc)"

  # -------- Optional install step --------
  if [[ -n "${INSTALL_DIR}" ]]; then
    echo "[+] Installing built toolchain to: ${INSTALL_DIR}"
    mkdir -p "${INSTALL_DIR}"

    # Copy relevant directories if they exist.
    for d in bin lib lib64 include share; do
      if [[ -d "${BUILD_DIR}/${d}" ]]; then
        mkdir -p "${INSTALL_DIR}/${d}"
        rsync -a --delete "${BUILD_DIR}/${d}/" "${INSTALL_DIR}/${d}/"
      fi
    done

    # Generate set_envs.sh for easy environment setup
    local SET_ENVS="${INSTALL_DIR}/set_envs.sh"
    cat > "${SET_ENVS}" <<'EOF'
#!/usr/bin/env bash
# Source this file to set environment variables for the installed DPC++ toolchain.

if [[ -z "${BASH_SOURCE[0]}" ]]; then
  echo "Please source this script: 'source set_envs.sh'"
  return 1
fi

INSTALL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export PATH="${INSTALL_DIR}/bin:${PATH}"
# Prefer lib64 if present, else lib
if [[ -d "${INSTALL_DIR}/lib64" ]]; then
  export LD_LIBRARY_PATH="${INSTALL_DIR}/lib64:${LD_LIBRARY_PATH:-}"
else
  export LD_LIBRARY_PATH="${INSTALL_DIR}/lib:${LD_LIBRARY_PATH:-}"
fi

# Prepend install dir to CMAKE_PREFIX_PATH so cmake can find the installed toolchain
export CMAKE_PREFIX_PATH="${INSTALL_DIR}:${CMAKE_PREFIX_PATH:-}"

echo "[+] DPC++ environment set:"
echo "    PATH prepended with: ${INSTALL_DIR}/bin"
if [[ -d "${INSTALL_DIR}/lib64" ]]; then
  echo "    LD_LIBRARY_PATH prepended with: ${INSTALL_DIR}/lib64"
else
  echo "    LD_LIBRARY_PATH prepended with: ${INSTALL_DIR}/lib"
fi
echo "    CMAKE_PREFIX_PATH prepended with: ${INSTALL_DIR}"
EOF
    chmod +x "${SET_ENVS}"
    echo "[+] Generated ${SET_ENVS}"
  fi

  # -------- Environment setup (current shell) --------
  echo "[+] Setting PATH and LD_LIBRARY_PATH to use built toolchain (current session)..."
  export PATH="${BUILD_DIR}/bin:${PATH}"
  if [[ -d "${BUILD_DIR}/lib64" ]]; then
    export LD_LIBRARY_PATH="${BUILD_DIR}/lib64:${LD_LIBRARY_PATH:-}"
  else
    export LD_LIBRARY_PATH="${BUILD_DIR}/lib:${LD_LIBRARY_PATH:-}"
  fi

  # -------- Create and build a simple SYCL app for CUDA --------
  echo "[+] Creating simple SYCL app (in work dir)..."
  cat > simple-sycl-app.cpp <<'EOF'
#include <iostream>
#include <sycl/sycl.hpp>

int main() {
  sycl::buffer<size_t, 1> Buffer(4);
  sycl::queue Queue;
  sycl::range<1> NumOfWorkItems{Buffer.size()};

  Queue.submit([&](sycl::handler &cgh) {
    sycl::accessor Accessor{Buffer, cgh, sycl::write_only};
    cgh.parallel_for<class FillBuffer>(NumOfWorkItems, [=](sycl::id<1> WIid) {
      Accessor[WIid] = WIid.get(0);
    });
  });

  sycl::host_accessor HostAccessor{Buffer, sycl::read_only};

  bool MismatchFound = false;
  for (size_t I = 0; I < Buffer.size(); ++I) {
    if (HostAccessor[I] != I) {
      std::cout << "The result is incorrect for element: " << I
                << " , expected: " << I << " , got: " << HostAccessor[I]
                << std::endl;
      MismatchFound = true;
    }
  }
  if (!MismatchFound) {
    std::cout << "The results are correct!" << std::endl;
  }
  return MismatchFound;
}
EOF

  echo "[+] Building simple SYCL app for CUDA..."
  clang++ -std=c++17 -O3 -fsycl -fsycl-targets=nvptx64-nvidia-cuda \
    simple-sycl-app.cpp -o simple-sycl-app-cuda.exe

  echo "[+] Running the app on CUDA backend..."
  ONEAPI_DEVICE_SELECTOR=cuda:* ./simple-sycl-app-cuda.exe

  popd >/dev/null
  echo "[+] Done."
}

# If the script is executed directly (not sourced), run with defaults in a subdir to avoid clutter.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  DEFAULT_WORK_DIR="$(pwd)/dpcpp-work"
  echo "[i] Script executed directly. Using default work dir: ${DEFAULT_WORK_DIR}"
  build_dpcpp_cuda "${DEFAULT_WORK_DIR}" "${INSTALL_DIR:-}" "${CUDAToolkit_ROOT:-}" "${CC:-gcc-12}" "${CXX:-g++-12}"
fi
