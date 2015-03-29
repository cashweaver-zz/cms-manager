#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Functions to make life easier

# Purpose: Check if a given directory is writable by a given user.
# Arguments:
#   1. directory_path
#   2. username
#   3. result (return variable)
#       "true": The directory is writable
#       "false": Otherwise
function check_for_write_permissions {
  if [[ $# -ne 3  ]]; then
    msg "ERROR" "check_for_write_permissions takes three arguments:"
    msg "ERROR" "  directory: The full path to the directory to be checked"
    msg "ERROR" "  username : The user to be checked"
    msg "ERROR" "  result   : Return variable containing \"true\" or \"false\""
    exit "${error[wrong_number_of_args]}"
  fi

  local _directory_path="$1"
  if [[ ! -d "$_directory_path"  ]]; then
    msg "ERROR" "check_for_write_permissions:"
    msg "ERROR" "  directory: $_directory_path"
    msg "ERROR" "  is not a valid directory path"
    exit "${error[bad_arg]}"
  fi

  local _username="$2"
  local _user_exists=""
  check_if_user_exists "$_username" user_exists
  if [[ "$_user_exists" = "false"  ]]; then
    msg "ERROR" "check_for_write_permissions:"
    msg "ERROR" "  username : $_username"
    msg "ERROR" "  was not found. Is the spelling correct?"
    exit "${error[bad_arg]}"
  fi

  local _ret_result="$3"
  local _result="false"

  local _directory_values=""
  # ref: http://stackoverflow.com/a/14103893
  if read -a _directory_values < <(stat -Lc "%U %G %A" $_directory_path) && (
    ( [ "$_directory_values" == "$_username" ] && [ "${_directory_values[2]:2:1}" == "w" ] ) ||
    ( [ "${_directory_values[2]:8:1}" == "w" ] ) ||
    ( [ "${_directory_values[2]:5:1}" == "w" ] && (
        local _groups_belonged_to=($(groups $_username)) &&
        [[ "${_groups_belonged_to[*]:2}" =~ ^(.* |)${_directory_values[1]}( .*|)$ ]]
    ) ) )
  then
    _result="true"
  fi

  eval $_ret_result="'$_result'"
}

# Purpose: Check if a given user exists
# Arguments:
#   1. username
#   2. result (return variable)
#       "true": The user exists
#       "false": Otherwise
function check_if_user_exists {
  if [[ $# -ne 2  ]]; then
    msg "ERROR" "check_if_user_exists takes one argument:"
    msg "ERROR" "  username : The user to be checked"
    msg "ERROR" "  result   : Return variable containing \"true\" or \"false\""
    exit "${error[wrong_number_of_args]}"
  fi

  local _username="$1"
  local __result="$2"
  local _result="false"
  getent passwd "$_username" >/dev/null 2>&1 && _result="true"
  eval $__result="'$_result'"
}

# Purpose: Determine CMS of compressed website
# Arguments:
#   1. compressed_file
#   2. website_type (return variable)
#       "WordPress": The compressed file contains a WordPress website
#       "Drupal": The compressed file contains a Drupal website
#   3. contains_sql_file (return variable)
#       "true": The compressed_file contains an sql file in the top-level
#       "false": Otherwise
function get_compressed_website_type {
  if [[ $# -ne 3  ]]; then
    msg "ERROR" "get_compressed_website_type takes two argument:"
    msg "ERROR" "  compressed_file: Compressed file containing website files"
    msg "ERROR" "  website_type: Type of website. This is a return variable."
    msg "ERROR" "  contains_sql_file: Type of website. This is a return variable."
    exit "${error[wrong_number_of_args]}"
  fi

  # Prefix "_" to prevent same variable name issue with the backup() function
  local _compressed_website_files="$1"

  local _ret_website_type="$2"
  local _website_type="_"

  local _ret_contains_sql_file="$3"
  local _contains_sql_file=""

  local _matched_website_type="_"
  local _website_signature=""

  # Check for Drupal
  # ================

  # Remove the leading relative file position if present. The relative
  # position is used in other tests, but will cause this one to break.
  _website_signature="${config[website_signature_drupal]}"
  if [[ "${config[website_signature_drupal]:0:2}" = "./" ]]; then
    _website_signature="${_website_signature:2}"
  fi

  print_contents_of_compressed_file "$_compressed_website_files" | grep ".*$_website_signature" >/dev/null 2>&1 && _matched_website_type="Drupal"
  if [[ "$_matched_website_type" = "Drupal" ]]; then
    _website_type="Drupal"
    print_contents_of_compressed_file "$_compressed_website_files" | grep "[^\/]*\/[^\/]*\.sql" >/dev/null 2>&1 && _contains_sql_file="true"
  fi

  # Check for WordPress
  # ===================

  # Remove the leading relative file position if present. The relative
  # position is used in other tests, but will cause this one to break.
  _website_signature="${config[website_signature_wordpress]}"
  if [[ "${config[website_signature_wordpress]:0:2}" = "./" ]]; then
    _website_signature="${_website_signature:2}"
  fi

  print_contents_of_compressed_file "$_compressed_website_files" | grep ".*$_website_signature" >/dev/null 2>&1 && _matched_website_type="WordPress"
  if [[ "$_website_type" = "_" ]]; then
    if [[ "$_matched_website_type" = "WordPress" ]]; then
      _website_type="WordPress"
    fi
  else
    # Print error if more than one website_signature returned true
    if [[ "$_matched_website_type" = "WordPress" ]]; then
      msg "ERROR" "Cannot determine website type for $_compressed_website_files"
      exit
    fi
  fi

  eval $_ret_website_type="'$_website_type'"
  eval $_ret_contains_sql_file="'$_contains_sql_file'"
}

# Purpose: Print the contents of a compressed file without expanding it
# Arguments:
#   1. compressed_file
function print_contents_of_compressed_file {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "print_contents_of_compressed_file takes one argument:"
    msg "ERROR" "  compressed_file: Compressed file containing website files"
    exit "${error[wrong_number_of_args]}"
  fi

  case "$1" in
    *.tar.bz2) tar tvjf "$1" ;;
    *.tar.gz) tar tvzf "$1" ;;
    *.tar.xz) tar tvJf "$1" ;;
    *.tar) tar tvf "$1" ;;
    *.tbz2) tar tvjf "$1" ;;
    *.tgz) tar tvzf "$1" ;;
    *.zip) unzip -l "$1" ;;
  esac
}

# Purpose: Determines CMS type of given website
# Arguments:
#   1. website_path
#   2. website_type (return_variable)
#       "WordPress": The compressed file contains a WordPress website
#       "Drupal": The compressed file contains a Drupal website
function get_website_type {
  if [[ $# -ne 2  ]]; then
    msg "ERROR" "get_website_type takes two argument:"
    msg "ERROR" "  website_path: Path to the website to be checked."
    msg "ERROR" "  website_type: Type of website. This is the return variable."
    exit "${error[wrong_number_of_args]}"
  fi

  local _website_path="$1"
  local _ret_website_type="$2"

  # Prefix "_" to prevent same variable name issue with the backup() function
  local _website_type="_"

  # Ensure path valid
  if [[ -d "$_website_path"  ]]; then
    cd "$_website_path"
    local _matched_website_type=""

    if [[ -f "${config[website_signature_wordpress]}" ]]; then
      _matched_website_type="WordPress"
      # Fail if website matches more than one signature
      if [[ "$_website_type" = "_" ]]; then
        _website_type="$_matched_website_type"
      else
        msg "ERROR" "Cannot determine website type for $_website_path"
        msg "ERROR" "Could be either $_website_type, or $_matched_website_type"
      fi
    fi

    if [[ -f "${config[website_signature_drupal]}" ]]; then
      _matched_website_type="Drupal"
      # Fail if website matches more than one signature
      if [[ "$_website_type" = "_" ]]; then
        _website_type="$_matched_website_type"
      else
        msg "ERROR" "Cannot determine website type for $_website_path"
        msg "ERROR" "Could be either $_website_type, or $_matched_website_type"
      fi
    fi
  else
    msg "ERROR" "Bad path"
    msg "ERROR" "  $_website_path"
    exit "${error[bad_arg]}"
  fi

  if [[ "$_website_type" = "_"  ]]; then
    msg "ERROR" "Cannot determine website type for given path"
    msg "ERROR" "  $_website_path"
    exit "${error[unknown_site_type]}"
  fi

  eval $_ret_website_type="'$_website_type'"
}

# Purpose: Extract various components from website path
# Arguments:
#   1. website_path
#   2. domain (return variable)
#   3. subdomain (return variable)
#   4. website_owner (return variable)
function parse_website_path {
  if [[ $# -ne 4  ]]; then
    msg "ERROR" "get_website_type takes four arguments:"
    msg "ERROR" "  website_path : Path to the website to be parsed"
    msg "ERROR" "  domain       : Return variable."
    msg "ERROR" "  subdomain    : Return variable."
    msg "ERROR" "  website_owner: Return variable."
    exit "${error[wrong_number_of_args]}"
  fi

  local _website_path="$1"
  if [[ ! -d "$_website_path"  ]]; then
    msg "ERROR" "parse_website_path:"
    msg "ERROR" "  website_path: $_website_path"
    msg "ERROR" "  is not a valid directory path"
    exit "${error[bad_arg]}"
  else
    local _regex="\/var\/www\/[^\/]+\/[^\/]+\/[^\/]+\/"
    if [[ ! "$_website_path" =~ $_regex ]]; then
      msg "ERROR" "parse_website_path:"
      msg "ERROR" "  website_path: $_website_path"
      msg "ERROR" "  does not follow website directory pattern:."
      msg "ERROR" "    /var/www/<domain>/<subdomain>/public_html"
      exit "${error[bad_arg]}"
    fi
  fi

  local _ret_domain="$2"
  local _ret_subdomain="$3"
  local _ret_website_owner="$4"

  local _sanitary_selected_site_path=${_website_path#/}
  _sanitary_selected_site_path=${_sanitary_selected_site_path%/}

  local _domain=${_sanitary_selected_site_path#var/www/}
  _domain=${_domain%/*/*}

  local _subdomain=${_sanitary_selected_site_path#var/www/}
  _subdomain=${_subdomain#*/}
  _subdomain=${_subdomain%/*}

  local _website_owner="$_domain-$_subdomain"

  eval $_ret_domain="'$_domain'"
  eval $_ret_subdomain="'$_subdomain'"
  eval $_ret_website_owner="'$_website_owner'"
}

# Purpose: Count down from a given number
# Arguments:
#   1. number
function count_from {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "count_from takes one argument:"
    msg "ERROR" "  number: How high to count (integer)"
    exit "${error[wrong_number_of_args]}"
  fi

  local re='^[0-9]+$'
  if ! [[ $1 =~ $re ]]; then
    msg "ERROR" "Not an integer: $1"
    exit "${error[bad_arg]}"
  fi

  for (( i=$1; i>=1; i--)); do
    echo -en "\r$i"
    sleep 1
  done
  echo -en "\r"
}

# Purpose: Extract a compressed file
# Arguments:
#   1. compressed_file
# ref: http://www.shellhacks.com/en/HowTo-Extract-Archives-targzbz2rarzip7ztbz2tgzZ
function extract {
  if [[ $# -ne 1 || -z "$1" ]]; then
    msg "ERROR" "extract expects one argument"
    exit "${error[wrong_number_of_args]}"
  else
    if [[ -f $1 ]]; then
      # NAME=${1%.*}
      # mkdir $NAME && cd $NAME
      case $1 in
      *.tar.bz2) tar xvjf $1 ;;
      *.tar.gz) tar xvzf $1 ;;
      *.tar.xz) tar xvJf $1 ;;
      *.lzma) unlzma $1 ;;
      *.bz2) bunzip2 $1 ;;
      *.rar) unrar x -ad $1 ;;
      *.gz) gunzip $1 ;;
      *.tar) tar xvf $1 ;;
      *.tbz2) tar xvjf $1 ;;
      *.tgz) tar xvzf $1 ;;
      *.zip) unzip $1 ;;
      *.Z) uncompress $1 ;;
      *.7z) 7z x $1 ;;
      *.xz) unxz $1 ;;
      *.exe) cabextract $1 ;;
      *)
        msg "ERROR" "extract: '$1' - unknown archive method"
        exit "${error[bad_arg]}"
        ;;
      esac
    else
      msg "ERROR" "$1 - file does not exist"
      exit "${error[bad_arg]}"
    fi
  fi
}

# Purpose: Extract database credentials from a given website_path
# Arguments:
#   1. website_path
#   2. cms_type
#   3. db_name (return variable)
#   4. db_user_name (return variable)
#   5. db_user_pass (return variable)
function get_db_credentials {
  if [[ $# -ne 5  ]]; then
    msg "ERROR" "get_db_credentials takes four arguments:"
    msg "ERROR" "   website_path: path to website root"
    msg "ERROR" "   cms_type: type of CMS"
    msg "ERROR" "   db_name: Database name (return variable)"
    msg "ERROR" "   db_user_name: Database user name (return variable)"
    msg "ERROR" "   db_user_pass: Database user password (return variable)"
    exit "${error[wrong_number_of_args]}"
  fi

  local _website_path="$1"
  local _cms_type="$2"
  local _ret_db_name="$3"
  local _ret_db_user_name="$4"
  local _ret_db_user_pass="$5"

  # Set up database variables
  local _db_name=""
  local _db_user_name=""
  local _db_user_pass=""

  cd "$_website_path"
  case "$_cms_type" in
    Drupal)
      _db_name=$(grep "^[^\$\*]*database" sites/default/settings.php | sed "s/.*'[^'']*'.*'\([^'']*\)',/\1/")
      _db_user_name=$(grep "^[^\$\*]*username" sites/default/settings.php | sed "s/.*'[^'']*'.*'\([^'']*\)',/\1/")
      _db_user_pass=$(grep "^[^\$\*]*password" sites/default/settings.php | sed "s/.*'[^'']*'.*'\([^'']*\)',/\1/")
      ;;
    WordPress)
      _db_name=$(grep "DB_NAME" wp-config.php | sed "s/define('DB_NAME', '\([^'']*\)');/\1/")
      _db_user_name=$(grep "DB_USER" wp-config.php | sed "s/define('DB_USER', '\([^'']*\)');/\1/")
      _db_user_pass=$(grep "DB_PASSWORD" wp-config.php | sed "s/define('DB_PASSWORD', '\([^'']*\)');/\1/")
      ;;
  esac

  if [[ -z "$_db_name" || -z "$_db_user_name" || -z "$_db_user_pass" ]]; then
    msg "ERROR" "Unable to detect database credentials."
    exit "${error[command_failed]}"
  fi

  eval $_ret_db_name="'$_db_name'"
  eval $_ret_db_user_name="'$_db_user_name'"
  eval $_ret_db_user_pass="'$_db_user_pass'"
}

function update_db_credentials {
  if [[ $# -ne 5  ]]; then
    msg "ERROR" "get_db_credentials takes four arguments:"
    msg "ERROR" "   website_path: path to website root"
    msg "ERROR" "   cms_type: type of CMS"
    msg "ERROR" "   new_db_name: New database name"
    msg "ERROR" "   new_db_user_name: New database user name"
    msg "ERROR" "   new_db_user_pass: New database user password"
    exit "${error[wrong_number_of_args]}"
  fi

  local _website_path="$1"
  local _cms_type="$2"
  local _new_db_name="$3"
  local _new_db_user_name="$4"
  local _new_db_user_pass="$5"

  local _old_db_name=""
  local _old_db_user_name=""
  local _old_db_user_pass=""

  get_db_credentials "$_website_path" "$_cms_type" _old_db_name _old_db_user_name _old_db_user_pass

  cd "$_website_path"
  local has_write_permissions=""
  local granted_write_permissions="false"
  case "$_cms_type" in
    Drupal)
      # Permissions may be configured (for security reqsons) to disallow
      # writing in sites/default. Enable writing temporarily if it is
      # required.
      check_for_write_permissions "$_website_path" "$(whoami)" has_write_permissions
      if [[ "$has_write_permissions" = "false" ]]; then
        granted_write_permissions="true"
        chmod u+w sites/default/settings.php
      fi

      # settings.php is read-only. Enable writing.
      chmod u+w sites/default
      sed -i "s/'database' => '$_old_db_name'/'database' => '$_new_db_name'/" sites/default/settings.php
      sed -i "s/'username' => '$_old_db_user_name'/'username' => '$_old_db_user_name'/" sites/default/settings.php
      sed -i "s/'password' => '$_old_db_user_pass'/'password' => '$_old_db_user_pass'/" sites/default/settings.php

      # Remember to disable writing!
      chmod u-w sites/default

      # Revoke writing previledges if they were granted above.
      if [[ "$granted_write_permissions" = "true" ]]; then
        chmod u-w sites/default/settings.php
      fi
      ;;

    WordPress)
      sed -i "s/define('DB_NAME', '$_old_db_name')/define('DB_NAME', '$_new_db_name')/" wp-config.php
      sed -i "s/define('DB_USER', '$_old_db_user_name')/define('DB_USER', '$_new_db_user_name')/" wp-config.php
      sed -i "s/define('DB_PASSWORD', '$_old_db_user_pass')/define('DB_PASSWORD', '$_new_db_user_pass')/" wp-config.php
      ;;
  esac
}
