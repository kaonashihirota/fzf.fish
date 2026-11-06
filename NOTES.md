# Fork notes

Local fork of [PatrickF1/fzf.fish](https://github.com/PatrickF1/fzf.fish) for
`kaonashihirota`. Two small, independent, upstream-able commits on top of
`6a61369`. Everything below is what was learned while making them, so it
doesn't have to be rediscovered.

## Commits

| Commit    | Change                                                                 |
| --------- | ---------------------------------------------------------------------- |
| `a9fa14a` | `_fzf_search_history`: separator configurable via `fzf_history_separator` |
| `17932fa` | `_fzf_preview_file`: use fzf's `fzf-preview.sh` when available (images)   |

Both touch the function, `README.md`, and add one test file. Cherry-pickable
individually.

## 1. History separator (`a9fa14a`)

Before: `_fzf_search_history` appended the literal `" │ "` after
`$fzf_history_time_format` and matched `'^.*? │ '`. Nothing in the config
surface could reach it.

Problem this caused: with only `fzf_history_time_format`, the separator can
never be styled. Any SGR opened in the format also colours the command text
(it comes after), and any reset leaves the separator unstyled.

After:

```fish
set -g fzf_history_time_format (string unescape '\e[2m%m-%d %H:%M:%S\e[0m')
set -g fzf_history_separator (string unescape '\e[2m │ \e[0m')  # may contain ANSI
set -g fzf_history_opts --ansi                                  # needed to render it
```

Implementation details:

- `fzf_history_separator` defaults to `" │ "`, so existing behaviour is intact.
- The match pattern is built from the *plain* separator, i.e. ANSI escapes are
  stripped first, because fzf strips them from its output.
- Pattern is `^.*?<escaped separator>(?:\x1b\[[0-9;]*[A-Za-z])*`: non-greedy so
  commands containing the separator survive, and the trailing group eats a
  reset code in case fzf ever hands escapes back.
- Separator is regex-escaped with `string escape --style=regex`, so `|`, `::`,
  tabs, etc. all work.
- A separator with no visible character (ANSI only) falls back to the default;
  otherwise the non-greedy anchor would match nothing and stripping would break.

Gotcha worth remembering: **fish does not expand `\e` inside quotes** (single or
double), which is why `"\e[2m"` prints literally. Use `string unescape` or
`printf '%b'`.

## 2. Image previews (`17932fa`)

- fzf 0.74 has experimental Kitty/Sixel preview support in the binary
  (`isImagePassThrough`, `wrapPassThrough`, `makeImageBorder`). It also wraps a
  raw Kitty APC for tmux itself, so both raw and `\ePtmux;`-wrapped output work.
- fzf ships `fzf-preview.sh` inside its own keg (Homebrew:
  `/opt/homebrew/Cellar/fzf/<version>/bin/fzf-preview.sh`). It selects
  `kitten icat --unicode-placeholder` on kitty/Ghostty, else `chafa` (sixel),
  else `imgcat` (iTerm2), else `bat` for text, `file` for binaries, and sizes
  the image from `FZF_PREVIEW_COLUMNS`/`FZF_PREVIEW_LINES`.
- `_fzf_preview_file` now calls it when it is on `PATH`, keeping `bat` (and
  `fzf_preview_file_cmd`) precedence intact. No new dependency: installs without
  the script behave exactly as before.
- `fzf-preview.sh` uses `--unicode-placeholder`, so the image is attached to
  `U+10EEEE` placeholder cells that fzf prints as text. That is the mechanism
  that makes it work through fzf's text-only preview renderer.

Requirements and caveats:

- Kitty protocol inside tmux needs `set -g allow-passthrough on`.
- `kitten icat --place` needs the terminal to report cell pixel size
  (Ghostty/kitty/WezTerm do; a bare xterm does not).
- Fallback that works anywhere, if a terminal has no graphics support:
  `chafa --format=symbols --colors=full --polite=on --size=WxH -- FILE`.
  `--polite=on` matters: without it chafa emits `\e[?25l`/`\e[?25h`, which ends
  up in fzf's preview buffer.
- Not covered: PDFs (`application/pdf` goes to `bat`).

## How this was verified

- Separator: `history --show-time` passes ESC through; the strip regex returns
  bare commands for ` │ `, `·`, `|`, tab, `::`, ANSI-styled and ANSI-only
  separators; real `fzf` runs (via `--filter`) through the function.
- Previews: in tmux 3.7b + `allow-passthrough on` + Ghostty, `_fzf_preview_file`
  on a PNG emits `\ePtmux;`-wrapped `\e_Ga=T,…` plus 9 rows of `U+10EEEE`;
  text files still go through `bat`; removing `fzf-preview.sh` from `PATH`
  falls back to `bat`.
- `fish --no-execute` and `fish_indent --check` clean on all touched files.
- `fishtape`, `clownfish` and `prettier` are not installed on this machine, so
  the suites were exercised through a shim reproducing `mock`/`@test`; CI
  (`fishtape tests/*/*.fish`, `fish-actions/format-check`, `prettier --check`)
  remains the real gate.

## Rejected approaches

- Patching the plugin file text at startup and `source`ing it: no shorter,
  silently no-ops if upstream reformats the line, and leaves a stray `\e[0m`
  on the selected command unless the strip regex is patched too.
- Copying `_fzf_search_history` into dotfiles as an override: worked, but it
  was ~50 lines to maintain for one hardcoded literal; the knob in the fork
  replaced it.
- Colouring the whole history line with fzf `--color=fg:…`: only option without
  a fork, but recolours the timestamp and command too.
- `--delimiter=' │ ' --with-nth=2..`: hides the timestamp entirely, zero code,
  but not what was wanted.

## Upstreaming

Both commits are small, documented and tested. `a9fa14a` exposes an existing
hardcoded literal; `17932fa` prefers a script that fzf itself ships and degrades
gracefully. Offered upstream as-is.
