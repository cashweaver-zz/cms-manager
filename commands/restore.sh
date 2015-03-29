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

  #=============================================================================
  #===  1. Gather and validate command line arguments
  #=============================================================================

  local options=":r:f:d:"

  local restore_path=""
  local backup_files=""
  local backup_database=""
  while getopts "$options" o; do
    case "${o}" in
      r) restore_path="${OPTARG%/}" ;;
      f) backup_files="${OPTARG}" ;;
      d) backup_database="${OPTARG}" ;;
      *)
        usage restore
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Evaluate arguments
  #   1. restore_path and backup_files must be set
  #   2. restore_path must be:
  #     2a. a directory
  #     2b. writable by the executing user
  #   3. backup_files must be:
  #     3a. a valid file
  #     3b. a recognized compressed file
  #   4. if backup_database is set, it must
  #     3a. be a valid file
  #     3b. have file extension '.sql'

  #   1. restore_path and backup_files must be set
  if [[ ! -z "$restore_path" ]]; then
    #   2. restore_path must be:
    #     2a. a directory
    #     2b. writable by the executing user
    _validate_restore_path "$restore_path"
  else
    msg "ERROR" "Missing restore path"
    usage restore
    exit "${error[missing_required_args]}"
  fi

  if [[ ! -z "$backup_files" ]]; then
    #   3. backup_files must be:
    #     3a. a valid file
    #     3b. a recognized compressed file
    _validate_backup_files "$backup_files"
  else
    msg "ERROR" "Missing backup files"
    usage restore
    exit "${error[missing_required_args]}"
  fi

  #   4. if backup_database is set, it must
  if [[ ! -z "$backup_database" ]]; then
    #     4a. be a valid file
    #     4b. have file extension '.sql'
    _validate_backup_database "$backup_database"
  fi

  msg "COMMENT" "Gathering information..."
  echo ""


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
  #===  3. Determine which CMS is held within $backup_files
  #=============================================================================

  local backup_files_website_type=""
  local contains_sql_file=""
  get_compressed_website_type "$backup_files" backup_files_website_type contains_sql_file

  if [[ ! -z "$backup_database" && ! -z "$contains_sql_file" ]]; then
    msg "ERROR" "Two database files detected."
    msg "ERROR" "    1. [$backup_database]"
    msg "ERROR" "    2. SQL file within [$backup_files]"
    exit "${error[command_failed]}"
  fi


  #=============================================================================
  #===  4. Confirm restoration
  #=============================================================================

  msg "COMMENT" "Please review the following:"
  msg "COMMENT" "    CMS to restore         : $backup_files_website_type"
  msg "COMMENT" "    Directory to restore to: $restore_path"
  msg "COMMENT" "    Files to restore       : $backup_files"
  if [[ ! -z "$backup_database" ]]; then
    msg "COMMENT" "    Database to restore    : $backup_database"
  elif  [[ ! -z "$contains_sql_file" && "$backup_files_website_type" = "Drupal" ]]; then
    msg "COMMENT" "    Database to restore    : Contained within compressed files."
  else
    msg "COMMENT" "    Database to restore    : None!"
  fi

  if [[ ! -z "$restore_path_website_type" ]]; then
    if [[ "$restore_path_website_type" != "$backup_files_website_type" ]]; then
      echo ""
      msg "ERROR" "    WARNING: CMS mismatch! The CMS contained at [$restore_path] is not the same as the one within [$backup_files]."
    fi
  fi

  echo ""
  msg "COMMENT" "All files within [$restore_path] will be deleted and replaced with those contained in [$backup_files]."
  echo ""
  msg "COMMENT" "If any of the above values are incorrect:  abort the restoration and proceed manually."
  count_from 9
  #read -t 1 -n 10000 discard
  read -p "Click [enter] to start restoration"


  #=============================================================================
  #===  5. Restore
  #=============================================================================

  msg "COMMENT" "Restoring $backup_files_website_type website"

  msg "COMMENT" "Removing all files within $restore_path/*"
  rm -rf "$restore_path/*"

  cd "$restore_path"

  # Handle file extraction
  local database_not_yet_restored=""
  case "$backup_files_website_type" in
    Drupal)
      if [[ ! -z "$contains_sql_file" ]]; then
        msg "COMMENT" "Running drush archive-restore"
        drush archive-restore "$backup_files"
        database_not_yet_restored="true"
      else
        msg "COMMENT" "Extracting files..."
        extract "$backup_files" >/dev/null
      fi
      ;;
    WordPress)
      msg "COMMENT" "Extracting files..."
      extract "$backup_files" >/dev/null
      ;;
  esac

  if [[ -z "$database_not_yet_restored" ]]; then
    # Handle database restoration
    local db_name=""
    local db_user_name=""
    local db_user_pass=""
    if [[ ! -z "$backup_database" ]]; then
      case "$backup_files_website_type" in
        Drupal)
          get_db_credentials "$restore_path" "$backup_files_website_type" db_name db_user_name db_user_pass
          ;;
        WordPress)
          get_db_credentials "$restore_path" "$backup_files_website_type" db_name db_user_name db_user_pass
          ;;
      esac

      # Create database and user if they don't exist.
      msg "COMMENT" "Restoring database..."
      msg "PROMPT" "MySQL: Please enter root password MySQL"
      echo ""
      local mysql_create_db="CREATE DATABASE IF NOT EXISTS $db_name;"
      local mysql_create_user="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES on $db_name.* to $db_user_name@localhost identified by '$db_user_pass'; flush privileges;"
      local mysql_command="$mysql_create_db$mysql_create_user"

      local mysqlcmd_out=$(mysql -uroot -p -e "$mysql_command")
      local mysqlcmd_rc=$?
      if [[ $mysqlcmd_rc -eq 0 ]]; then
        msg "SUCCESS" "MySQL: Database environment configured"
      else
        msg "ERROR" "MySql error."
        msg "ERROR" "rc = $mysqlcmd_rc"
        msg "ERROR" "Exiting."
        exit "${error[command_failed]}"
      fi

      # Drop existing database.
      local mysql_drop_all_tables="SELECT concat('DROP TABLE IF EXISTS ', table_name, ';') FROM information_schema.tables WHERE table_schema = '$db_name';"
      mysqlcmd_out=$(mysql -u$db_user_name -p$db_user_pass -e "$mysql_drop_all_tables" >/dev/null)
      local mysqlcmd_rc=$?
      if [[ $mysqlcmd_rc -eq 0 ]]; then
        msg "SUCCESS" "MySQL: Tables dropped"
      else
        msg "ERROR" "MySql error."
        msg "ERROR" "rc = $mysqlcmd_rc"
        msg "ERROR" "Exiting."
        exit "${error[command_failed]}"
      fi

      # Replace with new.
      mysqlcmd_out=$(mysql -u$db_user_name -p$db_user_pass $db_name < "$backup_database")
      local mysqlcmd_rc=$?
      if [[ $mysqlcmd_rc -eq 0 ]]; then
        msg "SUCCESS" "MySQL: Restoration complete!"
      else
        msg "ERROR" "MySql error."
        msg "ERROR" "rc = $mysqlcmd_rc"
        msg "ERROR" "Exiting."
        exit "${error[command_failed]}"
      fi
    fi
  fi

  echo ""
  msg "SUCCESS" "Website restoration completed."
}

# Purpose: Ensure restore path is valid
# Arguments:
#   1. restore_path
function _validate_restore_path {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_restore_path takes one argument: \$restore_path"
    exit "${error[wrong_number_of_args]}"
  fi

  local _restore_path="$1"

  # a. restore_path must be a valid directory
  if [[ ! -d "$_restore_path" ]]; then
    msg "ERROR" "Restore path ($_restore_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # b. restore_path must be writable
  local write_permissions=""
  check_for_write_permissions "$_restore_path" "$(whoami)" write_permissions
  if [[ "$write_permissions" = "false" ]]; then
    msg "ERROR" "Restore path ($_restore_path) is not writable by $(whoami)"
    exit "${error[bad_arg]}"
  fi
}

# Purpose: Ensure files file is valid
# Arguments:
#   1. backup_files
function _validate_backup_files {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_backup_files takes one argument: \$backup_files"
    exit "${error[wrong_number_of_args]}"
  fi

  local _backup_files="$1"

  # a. backup_files must be a valid file
  if [[ ! -f "$_backup_files" ]]; then
    msg "ERROR" "Backup files ($_backup_files) is not a valid file"
    exit "${error[bad_arg]}"
  fi

  # b. backup_files must be compressed as a tar or zip file
  case "$_backup_files" in
    *.tar.bz2) ;;
    *.tar.gz) ;;
    *.tar.xz) ;;
    *.tar) ;;
    *.tbz2) ;;
    *.tgz) ;;
    *.zip) ;;
    *)
      msg "ERROR" "Backup files ($_backup_files): is an invalid compression format"
      exit "${error[bad_arg]}"
      ;;
  esac
}

# Purpose: Ensure database file is valid
# Arguments:
#   1. backup_database
function _validate_backup_database {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_validate_database_file takes one argument: \$backup_database"
    exit "${error[wrong_number_of_args]}"
  fi

  local _backup_database="$1"

  # a. backup_database must be a valid file
  if [[ ! -f "$_backup_database" ]]; then
    msg "ERROR" "Backup dtabase ($_backup_database) is not a valid file"
    exit "${error[bad_arg]}"
  fi

  # a. backup_database must be a .sql file
  local _extension="$(echo ${_backup_database##*.})"
  if [[ "$_extension" != "sql" ]]; then
    msg "ERROR" "Backup database ($_backup_database) is not of type 'sql'"
    exit "${error[bad_arg]}"
  fi
}
