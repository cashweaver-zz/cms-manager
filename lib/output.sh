#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Handle output to stdout and stderr

reset_all="\033[0m"
reset_bold="\033[21m"
bold="\033[1m"

black="\033[0;30m"
dark_gray="\033[1;30m"
blue="\033[0;34m"
light_blue="\033[1;34m"
green="\033[0;32m"
light_green="\033[1;32m"
cyan="\033[0;36m"
light_cyan="\033[1;36m"
red="\033[0;31m"
light_red="\033[1;31m"
purple="\033[0;35m"
light_purple="\033[1;35m"
brown="\033[0;33m"
yellow="\033[1;33m"
light_gray="\033[0;37m"
white="\033[1;37m"

# Purpose: Format and print a given message
# Arguments:
#   1. message_type
#   2. message
function msg {
if [[ $quiet = "false" ]]; then
  if [[ $# -eq 2 ]]; then
    case $1 in
      ERROR )
        echo -e "$light_red$2$reset_all" >&2
        ;;
      PROMPT )
        echo -en "$light_cyan$2$reset_all"
        ;;
      COMMENT )
        echo -e "$yellow$2$reset_all"
        ;;
      SUCCESS )
        echo -e "$light_green$2$reset_all"
        ;;
      PLAIN )
        echo -e "$white$1$reset_all"
        ;;
      * )
        echo -e "$2"
        ;;
    esac
  else
    echo "$1"
  fi
fi
}

# test all colors
# Comment this section out while not testing.
#message="Here's some text in a special color!"
#echo -e "black: $black$message$reset_all"
#echo -e "dark_gray: $dark_gray$message$reset_all"
#echo -e "blue: $blue$message$reset_all"
#echo -e "light_blue: $light_blue$message$reset_all"
#echo -e "green: $green$message$reset_all"
#echo -e "light_green: $light_green$message$reset_all"
#echo -e "cyan: $cyan$message$reset_all"
#echo -e "light_cyan: $light_cyan$message$reset_all"
#echo -e "red: $red$message$reset_all"
#echo -e "light_red: $light_red$message$reset_all"
#echo -e "purple: $purple$message$reset_all"
#echo -e "light_purple: $light_purple$message$reset_all"
#echo -e "brown: $brown$message$reset_all"
#echo -e "yellow: $yellow$message$reset_all"
#echo -e "light_gray: $light_gray$message$reset_all"
#echo -e "white: $white$message$reset_all"
