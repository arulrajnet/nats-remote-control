#!/bin/bash
set -x
cmd="subscribe \">\""
read -r -a args <<< "$cmd"
echo "${args[@]}"
