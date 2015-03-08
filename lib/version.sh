#!/usr/bin/env bash
# Description:
# Print version of the script

function version {
  msg "$(sed -n 4p "$self_dir/README.md")"
}
