---
description: 'Find and fix missing or incorrect type hints using mypy'
agent: 'agent'
tools: ['run_terminal', 'read', 'edit', 'search/codebase']
---

Find and fix all missing or incorrect type hints in `${input:target:src/ or a specific file/module path}`.

## Rules

- **Prefer built-in types** over `typing` equivalents:
  - `list[...]` not `List[...]`, `dict[...]` not `Dict[...]`, `tuple[...]` not `Tuple[...]`, `set[...]` not `Set[...]`, `type[...]` not `Type[...]`
  - `X | Y` not `Union[X, Y]`, `X | None` not `Optional[X]`
  - These built-in generics are available from Python 3.10+; this project targets Python 3.12.
- **Fix the root cause** — add or correct the type annotation. Do not suppress errors with `# type: ignore` comments unless the issue is a known third-party stub limitation with no other solution, in which case add a brief inline comment explaining why.
- **Do not change runtime behavior** — only change type annotations, imports, and (if needed) narrow types with `assert` or `isinstance` guards where the type truly is ambiguous.
- Remove unused imports from `typing` that become unnecessary after the fixes.

## Steps

1. **Run mypy** on the target path from the workspace root to get the full list of errors:
   ```
   uv run mypy ${input:target:src/ or a specific file/module path}
   ```
2. **Read each file** that has errors reported by mypy.
3. **Fix every error** following the rules above. Group edits by file.
4. **Re-run mypy** after all edits to confirm the error count is zero (or only contains pre-existing `# type: ignore` suppressions with explanatory comments).
5. If re-running mypy reveals new errors introduced by the fixes, resolve them before finishing.

## Output

After all fixes are applied, provide a brief summary:
- Total errors fixed
- Files changed
- Any errors intentionally left with `# type: ignore` and the reason why

