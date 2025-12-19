cmake_minimum_required(VERSION 3.20)
project(StaticTripCountPass LANGUAGES CXX)

find_package(LLVM 17 REQUIRED CONFIG)

message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")

include_directories(${LLVM_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

add_library(StaticTripCountPass SHARED
        pass.cpp
)

set_target_properties(StaticTripCountPass PROPERTIES
        CXX_STANDARD 17
        CXX_STANDARD_REQUIRED YES
        POSITION_INDEPENDENT_CODE ON
        PREFIX ""
)
