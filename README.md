# DPCPP
To build the latest DPCPP release on archlinux, we need CMake 3.27.
The one that Archlinux provides is too recent and will cause errors.

```bash
conda create -n py310 python=3.10 -y
conda activate py310
conda install nvidia::cuda-toolkit==12.8.0
conda install zlib -c conda-forge --override-channels


source /mnt/LinuxData2/conda/enable.conda.sh
conda activate py310
bash 01_build_dpcpp.sh
```


# LLVM17
To comply with the book for LLVM17, I have prepared a script to fetch and build LLVM17 from source:

```bash
bash fetch_build_llvm17.sh
```
