#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define N_MAT 1024
#define N_VEC (1 << 22)
#define REPEAT_VEC 150
#define N_SORT 3000000

#define NOINLINE __attribute__((noinline))
#define CLOBBER_MEMORY() __asm__ volatile("" ::: "memory")

static double now_sec(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec + ts.tv_nsec * 1e-9;
}

static uint32_t rng_state = 12345u;

static inline uint32_t rng(void) {
    rng_state = rng_state * 1664525u + 1013904223u;
    return rng_state;
}

NOINLINE void init_data(float *a, size_t n) {
    for (size_t i = 0; i < n; i++)
        a[i] = (float)(rng() % 1000) / 100.0f;
}

NOINLINE void matmul(const float *A, const float *B, float *C, int n) {
    memset(C, 0, sizeof(float) * n * n);
    for (int i = 0; i < n; i++)
        for (int k = 0; k < n; k++) {
            float a = A[i * n + k];
            for (int j = 0; j < n; j++)
                C[i * n + j] += a * B[k * n + j];
        }
}

NOINLINE void saxpy(float a, const float *restrict x, float *restrict y, size_t n) {
    for (size_t i = 0; i < n; i++)
        y[i] = a * x[i] + y[i];
}

NOINLINE double sum_sqrt(const float *x, size_t n) {
    float s = 0.0f;
    for (size_t i = 0; i < n; i++)
        s += sqrtf(x[i]);
    return s;
}

static int cmp_int(const void *a, const void *b) {
    int x = *(const int *)a, y = *(const int *)b;
    return (x > y) - (x < y);
}

NOINLINE void sort_ints(int *v, size_t n) {
    qsort(v, n, sizeof(int), cmp_int);
}

int main(void) {
    double t0, t_total = now_sec();

    float *A = malloc(sizeof(float) * N_MAT * N_MAT);
    float *B = malloc(sizeof(float) * N_MAT * N_MAT);
    float *C = malloc(sizeof(float) * N_MAT * N_MAT);
    float *x = malloc(sizeof(float) * N_VEC);
    float *y = malloc(sizeof(float) * N_VEC);
    int *v = malloc(sizeof(int) * N_SORT);
    if (!A || !B || !C || !x || !y || !v) {
        perror("malloc");
        return 1;
    }

    init_data(A, (size_t)N_MAT * N_MAT);
    init_data(B, (size_t)N_MAT * N_MAT);
    init_data(x, N_VEC);
    init_data(y, N_VEC);
    for (size_t i = 0; i < N_SORT; i++)
        v[i] = (int)rng();

    t0 = now_sec();
    matmul(A, B, C, N_MAT);
    printf("matmul    : %8.3f s  (C[7]=%.2f)\n", now_sec() - t0, C[7]);

    t0 = now_sec();
    for (int r = 0; r < REPEAT_VEC; r++)
        saxpy(1.0001f, x, y, N_VEC);
    printf("saxpy     : %8.3f s  (y[7]=%.2f)\n", now_sec() - t0, y[7]);

    t0 = now_sec();
    double s = 0;
    for (int r = 0; r < REPEAT_VEC; r++) {
        CLOBBER_MEMORY();
        s += sum_sqrt(x, N_VEC);
    }
    printf("sum_sqrt  : %8.3f s  (s=%.3e)\n", now_sec() - t0, s);

    t0 = now_sec();
    sort_ints(v, N_SORT);
    printf("sort_ints : %8.3f s  (v[0]=%d)\n", now_sec() - t0, v[0]);

    printf("TOTAL     : %8.3f s\n", now_sec() - t_total);

    free(A);
    free(B);
    free(C);
    free(x);
    free(y);
    free(v);
    return 0;
}
