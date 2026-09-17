# Lua conventions

## Development tools

Use Lua 5.4, StyLua 2.5.2 and Luacheck 1.2.0. Node.js and Python 3 run the existing
HTML-panel and snapshot contract tests. Hammerspoon itself is not required for
these offline tests.

On macOS:

```sh
brew install lua stylua luacheck
make format
make check
```

`make format` formats project Lua files and verifies that StyLua preserves their
AST. `make check` checks formatting, runs Luacheck, and runs all offline tests.
The configuration files are `stylua.toml` and `.luacheckrc`. Keep the CI tool
versions aligned when upgrading formatters or linters.

`AGENTS.md` makes these commands part of the agent workflow. The GitHub workflow
runs them independently on pushes and pull requests. Enforcing a merge gate also
requires marking the `Lua quality` job as required in the repository's branch
protection/ruleset; a Markdown file alone cannot guarantee compliance by every tool.
Other agents that do not recognize `AGENTS.md` should be explicitly directed to it.

## Formatting and code structure

- Two spaces, LF line endings and single quotes where practical; let StyLua decide
  wrapping and punctuation. Do not hand-format against its output.
- Use `local` by default and return a module table. Hammerspoon supplies `hs`;
  other accidental globals are lint errors.
- Keep dependencies and module state at the top, private helpers next, then the
  public API. Retain timers/tasks/UI objects for their full asynchronous lifetime.
- Use `_` or `_name` for deliberately unused callback parameters. Fix unused
  locals instead of globally suppressing their warnings.
- Preserve function signatures used by Hammerspoon callbacks and browser adapters.
- Keep user-facing text in both locale catalogs and use named parameters for
  dynamic messages. Prompts and external protocol/menu identifiers are not UI copy.
- Long prompts and translations may exceed the formatting target. Luacheck does
  not duplicate StyLua's layout checks or force edits to those string contents.

## Comments and API documentation

Write code comments in English, matching existing identifiers and project comments.
Keep user-facing documentation and translations in their intended language.

Start each module with its purpose. Separate meaningful responsibilities with
short `--` comments. Explain *why*: lifecycle ownership, focus checks, external
protocol assumptions, fallback behavior, and asynchronous ordering. Do not narrate
obvious assignments, add an explanation to every line, or describe planned behavior
as though it already exists.

Use LDoc-style `---` comments for public functions. Include `@param` and `@return`
when their shape or meaning is not obvious, especially for tables, callbacks,
acceptance-versus-completion results and side effects. A short summary is enough
for simple lifecycle methods. Document data-only catalogs by logical group rather
than repeating a comment for each translation. LDoc generation is optional; no
runtime documentation dependency is required.

```lua
--- Accept a request for asynchronous execution.
-- @param request Validated request table with ordered URLs.
-- @return true when accepted, or false plus an error message; not completion.
function M.open(request)
  -- Validate before scheduling work so rejection cannot produce partial effects.
end
```

Keep comments accurate as code changes. Tests should identify setup, simulated
behavior and scenarios; comments must explain what regression an assertion catches.

## README maintenance

Review `README.md` for every change. Keep behavior descriptions, configuration
examples, commands, installation steps, architecture, limitations and user flows
aligned with the implementation. Add new guidance, correct changed behavior and
remove obsolete instructions as part of the same change. A change that leaves
reader-facing documentation inaccurate is incomplete even when its tests pass.

For internal changes that do not affect the README, record that it was reviewed
and remains accurate; do not introduce unrelated edits merely to touch the file.
The completion report must mention either the documentation update or this review.

## Verification boundaries

Tests replace Hammerspoon APIs and personal configuration with fixtures. Do not
connect to AWS, LM Studio, Hue or real browsers from automated tests. Interactive
confirmation dialogs are not ordinary notifications and must retain their guards.

Formatting/comment changes should preserve runtime behavior and prompt contents.
When lint reveals a real behavioral issue, make a focused fix with a relevant test
and call it out rather than hiding it in a formatting change.

## References

- [Codex repository instructions](https://developers.openai.com/codex/guides/agents-md)
- [StyLua](https://github.com/JohnnyMorganz/StyLua)
- [Luacheck configuration](https://luacheck.readthedocs.io/en/stable/config.html)
- [LDoc comments](https://github.com/lunarmodules/ldoc/blob/master/manual.md)
