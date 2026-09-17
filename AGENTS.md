# Repository instructions

## Scope and conventions

This repository is VSDeck, a Lua 5.4 configuration for Hammerspoon on macOS.
Read `CONVENTIONS.md` before editing Lua code. Preserve existing user changes,
public action IDs, prompts, keyboard shortcuts and behavior unless the task
explicitly requests changes to them. A planning request does not authorize execution.

## Required completion checks

After changing Lua code or its documentation comments:

1. Run `make format` (StyLua with AST verification).
2. Run `make check` (format verification, Luacheck and offline tests).
3. Inspect the final diff for unintended changes and run `git diff --check`.
4. Fix failures caused by your changes. Do not disable lint rules or remove tests
   merely to obtain a passing result. Explain any pre-existing blocker precisely.
5. Report checks actually executed and any remaining limitations. Never claim
   checks passed when a tool was unavailable or execution was skipped.

Install missing development tools following `CONVENTIONS.md`; do not silently
skip formatting or linting. For documentation-only Markdown edits, validate links
and examples; the Lua suite is only necessary if Lua files or tooling also change.

## README maintenance (required for every change)

Review `README.md` as part of every change, including fixes, refactors and tooling.
Update or add the affected instructions whenever behavior, configuration, commands,
installation, architecture, limitations or usage changes. Remove outdated guidance
in the same change. If the README is still accurate, do not add filler; state that
it was reviewed and no update was needed in the completion report.

README maintenance is part of completion, not an optional follow-up. Before
finishing, report what was updated or why no README change was necessary.

## Documentation and implementation

- Follow the comment and module conventions in `CONVENTIONS.md`.
- Use `modules.i18n` for interface strings; update both locale catalogs.
- Route notifications through `modules.notifications`.
- Keep installation-specific values in `~/.config/hammerspoon/personal.lua`.
  Do not read, format or modify that private file unless required by the task.
- Use offline mocks for AWS, Hue, browser automation, clipboard and AI requests.
  Running tests must not create snapshots, change lights or paste into real apps.
- Do not commit, push or publish unless the user asks for those actions.
