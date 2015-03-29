#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Print the status of CMS core and plugins

# Purpose: Print the status of a given CMS core and its plugins
# Arguments:
#   None
function check_status {
  # 1. Collect and test arguments
  # 2. Check status of plugins and core

  #=============================================================================
  #===  1. Collect and test arguments
  #=============================================================================

  local options=":w:"

  local website_path=""
  while getopts "$options" o; do
    case "${o}" in
      w)
        website_path="${OPTARG%/}"
        ;;
      *)
        echo "${o}"
        usage status
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Evaluate arguments
  #   1. website_path must be set
  #   2. website_path must be:
  #     2a. a directory
  #     2b. a valid CMS root


  # 1. website_path must be set
  if [[ -z "$website_path" ]]; then
    msg "ERROR" "Missing path to website"
    usage status
    exit "${error[missing_required_args]}"
  fi

  # 2a. website_path must be a directory
  if [[ ! -d "$website_path" ]]; then
    msg "ERROR" "Website path ($website_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 2b. website_path must be a valid CMS root
  local website_type=""
  get_website_type "$website_path" website_type
  # Errors are handled within get_website_type.

  #=============================================================================
  #===  2. Check status of plugins and core
  #=============================================================================

  msg "COMMENT" "$website_type website detected. Checking for available updates..."
  case "$website_type" in
    Drupal)
      _status_drupal "$website_path"
      ;;
    WordPress)
      _status_wordpress "$website_path"
      ;;
  esac
}

# Purpose: Print the status of Drupal core and modules
# Arguments:
#   1. website_path
function _status_drupal {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_status_drupal takes one argument:"
    msg "ERROR" "  website_path: The full path to the directory to be backed up"
    exit "${error[wrong_number_of_args]}"
  fi

  local website_path="$1"

  cd $website_path
  drush pm-updatestatus
}

# Purpose: Print the status of WordPress core and plugins
# Arguments:
#   1. website_path
function _status_wordpress {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_status_wordpress takes one argument:"
    msg "ERROR" "  website_path: The full path to the directory to be backed up"
    exit "${error[wrong_number_of_args]}"
  fi

  local website_path="$1"

  cd $website_path
  wp core check-update
  wp plugin status
}
