#include <stdio.h>
#include <stdlib.h>

#define SAMPLE_LIMIT 8

static int clamp(int value, int min, int max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
}

int main(void) {
    int total = 0;
    for (int i = 0; i < SAMPLE_LIMIT; i++) {
        int normalized = clamp(i * 7, 0, 42);
        total += normalized;
        printf("row=%d normalized=%d\n", i, normalized);
    }
    printf("total=%d\n", total);
    return EXIT_SUCCESS;
}
