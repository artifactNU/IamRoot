# Pandoc – Markdown to PDF

This snippet is a simple and reliable way to convert Markdown files into PDF format using **Pandoc** and **XeLaTeX**.

**Dependencies:**
pandoc, texlive-xetex, fonts-dejavu-core

---

## Markdown → PDF (XeLaTeX)

```sh

pandoc <input>.md \
  -o <output>.pdf \
  --pdf-engine=xelatex \
  -V monofont="DejaVu Sans Mono"

```