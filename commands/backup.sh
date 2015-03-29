#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Create a backup of files and the database

# Purpose: Backup a given website
# Arguments:
#   None
function backup {
  # 1. Collect and test arguments
  # 2. Attempt to create backup
  # 3. Handle errors, and print success/error messages

  #=============================================================================
  #===  1. Collect and test arguments
  #=============================================================================

  local options=":w:s:"

  local website_path=""
  local save_dir=""
  while getopts "$options" o; do
    case "${o}" in
      w) website_path="${OPTARG}" ;;
      s) save_dir="${OPTARG%/}" ;;
      *)
        usage backup
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))


  # Evaluate arguments
  #   1. save_dir and website_path must be set
  #   2. save_dir must be:
  #     2a. a directory
  #     2b. writable by the executing user
  #   3. website_path must be:
  #     3a. a directory
  #     3b. a valid CMS root

  # 1. save_dir and website_path must be set
  if [[ -z "$save_dir" ]]; then
    msg "ERROR" "Missing save directory"
    usage backup
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$website_path" ]]; then
    msg "ERROR" "Missing path to website"
    usage backup
    exit "${error[missing_required_args]}"
  fi

  # 2a. save_dir must be a directory
  if [[ ! -d "$save_dir" ]]; then
    msg "ERROR" "Save directory ($save_dir) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 2b. save_dir must be a writable by the executing user
  local write_permissions=""
  check_for_write_permissions "$save_dir" "$(whoami)" write_permissions
  if [[ "$write_permissions" = "false" ]]; then
    msg "ERROR" "Save directory ($save_dir) is not writable by $(whoami)"
    exit "${error[bad_arg]}"
  fi

  # 3a. website_path must be a directory
  if [[ ! -d "$website_path" ]]; then
    msg "ERROR" "Website path ($website_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 3b. website_path must be a valid CMS root
  local website_type=""
  get_website_type "$website_path" website_type
  # Errors are handled within get_website_type.


  #=============================================================================
  #===  2. Attempt to create backup
  #===  3. Handle errors, and print success/error messages
  #=============================================================================

  msg "COMMENT" "$website_type website detected. Creating backup..."
  case "$website_type" in
    Drupal)
      _backup_drupal "$save_dir" "$website_path"
      ;;
    WordPress)
      _backup_wordpress "$save_dir" "$website_path"
      ;;
  esac
}


# TODO
# Purpose: Backup a given Drupal website
# Arguments:
#   1. save_dir
#   2. website_path
function _backup_drupal {
  if [[ $# -ne 2  ]]; then
    msg "ERROR" "_backup_drupal takes two arguments:"
    msg "ERROR" "  save_dir: The full path to the directory save the backup"
    msg "ERROR" "  website_path: The full path to the directory to be backed up"
    exit "${error[wrong_number_of_args]}"
  fi

  local save_dir="$1"
  local website_path="$2"

  local backup_destination="$save_dir/$(date "+%Y%m%d-%H%M%S").tar.gz"

  cd $website_path
  drush cc all >/dev/null 2>&1
  drush archive-dump --destination=$backup_destination >/dev/null 2>&1

  if [[ ! -f $backup_destination ]]; then
    msg "ERROR" "Error saving backup archives:"
    msg "ERROR" "    $backup_destination"
    exit "${error[command_failed]}"
  else 
    msg "SUCCESS" "Backup archive saved as:"
    msg "SUCCESS" "    $backup_destination"
  fi
}

# TODO
# Purpose: Backup a given WordPress website
# Arguments:
#   1. save_dir
#   2. website_path
function _backup_wordpress {
  if [[ $# -ne 2  ]]; then
    msg "ERROR" "_backup_wordpress takes two arguments:"
    msg "ERROR" "  save_dir: The full path to the directory save the backup"
    msg "ERROR" "  website_path: The full path to the directory to be backed up"
    exit "${error[wrong_number_of_args]}"
  fi

  local save_dir="$1"
  local website_path="$2"

  local file_backup_destination="$save_dir/$(date "+%Y%m%d-%H%M%S").tar.gz"
  local sql_backup_destination="$save_dir/$(date "+%Y%m%d-%H%M%S").sql"

  cd "$website_path"
  wp db export $sql_backup_destination >/dev/null 2>&1
  tar -cvzf $file_backup_destination * >/dev/null 2>&1

  if [[ ! -f $file_backup_destination  ||  ! -f $sql_backup_destination ]]; then
    msg "ERROR" "Error saving backup archives:"
    if [[ ! -f $file_backup_destination ]]; then 
      msg "ERROR" "    Files:    $file_backup_destination"
    else 
      msg "SUCCESS" "    Files:    $file_backup_destination"
    fi

    if [[ ! -f $sql_backup_destination ]]; then 
      msg "ERROR" "    Database: $sql_backup_destination"
    else
      msg "SUCCESS" "    Database: $sql_backup_destination"
    fi

    exit "${error[command_failed]}"
  else 
    msg "SUCCESS" "Backup archives saved as:"
    msg "SUCCESS" "    Files:    $file_backup_destination"
    msg "SUCCESS" "    Database: $sql_backup_destination"
  fi
}
