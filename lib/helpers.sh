#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Functions to make life easier

# Check if a given directory is writable by a given user.
#
# Returns "true" if the directory is writable, and "false" otherwise.
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
  if read -a directory_values < <(stat -Lc "%U %G %A" $_directory_path) && (
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

# Check if a given user exists.
#
# Returns "true" if the user exists, and "false" otherwise.
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

# Determines type of website
#
# Returns "WordPress", or "Drupal"
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

# Parses given website path
#
# Returns the expected domain, subdomain, and website_owner of the given path
function parse_website_path {
  if [[ $# -ne 4  ]]; then
    msg "ERROR" "get_website_type takes two argument:"
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
