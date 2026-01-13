# Vim Cheat Sheet

Quick reference for common Vim operations and commands.

---

## Table of Contents

- [Modes](#modes)
- [Starting and Exiting](#starting-and-exiting)
- [Basic Movement](#basic-movement)
- [Advanced Movement](#advanced-movement)
- [Insert Mode](#insert-mode)
- [Editing](#editing)
- [Copy & Paste](#copy--paste-yank--put)
- [Visual Mode](#visual-mode)
- [Search](#search)
- [Replace](#replace)
- [Marks & Jumps](#marks--jumps)
- [Macros](#macros)
- [Multiple Files & Buffers](#multiple-files--buffers)
- [Windows (Splits)](#windows-splits)
- [Tabs](#tabs)
- [Folding](#folding)
- [Indentation](#indentation)
- [Registers](#registers)
- [Text Objects](#text-objects)
- [Command Mode](#command-mode)
- [Useful Settings](#useful-settings)
- [Configuration](#configuration)
- [Plugins](#plugins)
- [Troubleshooting](#troubleshooting)
- [Quick Reference](#quick-reference)

---

## Modes

Vim has distinct modes for different operations:

- **Normal** — navigation and commands (default mode)
- **Insert** — text insertion (`i`, `a`, `o`)
- **Visual** — text selection (`v`, `V`, `Ctrl+v`)
- **Command** — ex commands (`:`)
- **Replace** — overwrite text (`R`)

Return to Normal mode from anywhere with `Esc` or `Ctrl+[`.

Check current mode in the bottom left of the screen.

---

## Starting and Exiting

### Opening Files

- Open file  
  `vim <file>`

- Open at specific line  
  `vim +<line> <file>`
  `vim +42 script.sh`

- Open and search for pattern  
  `vim +/pattern <file>`

- Open multiple files  
  `vim file1 file2 file3`

- Open in read-only mode  
  `vim -R <file>`
  `view <file>`

- Recover from swap file  
  `vim -r <file>`

### Exiting

- Quit  
  `:q`

- Quit without saving (discard changes)  
  `:q!`

- Save  
  `:w`

- Save and quit  
  `:wq`
  `:x` (same as :wq)
  `ZZ` (same as :wq)

- Quit all windows  
  `:qa`

- Quit all without saving  
  `:qa!`

- Save as new file  
  `:w <newfile>`

- Save read-only file (force)  
  `:w!`
  `:w !sudo tee %` (save with sudo)

---

## Basic Movement

### Character and Line Movement

- Left / Down / Up / Right  
  `h` `j` `k` `l`

- Start of line (first character)  
  `0`

- Start of line (first non-blank)  
  `^`

- End of line  
  `$`

- Move to column N  
  `N|` (e.g., `20|` moves to column 20)

### Word Movement

- Word forward  
  `w` (next word start)

- Word backward  
  `b` (previous word start)

- End of word  
  `e`

- WORD forward (space-delimited)  
  `W`

- WORD backward  
  `B`

- End of WORD  
  `E`

### Line Movement

- Beginning of file  
  `gg`

- End of file  
  `G`

- Go to line N  
  `NG` or `:N`
  `42G` (go to line 42)

- Move down N lines  
  `Nj` (e.g., `10j`)

- Move up N lines  
  `Nk`

### Screen Movement

- Top of screen  
  `H` (High)

- Middle of screen  
  `M` (Middle)

- Bottom of screen  
  `L` (Low)

- Scroll down half page  
  `Ctrl+d`

- Scroll up half page  
  `Ctrl+u`

- Scroll down full page  
  `Ctrl+f`

- Scroll up full page  
  `Ctrl+b`

- Center cursor on screen  
  `zz`

- Cursor to top of screen  
  `zt`

- Cursor to bottom of screen  
  `zb`

---

## Advanced Movement

### Paragraph and Block Movement

- Next paragraph  
  `}`

- Previous paragraph  
  `{`

- Next sentence  
  `)`

- Previous sentence  
  `(`

### Character Search (in line)

- Find character forward  
  `f<char>` (e.g., `fa` finds next 'a')

- Find character backward  
  `F<char>`

- Till character forward (before char)  
  `t<char>`

- Till character backward  
  `T<char>`

- Repeat last find  
  `;`

- Repeat last find (opposite)  
  `,`

### Matching Brackets

- Jump to matching bracket  
  `%` (works on `()`, `[]`, `{}`)

---

## Insert Mode

### Entering Insert Mode

- Insert before cursor  
  `i`

- Insert after cursor  
  `a`

- Insert at start of line  
  `I`

- Insert at end of line  
  `A`

- Open new line below  
  `o`

- Open new line above  
  `O`

- Replace character  
  `r<char>` (single char then back to normal)

- Replace mode  
  `R` (continuous overwrite)

- Change text (delete and insert)  
  `c<motion>` (e.g., `cw` change word)

### Insert Mode Commands

While in insert mode:

- Delete character before cursor  
  `Ctrl+h` or `Backspace`

- Delete word before cursor  
  `Ctrl+w`

- Delete to start of line  
  `Ctrl+u`

- Insert character literally  
  `Ctrl+v` then character

- Insert from register  
  `Ctrl+r` then register name

- Exit insert mode  
  `Esc` or `Ctrl+[` or `Ctrl+c`

---

## Editing

### Deleting

- Delete character under cursor  
  `x`

- Delete character before cursor  
  `X`

- Delete word  
  `dw` (from cursor to end of word)

- Delete WORD  
  `dW`

- Delete to end of line  
  `D` or `d$`

- Delete entire line  
  `dd`

- Delete N lines  
  `Ndd` (e.g., `5dd` deletes 5 lines)

- Delete to start of line  
  `d0`

- Delete inside word  
  `diw` (delete inner word)

- Delete around word  
  `daw` (delete word including spaces)

### Changing (Delete and Enter Insert)

- Change word  
  `cw`

- Change to end of line  
  `C` or `c$`

- Change entire line  
  `cc`

- Change inside word  
  `ciw`

- Change inside quotes  
  `ci"` or `ci'`

- Change inside parentheses  
  `ci(` or `ci)`

### Join Lines

- Join current line with next  
  `J` (adds space)

- Join without space  
  `gJ`

### Undo and Redo

- Undo  
  `u`

- Redo  
  `Ctrl+r`

- Undo all changes on line  
  `U`

- Go to earlier state  
  `:earlier 5m` (5 minutes ago)

- Go to later state  
  `:later 5m`

### Repeat

- Repeat last command  
  `.` (dot command - very powerful!)

---

## Copy & Paste (Yank & Put)

### Yanking (Copying)

- Yank line  
  `yy` or `Y`

- Yank word  
  `yw`

- Yank to end of line  
  `y$`

- Yank inside word  
  `yiw`

- Yank N lines  
  `Nyy` (e.g., `3yy`)

- Yank entire file  
  `gg"+yG` (to system clipboard)

### Putting (Pasting)

- Paste after cursor/line  
  `p`

- Paste before cursor/line  
  `P`

- Paste from register  
  `"<reg>p` (e.g., `"ap` pastes from register 'a')

- Paste from system clipboard  
  `"+p`

- Paste from primary clipboard  
  `"*p`

### Cut (Delete to Register)

Deleted text is automatically yanked:

- Cut line  
  `dd` (then `p` to paste)

- Cut word  
  `dw`

- Cut selection (visual mode)  
  Select with `v`, then `d`

---

## Visual Mode

### Entering Visual Mode

- Visual (character selection)  
  `v`

- Visual line (full lines)  
  `V`

- Visual block (column selection)  
  `Ctrl+v`

- Reselect last selection  
  `gv`

### Operations in Visual Mode

Once text is selected:

- Yank (copy)  
  `y`

- Delete (cut)  
  `d`

- Change (delete and insert)  
  `c`

- Indent right  
  `>`

- Indent left  
  `<`

- Make uppercase  
  `U`

- Make lowercase  
  `u`

- Toggle case  
  `~`

- Join lines  
  `J`

- Sort lines  
  `:sort`

### Visual Block Mode

Useful for column editing:

1. Enter visual block: `Ctrl+v`
2. Select columns with `h`/`j`/`k`/`l`
3. Insert on multiple lines:
   - `I` insert before
   - `A` insert after
   - `c` change selection
   - `d` delete selection

---

## Search

### Basic Search

- Search forward  
  `/pattern`

- Search backward  
  `?pattern`

- Next match  
  `n`

- Previous match  
  `N`

- Search for word under cursor (forward)  
  `*`

- Search for word under cursor (backward)  
  `#`

- Search for partial word under cursor  
  `g*` (forward)
  `g#` (backward)

### Search Options

- Case-insensitive search  
  `/pattern\c`

- Case-sensitive search  
  `/pattern\C`

- Search with very magic (less escaping)  
  `/\vpattern`

- Clear search highlight  
  `:noh` or `:nohlsearch`

### Search and Replace

See [Replace](#replace) section below.

---

## Replace

### Single Line Replace

- Replace first match on line  
  `:s/old/new`

- Replace all matches on line  
  `:s/old/new/g`

- Replace with confirmation  
  `:s/old/new/gc`

### File-wide Replace

- Replace first match on each line  
  `:%s/old/new`

- Replace all matches in file  
  `:%s/old/new/g`

- Replace with confirmation  
  `:%s/old/new/gc`

- Replace only in lines 5-10  
  `:5,10s/old/new/g`

- Replace in visual selection  
  Select with `V`, then `:s/old/new/g`

### Replace Flags

- `g` - global (all matches on line)
- `c` - confirm each replacement
- `i` - case-insensitive
- `I` - case-sensitive

### Confirmation Keys

When using `/gc` flag:
- `y` - yes, replace
- `n` - no, skip
- `a` - replace all remaining
- `q` - quit
- `l` - replace and quit

---

## Marks & Jumps

### Marks

- Set mark at current position  
  `m<letter>` (e.g., `ma` sets mark 'a')

- Jump to mark (exact position)  
  `` `<letter> `` (e.g., `` `a ``)

- Jump to mark (line start)  
  `'<letter>` (e.g., `'a`)

- List all marks  
  `:marks`

- Delete mark  
  `:delmarks <letter>`

Marks a-z are local to buffer, A-Z are global.

### Jump List

- Jump to previous location  
  `Ctrl+o`

- Jump to next location  
  `Ctrl+i` or `Tab`

- List jump locations  
  `:jumps`

### Change List

- Jump to previous change  
  `g;`

- Jump to next change  
  `g,`

- List changes  
  `:changes`

---

## Macros

### Recording Macros

- Start recording to register  
  `q<letter>` (e.g., `qa` records to register 'a')

- Stop recording  
  `q`

- Play macro  
  `@<letter>` (e.g., `@a`)

- Repeat last macro  
  `@@`

- Play macro N times  
  `N@<letter>` (e.g., `10@a`)

### Macro Example

```
qa          " Start recording to register 'a'
I"          " Insert quote at start of line
A"          " Insert quote at end of line
j           " Move down one line
q           " Stop recording
@a          " Play macro once
10@a        " Play macro 10 times
```

### Editing Macros

- Paste macro to edit  
  `"ap` (pastes contents of register 'a')

- Edit the text
- Yank back to register  
  `"ayy` or select and `"ay`

---

## Multiple Files & Buffers

### Buffers

- List buffers  
  `:ls` or `:buffers`

- Switch to buffer by number  
  `:b <number>` or `:buffer <number>`

- Switch to buffer by name  
  `:b <name>` (supports tab completion)

- Next buffer  
  `:bn` or `:bnext`

- Previous buffer  
  `:bp` or `:bprev`

- First buffer  
  `:bf` or `:bfirst`

- Last buffer  
  `:bl` or `:blast`

- Delete buffer (close file)  
  `:bd` or `:bdelete`

- Delete buffer by number  
  `:bd 3`

- Open new buffer  
  `:e <file>` or `:edit <file>`

- Reload current buffer  
  `:e` or `:edit`

### Buffer Navigation

- Alternate buffer (previous)  
  `Ctrl+^` or `:b#`

- Open file under cursor  
  `gf`

- Jump to tag (definition)  
  `Ctrl+]`

- Jump back  
  `Ctrl+t`

---

## Windows (Splits)

### Creating Splits

- Horizontal split  
  `:split` or `:sp` or `Ctrl+w s`

- Vertical split  
  `:vsplit` or `:vs` or `Ctrl+w v`

- Open file in horizontal split  
  `:sp <file>`

- Open file in vertical split  
  `:vsp <file>`

- New empty split  
  `:new` (horizontal)
  `:vnew` (vertical)

### Navigating Splits

- Move to split (direction)  
  `Ctrl+w h` (left)
  `Ctrl+w j` (down)
  `Ctrl+w k` (up)
  `Ctrl+w l` (right)

- Move to next split  
  `Ctrl+w w`

- Move to previous split  
  `Ctrl+w W`

- Move to top/bottom/left/right split  
  `Ctrl+w t/b/h/l` (with shift)

### Resizing Splits

- Make splits equal size  
  `Ctrl+w =`

- Maximize current split height  
  `Ctrl+w _`

- Maximize current split width  
  `Ctrl+w |`

- Increase height  
  `Ctrl+w +`
  `:resize +5`

- Decrease height  
  `Ctrl+w -`
  `:resize -5`

- Increase width  
  `Ctrl+w >`
  `:vertical resize +5`

- Decrease width  
  `Ctrl+w <`
  `:vertical resize -5`

- Set height  
  `:resize 30`

- Set width  
  `:vertical resize 80`

### Managing Splits

- Close current split  
  `:q` or `Ctrl+w c`

- Close all other splits  
  `Ctrl+w o` or `:only`

- Rotate splits  
  `Ctrl+w r` (rotate down/right)
  `Ctrl+w R` (rotate up/left)

- Move split to new tab  
  `Ctrl+w T`

---

## Tabs

### Creating Tabs

- New tab  
  `:tabnew` or `:tabe`

- Open file in new tab  
  `:tabnew <file>`

- Open file in new tab (edit)  
  `:tabe <file>`

### Navigating Tabs

- Next tab  
  `gt` or `:tabn` or `:tabnext`

- Previous tab  
  `gT` or `:tabp` or `:tabprev`

- First tab  
  `:tabfirst` or `:tabr`

- Last tab  
  `:tablast`

- Go to tab N  
  `Ngt` (e.g., `3gt` goes to tab 3)

### Managing Tabs

- Close current tab  
  `:tabclose` or `:tabc`

- Close all other tabs  
  `:tabonly` or `:tabo`

- Move tab to position N  
  `:tabm N` (0 = first, $ = last)

- List all tabs  
  `:tabs`

---

## Folding

### Creating Folds

- Create fold (visual selection)  
  Select with `V`, then `zf`

- Fold by motion  
  `zf<motion>` (e.g., `zf5j` folds 5 lines)

- Fold paragraph  
  `zfap`

- Fold inside braces  
  `zfi{`

### Using Folds

- Toggle fold  
  `za`

- Open fold  
  `zo`

- Close fold  
  `zc`

- Open all folds  
  `zR`

- Close all folds  
  `zM`

- Open folds recursively  
  `zO`

- Close folds recursively  
  `zC`

- Delete fold  
  `zd`

- Delete all folds  
  `zD`

### Fold Navigation

- Move to next fold  
  `zj`

- Move to previous fold  
  `zk`

---

## Indentation

### Manual Indenting

- Indent line right  
  `>>` (in normal mode)

- Indent line left  
  `<<`

- Indent N lines  
  `N>>` (e.g., `5>>`)

- Indent in visual mode  
  Select with `V`, then `>` or `<`

- Repeat indentation  
  `.` (dot command)

### Auto Indenting

- Auto-indent current line  
  `==`

- Auto-indent N lines  
  `N==`

- Auto-indent entire file  
  `gg=G`

- Auto-indent inside braces  
  `=i{`

- Auto-indent visual selection  
  Select with `V`, then `=`

### Indent Settings

- Set tab width  
  `:set tabstop=4`

- Set indent width  
  `:set shiftwidth=4`

- Use spaces instead of tabs  
  `:set expandtab`

- Show tabs visually  
  `:set list`

---

## Registers

### Named Registers

- Yank to register  
  `"<reg>y` (e.g., `"ay` yanks to register 'a')

- Paste from register  
  `"<reg>p` (e.g., `"ap`)

- View registers  
  `:reg` or `:registers`

### Special Registers

- `"` - unnamed (last yank/delete)
- `0` - last yank
- `1-9` - last deletes (1 is most recent)
- `+` - system clipboard
- `*` - primary selection (X11)
- `%` - current filename
- `.` - last inserted text
- `/` - last search pattern
- `:` - last command

### Using System Clipboard

- Copy to clipboard  
  `"+y`

- Paste from clipboard  
  `"+p`

- Copy entire file to clipboard  
  `gg"+yG`

---

## Text Objects

Text objects allow operations on structured text.

### Syntax

- `i` - inner (excludes delimiters)
- `a` - around (includes delimiters)

### Common Text Objects

- Word: `iw` `aw`
- Sentence: `is` `as`
- Paragraph: `ip` `ap`
- Quotes: `i"` `a"` `i'` `a'`
- Parentheses: `i(` `a(` or `i)` `a)`
- Brackets: `i[` `a[` or `i]` `a]`
- Braces: `i{` `a{` or `i}` `a}`
- Angle brackets: `i<` `a<` or `i>` `a>`
- Tags (HTML/XML): `it` `at`

### Examples

```
ciw     " Change inner word
daw     " Delete around word
yi"     " Yank inside quotes
ca{     " Change around braces
dit     " Delete inside HTML tag
vap     " Visual select around paragraph
```

---

## Command Mode

### File Operations

- Edit file  
  `:e <file>` or `:edit <file>`

- Save file  
  `:w` or `:write`

- Save as  
  `:w <newfile>`

- Save and quit  
  `:wq` or `:x`

- Quit without saving  
  `:q!`

- Save all buffers  
  `:wa`

- Quit all  
  `:qa`

### Line Numbers

- Go to line  
  `:N` (e.g., `:42`)

- Show current line number  
  `Ctrl+g`

- Show line numbers  
  `:set number`

- Show relative line numbers  
  `:set relativenumber`

### Execute Commands

- Execute shell command  
  `:!<command>` (e.g., `:!ls`)

- Read output into buffer  
  `:r !<command>` (e.g., `:r !date`)

- Filter lines through command  
  `:<range>!<command>` (e.g., `:1,5!sort`)

- Run command on current line  
  `:.!<command>`

### Range Operations

- Current line  
  `.`

- All lines  
  `%`

- Lines N to M  
  `N,M`

- From current to end  
  `.,$`

- Mark to mark  
  `'a,'b`

Examples:
```
:1,10d          " Delete lines 1-10
:5,10s/old/new/g  " Replace in lines 5-10
:%!sort         " Sort entire file
```

---

## Useful Settings

### Display Settings

- Show line numbers  
  `:set number` or `:set nu`

- Hide line numbers  
  `:set nonumber` or `:set nonu`

- Show relative line numbers  
  `:set relativenumber` or `:set rnu`

- Highlight current line  
  `:set cursorline`

- Highlight current column  
  `:set cursorcolumn`

- Show command in status  
  `:set showcmd`

- Show matching brackets  
  `:set showmatch`

- Enable syntax highlighting  
  `:syntax on`

- Disable syntax highlighting  
  `:syntax off`

### Search Settings

- Highlight search matches  
  `:set hlsearch`

- Incremental search  
  `:set incsearch`

- Case-insensitive search  
  `:set ignorecase`

- Smart case (case-sensitive if uppercase used)  
  `:set smartcase`

### Editing Settings

- Enable auto-indent  
  `:set autoindent`

- Smart indent  
  `:set smartindent`

- Tab width  
  `:set tabstop=4`

- Indent width  
  `:set shiftwidth=4`

- Use spaces instead of tabs  
  `:set expandtab`

- Enable mouse support  
  `:set mouse=a`

- Line wrapping  
  `:set wrap` / `:set nowrap`

- Paste mode (disable auto-indent)  
  `:set paste` / `:set nopaste`

### View Settings

- Show current setting  
  `:set <option>?` (e.g., `:set number?`)

- Show all settings  
  `:set all`

- Show changed settings  
  `:set`

---

## Configuration

### .vimrc File

Your personal Vim configuration file: `~/.vimrc`

Example minimal .vimrc:

```vim
" Basic settings
set number                  " Show line numbers
set relativenumber          " Relative line numbers
set cursorline             " Highlight current line
set tabstop=4              " Tab width
set shiftwidth=4           " Indent width
set expandtab              " Use spaces not tabs
set autoindent             " Auto-indent new lines
set smartindent            " Smart auto-indenting
set hlsearch               " Highlight search
set incsearch              " Incremental search
set ignorecase             " Case-insensitive search
set smartcase              " Smart case search
set showmatch              " Show matching brackets
set mouse=a                " Enable mouse
syntax on                  " Syntax highlighting

" Key mappings
let mapleader = ","        " Set leader key
nnoremap <leader>w :w<CR>  " Save with ,w
nnoremap <leader>q :q<CR>  " Quit with ,q

" Clear search highlight
nnoremap <leader>h :noh<CR>
```

### Applying Changes

- Reload .vimrc  
  `:source ~/.vimrc` or `:so %` (if editing .vimrc)

- Edit .vimrc  
  `:e ~/.vimrc`

---

## Plugins

### Plugin Managers

Popular plugin managers:
- **vim-plug** (recommended)
- Vundle
- Pathogen

### Installing vim-plug

```bash
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

### Using vim-plug

Add to .vimrc:

```vim
call plug#begin('~/.vim/plugged')

" List plugins here
Plug 'tpope/vim-surround'
Plug 'preservim/nerdtree'
Plug 'junegunn/fzf.vim'

call plug#end()
```

Then run:
- `:PlugInstall` - Install plugins
- `:PlugUpdate` - Update plugins
- `:PlugClean` - Remove unused plugins

### Popular Plugins

- **NERDTree** - File explorer
- **fzf.vim** - Fuzzy file finder
- **vim-surround** - Surround text with quotes/brackets
- **vim-commentary** - Comment lines easily
- **vim-airline** - Status bar
- **vim-fugitive** - Git integration
- **coc.nvim** - Intellisense/completion

---

## Troubleshooting

### Common Issues

**Stuck in insert mode**
- Press `Esc` or `Ctrl+[` or `Ctrl+c`

**Can't exit Vim**
- `:q` to quit
- `:q!` to quit without saving
- `:wq` to save and quit

**Swap file exists**
- View swap file differences: `:e` then choose option
- Delete swap file: `rm .filename.swp`
- Recover: `vim -r filename`

**Accidentally in Ex mode (: prompt)**
- Type `:visual` or `:vi` to return to normal mode

**Pasted text is wrongly indented**
- Use paste mode: `:set paste` before pasting
- Turn off after: `:set nopaste`

**Can't save read-only file**
- Force save: `:w!`
- Save with sudo: `:w !sudo tee %`

### Performance

- Disable syntax for large files  
  `:syntax off`

- Show slow syntax items  
  `:syntime on` then `:syntime report`

- Profile Vim startup  
  `vim --startuptime startup.log`

---

## Quick Reference

### Essential Commands

```
# Modes
Esc              # Normal mode
i a o            # Insert modes
v V Ctrl+v       # Visual modes

# Saving and quitting
:w               # Save
:q               # Quit
:wq or :x        # Save and quit
:q!              # Quit without saving

# Movement
h j k l          # Left, down, up, right
w b              # Word forward/backward
0 $              # Line start/end
gg G             # File start/end
Ctrl+d Ctrl+u    # Half page down/up

# Editing
x                # Delete character
dd               # Delete line
dw               # Delete word
u                # Undo
Ctrl+r           # Redo
yy               # Yank (copy) line
p                # Paste

# Search
/pattern         # Search forward
n N              # Next/previous match
*                # Search word under cursor
:%s/old/new/g    # Replace all

# Visual mode
v                # Select characters
V                # Select lines
Ctrl+v           # Select block
```

### Quick Tips

- `.` repeats the last command (very powerful!)
- `Ctrl+g` shows file info and line position
- `:help <topic>` opens built-in help
- `vimtutor` command runs interactive tutorial
- `Ctrl+o` jumps to previous location
- `gf` opens file under cursor
- `%` jumps to matching bracket
- `Ctrl+a` / `Ctrl+x` increment/decrement numbers

---
