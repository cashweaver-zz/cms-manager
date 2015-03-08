#!/usr/bin/env bash
# Description:
# Backup a website

function _backup {
  #=============================================================================
  #===  Collect Arguments
  #=============================================================================

  short_options=""
  long_options="website_path:,save_dir:"
  getopt_results=$(getopt -s bash --options $short_options --long $long_options -- "$@")

  # Ensure arguments were successfully parsed
  if [[ $? -ne 0 ]]; then
    usage backup
    exit "${error[bad_arg_parse]}"
  elif [[ "$1" = "--" ]]; then
    usage backup
    exit "${error[bad_arg]}"
  fi

  eval set -- "$getopt_results"
  local website_path=""
  local save_dir=""
  while true; do
    case "$1" in
      -s|--save_dir)
        # Remove trailing '/'s
        save_dir="${2%/}"
        if [[ ! -d "$save_dir" ]]; then
          msg "ERROR" "Bad save directory"
          usage backup
          exit "${error[bad_arg]}"
        fi
        shift 2
        ;;
      -w|--website_path)
        website_path="$2"
        if [[ -z "$website_path" ]]; then
          msg "ERROR" "Missing path"
          usage backup
          exit "${error[missing_required_args]}"
        fi
        shift 2
        ;;
      --)
        shift
        break
        ;;
      *)
        usage backup
        exit "${error[bad_arg]}"
        ;;
    esac
  done

  # Ensure path set
  if [[ -z "$website_path" ]]; then
    msg "ERROR" "Missing path"
    usage backup
    exit "${error[missing_required_args]}"
  fi

  #local website_type=""
  website_type=""
  get_website_type "$website_path" website_type

  #=============================================================================
  #===  Update Website
  #=============================================================================

  msg "COMMENT" "$website_type website detected. Creating backup..."

  # Get $domain, and $subdomain
  parse_website_path "$website_path" domain subdomain website_owner
  local sanitary_selected_site_path=${website_path#/}
  sanitary_selected_site_path=${sanitary_selected_site_path%/}
  local domain=${sanitary_selected_site_path#var/www/}
  domain=${domain%/*/*}
  local subdomain=${sanitary_selected_site_path#var/www/}
  subdomain=${subdomain#*/}
  subdomain=${subdomain%/*}

  local website_owner="$domain-$subdomain"

  local backup_dir_path=""
  local has_write_permissions=""
  if [[ ! -z "$save_dir" ]]; then
    backup_dir_path="$save_dir"
    # The user running the script should have write permissions for the backup dir
    check_for_write_permissions "$backup_dir_path" "$website_owner" has_write_permissions
    if [[ "$has_write_permissions" = "false" ]]; then
      msg "ERROR" "$(whoami) cannot write to backup directory:"
      msg "ERROR" "  $backup_dir_path"
      exit "${error[command_failed]}"
    fi
  else
    # The user running the script should have write permissions for the backup dir
    check_for_write_permissions "${config[backup_basepath]}" "$website_owner" has_write_permissions
    if [[ "$has_write_permissions" = "false" ]]; then
      msg "ERROR" "$(whoami) cannot write to backup directory:"
      msg "ERROR" "  ${config[backup_basepath]}"
      exit "${error[command_failed]}"
    fi

    backup_dir_path="${config[backup_basepath]}/$domain/$subdomain"
    # Ensure the folders we'll be writing to exist.
    if [[ ! -d "$backup_dir_path" ]]; then
      _create_backup_dir $backup_dir_path
    fi

    # The user running the script should have write permissions for the backup dir
    check_for_write_permissions "$backup_dir_path" "$website_owner" has_write_permissions
    if [[ "$has_write_permissions" = "false" ]]; then
      msg "ERROR" "$(whoami) cannot write to backup directory:"
      msg "ERROR" "  $backup_dir_path"
      exit "${error[command_failed]}"
    fi
  fi

  case "$website_type" in
    Drupal)
      _backup_drupal "$backup_dir_path" "$website_owner" "$website_path"
      ;;
    WordPress)
      _backup_wordpress "$backup_dir_path" "$website_owner" "$website_path"
      ;;
  esac
}


function _backup_drupal {
  local backup_dir_path="$1"
  local website_owner="$2"
  local website_path="$3"

  local backup_destination="$backup_dir_path/$(date "+%Y-%m-%d-%H-%M-%S").tar.gz"

  sudo su $website_owner <<EOF
cd $website_path
drush cc all >/dev/null 2>&1
drush archive-dump --destination=$backup_destination >/dev/null 2>&1
EOF

  if [[ ! -f $backup_destination ]]; then
    msg "ERROR" "Error saving backup archives:"
    msg "ERROR" "    $backup_destination"
    exit "${error[command_failed]}"
  else 
    msg "SUCCESS" "Backup archive saved as:"
    msg "SUCCESS" "    $backup_destination"
  fi
}

function _backup_wordpress {
  local backup_dir_path="$1"
  local website_owner="$2"
  local website_path="$3"

  local file_backup_destination="$backup_dir_path/$(date "+%Y-%m-%d-%H-%M-%S").tar.gz"
  local sql_backup_destination="$backup_dir_path/$(date "+%Y-%m-%d-%H-%M-%S").sql"

  sudo su $website_owner <<EOF
cd $website_path
wp db export $sql_backup_destination >/dev/null 2>&1
tar -cvzf $file_backup_destination * >/dev/null 2>&1
EOF

  if [[ ! -f $file_backup_destination  ||  ! -f $sql_backup_destination ]]; then
    msg "ERROR" "Error saving backup archives:"
    backup_error=1
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


# Description:
# Create backup directory at specified path using specified owner
# In:
#   1: backup root path eg: /home/mitc/drupal-backups
#   2: site name eg: d7
function _create_backup_dir {
    local backup_root_path=$1

sudo su "${config[web_adminstrator_username]}" <<EOF
mkdir -p $backup_root_path
EOF
    msg "COMMENT" "Created dir $backup_root_path"
}
