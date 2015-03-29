#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Create a new instance of a CMS

# Purpose: Create a new instance of a CMS
# Arguments:
#   None
function new {
  #=============================================================================
  #===  1. Collect and test arguments
  #=============================================================================

  local options=":w:d:"

  local website_type=""
  while getopts "$options" o; do
    case "${o}" in
      d)
        website_type="Drupal"
        website_path="${OPTARG}"
        ;;
      w)
        website_type="WordPress"
        website_path="${OPTARG}"
        ;;
      *)
        usage new
        exit "${error[bad_arg]}"
        ;;
    esac
  done
  shift $((OPTIND-1))

  # Evaluate arguments
  #   1. website_type and website_path must be set
  #   2. website_path must be:
  #     2a. a directory
  #     2b. writable by the executing user

  # 1. website_type and website_path must be set
  if [[ -z "$website_type" ]]; then
    msg "ERROR" "Missing website type"
    usage backup
    exit "${error[missing_required_args]}"
  fi

  if [[ -z "$website_path" ]]; then
    msg "ERROR" "Missing path to website"
    usage backup
    exit "${error[missing_required_args]}"
  fi

  # 2a. website_path must be a directory
  if [[ ! -d "$website_path" ]]; then
    msg "ERROR" "Save directory ($save_dir) is not a directory"
    exit "${error[bad_arg]}"
  fi

  # 2b. website_path must be a writable by the executing user
  local write_permissions=""
  check_for_write_permissions "$website_path" "$(whoami)" write_permissions
  if [[ "$write_permissions" = "false" ]]; then
    msg "ERROR" "Website path ($website_path) is not writable by $(whoami)"
    exit "${error[bad_arg]}"
  fi


  msg "COMMENT" "Creating a new $website_type installation..."
  case "$website_type" in
    Drupal)
      _new_drupal "$website_path"
      ;;
    WordPress)
      _new_wordpress "$website_path"
      ;;
  esac
}

# Purpose: Create a new Drupal installation
# Arguments:
#   1. website_path
function _new_drupal {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_new_drupal takes one argument:"
    msg "ERROR" "  website_path: The full path to the directory to be install Drupal to"
    exit "${error[wrong_number_of_args]}"
  fi

  # 1. Gather site credentials
  # 2. Create database
  # 3. Install Drupal
  # 4. Print summary

  #=============================================================================
  #===  1. Gather Site Credentials
  #=============================================================================

  msg "COMMENT" "To create a new Drupal 7.x site,"
  msg "COMMENT" "please enter the new site's relevent information. Use this as an example:"
  echo " "
  msg "COMMENT" "If the new site would be \"www.myspecialwebsite.com\""
  msg "COMMENT" "  Database name             :  myspecialwebsite"
  msg "COMMENT" "  Database username         :  msw_admin"
  echo ""
  msg "COMMENT" "  Drupal admin username     :  admin"
  msg "COMMENT" "  Drupal admin password     :  some.complex.password"
  echo " "

  msg "PROMPT" "Database name: "
  local db_name=""
  read db_name
  while [ -z $db_name ]; do
    msg "PROMPT" "Database name: "
    read db_name
  done

  msg "PROMPT" "Database username (<16 char): "
  local db_user_name=""
  read db_user_name
  while [ ${#db_user_name} -gt 16 ]; do
    msg "PROMPT" "Database username (<16 char): "
    read db_user_name
  done

  msg "PROMPT" "Drupal admin username: "
  local drupal_admin_username=""
  read drupal_admin_username
  while [ ${#drupal_admin_username} -gt 16 ]; do
    msg "PROMPT" "Drupal admin username: "
    read drupal_admin_username
  done

  msg "PROMPT" "Drupal admin password: "
  local drupal_admin_password=""
  read drupal_admin_password
  while [ ${#drupal_admin_password} -gt 16 ]; do
    msg "PROMPT" "Drupal admin password: "
    read drupal_admin_password
  done

  # Print the values back to user for double-checking
  msg "COMMENT" "Double check these entries:"
  msg "COMMENT" "  Database name             :  $db_name"
  msg "COMMENT" "  Database username         :  $db_user_name"
  msg "COMMENT" "  Database user password will be randomly generated"
  echo ""
  msg "COMMENT" "  Drupal admin username     :  $drupal_admin_username"
  msg "COMMENT" "  Drupal admin password     :  $drupal_admin_password"

  count_from 3
  #read -t 1 -n 10000 discard
  read -p "Click [enter] to continue"
  echo ""

  local db_user_pass=$(apg -m 16 -x 16 -n 1 -M ncl)

  #=============================================================================
  #===  2. Create database
  #=============================================================================

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

  #=============================================================================
  #===  3. Install Drupal
  #=============================================================================


  msg "COMMENT" "Downloading Drupal 7.x"
  cd "$website_path"
  drush dl drupal-7.x
  mv drupal-7.x-dev/* .
  mv drupal-7.x-dev/.gitignore .
  mv drupal-7.x-dev/.htaccess .
  rmdir drupal-7.x-dev

  msg "COMMENT" "Installing Drupal"
  drush site-install -y standard --account-name=$drupal_admin_username --account-pass=$drupal_admin_password --db-url=mysql://$db_user_name:$db_user_pass@localhost/$db_name


  #=============================================================================
  #===  4. Print summary
  #=============================================================================

  msg "SUCCESS" "New Drupal website successfully created!"
  msg "COMMENT" "  Database name             :  $db_name"
  msg "COMMENT" "  Database username         :  $db_user_name"
  msg "COMMENT" "  Database user password    :  $db_user_pass"
  echo ""
  msg "COMMENT" "  Drupal admin username     :  $drupal_admin_username"
  msg "COMMENT" "  Drupal admin password     :  $drupal_admin_password"
}

# Purpose: Create a new WordPress installation
# Arguments:
#   1. website_path
function _new_wordpress {
  if [[ $# -ne 1  ]]; then
    msg "ERROR" "_new_wordpress takes one argument:"
    msg "ERROR" "  website_path: The full path to the directory to be install WordPress to"
    exit "${error[wrong_number_of_args]}"
  fi

  # 1. Gather site credentials
  # 2. Create database
  # 3. Install WordPress
  # 4. Print summary

  #=============================================================================
  #===  1. Gather Site Credentials
  #=============================================================================

  msg "COMMENT" "To create a new WordPress website,"
  msg "COMMENT" "please enter the new site's relevent information. Use this as an example:"
  echo " "
  msg "COMMENT" "If the new site would be \"www.myspecialwebsite.com\""
  msg "COMMENT" "  Website title           :  My Special Website"
  msg "COMMENT" "  Website URL             :  www.myspecialwebsite.com"
  echo ""
  msg "COMMENT" "  Database name           :  myspecialwebsite"
  msg "COMMENT" "  Database username       :  msw_admin"
  echo ""
  msg "COMMENT" "  WordPress admin username:  admin"
  msg "COMMENT" "  WordPress admin password:  some.complex.password"
  msg "COMMENT" "  WordPress admin email   :  myemail@mail.com"
  echo " "

  msg "PROMPT" "Website title: "
  local website_title=""
  read website_title
  while [ -z "$website_title" ]; do
    msg "PROMPT" "Website title: "
    read website_title
  done

  msg "PROMPT" "Website URL (without http): "
  local website_url=""
  read website_url
  while [ -z $website_url ]; do
    msg "PROMPT" "Website URL (without http): "
    read website_url
  done

  msg "PROMPT" "Database name: "
  local db_name=""
  read db_name
  while [ -z $db_name ]; do
    msg "PROMPT" "Database name: "
    read db_name
  done

  msg "PROMPT" "Database username (<16 char): "
  local db_user_name=""
  read db_user_name
  while [ ${#db_user_name} -gt 16 ]; do
    msg "PROMPT" "Database username (<16 char): "
    read db_user_name
  done

  msg "PROMPT" "WordPress admin username: "
  local wordpress_admin_username=""
  read wordpress_admin_username
  while [ ${#wordpress_admin_username} -gt 16 ]; do
    msg "PROMPT" "WordPress admin username: "
    read wordpress_admin_username
  done

  msg "PROMPT" "WordPress admin password: "
  local wordpress_admin_password=""
  read wordpress_admin_password
  while [ ${#wordpress_admin_password} -gt 16 ]; do
    msg "PROMPT" "WordPress admin password: "
    read wordpress_admin_password
  done

  msg "PROMPT" "WordPress admin email: "
  local wordpress_admin_email=""
  read wordpress_admin_email
  while [ ${#wordpress_admin_email} -gt 16 ]; do
    msg "PROMPT" "WordPress admin password: "
    read wordpress_admin_email
  done

  # Print the values back to user for double-checking
  msg "COMMENT" "Double check these entries:"
  msg "COMMENT" "  Website title           :  $website_title"
  msg "COMMENT" "  Website URL             :  $website_url"
  echo ""
  msg "COMMENT" "  Database name           :  $db_name"
  msg "COMMENT" "  Database username       :  $db_user_name"
  msg "COMMENT" "  Database user password will be randomly generated"
  echo ""
  msg "COMMENT" "  WordPress admin username:  $wordpress_admin_username"
  msg "COMMENT" "  WordPress admin password:  $wordpress_admin_password"
  msg "COMMENT" "  WordPress admin email   :  $wordpress_admin_email"

  count_from 3
  #read -t 1 -n 10000 discard
  read -p "Click [enter] to continue"
  echo ""

  local db_user_pass=$(apg -m 16 -x 16 -n 1 -M ncl)

  #=============================================================================
  #===  2. Create database
  #=============================================================================

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

  #=============================================================================
  #===  3. Install WordPress
  #=============================================================================

  msg "COMMENT" "Downloading WordPress"
  cd "$website_path"
  wp core download

  msg "COMMENT" "Installing WordPress"
  wp core config --dbname="$db_name" --dbuser="$db_user_name" --dbpass="$db_user_pass" --dbhost="localhost"
  wp core install --url="$website_url" --title="$website_title" --admin_user="$wordpress_admin_username" --admin_password="$wordpress_admin_password" --admin_email="$wordpress_admin_email"


  #=============================================================================
  #===  4. Print summary
  #=============================================================================

  msg "SUCCESS" "New WordPress website successfully created!"
  msg "COMMENT" "  Website title           :  $website_title"
  msg "COMMENT" "  Website URL             :  $website_url"
  echo ""
  msg "COMMENT" "  Database name             :  $db_name"
  msg "COMMENT" "  Database username         :  $db_user_name"
  msg "COMMENT" "  Database user password    :  $db_user_pass"
  echo ""
  msg "COMMENT" "  WordPress admin username  :  $wordpress_admin_username"
  msg "COMMENT" "  WordPress admin password  :  $wordpress_admin_password"
  msg "COMMENT" "  WordPress admin email     :  $wordpress_admin_email"
}
