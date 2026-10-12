#!/bin/bash
# Switch the NVIDIA dGPU's compute mode off, properly.
#  - A unit left in "failed" state ignores `systemctl stop`, so bring it back to active first.
#  - Browsers open the card as soon as it appears (their GPU helper process), and the disable
#    script refuses while anything holds it. Those helpers restart on their own, so close them.
#    Anything else holding the card (a real GPU job) is left alone and reported.
u=dgpu-compute.service
holders() { for p in /proc/[0-9]*; do ls -l "$p/fd" 2>/dev/null | grep -q '/dev/nvidia' && echo "${p#/proc/}"; done; }

for try in 1 2 3 4; do
    systemctl reset-failed "$u" 2>/dev/null
    systemctl is-active -q "$u" || systemctl start "$u" 2>/dev/null
    for h in $(holders); do
        tr '\0' ' ' < "/proc/$h/cmdline" 2>/dev/null | grep -q -- '--type=gpu-process' && kill "$h" 2>/dev/null
    done
    sleep 0.15
    systemctl stop "$u" 2>/dev/null
    sleep 1.5
    [ "$(/usr/local/sbin/dgpu-status 2>/dev/null)" = off ] && exit 0
done

names=$(for h in $(holders); do cat "/proc/$h/comm" 2>/dev/null; done | sort -u | paste -sd, - | sed 's/,/, /g')
if [ -n "$names" ]; then echo "Still in use by: $names. Close it and try again." >&2
else journalctl -u "$u" -n 6 --no-pager 2>/dev/null | grep -o 'ERROR:.*' | tail -n1 >&2; fi
exit 1
