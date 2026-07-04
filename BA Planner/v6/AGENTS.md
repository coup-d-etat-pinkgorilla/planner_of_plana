# Agent Instructions

## Windows Editing

- When editing files, use the built-in `apply_patch` tool instead of invoking `apply_patch` through PowerShell or any shell command.
- Do not run shell-based `apply_patch` wrappers on Windows. They can fail under sandbox path and permission checks.

## Korean Text And Encoding

- Korean document content is allowed and preferred when the user asks for Korean text.
- PowerShell mojibake is a console display issue, not a reason to replace Korean content with ASCII-only text.
- Preserve UTF-8 Korean text in source files, Markdown, JSON, and generated documents.
- When Korean output appears broken in the console, verify the actual file content with UTF-8-aware reads, rendered documents, PDFs, screenshots, or application-level inspection instead of rewriting the wording in ASCII.
- Use ASCII explanations only when the user explicitly asks for ASCII-only content or when the target format truly cannot store Unicode.
