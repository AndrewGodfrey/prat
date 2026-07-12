---
name: windows-edit-recovery
description: Use when an Edit call just failed (string-not-found), when undoing an edit you just
  made, or before bulk edits in a Windows-hosted (CRLF) repo — a token rename across files,
  replace_all, or a large multi-line replacement.
---

CRLF line endings make Edit-tool string matching and pwsh text replacement unreliable. Known failure
modes and recovery recipes:

To undo an edit you just made: make ONE Edit call, with `old_string` and `new_string` literally
swapped from your prior Edit call as stored in working memory. Do not re-read the file. Do not
reconstruct content from memory. Do not make multiple approximating edits. Reach for git only when
you have specific reason to distrust your working memory (file externally modified, many turns
elapsed, suspect CRLF handling, or your prior edit overlapped other changes you need to preserve).
Don't use `git checkout <file>` — it can wipe accumulated work.

For renaming a token across multiple files, use multiple Edit `replace_all` calls rather than a
single pwsh heredoc with `-replace` + `Set-Content`. The pwsh approach can silently produce no
change on some files (likely CRLF/encoding interaction); Edit is reliable.

Before using `replace_all`, scan the file and confirm every occurrence should be replaced —
string literals, `Describe`/`Context` labels, and comments can all contain the token without
being targets. If any occurrence should be left untouched, use targeted individual Edits instead.

For multi-line string replacements in pwsh scripts, use `.IndexOf()` + `.Substring()` rather than
`.Replace()` with multi-line literals. Single-quoted PS strings don't expand `` `r`n ``, so `.Replace()`
silently fails on CRLF content. Index-based splicing is reliable regardless of line endings.

When replacing a large block of text in a Windows file (CRLF line endings), the Edit tool's
string matching can fail even when the content looks correct — "String to replace not found."
Workaround for large deletions:
1. Insert marker comments using small targeted Edits (short unique strings match reliably):
   - Before the block: `<!-- DELETE_FROM_HERE -->`
   - After the block: `<!-- DELETE_TO_HERE -->`
2. Run the helper script:
   ```bash
   pwsh -File ~/prat/lib/agents/Remove-MarkedBlock.ps1 -Path 'C:/path/to/file.md'
   ```
   Custom markers: add `-From '<!-- MY_START -->' -To '<!-- MY_END -->'`.
