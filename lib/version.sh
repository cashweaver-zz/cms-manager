#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Print version

function version {
  msg "$(sed -n 2p "$self_dir/README.md")"
}
