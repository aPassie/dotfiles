# Shell integration for foot.
#
# Emits OSC sequences that foot uses to:
#   - Mark prompt / command / output boundaries (OSC 133)
#       → enables Ctrl+Shift+Z / Ctrl+Shift+X "jump to previous/next prompt"
#       → makes scrollback search semantic
#   - Track current working directory (OSC 7)
#       → "new window in same directory" works correctly
#   - Fire desktop notifications when a long command finishes (OSC 777)

if not status is-interactive
    exit
end

# OSC 7 — current working directory
set -g __foot_host (cat /etc/hostname 2>/dev/null; or echo localhost)
function __foot_osc7 --on-variable PWD
    printf '\e]7;file://%s%s\e\\' $__foot_host (string escape --style=url -- $PWD)
end
__foot_osc7

# OSC 133 — prompt / command / output boundaries
set -g __foot_cmd_start_time 0
set -g __foot_last_cmd ''
set -g __foot_long_cmd_threshold 8  # seconds before a notification fires

function __foot_pre_prompt --on-event fish_prompt
    set -l exit_code $status
    if test $__foot_cmd_start_time -gt 0
        set -l elapsed (math (date +%s) - $__foot_cmd_start_time)
        printf '\e]133;D;%d\e\\' $exit_code
        if test $elapsed -ge $__foot_long_cmd_threshold -a -n "$__foot_last_cmd"
            # OSC 777 notify (foot maps to org.freedesktop.Notifications)
            set -l title 'Command finished'
            test $exit_code -ne 0; and set title 'Command failed'
            printf '\e]777;notify;%s;%s (%ds)\e\\' "$title" "$__foot_last_cmd" $elapsed
        end
        set __foot_cmd_start_time 0
        set __foot_last_cmd ''
    end
    printf '\e]133;A\e\\'
end

function __foot_preexec --on-event fish_preexec
    printf '\e]133;C\e\\'
    set __foot_cmd_start_time (date +%s)
    set __foot_last_cmd "$argv[1]"
end
