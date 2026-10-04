#include <cstdio>

int global_counter = 0;
const int MAGIC = 42;

static int square(int x) {
    return x * x;
}

static int sum_of_squares(int a, int b) {
    return square(a) + square(b);
}

static void bump_counter() {
    global_counter++;
}

int main() {
    int result = sum_of_squares(3, 4);
    bump_counter();
    printf("Result: %d, Counter: %d, Magic: %d\n", result, global_counter, MAGIC);
    return 0;
}
