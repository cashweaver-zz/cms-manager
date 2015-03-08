#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Print usage information

function all_usages {
  echo "$(basename $0) [options] [commands]" >&2
  echo "Options" >&2
  echo "  --quiet             Be quiet. Less output." >&2
  echo "  -q" >&2
  echo "" >&2
  echo "  --version           Print version" >&2
  echo "  -v" >&2
  echo "" >&2
  echo "Commands:" >&2
  for usage_file in $self_dir/lib/usage/*; do
    # Print command name and definition
    echo "  $(sed -n 1p $usage_file)" >&2
    # Print command description
    echo "  $(sed -n 2p $usage_file)" >&2

    echo "" >&2
  done
}

function usage {
  echo "" >&2
  if [[ $# -ne 1 ]]; then
    all_usages
  else
    if [[ -f "$self_dir/lib/usage/$1.md" ]];then
      echo -n "$(basename ${0}) " >&2
      cat "$self_dir/lib/usage/$1.md" >&2
    else
      all_usages
    fi
  fi
  echo "" >&2
}
