#!/bin/sh
# Проходит все этапы сборки simple.cpp. Запуск (из macOS):
#   docker run --rm --platform linux/amd64 -v "$PWD":/w -w /w gcc:14 sh run.sh > output.txt 2>&1
set -x
uname -m
g++ --version | head -1

# Этап 1. Препроцессинг
g++ -E simple.cpp -o simple.i
wc -l simple.cpp simple.i
grep -n 'int main' simple.i
grep -n 'Result: %d' simple.i
grep -c '^# ' simple.i
grep -n '^# ' simple.i | tail -5
grep -n 'MAGIC' simple.i
grep -n -w 'printf' simple.i | head -3

# Этап 2. Компиляция в ассемблер
g++ -S -masm=intel -O0 simple.cpp -o simple_O0.s
g++ -S -masm=intel -O2 simple.cpp -o simple_O2.s
wc -lc simple_O0.s simple_O2.s
grep -vcE '^\s*\.' simple_O0.s
grep -vcE '^\s*\.' simple_O2.s
sed -n '/^_Z6squarei:/,/\.cfi_endproc/p' simple_O0.s
sed -n '/^_Z14sum_of_squaresii:/,/\.cfi_endproc/p' simple_O0.s
sed -n '/^main:/,/\.cfi_endproc/p' simple_O0.s
sed -n '/^_Z6squarei:/,/\.cfi_endproc/p' simple_O2.s
sed -n '/^_Z14sum_of_squaresii:/,/\.cfi_endproc/p' simple_O2.s
sed -n '/^main:/,/\.cfi_endproc/p' simple_O2.s
grep -n 'call' simple_O2.s

# Этап 3. Объектный файл
g++ -c simple.cpp -o simple.o
nm simple.o
nm -C simple.o
size simple.o
size -A simple.o
objdump -h simple.o

# Этап 4. Компоновка и запуск
g++ simple.o -o simple
./simple
echo "exit code: $?"
size simple
nm -C simple | grep -E ' (main|_Z|global_counter|MAGIC|printf)'
