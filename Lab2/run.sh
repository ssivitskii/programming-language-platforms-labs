#!/bin/sh
# Все команды лабораторной 2. Запуск (из macOS):
#   docker run --rm --platform linux/amd64 -v "$PWD":/w -w /w gcc:14 sh run.sh > output.txt 2>&1
set -x
gcc --version | head -1
ld --version | head -1

### Этап 0. size
size core.o legacy.o hotfix.o main.o
size -A core.o
ls -l core.o legacy.o hotfix.o main.o

### Этап 1. Секции и строки
for f in core legacy hotfix main; do readelf -S -W $f.o; done
strings -a core.o
readelf -p .rodata -p .comment core.o
readelf -x .data.rel.local -r core.o
objdump -s -j .data core.o | head -6

### Этап 2. Символы
for f in core legacy hotfix main; do nm $f.o; done
for f in core legacy hotfix main; do readelf -s -W $f.o; done
nm -A core.o legacy.o hotfix.o main.o | awk '{print $NF}' | sort | uniq -c | sort -rn
nm -A core.o legacy.o hotfix.o main.o | grep -w system_mode
objdump -d -M intel -r core.o legacy.o hotfix.o main.o

### Этап 3. Компоновка с -fcommon
gcc -fcommon core.o legacy.o hotfix.o main.o -o app; echo "link exit=$?"
./app
gcc -fcommon -Wl,--warn-common core.o legacy.o hotfix.o main.o -o app_warn; echo "link exit=$?"
rm -f app_warn

### Этап 4. Исполняемый файл
nm app | grep system_mode
readelf -s -W app | grep -E ' (system_mode|config_table|large_buffer|welcome_msg)$'
readelf -S -W app | grep -E ' \.(data|bss) '
size app

# -fno-common при компоновке готовых .o
gcc -fno-common main.o hotfix.o legacy.o core.o -o app_better; echo "link exit=$?"
nm app_better | grep system_mode

# hotfix.c, пересобранный с -fno-common
gcc -c -fno-common hotfix.c -o hotfix_nocommon.o
nm hotfix_nocommon.o
gcc -fno-common main.o hotfix_nocommon.o legacy.o core.o -o app_better; echo "link exit=$?"

# Исправления
for v in extern static; do
  gcc -c -fno-common -Wall -Wextra fix/hotfix_$v.c -o fix/hotfix_$v.o
  nm fix/hotfix_$v.o
  gcc -fno-common main.o fix/hotfix_$v.o legacy.o core.o -o fix/app_better_$v; echo "link exit=$?"
  nm fix/app_better_$v | grep system_mode
  ./fix/app_better_$v
done
