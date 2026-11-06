function _fzf_search_history --description "Search command history. Replace the command line with the selected command."
    # history merge incorporates history changes from other fish sessions
    # it errors out if called in private mode
    if test -z "$fish_private_mode"
        builtin history merge
    end

    if not set --query fzf_history_time_format
        # Reference https://devhints.io/strftime to understand strftime format symbols
        set -f fzf_history_time_format "%m-%d %H:%M:%S"
    end

    if not set --query fzf_history_separator
        # Delineates the time from the command in each history entry. It may be longer than one
        # character and it may contain ANSI escape codes to color it, which fzf will only render
        # if --ansi is in fzf_history_opts.
        set -f fzf_history_separator " │ "
    end

    # Delinate time from command in history entries using the separator. Then, to get raw command
    # from history entries, delete everything up to it. The ? on regex is necessary to make regex
    # non-greedy so it won't match into commands containing the separator. Escape codes are left
    # out of the match because fzf doesn't include them in its output, but they are eaten if it did.
    set -f separator_escape_regex '\x1b\[[0-9;]*[A-Za-z]'
    set -f plain_separator (string replace --regex --all $separator_escape_regex '' -- $fzf_history_separator)
    if test -z "$plain_separator"
        # there is no visible char to anchor the regex on, so ignore the custom separator
        set -f fzf_history_separator " │ "
        set -f plain_separator " │ "
    end
    set -f time_prefix_regex '^.*?'(string escape --style=regex -- $plain_separator)'(?:'$separator_escape_regex')*'
    # Delinate commands throughout pipeline using null rather than newlines because commands can be multi-line
    set -f commands_selected (
        builtin history --null --show-time="$fzf_history_time_format$fzf_history_separator" |
        _fzf_wrapper --read0 \
            --print0 \
            --multi \
            --scheme=history \
            --prompt="History> " \
            --query=(commandline) \
            --preview="string replace --regex '$time_prefix_regex' '' -- {} | fish_indent --ansi" \
            --preview-window="bottom:3:wrap" \
            $fzf_history_opts |
        string split0 |
        # remove timestamps from commands selected
        string replace --regex $time_prefix_regex ''
    )

    if test $status -eq 0
        commandline --replace -- $commands_selected
    end

    commandline --function repaint
end
