set fish_history test
set history_file_path ~/.local/share/fish/test_history
printf "%s" "- cmd: echo hello
  when: 1612201487
- cmd: echo 'lots of │ chars
  when: 1612201488" >$history_file_path

mock commandline "--replace --" "echo \$argv"
mock commandline \* ""
set --export --append FZF_DEFAULT_OPTS "--filter=hello"

set --export fzf_history_separator " :: "
set actual (_fzf_search_history)
@test "strips a custom separator" "$actual" = "echo hello"

set --export fzf_history_separator (string unescape '\e[2m │ \e[0m')
set --export --append FZF_DEFAULT_OPTS --ansi
set actual (_fzf_search_history)
@test "strips a colored separator without leaving escape codes" "$actual" = "echo hello"

set --export fzf_history_separator (string unescape '\e[2m\e[0m')
set actual (_fzf_search_history)
@test "falls back to the default separator if it has no visible characters" "$actual" = "echo hello"

rm $history_file_path
