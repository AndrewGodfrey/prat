# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in the 'prat' repository.

## Style

- Markdown files: wrap lines at 120 characters max. Break at natural phrase boundaries
  for readability (like this).

## Prat module pattern

When adding an exported function to a prat module (Installers, PratBase, TextFileEditor):
1. Create/edit the `.ps1` file
2. Dot-source it in the `.psm1`
3. Add the function name to `FunctionsToExport` in the `.psd1` ← easy to forget

