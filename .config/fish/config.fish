if status is-interactive
    # No greeting
    set fish_greeting

    # Aliases
    # clear screen + scrollback (default `clear` only clears the visible region)
    alias clear "printf '\033[2J\033[3J\033[1;1H'"
    alias celar "printf '\033[2J\033[3J\033[1;1H'"
    alias claer "printf '\033[2J\033[3J\033[1;1H'"
    if command -v eza &>/dev/null
        alias ls 'eza --icons'
    end
end
