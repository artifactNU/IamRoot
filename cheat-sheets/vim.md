# Vim Cheat Sheet

Quick reference for common Vim operations.

---

## Modes

- Normal — navigation and commands (default)
- Insert — text insertion (`i`, `a`, `o`)
- Visual — text selection (`v`, `V`, `Ctrl+v`)
- Command — ex commands (`:`)

Return to Normal mode from anywhere with `Esc`.

---

## Starting and Exiting

- Open file  
  `vim <file>`

- Quit  
  `:q`

- Quit without saving  
  `:q!`

- Save  
  `:w`

- Save and quit  
  `:wq` or `ZZ`

---

## Basic Movement

- Left / Down / Up / Right  
  `h` `j` `k` `l`

- Start / end of line  
  `0` `$`

- Beginning / end of file  
  `gg` `G`

- Word forward / backward  
  `w` `b`

- Paragraph forward / backward  
  `{` `}`

---

## Insert Mode

- Insert before cursor  
  `i`

- Insert after cursor  
  `a`

- Insert at start of line  
  `I`

- Insert at end of line  
  `A`

- Open new line below / above  
  `o` `O`

---

## Editing

- Delete character  
  `x`

- Delete word  
  `dw`

- Delete line  
  `dd`

- Delete to end of line  
  `D`

- Change word  
  `cw`

- Change line  
  `cc`

- Undo / redo  
  `u` `Ctrl+r`

---

## Copy & Paste (Yank & Put)

- Yank line  
  `yy`

- Yank word  
  `yw`

- Paste after cursor  
  `p`

- Paste before cursor  
  `P`

---

## Visual Mode

- Visual (character)  
  `v`

- Visual (line)  
  `V`

- Visual (block)  
  `Ctrl+v`

Common actions in visual mode:
- Yank selection: `y`
- Delete selection: `d`
- Indent right / left: `>` `<`

---

## Search

- Search forward  
  `/pattern`

- Search backward  
  `?pattern`

- Next / previous match  
  `n` `N`

- Clear search highlight  
  `:noh`

---

## Replace

- Replace first match on line  
  `:s/old/new`

- Replace all matches on line  
  `:s/old/new/g`

- Replace in entire file  
  `:%s/old/new/g`

- Confirm each replacement  
  `:%s/old/new/gc`

---

## Multiple Files & Buffers

- List buffers  
  `:ls`

- Switch to buffer  
  `:b <number>`

- Next / previous buffer  
  `:bn` `:bp`

---

## Windows (Splits)

- Horizontal split  
  `:split` or `Ctrl+w s`

- Vertical split  
  `:vsplit` or `Ctrl+w v`

- Move between splits  
  `Ctrl+w h/j/k/l`

- Close split  
  `Ctrl+w c`

---

## Tabs

- New tab  
  `:tabnew`

- Next / previous tab  
  `gt` `gT`

- Close tab  
  `:tabclose`

---

## Useful Settings (Temporary)

- Show line numbers  
  `:set number`

- Show relative numbers  
  `:set relativenumber`

- Enable syntax highlighting  
  `:syntax on`

---

## Emergency Commands

- Exit Vim when things go wrong  
  `Esc Esc :q!`

- Recover swap file  
  `vim -r <file>`

---
