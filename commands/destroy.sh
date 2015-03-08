#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: TODO

function _command_name {
  #opt_string=":a"
  #while getopts $opt_string opt; do
    #case $opt in
      #a)
        #echo "-a was triggered!" >&1
        #;;
      #\?)
        #echo "Invalid option: -$OPTARG" >&2
        #exit $errorcode_invalid_args
        #;;
    #esac
  #done

  # Fail without any arguments
  if [ $# -eq 0 ]; then
    usage update
    exit ${error[
o_args]}
  fi
}
