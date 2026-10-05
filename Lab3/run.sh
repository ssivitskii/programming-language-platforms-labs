#!/bin/sh
# Воспроизведение лабораторной 3 в Linux x86-64 с GCC и GNU binutils.
set -eu

SCRIPT_DIR=$(CDPATH= cd "$(dirname "$0")" && pwd)
BUILD_DIR="$SCRIPT_DIR/build"

mkdir -p "$BUILD_DIR"
RUN_DIR=$(mktemp -d "$BUILD_DIR/run.XXXXXX")
mkdir -p "$RUN_DIR/work" "$RUN_DIR/no_extern_c" "$RUN_DIR/nopic_control"
cp "$SCRIPT_DIR/vector_math.h" "$SCRIPT_DIR/vector_math.c" "$SCRIPT_DIR/main.cpp" "$RUN_DIR/work/"

export LC_ALL=C
cd "$RUN_DIR/work"

header_hash_before=$(sha256sum ../../../vector_math.h | awk '{print $1}')
source_hash_before=$(sha256sum ../../../vector_math.c | awk '{print $1}')
main_hash_before=$(sha256sum ../../../main.cpp | awk '{print $1}')

expect_output() {
    actual=$($1)
    expected='Library version: v2.4.1-release
Dot product result: 32'
    if [ "$actual" != "$expected" ]; then
        printf '%s\n' "unexpected program output:" "$actual" >&2
        exit 1
    fi
    printf '%s\n' "$actual"
}

set -x
gcc --version | head -1
g++ --version | head -1
ld --version | head -1
uname -m
sha256sum ../../../vector_math.h ../../../vector_math.c ../../../main.cpp

# Этап 1. Статическая библиотека
gcc -c vector_math.c -o vector_math.o
g++ -c main.cpp -o main.o
nm main.o | grep -E ' main$|dot_product|get_lib_version'

ar rcs libmath_static.a vector_math.o
archive_hash_first=$(sha256sum libmath_static.a | awk '{print $1}')
ar rcs libmath_static.a vector_math.o
archive_hash_second=$(sha256sum libmath_static.a | awk '{print $1}')
test "$archive_hash_first" = "$archive_hash_second"
printf 'archive sha256 after first ar rcs:  %s\n' "$archive_hash_first"
printf 'archive sha256 after second ar rcs: %s\n' "$archive_hash_second"
ar t libmath_static.a
member_count=$(ar t libmath_static.a | wc -l | tr -d '[:space:]')
test "$member_count" -eq 1
test "$(ar t libmath_static.a)" = vector_math.o

g++ main.o -L. -lmath_static -o app_static
expect_output ./app_static
nm app_static | grep -E ' (dot_product|get_lib_version)$'

# Этап 2. Динамическая библиотека
# Первые две команды в точности повторяют эксперимент из задания.
gcc -c vector_math.c -o vector_math_nopic.o
if gcc -shared -o libmath_broken.so vector_math_nopic.o; then
    nopic_status=0
else
    nopic_status=$?
fi
printf 'original no-PIC shared link exit=%s\n' "$nopic_status"
case "$nopic_status" in 0|1) ;; *) exit 1 ;; esac
readelf -rW vector_math_nopic.o

gcc -c -fPIC vector_math.c -o vector_math_pic.o
gcc -shared -o libmath_dynamic.so vector_math_pic.o
g++ main.o -L. -lmath_dynamic -o app_dynamic
LD_LIBRARY_PATH=. expect_output ./app_dynamic

size app_static app_dynamic libmath_dynamic.so
nm app_static | grep -E ' (dot_product|get_lib_version)$'
nm app_dynamic | grep -E ' (dot_product|get_lib_version)$'
readelf -dW app_dynamic | grep NEEDED

# Дополнительный контролируемый эксперимент: внешний LIB_VERSION создаёт
# непригодную для shared object R_X86_64_PC32-релокацию без -fPIC.
cd ../nopic_control
cp ../work/vector_math.h .
sed 's/^static const char\* LIB_VERSION/const char* LIB_VERSION/' ../work/vector_math.c > vector_math.c
grep '^const char\* LIB_VERSION' vector_math.c
gcc -c vector_math.c -o vector_math_nopic.o
readelf -rW vector_math_nopic.o
if gcc -shared -o libmath_control_nopic.so vector_math_nopic.o > nopic_link.log 2>&1; then
    control_nopic_status=0
else
    control_nopic_status=$?
fi
cat nopic_link.log
printf 'controlled no-PIC shared link exit=%s\n' "$control_nopic_status"
test "$control_nopic_status" -eq 1
grep -F 'R_X86_64_PC32' nopic_link.log
gcc -c -fPIC vector_math.c -o vector_math_pic.o
gcc -shared -o libmath_control_pic.so vector_math_pic.o
test -s libmath_control_pic.so

# Этап 3. Порядок аргументов и режим --as-needed
cd ../work
if g++ -L. -lmath_dynamic main.o -o app_wrong_order > wrong_order.log 2>&1; then
    wrong_order_status=0
else
    wrong_order_status=$?
fi
cat wrong_order.log
printf 'plain wrong-order link exit=%s\n' "$wrong_order_status"
case "$wrong_order_status" in 0|1) ;; *) exit 1 ;; esac

g++ main.o -L. -lmath_dynamic -o app_correct
LD_LIBRARY_PATH=. expect_output ./app_correct

if g++ -L. -lmath_static main.o -o app_static_wrong_order > static_wrong_order.log 2>&1; then
    static_wrong_order_status=0
else
    static_wrong_order_status=$?
fi
cat static_wrong_order.log
printf 'static archive wrong-order link exit=%s\n' "$static_wrong_order_status"
test "$static_wrong_order_status" -eq 1
grep -F 'undefined reference to `get_lib_version' static_wrong_order.log
grep -F 'undefined reference to `dot_product' static_wrong_order.log

if g++ -Wl,--as-needed -L. -lmath_dynamic main.o -o app_wrong_order_as_needed > wrong_order_as_needed.log 2>&1; then
    as_needed_status=0
else
    as_needed_status=$?
fi
cat wrong_order_as_needed.log
printf 'explicit --as-needed wrong-order link exit=%s\n' "$as_needed_status"
test "$as_needed_status" -eq 1
grep -F 'undefined reference to `get_lib_version' wrong_order_as_needed.log
grep -F 'undefined reference to `dot_product' wrong_order_as_needed.log

g++ -Wl,--as-needed main.o -L. -lmath_dynamic -o app_correct_as_needed
readelf -dW app_correct_as_needed | grep 'Shared library: \[libmath_dynamic.so\]'

g++ -Wl,--no-as-needed -L. -lmath_dynamic main.o -o app_wrong_order_no_as_needed
readelf -dW app_wrong_order_no_as_needed | grep 'Shared library: \[libmath_dynamic.so\]'
LD_LIBRARY_PATH=. expect_output ./app_wrong_order_no_as_needed

# Этап 4. Заголовок без extern "C" создаётся только внутри build/.
cd ../no_extern_c
cp ../work/main.cpp .
sed '/^#ifdef __cplusplus$/,/^#endif$/d' ../work/vector_math.h > vector_math.h
test "$(grep -c '__cplusplus\|extern "C"' vector_math.h || true)" -eq 0
g++ -c main.cpp -o main_no_extern.o
nm main_no_extern.o | grep -E 'dot_product|get_lib_version'
nm -C main_no_extern.o | grep -E 'dot_product|get_lib_version'
nm ../work/libmath_dynamic.so | grep -E ' (dot_product|get_lib_version)$'

if g++ main_no_extern.o -L../work -lmath_dynamic -o app_no_extern > no_extern_link.log 2>&1; then
    no_extern_status=0
else
    no_extern_status=$?
fi
cat no_extern_link.log
printf 'link without extern C exit=%s\n' "$no_extern_status"
test "$no_extern_status" -eq 1
grep -F 'undefined reference to `get_lib_version()' no_extern_link.log
grep -F 'undefined reference to `dot_product(int const*, int const*, int)' no_extern_link.log

cd ../../..
sha256sum vector_math.h vector_math.c main.cpp
test "$(sha256sum vector_math.h | awk '{print $1}')" = "$header_hash_before"
test "$(sha256sum vector_math.c | awk '{print $1}')" = "$source_hash_before"
test "$(sha256sum main.cpp | awk '{print $1}')" = "$main_hash_before"
printf '%s\n' 'ALL CHECKS PASSED'
