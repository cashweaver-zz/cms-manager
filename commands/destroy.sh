#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Destroy a given website by deleting all files and the database.

# TODO
# Purpose: Destroy a given website
# Arguments:
#   None
function destroy {
  # 1. Collect and test arguments
  # 2. Update

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
        usage destroy
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
    usage destroy
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
  #===  2. Destroy
  #=============================================================================

  msg "COMMENT" "$website_type website detected."

  # Set up database variables
  local db_name=""
  local db_user_name=""
  case "$website_type" in
    Drupal)
      cd "$website_path"
      db_name=$(grep "^[^\$\*]*database" sites/default/settings.php | sed "s/.*'[^'']*'.*'\([^'']*\)',/\1/")
      db_user_name=$(grep "^[^\$\*]*username" sites/default/settings.php | sed "s/.*'[^'']*'.*'\([^'']*\)',/\1/")
      ;;
    WordPress)
      cd "$website_path"
      db_name=$(grep "DB_NAME" wp-config.php | sed "s/define('DB_NAME', '\([^'']*\)');/\1/")
      db_user_name=$(grep "DB_USER" wp-config.php | sed "s/define('DB_USER', '\([^'']*\)');/\1/")
      ;;
  esac

  if [[ -z "$db_name" || -z "$db_user_name" ]]; then
    msg "ERROR" "Could not automatically detect database and database user."
    exit "${error[command_failed]}"
  fi

  # Double check with user
  msg "COMMENT" "Review the following."
  msg "COMMENT" "Stop this script and destroy the website manually if the values below are incorrect."
  echo ""
  msg "COMMENT" "Please ensure you have a backup."
  echo ""
  msg "COMMENT" "The following will be dropped:"
  msg "COMMENT" "    DB Name     : $db_name"
  msg "COMMENT" "    DB User Name: $db_user_name"
  echo ""
  msg "COMMENT" "The following will be deleted:"
  msg "COMMENT" "    Website Path: $website_path"
  count_from 9
  #read -t 1 -n 10000 discard
  read -p "Click [enter] to drop database and database user"
  echo ""

  # Drop database and database user
  msg "PROMPT" "MySQL: Please enter root password Mysql"
  echo ""
  mysql_command="drop database $db_name; drop user $db_user_name; drop user $db_user_name@localhost;"
  mysqlcmd_out=$(mysql -uroot -p -e "$mysql_command" 2>&1)
  mysqlcmd_rc=$?
  if [[ $mysqlcmd_rc -eq 0 ]]; then
    msg "SUCCESS" "MySQL: Successfully dropped db and db user"
  else
    msg "ERROR" "MySql error."
    msg "ERROR" "rc = $mysqlcmd_rc"
    msg "ERROR" "Exiting."
    exit "${error[command_failed]}"
  fi

  msg "COMMENT" "Deleting all files within, and including, $website_path"
  rm -rf "$website_path"
}
