#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Restore a backup of files and database

# TODO: Target release v1.1
# TODO: Needs a complete re-thinking.
# Purpose: Restore a website from backup
# Arguments:
#   None
function restore {
  # 1. Gather and validate command line arguments
  # 2. Determine if restore will overwrite anything
  # 3. Determine which CMS is held within $files_file
  # 4. Confirm restoration
  # 5. Restore

  #=============================================================================
  #===  1. Gather and validate command line arguments
  #=============================================================================

  local options=":r:f:d:"

  local restore_path=""
  local files_file=""
  local database_file=""
  while getopts "$options" o; do
    case "${o}" in
      r) restore_path="${OPTARG%/}" ;;
      f) files_file="${OPTARG}" ;;
      d) database_file="${OPTARG}" ;;
      *)
        usage restore
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Validate arguments
  if [[ ! -z "$restore_path" ]]; then
    _validate_restore_path "$restore_path"
  else
    msg "ERROR" "Missing restore_path"
    usage restore
    exit "${error[missing_required_args]}"
  fi

  if [[ ! -z "$files_file" ]]; then
    _validate_files_file "$files_file"
  else
    msg "ERROR" "Missing files_file"
    usage restore
    exit "${error[missing_required_args]}"
  fi

  if [[ ! -z "$database_file" ]]; then
    _validate_database_file "$database_file"
  fi


  #=============================================================================
  #===  2. Determine if restore will overwrite anything
  #=============================================================================

  local overwriting=false
  local restore_path_website_type=""
  if [[ "$(ls -A $restore_path)" ]]; then
    overwriting=true
    get_website_type "$restore_path" restore_path_website_type
  fi

  #=============================================================================
  #===  3. Determine which CMS is held within $files_file
  #=============================================================================

  local files_website_type=""
  local contains_sql_file=""
  get_compressed_website_type "$files_file" files_website_type contains_sql_file

  if [[ ! -z "$database_file" && ! -z "$contains_sql_file" ]]; then
    msg "ERROR" "Two database files detected."
    msg "ERROR" "    1. [$database_file]"
    msg "ERROR" "    2. SQL file within [$files_file]"
    exit "${error[command_failed]}"
  fi


  #=============================================================================
  #===  4. Confirm restoration
  #=============================================================================

  msg "COMMENT" "Please review the following:"
  msg "COMMENT" "    CMS to restore         : $files_website_type"
  msg "COMMENT" "    Directory to restore to: $restore_path"
  msg "COMMENT" "    Files to restore       : $files_file"
  if [[ ! -z "$database_file" ]]; then
    msg "COMMENT" "    Database to restore    : $files_file"
  elif  [[ ! -z "$contains_sql_file" && "$files_website_type" = "Drupal" ]]; then
    msg "COMMENT" "    Database to restore    : Contained within compressed files."
  else
    msg "COMMENT" "    Database to restore    : None!"
  fi

  if [[ ! -z "$restore_path_website_type" ]]; then
    if [[ "$restore_path_website_type" != "$files_website_type" ]]; then
      echo ""
      msg "COMMENT" "    WARNING: CMS mismatch! The CMS contained at [$restore_path] is not the same as the one within [$files_file]."
    fi
  fi

  echo ""
  msg "COMMENT" "All files within [$restore_path] will be deleted and replaced with those contained in [$files_file]."
  msg "COMMENT" "If any of the above values are incorrect:  abort the restoration and proceed manually."
  count_from 9
  #read -t 1 -n 10000 discard
  read -p "Click [enter] to start restoration"


  #=============================================================================
  #===  5. Restore
  #=============================================================================

  msg "COMMENT" "Restoring $files_website_type website"

  msg "COMMENT" "Removing all files within $restore_path/*"
  rm -rf "$restore_path/*"

  cd "$restore_path"

  # Handle file extraction
  case "$files_website_type" in
    Drupal)
      if [[ ! -z "$contains_sql_file" ]]; then
        msg "COMMENT" "Running drush archive-restore"
        drush archive-restore "$files_file"
      else
        msg "COMMENT" "Extracting files..."
        extract "$files_file"
      fi
      ;;
    WordPress)
      msg "COMMENT" "Extracting files..."
      extract "$files_file"
      ;;
  esac

  # Handle database restoration
  local db_name=""
  local db_user_name=""
  local db_user_pass=""
  if [[ ! -z "$database_file" ]]; then
    case "$files_website_type" in
      Drupal)
        if [[ -z "$contains_sql_file" ]]; then
          get_db_credentials "$restore_path" "$files_website_type" db_name db_user_name db_user_pass
        fi
        ;;
      WordPress)
        get_db_credentials "$restore_path" "$files_website_type" db_name db_user_name db_user_pass
        ;;
    esac

    # Create database and user if they don't exist.
    msg "COMMENT" "Restoring database..."
    msg "PROMPT" "MySQL: Please enter root password MySQL"
    echo ""
    local mysql_create_db="CREATE DATABASE IF NOT EXISTS $db_name;"
    local mysql_create_user="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES on $db_name.* to $db_user_name@localhost identified by '$db_user_pass'; flush privileges;"
    local mysqlcmd_out=$(mysql -uroot -p -e "$mysql_create_db$mysql_create_user" 2>&1)
    local mysqlcmd_rc=$?
    if [[ $mysqlcmd_rc -eq 0 ]]; then
      msg "SUCCESS" "MySQL: Successfully restored"
    else
      msg "ERROR" "MySql error."
      msg "ERROR" "rc = $mysqlcmd_rc"
      msg "ERROR" "Exiting."
      exit "${error[command_failed]}"
    fi

    # Drop existing database.
    local mysql_drop_all_tables="SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '$db_name';"
    mysql -u$db_user_name -p$db_user_pass -e "$mysql_drop_all_tables"

    # Replace with new.
    mysql -u$db_user_name -p$db_user_pass $db_name < "$database_file"
  fi
}

# Purpose: Ensure restore path is valid
# Arguments:
#   1. restore_path
function _validate_restore_path {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_restore_path takes one argument: \$restore_path"
    exit "${error[wrong_number_of_args]}"
  fi

  # a. restore_path must be a valid directory
  if [[ ! -d "$restore_path" ]]; then
    msg "ERROR" "restore_path ($restore_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # b. restore_path must be writable
  local write_permissions=""
  check_for_write_permissions "$restore_path" "$(whoami)" write_permissions
  if [[ "$write_permissions" = "false" ]]; then
    msg "ERROR" "restore_path ($restore_path) is not writable by $(whoami)"
    exit "${error[bad_arg]}"
  fi
}

# Purpose: Ensure files file is valid
# Arguments:
#   1. files_file
function _validate_files_file {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_files_file takes one argument: \$files_file"
    exit "${error[wrong_number_of_args]}"
  fi

  # a. files_file must be a valid file
  if [[ ! -f "$files_file" ]]; then
    msg "ERROR" "files_file ($files_file) is not a valid file"
    exit "${error[bad_arg]}"
  fi

  # b. files_file must be compressed as a tar or zip file
  case "$files_file" in
    *.tar.bz2) ;;
    *.tar.gz) ;;
    *.tar.xz) ;;
    *.tar) ;;
    *.tbz2) ;;
    *.tgz) ;;
    *.zip) ;;
    *)
      msg "ERROR" "files_file: is an invalid compression format"
      exit "${error[bad_arg]}"
      ;;
  esac
}

# Purpose: Ensure database file is valid
# Arguments:
#   1. database_file
function _validate_database_file {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_database_file takes one argument: \$database_file"
    exit "${error[wrong_number_of_args]}"
  fi

  # a. database_file must be a valid file
  if [[ ! -f "$database_file" ]]; then
    msg "ERROR" "database_file ($database_file) is not a valid file"
    exit "${error[bad_arg]}"
  fi
}
