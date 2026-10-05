# Лабораторная 3. Задача A — Как пройти в библиотеку?

**Окружение:** Linux x86-64, `gcc/g++ (GCC) 14.4.0`, `GNU ld (GNU Binutils for Debian) 2.44` (Docker-образ `gcc:14`, `--platform linux/amd64`).

Исходные файлы задания находятся в корне каталога `Lab3` и во время экспериментов не изменяются. [run.sh](run.sh) создаёт их рабочие копии и все результаты сборки внутри игнорируемого каталога `build/`. Полный вывод сохранён в [output.txt](output.txt).

## Этап 1. Статическая библиотека

### 1. Флаги `ar rcs` и повторный запуск

- `r` (`replace`) добавляет файл в архив или заменяет одноимённый существующий элемент;
- `c` (`create`) подавляет предупреждение о создании нового архива; `r` создаст отсутствующий архив и без `c`;
- `s` создаёт или обновляет индекс глобальных символов архива, который использует компоновщик.

Поэтому повторная команда с теми же архивом и объектным файлом **заменяет** `vector_math.o`, а не добавляет его вторую копию. В эксперименте после двух запусков `ar rcs` команда `ar t` показала один элемент, а контрольные суммы архива совпали:

```text
archive sha256 after first ar rcs:  62bbae42a819807ffb91ed2407671b3b58ca553d76adf89c30b9a800491266dc
archive sha256 after second ar rcs: 62bbae42a819807ffb91ed2407671b3b58ca553d76adf89c30b9a800491266dc
vector_math.o
```

Это поведение описано в [руководстве GNU `ar`](https://sourceware.org/binutils/docs/binutils.html#ar).

### 2. Почему имя `main` не искажено

В `main.o` получилась следующая таблица символов:

```text
                 U dot_product
                 U get_lib_version
0000000000000000 T main
```

`main` — особая функция запуска программы. Для типа `main` стандарт требует C++ language linkage. При этом написание имени в таблице символов задаётся ABI: в используемом ABI GCC для ELF компилятор публикует специальную функцию как символ `main` без обычного C++ name mangling, чтобы код запуска среды выполнения мог вызвать её по согласованному имени. Отсутствие mangling здесь не означает `extern "C"`. Точкой входа ELF обычно является `_start`, а уже код запуска вызывает `main`.

Функции библиотеки тоже имеют простые имена, но по другой причине: в `vector_math.h` их объявления окружены `extern "C"`. Правила для `main` приведены в [черновике стандарта C++](https://eel.is/c++draft/basic.start.main).

Программа, скомпонованная со статической `libmath`, работает и содержит определения обеих функций (стандартные системные библиотеки при этом могут оставаться динамическими):

```text
Library version: v2.4.1-release
Dot product result: 32

0000000000401211 T dot_product
0000000000401204 T get_lib_version
```

## Этап 2. Динамическая библиотека

### 1. Сборка без `-fPIC`

Две команды из задания в данном окружении **не выдали ошибку**:

```text
$ gcc -c vector_math.c -o vector_math_nopic.o
$ gcc -shared -o libmath_broken.so vector_math_nopic.o
original no-PIC shared link exit=0
```

В этом исходнике `LIB_VERSION` объявлен как `static`, то есть имеет внутреннюю связность. Обращение к нему представлено PC-relative релокацией на локальную секцию `.data`, которую компоновщик может разрешить внутри самой библиотеки:

```text
R_X86_64_PC32  .data - 4
```

Поэтому формулировка задания «без `-fPIC` обязательно будет ошибка» для этого конкретного кода, архитектуры и набора инструментов не подтверждается. GCC рекомендует при создании shared library компилировать входные файлы с `-fPIC`, но документация `-shared` отдельно оговаривает, что связывание кода без PIC возможно не на всех системах: [опции генерации кода](https://gcc.gnu.org/onlinedocs/gcc/Code-Gen-Options.html) и [опции компоновки GCC](https://gcc.gnu.org/onlinedocs/gcc/Link-Options.html).

Чтобы показать ошибку, не подменяя основной эксперимент, сценарий создаёт **дополнительный контролируемый вариант только в `build/`**: убирает `static` у `LIB_VERSION`. Тогда символ получает внешнюю связность, а no-PIC объект содержит релокацию к переопределяемому символу:

```text
R_X86_64_PC32  LIB_VERSION - 4
```

Его компоновка завершается с кодом 1:

```text
/usr/bin/ld: vector_math_nopic.o: warning: relocation against `LIB_VERSION' in read-only section `.text'
/usr/bin/ld: vector_math_nopic.o: relocation R_X86_64_PC32 against symbol `LIB_VERSION' can not be used when making a shared object; recompile with -fPIC
/usr/bin/ld: final link failed: bad value
collect2: error: ld returned 1 exit status
controlled no-PIC shared link exit=1
```

Тот же контролируемый вариант с `-fPIC` успешно собирается. Основные файлы задания после эксперимента имеют те же SHA-256, что и до него.

### 2. Размер `text` и расположение кода

```text
   text    data     bss     dec     hex filename
   1900     624     280    2804     af4 app_static
   1869     648     280    2797     aed app_dynamic
   1148     488       8    1644     66c libmath_dynamic.so
```

У `app_dynamic` значение `text` на 31 байт меньше (`1869` вместо `1900`). Это небольшая разница: GNU `size` включает в столбец `text` не только машинный код функций, но и другие доступные только для чтения секции, а динамическому варианту нужны таблицы и служебные данные динамической компоновки.

Код `dot_product` и `get_lib_version` находится в `libmath_dynamic.so`. В статической программе символы определены (`T`), а в динамической остаются неразрешёнными до загрузки (`U`):

```text
$ nm app_static | grep -E ' (dot_product|get_lib_version)$'
0000000000401211 T dot_product
0000000000401204 T get_lib_version

$ nm app_dynamic | grep -E ' (dot_product|get_lib_version)$'
                 U dot_product
                 U get_lib_version
```

Динамическая секция программы содержит явную зависимость:

```text
(NEEDED) Shared library: [libmath_dynamic.so]
```

При запуске динамический загрузчик отображает библиотеку в адресное пространство процесса и разрешает эти ссылки. Программа с `LD_LIBRARY_PATH=.` выводит:

```text
Library version: v2.4.1-release
Dot product result: 32
```

## Этап 3. Порядок компоновки

### 1. Множества `U`, `D`, `E` и фактическое поведение

Обычная команда из задания в проверенном окружении неожиданно завершилась успешно:

```text
$ g++ -L. -lmath_dynamic main.o -o app_wrong_order
plain wrong-order link exit=0
```

Причина в настройке компоновщика: без `--as-needed` разделяемая библиотека сохраняется как зависимость даже в том случае, если на момент её появления ещё нет неразрешённых ссылок. Это отличается от извлечения членов статического архива.

Классическая модель `U/D/E` непосредственно описывает обработку **архива** `.a`: `U` — неразрешённые ссылки, `D` — найденные определения, `E` — включённые объектные файлы. Ниже рассматриваются только два математических символа и пользовательские входные файлы; служебные объекты C/C++ runtime у `g++` имеют собственные символы:

1. для этих двух имён до пользовательских входных файлов `U` и `D` пусты;
2. если `libmath_static.a` встречается первой, в `U` ещё нет `dot_product` и `get_lib_version`, поэтому `vector_math.o` не извлекается и в `E` не попадает;
3. последующий обычный объект `main.o` включается безусловно, попадает в `E` и добавляет оба имени в `U`, но архив уже пройден, поэтому ссылки остаются неразрешёнными;
4. в правильном порядке `main.o` сначала добавляет имена в `U`, после чего из архива извлекается `vector_math.o`: он попадает в `E`, а его определения — в `D`, закрывая обе ссылки.

Контрольный запуск подтверждает это:

```text
$ g++ -L. -lmath_static main.o -o app_static_wrong_order
main.cpp:(.text+0x46): undefined reference to `get_lib_version'
main.cpp:(.text+0x88): undefined reference to `dot_product'
collect2: error: ld returned 1 exit status
static archive wrong-order link exit=1
```

Для `.so` члены в `E` не извлекаются: библиотека является одной динамической зависимостью. Однако явный `--as-needed` принимает решение о сохранении этой зависимости в точке, где она встретилась. В неправильном порядке требуемых ссылок ещё нет, библиотека отбрасывается, а затем `main.o` добавляет два имени в `U`:

```text
$ g++ -Wl,--as-needed -L. -lmath_dynamic main.o -o app_wrong_order_as_needed
main.cpp:(.text+0x46): undefined reference to `get_lib_version'
main.cpp:(.text+0x88): undefined reference to `dot_product'
collect2: error: ld returned 1 exit status
explicit --as-needed wrong-order link exit=1
```

В правильном порядке `main.o` сначала создаёт неразрешённые ссылки, поэтому библиотека удовлетворяет их и сохраняется в `DT_NEEDED` даже с явным `--as-needed`. Обратная контрольная команда с `--no-as-needed` также успешно работает в неправильном порядке и содержит `NEEDED: libmath_dynamic.so`. Правила зависят от позиции аргумента и описаны в [руководстве GNU `ld`](https://sourceware.org/binutils/docs/ld/Options.html#Options).

## Этап 4. Name mangling и `extern "C"`

### 1. Имена символов без `extern "C"`

Сценарий создаёт изменённую копию заголовка внутри `build/`, не меняя исходный `vector_math.h`. После удаления блоков `extern "C"` компилятор C++ кодирует в имени функции её сигнатуру:

```text
$ nm main_no_extern.o | grep -E 'dot_product|get_lib_version'
                 U _Z11dot_productPKiS0_i
                 U _Z15get_lib_versionv

$ nm -C main_no_extern.o | grep -E 'dot_product|get_lib_version'
                 U dot_product(int const*, int const*, int)
                 U get_lib_version()
```

Библиотека скомпилирована как C и по-прежнему экспортирует простые имена:

```text
0000000000001106 T dot_product
00000000000010f9 T get_lib_version
```

Имена `_Z11dot_productPKiS0_i` и `_Z15get_lib_versionv` не совпадают с `dot_product` и `get_lib_version`, поэтому линковка завершается с кодом 1:

```text
main.cpp:(.text+0x46): undefined reference to `get_lib_version()'
main.cpp:(.text+0x88): undefined reference to `dot_product(int const*, int const*, int)'
collect2: error: ld returned 1 exit status
link without extern C exit=1
```

`extern "C"` в исходном заголовке задаёт C language linkage для объявлений, благодаря чему C++-модуль запрашивает те же простые имена, которые определяет C-библиотека. Языковое связывание описано в [разделе `[dcl.link]` стандарта C++](https://eel.is/c++draft/dcl.link).
