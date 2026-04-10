# Text Processing Cheat Sheet

Reference for stream and text manipulation with `grep`, `sed`, and `awk`.

---

## Table of Contents

- [Regex Quick Reference](#regex-quick-reference)
- [grep — Searching](#grep--searching)
- [grep — Flags & Options](#grep--flags--options)
- [grep — Patterns & Examples](#grep--patterns--examples)
- [sed — Basics](#sed--basics)
- [sed — Substitution](#sed--substitution)
- [sed — Deletion & Insertion](#sed--deletion--insertion)
- [sed — Ranges & Addresses](#sed--ranges--addresses)
- [sed — In-Place Editing](#sed--in-place-editing)
- [sed — Useful One-Liners](#sed--useful-one-liners)
- [awk — Basics](#awk--basics)
- [awk — Built-in Variables](#awk--built-in-variables)
- [awk — Patterns & Actions](#awk--patterns--actions)
- [awk — Built-in Functions](#awk--built-in-functions)
- [awk — Control Flow](#awk--control-flow)
- [awk — Useful One-Liners](#awk--useful-one-liners)
- [Combining Tools](#combining-tools)

---

## Regex Quick Reference

Used by grep, sed, and awk (ERE/BRE applies — see notes per tool).

| Pattern      | Meaning                              |
|--------------|--------------------------------------|
| `.`          | Any single character (not newline)   |
| `*`          | Zero or more of the preceding        |
| `+`          | One or more (ERE/Perl only)          |
| `?`          | Zero or one (ERE/Perl only)          |
| `^`          | Start of line                        |
| `$`          | End of line                          |
| `[abc]`      | Character class (a, b, or c)         |
| `[^abc]`     | Negated class (not a, b, or c)       |
| `[a-z]`      | Range                                |
| `(foo\|bar)` | Alternation (ERE: `foo\|bar`)        |
| `\b`         | Word boundary (grep -P / awk)        |
| `\d`         | Digit (Perl/grep -P only)            |
| `\w`         | Word character (Perl/grep -P only)   |
| `{n,m}`      | Between n and m repetitions (ERE)    |
| `\1`         | Backreference to group 1             |

> **BRE** (basic) — default for `grep` and `sed`; `(`, `{`, `+`, `?` must be escaped.  
> **ERE** (extended) — enabled with `grep -E` / `egrep`, `sed -E`, and `awk` natively.  
> **PCRE** — enabled with `grep -P`; supports `\d`, `\w`, `\b`, lookaheads, etc.

---

## grep — Searching

- Search for a pattern in a file  
  `grep 'pattern' file`

- Search recursively in a directory  
  `grep -r 'pattern' /path/`

- Case-insensitive search  
  `grep -i 'pattern' file`

- Show line numbers  
  `grep -n 'pattern' file`

- Count matching lines  
  `grep -c 'pattern' file`

- Print only the matching part (not the whole line)  
  `grep -o 'pattern' file`

- Invert match (lines NOT matching)  
  `grep -v 'pattern' file`

- Match whole word  
  `grep -w 'word' file`

- Match whole line  
  `grep -x 'exact line' file`

- Show N lines of context  
  `grep -A 3 'pattern' file`  — 3 lines after  
  `grep -B 3 'pattern' file`  — 3 lines before  
  `grep -C 3 'pattern' file`  — 3 lines either side

---

## grep — Flags & Options

| Flag         | Effect                                       |
|--------------|----------------------------------------------|
| `-E`         | Extended regex (ERE)                         |
| `-P`         | Perl-compatible regex (PCRE)                 |
| `-F`         | Fixed string (no regex), faster              |
| `-i`         | Case-insensitive                             |
| `-v`         | Invert match                                 |
| `-r` / `-R`  | Recursive (`-R` follows symlinks)            |
| `-l`         | Print filenames only (not matching lines)    |
| `-L`         | Print files with NO match                    |
| `-n`         | Print line numbers                           |
| `-c`         | Count matching lines per file                |
| `-o`         | Print only matched text                      |
| `-w`         | Whole word match                             |
| `-x`         | Whole line match                             |
| `--include`  | Limit recursion to file pattern              |
| `--exclude`  | Exclude file pattern from recursion          |
| `-m N`       | Stop after N matches per file                |
| `-q`         | Quiet — exit 0/1, no output (good in scripts)|
| `-s`         | Suppress error messages                      |
| `--color`    | Highlight matches                            |

---

## grep — Patterns & Examples

- Match IP addresses (rough)  
  `grep -E '[0-9]{1,3}(\.[0-9]{1,3}){3}' file`

- Find lines with two consecutive identical words  
  `grep -P '\b(\w+) \1\b' file`

- Search only `.log` files recursively  
  `grep -r --include='*.log' 'ERROR' /var/log/`

- Find files containing a pattern (no line output)  
  `grep -rl 'TODO' ./src/`

- Silent test in a script  
  ```bash
  if grep -q 'pattern' file; then
    echo "found"
  fi
  ```

- OR with ERE  
  `grep -E 'error|warn|crit' /var/log/syslog`

- AND (chain pipes)  
  `grep 'error' file | grep 'disk'`

---

## sed — Basics

`sed` reads input line by line, applies commands, and writes to stdout.  
Use `-n` to suppress default output and print only when explicitly told.

- Print a file (like cat)  
  `sed '' file`

- Print line 5 only  
  `sed -n '5p' file`

- Print lines 5 to 10  
  `sed -n '5,10p' file`

- Print last line  
  `sed -n '$p' file`

- Count lines (print line number of last line)  
  `sed -n '$=' file`

---

## sed — Substitution

```
sed 's/old/new/' file          # replace first match per line
sed 's/old/new/g' file         # replace all matches per line
sed 's/old/new/2' file         # replace 2nd match only
sed 's/old/new/gi' file        # case-insensitive, all matches
sed 's/old/new/p' file         # print line if substitution made
```

- Use `&` to refer to the matched text  
  `sed 's/[0-9]*/[&]/' file`  → wraps the number in brackets

- Use capture groups (BRE: `\(` `\)`, ERE: `(` `)`)  
  `sed 's/\(foo\)\(bar\)/\2\1/' file`  → swaps foo and bar  
  `sed -E 's/(foo)(bar)/\2\1/' file`   → same with ERE

- Use a different delimiter (useful when pattern contains `/`)  
  `sed 's|/old/path|/new/path|g' file`  
  `sed 's,/old/path,/new/path,g' file`

---

## sed — Deletion & Insertion

- Delete blank lines  
  `sed '/^$/d' file`

- Delete lines matching a pattern  
  `sed '/pattern/d' file`

- Delete line 3  
  `sed '3d' file`

- Delete lines 3 to 7  
  `sed '3,7d' file`

- Delete from pattern to end of file  
  `sed '/START/,$d' file`

- Insert a line before line 3 (BRE)  
  `sed '3i\new line here' file`

- Append a line after line 3  
  `sed '3a\new line here' file`

- Insert before lines matching a pattern  
  `sed '/pattern/i\inserted line' file`

- Replace entire line 5  
  `sed '5c\replacement line' file`

---

## sed — Ranges & Addresses

| Address          | Meaning                              |
|------------------|--------------------------------------|
| `N`              | Line number N                        |
| `$`              | Last line                            |
| `N,M`            | Lines N through M                    |
| `/regex/`        | Lines matching regex                 |
| `/start/,/end/`  | From first match to next match       |
| `N,/regex/`      | From line N to next match            |
| `0,/regex/`      | From start until first match (GNU)   |
| `~N`             | Every Nth line (GNU: `first~step`)   |

- Apply command only to lines NOT matching  
  `sed '/pattern/!d' file`  → keep only lines matching

- Nested address ranges  
  `sed -n '/START/,/END/p' file`  → print between markers

---

## sed — In-Place Editing

- Edit file in place  
  `sed -i 's/old/new/g' file`

- Edit in place with backup  
  `sed -i.bak 's/old/new/g' file`  → original saved as `file.bak`

- Edit multiple files  
  `sed -i 's/old/new/g' *.conf`

> Always use `-i.bak` on production files — a typo destroys the file.

---

## sed — Useful One-Liners

- Remove leading whitespace  
  `sed 's/^[[:space:]]*//' file`

- Remove trailing whitespace  
  `sed 's/[[:space:]]*$//' file`

- Remove both  
  `sed 's/^[[:space:]]*//;s/[[:space:]]*$//' file`

- Remove blank lines  
  `sed '/^[[:space:]]*$/d' file`

- Remove comments (lines starting with `#`)  
  `sed '/^[[:space:]]*#/d' file`

- Double-space a file  
  `sed 'G' file`

- Number lines  
  `sed '=' file | sed 'N;s/\n/\t/'`

- Print lines between two patterns (inclusive)  
  `sed -n '/BEGIN/,/END/p' file`

- Delete HTML tags  
  `sed 's/<[^>]*>//g' file`

- Reverse order of lines  
  `sed -n '1!G;h;$p' file`

---

## awk — Basics

`awk` processes input record by record (default: one line = one record).  
Each record is split into fields by the field separator (default: whitespace).

```
awk 'pattern { action }' file
```

- Print the whole line  
  `awk '{ print }' file`

- Print field 1 and field 3  
  `awk '{ print $1, $3 }' file`

- Use a custom field separator  
  `awk -F: '{ print $1 }' /etc/passwd`  → usernames  
  `awk -F, '{ print $2 }' data.csv`

- Use multiple-character separator  
  `awk -F'::' '{ print $1 }' file`

- Set separator in BEGIN  
  `awk 'BEGIN { FS=":" } { print $1 }' file`

- Set output separator  
  `awk 'BEGIN { OFS="-" } { print $1, $2 }' file`

- Pass a shell variable into awk  
  `awk -v threshold=100 '$3 > threshold { print }' file`

---

## awk — Built-in Variables

| Variable | Meaning                                      |
|----------|----------------------------------------------|
| `$0`     | Entire current record (line)                 |
| `$1`–`$N`| Field 1 through N                            |
| `NF`     | Number of fields in current record           |
| `NR`     | Current record number (across all files)     |
| `FNR`    | Current record number within current file    |
| `FS`     | Input field separator (default: whitespace)  |
| `OFS`    | Output field separator (default: space)      |
| `RS`     | Input record separator (default: newline)    |
| `ORS`    | Output record separator (default: newline)   |
| `FILENAME`| Name of current input file                  |
| `ARGC`   | Number of command-line arguments             |
| `ARGV`   | Array of command-line arguments              |

- Print last field of each line  
  `awk '{ print $NF }' file`

- Print all but the first field  
  `awk '{ $1=""; print }' file`

---

## awk — Patterns & Actions

- Match lines containing a pattern  
  `awk '/pattern/ { print }' file`

- Negate a pattern  
  `awk '!/pattern/ { print }' file`

- Numeric comparison  
  `awk '$3 > 100 { print $1, $3 }' file`

- Range pattern (inclusive, like sed's range)  
  `awk '/START/,/END/ { print }' file`

- BEGIN and END blocks  
  ```awk
  awk 'BEGIN { print "start" } { print } END { print "done" }' file
  ```

- Count matching lines  
  `awk '/error/ { count++ } END { print count }' file`

- Sum a column  
  `awk '{ sum += $3 } END { print sum }' file`

- Average of column 2  
  `awk '{ sum += $2; n++ } END { print sum/n }' file`

- Print lines where field count equals 5  
  `awk 'NF == 5' file`

- Print line numbers with lines  
  `awk '{ print NR": "$0 }' file`

---

## awk — Built-in Functions

**String functions**

| Function                   | Effect                                   |
|----------------------------|------------------------------------------|
| `length(s)`                | Length of string s (or `$0` if omitted) |
| `substr(s, i, n)`          | Substring of s starting at i, length n  |
| `index(s, t)`              | Position of t in s (0 = not found)      |
| `split(s, arr, sep)`       | Split s into array arr on sep           |
| `sub(re, repl, target)`    | Replace first match of re in target     |
| `gsub(re, repl, target)`   | Replace all matches of re in target     |
| `match(s, re)`             | Sets RSTART/RLENGTH; returns position   |
| `sprintf(fmt, ...)`        | Format string (like printf)             |
| `toupper(s)` / `tolower(s)`| Case conversion                         |
| `gensub(re, repl, how, s)` | Like gsub but returns new string (gawk) |

**Numeric functions**

| Function        | Effect                     |
|-----------------|----------------------------|
| `int(x)`        | Truncate to integer        |
| `sqrt(x)`       | Square root                |
| `log(x)`        | Natural logarithm          |
| `exp(x)`        | e^x                        |
| `sin(x)` / `cos(x)` | Trig (radians)        |
| `rand()`        | Random float [0,1)         |
| `srand(seed)`   | Seed the RNG               |

---

## awk — Control Flow

```awk
# if/else
{ if ($3 > 100) print "high"; else print "low" }

# while loop
{ i=1; while (i <= NF) { print $i; i++ } }

# for loop (C-style)
{ for (i=1; i<=NF; i++) print $i }

# for-in loop (array)
END { for (k in counts) print k, counts[k] }

# next — skip to the next record
/^#/ { next }

# exit — stop processing
NR == 10 { exit }
```

---

## awk — Useful One-Liners

- Print unique lines (maintaining order, no sort needed)  
  `awk '!seen[$0]++' file`

- Print duplicate lines  
  `awk 'seen[$0]++' file`

- Print lines longer than 80 characters  
  `awk 'length > 80' file`

- Reverse fields on each line  
  `awk '{ for(i=NF;i>=1;i--) printf "%s%s",$i,(i>1?OFS:ORS) }' file`

- Print every second line  
  `awk 'NR%2==0' file`

- Remove duplicate blank lines (squeeze)  
  `awk '/^$/ { if (!blank) print; blank=1; next } { blank=0; print }' file`

- Column-align output  
  `awk '{ printf "%-20s %s\n", $1, $2 }' file`

- Word frequency count  
  `awk '{ for(i=1;i<=NF;i++) freq[$i]++ } END { for(w in freq) print freq[w], w }' file | sort -rn`

- Sum file sizes from `ls -l`  
  `ls -l | awk 'NR>1 { sum += $5 } END { print sum }'`

- Print lines between two line numbers  
  `awk 'NR>=10 && NR<=20' file`

- Simulate `wc -l`  
  `awk 'END { print NR }' file`

- Swap columns 1 and 2  
  `awk '{ print $2, $1 }' file`

- Extract CSV column (handles quoted commas poorly — use for simple CSVs)  
  `awk -F, '{ print $3 }' file.csv`

---

## Combining Tools

- Find all failed SSH logins, count by IP  
  ```bash
  grep 'Failed password' /var/log/auth.log \
    | awk '{ print $(NF-3) }' \
    | sort | uniq -c | sort -rn
  ```

- Strip comments and blank lines from a config  
  ```bash
  sed '/^[[:space:]]*#/d;/^[[:space:]]*$/d' /etc/ssh/sshd_config
  ```

- Extract unique HTTP status codes from access log  
  ```bash
  awk '{ print $9 }' /var/log/nginx/access.log | sort -u
  ```

- Replace a value in a specific column only  
  ```bash
  awk -F, 'BEGIN{OFS=","} $2=="old" { $2="new" } { print }' file.csv
  ```

- Find large log entries (lines > 1KB)  
  ```bash
  awk 'length > 1024 { print NR": "substr($0,1,80)"..." }' app.log
  ```

- Multi-step pipeline: top 10 IPs hitting a server  
  ```bash
  awk '{ print $1 }' /var/log/nginx/access.log \
    | sort | uniq -c | sort -rn | head -10
  ```

- In-place remove a user from `/etc/group` entries  
  ```bash
  sed -i "s/,\busername\b//g;s/\busername\b,//g" /etc/group
  ```

- Print config values without comments or blanks, with line numbers  
  ```bash
  grep -v '^\s*#' /etc/ssh/sshd_config \
    | grep -v '^\s*$' \
    | awk '{ print NR"\t"$0 }'
  ```
