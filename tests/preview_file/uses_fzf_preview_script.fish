set --query fzf_preview_file_cmd; and set --erase fzf_preview_file_cmd

set fake_bin (mktemp -d)
set fake_preview_script $fake_bin/fzf-preview.sh
printf '#!/bin/sh\necho "previewed $1"\n' >$fake_preview_script
chmod +x $fake_preview_script

set original_path $PATH
set --prepend PATH $fake_bin

set actual (_fzf_preview_file "tests/_resources/multi word dir/file 1.txt")
@test "previews regular files with fzf-preview.sh when it is available" "$actual" = "previewed tests/_resources/multi word dir/file 1.txt"

set PATH $original_path
rm -r $fake_bin
