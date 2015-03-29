#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Print version

# Purpose: Print cms-manager version
# Arguments:
#   None
function version {
  msg "$(sed -n 2p "$self_dir/README.md")"
}
