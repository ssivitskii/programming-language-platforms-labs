/*
 * solve.c — восстанавливает флаг прямо из исходника legacy.c.
 *
 * 1. Находит инициализатор массива `S*a[1024]={ ... }`.
 * 2. Для каждого элемента считает число вызовов z( — это длина списка,
 *    т.е. ожидаемое значение после преобразования df().
 * 3. Обращает df(): операции зависят от индекса по модулю 7
 *    (только для первых 896 элементов).
 *
 * Сборка:  cc -std=c99 -Wall -Wextra solve.c -o solve
 * Запуск:  ./solve legacy.c
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#define N 1024

static char *read_file(const char *path)
{
    FILE *f = fopen(path, "rb");
    if (!f) { perror(path); exit(2); }
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    char *buf = malloc(len + 1);
    if (!buf || fread(buf, 1, len, f) != (size_t)len) { perror("read"); exit(2); }
    buf[len] = '\0';
    fclose(f);

    /* Убираем пробельные символы: в legacy.c `z` и `(` бывают на разных строках. */
    char *w = buf;
    for (char *r = buf; *r; r++)
        if (!isspace((unsigned char)*r))
            *w++ = *r;
    *w = '\0';
    return buf;
}

/* Обратная операция к df() для элемента с индексом i. -1 — не обращается. */
static int invert(int i, int v)
{
    if (i >= 128 * 7)
        return v;
    switch (i % 7) {
    case 0: return v ^ 0x63;
    case 1: return v ^ 48;
    case 2: return v % 16 ? -1 : v >> 4;
    case 3: return v % 4  ? -1 : v >> 2;
    case 4: return v % 55 ? -1 : v / 55;
    case 5: return v - 97;
    case 6: return v - 44;
    }
    return -1;
}

int main(int argc, char **argv)
{
    const char *marker = "S*a[1024]={";
    char *src = read_file(argc > 1 ? argv[1] : "legacy.c");
    char *p = strstr(src, marker);
    if (!p) { fprintf(stderr, "array initializer not found\n"); return 2; }
    p += strlen(marker);

    int counts[N] = {0};
    int idx = 0, depth = 0;
    for (; *p && idx < N; p++) {
        if (*p == 'z' && p[1] == '(') {
            counts[idx]++;
            depth++;
            p++;
        } else if (*p == '(')
            depth++;
        else if (*p == ')')
            depth--;
        else if (*p == ',' && depth == 0)
            idx++;
        else if (*p == '}' && depth == 0)
            break;
    }

    char flag[N + 1];
    int n = 0;
    for (int i = 0; i < N; i++) {
        int c = invert(i, counts[i]);
        if (c < 0 || c > 255) {
            fprintf(stderr, "bad value at %d: %d\n", i, counts[i]);
            return 1;
        }
        if (c == 0 || c == '\n')
            break;
        flag[n++] = (char)c;
    }
    flag[n] = '\0';
    puts(flag);
    free(src);
    return 0;
}
