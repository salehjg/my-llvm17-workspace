// test.cpp
#include <cstddef>

void foo() {
    for (int i = 0; i < 128; i++) {
        asm volatile("");
    }

    for (int i = 0; i < 100; i += 2) {
        asm volatile("");
    }

    int N = 256;
    for (int i = 0; i < N; i++) {
        asm volatile("");
    }
}
