# Лабораторная 2. Задача A — Избавьтесь от легаси

**Окружение:** Linux x86-64, `gcc (GCC) 14.4.0`, `GNU ld (GNU Binutils for Debian) 2.44` (Docker-образ `gcc:14`, `--platform linux/amd64`).
Объектные файлы собраны автором задания: `GCC: (Ubuntu 15.2.0-16ubuntu1) 15.2.0` (из секции `.comment`).

Все команды лежат в [run.sh](run.sh), полный вывод — в [output.txt](output.txt). Повторить:

```bash
docker run --rm --platform linux/amd64 -v "$PWD":/w -w /w gcc:14 sh run.sh > output.txt 2>&1
```

---

## Этап 0. Размеры файлов и секций

**1. Вывод `size`**

```
$ size core.o legacy.o hotfix.o main.o
   text	   data	    bss	    dec	    hex	filename
    266	   4040	  50000	  54306	   d422	core.o
    127	      0	      0	    127	     7f	hotfix.o
    172	      0	      4	    176	     b0	legacy.o
    118	      0	      0	    118	     76	main.o
```

Из чего складываются столбцы для `core.o` (`size -A core.o`):

```
section               size
.text                   70  ┐
.rodata                 76  │ text = 70 + 76 + 32 + 88 = 266
.note.gnu.property      32  │
.eh_frame               88  ┘
.data                 4032  ┐ data = 4032 + 8 = 4040
.data.rel.local          8  ┘
.bss                 50000    bss
```

**2. Почему в одном из файлов `bss` аномально большой и где хранится его содержимое**

Аномалия в **`core.o`**: `bss = 50 000` байт, хотя сам файл весит всего **6200 байт**. В `.bss` лежит один объект:

```
4: 0000000000000000 50000 OBJECT  LOCAL  DEFAULT    4 large_buffer
```

Это локальный (`b` в `nm`, т.е. `static`) массив на 50 000 байт **без инициализатора** (или с нулевым), что-то вроде `static char large_buffer[50000];`.

**На диске содержимое `.bss` не хранится вообще.** У секции тип `NOBITS`:

```
  [Nr] Name   Type      Address          Off    Size   ES Flg Lk Inf Al
  [ 4] .bss   NOBITS    0000000000000000 001048 00c350 00  WA  0   0 32
  [ 5] .rodata PROGBITS 0000000000000000 001048 00004c 00   A  0   0 16
```

Смещение `.bss` в файле (`0x1048`) совпадает со смещением следующей секции `.rodata`, т.е. в файле она занимает 0 байт. В заголовке записан только размер (`0xc350` = 50 000). Начальное значение заранее известно (одни нули), поэтому хранить его незачем. `size` складывает в `dec` и «виртуальный» `bss`, поэтому `dec` (54 306) в 9 раз больше реального размера файла.

Память выделяется только при запуске. В исполняемом файле `.bss` входит в RW-сегмент, у которого размер в памяти больше размера в файле:

```
  Type  Offset   VirtAddr           FileSiz  MemSiz   Flg
  LOAD  0x002df8 0x0000000000403df8 0x001210 0x00d5a0 RW     ; .data .bss ...
```

Загрузчик отображает 0x1210 байт из файла, а оставшиеся `0xd5a0 − 0x1210` ≈ 50 KB добирает анонимными обнулёнными страницами. Так модуль и «потребляет слишком много памяти», почти не занимая места на диске.

Для контраста: `config_table` (4000 байт) лежит в `.data` и **хранится на диске целиком**, хотя ненулевые в ней только первые три `int` (`01 02 03`). Как только у массива есть хоть один ненулевой инициализатор, весь он уходит в `.data`.

---

## Этап 1. Извлечение строк

**3. Секция `core.o`, которой нет в `legacy.o` и `hotfix.o`**

**`.rodata`** — данные только для чтения, сюда компилятор кладёт строковые литералы и `const`-объекты:

```
  [ 5] .rodata           PROGBITS        0000000000000000 001048 00004c 00   A  0   0 16
```

Флаг только `A` (alloc), без `W`: при загрузке секция попадает в сегмент без права записи. Её содержимое:

```
$ readelf -p .rodata core.o
String dump of section '.rodata':
  [     0]  System Initialized v1.0
  [    20]  FLAG{b1nary_4rch4eology_2026}
  [    3e]  %s, Mode: %d\n
```

Ещё одна секция есть только в `core.o` — `.data.rel.local` (8 байт) с релокацией `R_X86_64_64 .rodata + 0`. Это указатель `welcome_msg`, который указывает на строку `"System Initialized v1.0"`. Значит, в исходнике было примерно `const char *welcome_msg = "System Initialized v1.0";`. Сам указатель изменяемый, поэтому лежит не в `.rodata`, а в отдельной секции `.data`, которой нужна релокация.

**4. Секретный токен**

```
$ strings -a core.o
System Initialized v1.0
FLAG{b1nary_4rch4eology_2026}
%s, Mode: %d
GCC: (Ubuntu 15.2.0-16ubuntu1) 15.2.0
core.c
...
```

```
FLAG{b1nary_4rch4eology_2026}
```

Это объект `secret_token` (`R`, `.rodata+0x20`, размер 30 = 29 символов + `\0`).

---

## Этап 2. Символы

```
$ nm core.o                              $ nm legacy.o
0000000000000020 D config_table          000000000000001a T apply_legacy_patch
0000000000000000 t internal_cleanup      0000000000000000 b legacy_counter
0000000000000000 b large_buffer          0000000000000000 t legacy_helper
0000000000000012 T print_status          0000000000000004 C system_mode
                 U printf
0000000000000020 R secret_token          $ nm hotfix.o
0000000000000000 D system_mode           0000000000000000 T apply_hotfix
0000000000000000 D welcome_msg           0000000000000004 C system_mode

                                         $ nm main.o
                                                          U apply_hotfix
                                         0000000000000000 T main
                                                          U print_status
```

**5. Какие имена встречаются более чем в одном файле**

```
$ nm -A *.o | awk '{print $NF}' | sort | uniq -c | sort -rn
      3 system_mode
      2 print_status
      2 apply_hotfix
      1 ...
```

- **`system_mode`** — в трёх файлах, и **в каждом из них он определён**. Это и есть проблема.
- `print_status` и `apply_hotfix` — в двух файлах, но это нормальная пара «определение + использование»: в `main.o` они `U` (undefined), компоновщик просто подставит адрес.

**6. Анализ каждого общего имени**

| имя | файл | тип `nm` | `Ndx` (`readelf -s`) | размер | что это |
|---|---|---|---|---|---|
| `system_mode` | `core.o` | **`D`** | **3 (`.data`)** | 4 | сильное определение с инициализатором |
| `system_mode` | `legacy.o` | **`C`** | **`COM`** | 4, выравнивание 4 | COMMON (предварительное определение) |
| `system_mode` | `hotfix.o` | **`C`** | **`COM`** | 4, выравнивание 1 | COMMON (предварительное определение) |
| `print_status` | `core.o` | `T` | 1 (`.text`) | 52 | определение функции |
| `print_status` | `main.o` | `U` | `UND` | — | ссылка |
| `apply_hotfix` | `hotfix.o` | `T` | 1 (`.text`) | 39 | определение функции |
| `apply_hotfix` | `main.o` | `U` | `UND` | — | ссылка |

```
core.o:   7: 0000000000000000     4 OBJECT  GLOBAL DEFAULT    3 system_mode
legacy.o: 6: 0000000000000004     4 OBJECT  GLOBAL DEFAULT  COM system_mode
hotfix.o: 3: 0000000000000001     4 OBJECT  GLOBAL DEFAULT  COM system_mode
```

У COMMON-символа нет секции (`Ndx = COM`), а поле `Value` хранит **не адрес, а требуемое выравнивание**: 4 в `legacy.o` (выравнивание `int`), 1 в `hotfix.o` (выравнивание `char`). Поэтому `nm` печатает в первой колонке `4` у обоих: для `C` это размер.

**7. Что можно сказать о `system_mode` в `core.o` и `legacy.o` и какой конфликт это создаёт**

Без исходников, по таблице символов, дизассемблеру и содержимому секций:

- **`core.o`: `int system_mode = 1;`**
  - Это сильное определение в `.data` размером 4 байта, а первые 4 байта `.data` равны `01 00 00 00`.
  - Используется как `int`: `print_status` читает его 4-байтной инструкцией `mov edx, DWORD PTR [system_mode]` и печатает через `"%s, Mode: %d\n"`.
- **`legacy.o`: `int system_mode;`**
  - Это неинициализированная глобальная переменная, которая при `-fcommon` стала COMMON.
  - Размер 4 и выравнивание 4 указывают на `int`, и `apply_legacy_patch` пишет в неё 4-байтное число: `mov DWORD PTR [system_mode], 0x2a` (`system_mode = 42`).
- **`hotfix.o`: `char system_mode[4];`** (это видно из исходника). Размер тот же, 4, но выравнивание 1, и запись идёт побайтно: `'A'`, `'B'`, `'C'`, `'\0'`.

**Конфликт.** Три модуля считают себя владельцами одной глобальной переменной и трактуют её по-разному: для двух это число, для `hotfix` — строка. Компоновщик склеит все три в **один и тот же объект в памяти**. Последствия:

- `apply_hotfix()` затирает режим, выставленный `core`, байтами `41 42 43 00`. При чтении как `int` (little-endian) это `0x00434241 = 4407873`, а не осмысленный режим.
- `apply_legacy_patch()`, наоборот, превратит «строку» хотфикса в `"*\0\0\0"` (42 = `'*'`).
- По стандарту C это нарушение правила «одно внешнее определение» (C11 6.9p5) и несовместимые типы одного объекта (6.2.7p2), т.е. **неопределённое поведение**. Обнаружить его можно только на этапе компоновки.

---

## Этап 3. Попытка компоновки

```
$ gcc -fcommon core.o legacy.o hotfix.o main.o -o app
$ echo $?
0
$ ./app
System Initialized v1.0, Mode: 1
System Initialized v1.0, Mode: 4407873
```

**8. Выдал ли компоновщик ошибку или предупреждение?**

**Нет**, ни ошибки, ни предупреждения: компоновка прошла молча с кодом 0. Однако программа уже ведёт себя неправильно. `main` вызывает `print_status()`, затем `apply_hotfix()`, затем снова `print_status()`, и режим превращается из `1` в мусорное `4407873` (`"ABC"`, прочитанное как `int`).

Почему компоновщик молчит:

1. **COMMON-символ по определению слабый.** Это «предварительное определение» из старого C (и Fortran COMMON-блоков): «если больше никто не определит эту переменную, выдели под неё память, иначе используй чужую». Правила разрешения в ld:
   - несколько `C` с одним именем сливаются в один объект максимального размера и выравнивания;
   - `C` + одно сильное определение (`D`/`B`) → побеждает сильное, а все `C` становятся ссылками на него;
   - ошибка `multiple definition` бывает только при **двух сильных** определениях.

   У нас ровно одно сильное (`core.o`) и два COMMON, так что с точки зрения правил всё законно.
2. **В ELF нет информации о типах.** Символ — это имя, адрес, размер и выравнивание. Компоновщик не знает, что в одном модуле это `int`, а в другом `char[4]`. Размеры к тому же совпадают (4 = 4), так что даже несовпадения размеров нет.

Проблему видно только с флагом `--warn-common`, и то как предупреждение, не как ошибку:

```
$ gcc -fcommon -Wl,--warn-common core.o legacy.o hotfix.o main.o -o app_warn
/usr/bin/ld: legacy.o: warning: common of `system_mode' overridden by definition from core.o
/usr/bin/ld: hotfix.o: warning: common of `system_mode' overridden by definition from core.o
```

---

## Этап 4. Анализ исполняемого файла и фикс

```
$ nm app | grep system_mode
0000000000404040 D system_mode

$ readelf -s -W app | grep -E ' (system_mode|config_table|large_buffer|welcome_msg)$'
    12: 0000000000405040 50000 OBJECT  LOCAL  DEFAULT   24 large_buffer
    32: 0000000000404040     4 OBJECT  GLOBAL DEFAULT   23 system_mode
    38: 0000000000404060  4000 OBJECT  GLOBAL DEFAULT   23 config_table

$ readelf -S -W app | grep -E ' \.(data|bss) '
  [23] .data   PROGBITS  0000000000404020 003020 000fe8 00  WA  0   0 32
  [24] .bss    NOBITS    0000000000405020 004008 00c378 00  WA  0   0 32
```

**9. В какой секции оказался `system_mode` и почему**

В **`.data`** (`D`, секция 23, адрес `0x404040`), т.е. ровно там, где его определил `core.o`: за ним по `0x404060` идёт `config_table` из того же модуля. Символ существует в одном экземпляре, и все три модуля обращаются к этому адресу.

Компоновщик выбрал `.data`, потому что **сильное определение всегда побеждает COMMON**. Определение из `core.o` инициализировано (`= 1`), а значение может храниться только в `.data`. Если бы победил COMMON и символ ушёл в `.bss`, начальное значение `1` потерялось бы. COMMON-символы из `legacy.o` и `hotfix.o` просто разрешились в ссылки на него (`overridden by definition from core.o`) и собственной памяти не получили. В `.bss` (обнулённые `NOBITS`) COMMON-символ попал бы только в случае, если бы сильного определения не было нигде.

---

### Пересборка с `-fno-common`

```
$ gcc -fno-common main.o hotfix.o legacy.o core.o -o app_better
$ echo $?
0
$ nm app_better | grep system_mode
0000000000404040 D system_mode
```

С **готовыми** объектными файлами эта команда **тоже проходит без ошибок**, и это важная деталь. `-fno-common` — **флаг компилятора, а не компоновщика**: он влияет только на то, как `cc1` генерирует код для новых `.c`-файлов. Когда на входе одни `.o`, `gcc` сразу вызывает `ld`, и флаг ни на что не действует. В `hotfix.o` и `legacy.o` уже записаны символы `COM`, и они разрешаются по старым правилам.

Чтобы флаг сработал, модуль нужно **перекомпилировать**. Исходник есть только у `hotfix.c`:

```
$ gcc -c -fno-common hotfix.c -o hotfix_nocommon.o
$ nm hotfix_nocommon.o
0000000000000000 T apply_hotfix
0000000000000000 B system_mode          <- теперь сильное определение в .bss, а не C
```

**10. Какое сообщение об ошибке теперь выдаёт компоновщик?**

```
$ gcc -fno-common main.o hotfix_nocommon.o legacy.o core.o -o app_better
/usr/bin/ld: warning: alignment 1 of normal symbol `system_mode' in hotfix_nocommon.o is smaller than 4 used by the common definition in legacy.o
/usr/bin/ld: warning: NOTE: alignment discrepancies can cause real problems.  Investigation is advised.
/usr/bin/ld: core.o:(.data+0x0): multiple definition of `system_mode'; hotfix_nocommon.o:(.bss+0x0): first defined here
collect2: error: ld returned 1 exit status
```

Главное — **`multiple definition of 'system_mode'`**: теперь в программе два сильных определения, `B` из хотфикса и `D` из `core.o`. Попутно ld предупреждает, что `char`-массив с выравниванием 1 не годится для `int`, которому нужно выравнивание 4 (оно известно из COMMON-символа `legacy.o`). Это ещё одно указание на несовпадение типов.

С `-fno-common` (поведение по умолчанию начиная с GCC 10) скрытый конфликт, который раньше молча порождал UB, превращается в явную ошибку сборки.

#### Как исправить `hotfix.c`, не меняя имён

Нужно, чтобы `hotfix.c` перестал **определять** `system_mode`, а только объявлял его. Тогда владельцем памяти будет `core.o`. Для этого достаточно добавить `extern` ([fix/hotfix_extern.c](fix/hotfix_extern.c)):

```c
extern char system_mode[4];   /* объявление: память выделяет core.o */

void apply_hotfix(void) {
  system_mode[0] = 'A';
  system_mode[1] = 'B';
  system_mode[2] = 'C';
  system_mode[3] = '\0';
}
```

```
$ gcc -c -fno-common fix/hotfix_extern.c -o fix/hotfix_extern.o
$ nm fix/hotfix_extern.o
0000000000000000 T apply_hotfix
                 U system_mode          <- больше не определение, а ссылка
$ gcc -fno-common main.o fix/hotfix_extern.o legacy.o core.o -o fix/app_better_extern
$ echo $?
0
$ ./fix/app_better_extern
System Initialized v1.0, Mode: 1
System Initialized v1.0, Mode: 4407873
```

Сборка проходит. Но `extern` устраняет только **ошибку компоновки**, а **несовпадение типов** остаётся: хотфикс по-прежнему пишет строку в `int`-переменную ядра, и вывод тот же, что у исходной `-fcommon`-сборки. Это правильный фикс, только если хотфикс действительно должен менять общий `system_mode`. Тогда тип в объявлении стоит привести к настоящему, `extern int system_mode;`, а записывать в него число, а не строку. Лучше всего вынести объявление в общий заголовок (`core.h`), который подключают и `core.c`, и `hotfix.c`: тогда компилятор сам поймает несовпадение типов.

Если же хотфиксу нужен собственный буфер, а совпадение имени случайное, переменную надо сделать **`static`** ([fix/hotfix_static.c](fix/hotfix_static.c)):

```c
static char system_mode[4];   /* внутренняя связность — символ не экспортируется */
```

```
$ nm fix/hotfix_static.o
0000000000000000 T apply_hotfix
0000000000000000 b system_mode          <- локальный символ, в разрешении имён не участвует
$ gcc -fno-common main.o fix/hotfix_static.o legacy.o core.o -o fix/app_better_static
$ ./fix/app_better_static
System Initialized v1.0, Mode: 1
System Initialized v1.0, Mode: 1
$ nm fix/app_better_static | grep system_mode
0000000000405021 b system_mode          <- буфер хотфикса в .bss
0000000000404040 D system_mode          <- int из core.o в .data, не затирается
```

Теперь это две разные переменные, и режим ядра больше не портится.

**Оставшийся риск:** `legacy.o` по-прежнему содержит COMMON-символ `system_mode` (его `int system_mode;` фактически означает «чужая переменная»). Сейчас это безопасно: `apply_legacy_patch` не вызывается, а тип и размер совпадают с `core.o`. Однако если `legacy.o` когда-нибудь пересоберут с `-fno-common`, то без исходника и `extern` получится та же ошибка `multiple definition`. Пока исходник `legacy` потерян, это стоит хотя бы ловить флагом `-Wl,--warn-common`.
