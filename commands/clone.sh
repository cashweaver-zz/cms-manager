#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Clone an existing website

# Purpose: Clone an existing website
# Arguments:
#   None
function clone {
  #=============================================================================
  #===  1. Collect and test arguments
  #=============================================================================

  local options=":w:d:u:p:n:"

  local new_db_name=""
  local new_db_user_name=""
  local new_db_user_pass=""
  local website_path=""
  local destination_path=""
  while getopts "$options" o; do
    case "${o}" in
      w) website_path="${OPTARG%/}" ;;
      d) destination_path="${OPTARG%/}" ;;
      u) new_db_user_name="${OPTARG}" ;;
      p) new_db_user_pass="${OPTARG}" ;;
      n) new_db_name="${OPTARG}" ;;
      *)
        usage clone
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Evaluate arguments
  #   1. all flags must be set
  #   2. website_path must be:
  #     2a. a directory
  #     2b. a valid CMS
  #   3. destination_path must be:
  #     3a. a directory
  #     3b. writable by the executing user


  # 1. destination_path and website_path must be set
  if [[ -z "$destination_path" ]]; then
    msg "ERROR" "Missing destination path"
    usage clone
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$website_path" ]]; then
    msg "ERROR" "Missing path to website"
    usage clone
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$new_db_user_name" ]]; then
    msg "ERROR" "Missing new database user's name"
    usage clone
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$new_db_user_pass" ]]; then
    msg "ERROR" "Missing new database user's password"
    usage clone
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$new_db_name" ]]; then
    msg "ERROR" "Missing new database name"
    usage clone
    exit "${error[missing_required_args]}"
  fi

  # 2a. website_path must be a directory
  if [[ ! -d "$website_path" ]]; then
    msg "ERROR" "Website to clone ($website_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 2b. website_path must be a valid CMS
  local website_type=""
  get_website_type "$website_path" website_type
  # Errors are handled within get_website_type.

  # 3a. destination_path must be a directory
  if [[ ! -d "$destination_path" ]]; then
    msg "ERROR" "Destination path ($destination_path) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 3b. destination_path must be writable by the executing user
  local write_permissions=""
  check_for_write_permissions "$destination_path" "$(whoami)" write_permissions
  if [[ "$write_permissions" = "false" ]]; then
    msg "ERROR" "Destination Path ($destination_path) is not writable by $(whoami)"
    exit "${error[bad_arg]}"
  fi

  #=============================================================================
  #===  2. Clone files
  #=============================================================================

  msg "COMMENT" "Cloning files..."
  rsync -a "$website_path/" "$destination_path/"

  #=============================================================================
  #===  3. Clone database
  #=============================================================================


  msg "COMMENT" "Creating the new database..."
  local old_db_name=""
  local old_db_user_name=""
  local old_db_user_pass=""
  case "$website_type" in
    Drupal)
      _new_drupal_database "$new_db_name" "$new_db_user_name" "$new_db_user_pass"
      get_db_credentials "$website_path" "Drupal" old_db_name old_db_user_name old_db_user_pass
      update_db_credentials "$destination_path" "Drupal" "$new_db_name" "$new_db_user_name" "$new_db_user_pass"
      ;;
    WordPress)
      _new_wordpress_database "$new_db_name" "$new_db_user_name" "$new_db_user_pass"
      get_db_credentials "$website_path" "WordPress" old_db_name old_db_user_name old_db_user_pass
      update_db_credentials "$destination_path" "WordPress" "$new_db_name" "$new_db_user_name" "$new_db_user_pass"
      ;;
  esac

  msg "COMMENT" "Copying database contents..."
  if [[ -f "/tmp/${old_db_name}.cms-manager.dumped.sql" ]]; then
    rm /tmp/${old_db_name}.cms-manager.dumped.sql
  fi
  mysqldump -u$old_db_user_name -p$old_db_user_pass $old_db_name > "/tmp/${old_db_name}.cms-manager.dumped.sql"
  mysql -u$new_db_user_name -p$new_db_user_pass $new_db_name < "/tmp/${old_db_name}.cms-manager.dumped.sql"
  if [[ -f "/tmp/${old_db_name}.cms-manager.dumped.sql" ]]; then
    rm /tmp/${old_db_name}.cms-manager.dumped.sql
  fi

  msg "SUCCESS" "Cloning complete."
}

# Purpose: Create a new database for Drupal
# Arguments:
#   1. db_name
#   2. db_user_name
#   3. db_user_pass
function _new_drupal_database {
  if [[ $# -ne 3  ]]; then
    msg "ERROR" "_new_drupal_database takes three arguments:"
    msg "ERROR" "  db_name: Database name to be generated"
    msg "ERROR" "  db_user_name: Database user to be generated and granted permissions on db_name"
    msg "ERROR" "  db_user_pass: Database user's password"
    exit "${error[wrong_number_of_args]}"
  fi

  local db_name="$1"
  local db_user_name="$2"
  local db_user_pass="$3"

  local mysql_command=""
  mysql_command="${mysql_command}create database $db_name;"
  mysql_command="${mysql_command} create user $db_user_name; set password for $db_user_name = password('$db_user_pass');"
  mysql_command="${mysql_command} GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES on ${db_name}.* to $db_user_name@localhost identified by '$db_user_pass';"
  mysql_command="${mysql_command} flush privileges;"

  msg "PROMPT" "MySQL: Please enter root password Mysql"
  echo ""
  mysqlcmd_out=$(mysql -uroot -p -e "$mysql_command")
  mysqlcmd_rc=$?

  if [[ $mysqlcmd_rc -eq 0 ]]; then
    msg "SUCCESS" "MySQL: Successfully created new database and user"
    echo ""
  else
    msg "ERROR" "MySql error. Check the db name, username prefix, and password to ensure they are valid."
    msg "ERROR" "rc = $mysqlcmd_rc"
    msg "ERROR" "Exiting."
    echo ""
    exit
  fi
}

# Purpose: Create a new database for WordPress
# Arguments:
#   1. db_name
#   2. db_user_name
#   3. db_user_pass
function _new_wordpress_database {
  if [[ $# -ne 3  ]]; then
    msg "ERROR" "_new_wordpress_database takes three arguments:"
    msg "ERROR" "  db_name: Database name to be generated"
    msg "ERROR" "  db_user_name: Database user to be generated and granted permissions on db_name"
    msg "ERROR" "  db_user_pass: Database user's password"
    exit "${error[wrong_number_of_args]}"
  fi

  local db_name="$1"
  local db_user_name="$2"
  local db_user_pass="$3"

  local mysql_command=""
  mysql_command="${mysql_command}create database $db_name;"
  mysql_command="${mysql_command} create user $db_user_name; set password for $db_user_name = password('$db_user_pass');"
  mysql_command="${mysql_command} GRANT ALTER, CREATE, CREATE TEMPORARY TABLES, DELETE, DROP, INDEX, INSERT, LOCK TABLES, SELECT, UPDATE on ${db_name}.* to $db_user_name@localhost identified by '$db_user_pass';"
  mysql_command="${mysql_command} flush privileges;"

  msg "PROMPT" "MySQL: Please enter root password Mysql"
  echo ""
  mysqlcmd_out=$(mysql -uroot -p -e "$mysql_command")
  mysqlcmd_rc=$?

  if [[ $mysqlcmd_rc -eq 0 ]]; then
    msg "SUCCESS" "MySQL: Successfully created new database and user"
    echo ""
  else
    msg "ERROR" "MySql error. Check the db name, username prefix, and password to ensure they are valid."
    msg "ERROR" "rc = $mysqlcmd_rc"
    msg "ERROR" "Exiting."
    echo ""
    exit
  fi
}
