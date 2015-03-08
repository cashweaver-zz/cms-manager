#!/usr/bin/env bash
# Description:
# TODO: Write description

function new {
  short_options="fp"
  long_options="prebuild,fresh"
  getopt_results=$(getopt -s bash --options $short_options --long $long_options -- "$@")

  # Ensure arguments were successfully parsed
  if [[ $? -ne 0 ]]; then
    usage new
    exit "${error[bad_arg_parse]}"
  elif [[ "$1" = "--" ]]; then
    usage new
    exit "${error[bad_arg]}"
  fi

  local prebuild=false
  local fresh=false
  local mysql=false

  eval set -- "$getopt_results"
  local website_path=""
  local save_dir=""
  while true; do
    case "$1" in
      -p|--prebuild)
        prebuild=true
        shift
        ;;
      -f|--fresh)
        fresh=true
        shift
        ;;
      --)
        shift
        break
        ;;
      *)
        usage new
        exit "${error[bad_arg]}"
        ;;
    esac
  done

  # Fail if more than one option are set
  if [[ ("$prebuild" = true && "$fresh" = true) ]]; then
    msg "ERROR" "Cannot select multiple options. Pick one!"
    usage new
    exit ${error[bad_arg]}
  fi

  if [[ "$prebuild" = true ]]; then
    _create_new_drupal_site_from_prebuild
  elif [[ "$fresh" = true ]]; then
    _create_new_drupal_site_from_source
  fi
}

function _gather_site_credentials {
  msg "COMMENT" "please enter the new site's relevent information. Use this as an example:"
  echo " "
  msg "COMMENT" "If the new site would be \"mysalonchico.bidwelltech.com\""
  msg "COMMENT" "\tSite Name               :  My Salon Chico"
  msg "COMMENT" "\tHost name               :  mysalonchico.bidwelltech.com"
  msg "COMMENT" "\tDB Username Prefix      :  msc_"
  echo " "

  msg "PROMPT" "Site name (<32 char): "
  read SITE_NAME
  if [ "${#SITE_NAME}" -gt 32 ] || [ -z "$SITE_NAME" ]
    then ERROR_PRESENT="yes"
    else ERROR_PRESENT=""
  fi
  while [ -n "$ERROR_PRESENT" ]; do
    msg "PROMPT" "Site name (<32 char): "
    read SITE_NAME
    if [ ${#SITE_NAME} -gt 32 ] || [ -z "$SITE_NAME" ]
      then ERROR_PRESENT="yes"
      else ERROR_PRESENT=""
    fi
  done

  msg "PROMPT" "Host name (without \"http://\"): "
  read HOST_NAME
  # Test for "http://"
  local ERROR_HTTP_PRESENT=""
  if grep '.*http:\/\/.*' <<<$HOST_NAME
    then ERROR_HTTP_PRESENT="yes"
    else ERROR_HTTP_PRESENT=""
  fi
  while [ -z "$HOST_NAME" ] || [ -n "$ERROR_HTTP_PRESENT" ]; do
    msg "PROMPT" "Site URL without \"http://\": "
    read HOST_NAME
    if grep '.*http:\/\/.*' <<<$HOST_NAME
      then ERROR_HTTP_PRESENT="yes"
      else ERROR_HTTP_PRESENT=""
    fi
  done

  SUBDOMAIN_NAME=$(echo $HOST_NAME | cut -f1 -d.)
  DOMAIN_NAME=$(echo $HOST_NAME | cut -f2 -d.)
  TOP_LEVEL_DOMAIN_NAME=$(echo $HOST_NAME | cut -f3 -d.)

  DB_NAME="${DOMAIN_NAME}_${SUBDOMAIN_NAME}"
  # Maximum length of MySQL database name is 64 characters
  DB_NAME=${DB_NAME:0:63}

  msg "PROMPT" "DB username prefix (<8 char): "
  read DB_USER_NAME_PREFIX
  if [ ${#DB_USER_NAME_PREFIX} -gt 8 ] || [ -z "$DB_USER_NAME_PREFIX" ]
    then ERROR_PRESENT="yes"
    else ERROR_PRESENT=""
  fi
  while [ -n "$ERROR_PRESENT" ]; do
    msg "PROMPT" "DB username prefix (<8 char): "
    read DB_USER_NAME_PREFIX
    if [ ${#DB_USER_NAME_PREFIX} -gt 8 ] || [ -z "$DB_USER_NAME_PREFIX" ]
      then ERROR_PRESENT="yes"
      else ERROR_PRESENT=""
    fi
  done

  SFTP_USER_NAME="$DOMAIN_NAME-$SUBDOMAIN_NAME"

  # Print the values back to user for double-checking
  msg "COMMENT" "Double check these entries:"
  msg "COMMENT" "    Site Name     : $SITE_NAME"
  msg "COMMENT" "    Site URL      : http://$HOST_NAME"
  echo ""
  msg "COMMENT" "    DB Name       : $DB_NAME"
  msg "COMMENT" "    DB User Prefix: $DB_USER_NAME_PREFIX"
  msg "COMMENT" "    DB User Password will be randomly generated"
  echo ""
  msg "COMMENT" "    SFTP User Name: $SFTP_USER_NAME"
  msg "COMMENT" "    SFTP user password will be randomly generated"

  # Sleep to ensure the double-check isn't passed over by overzealous button mashing
  echo -en "3"
  sleep 1
  echo -en "\r2"
  sleep 1
  echo -en "\r1"
  sleep 1
  echo -en "\r"
  read -t 1 -n 10000 discard
  read -p "Click [enter] to confirm"

  # Generate some random strings for the DB_USER_NAME suffix and DB_USER_PASSWORD
  msg "COMMENT" "Generating passwords..."
  DB_USER_NAME="$DB_USER_NAME_PREFIX$(apg -m 8 -x 8 -n 1 -M ncl)"
  DB_USER_PASSWORD=$(apg -m 16 -x 16 -n 1 -M ncl)
  SFTP_USER_PASSWORD=$(apg -m 16 -x 16 -n 1 -M ncl)
}

function _create_database {
    msg "PROMPT" "MySQL: Please enter root password Mysql"
    echo ""
    CMD="create database $DB_NAME; create user $DB_USER_NAME; set password for $DB_USER_NAME = password('$DB_USER_PASSWORD'); GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER, CREATE TEMPORARY TABLES, LOCK TABLES on $DB_NAME.* to $DB_USER_NAME@localhost identified by '$DB_USER_PASSWORD'; flush privileges;"
    mysqlcmd_out=$(mysql -uroot -p -e "$CMD" 2>&1)
    mysqlcmd_rc=$?
    if [[ $mysqlcmd_rc -eq 0 ]]; then
        msg "SUCCESS" "MySQL: Successfully created new db and users"
    else
        msg "ERROR" "MySql error. Check the db name, username prefix, and password to ensure they are valid."
        msg "ERROR" "rc = $mysqlcmd_rc"
        msg "ERROR" "Exiting."
        exit
    fi
}

function _create_apache_entry {
  msg "COMMENT" "Apache: Creating new entry"
  local OLD="/etc/apache2/sites-available/drupal7_prebuild.misystems.net.conf"
  local NEW="/etc/apache2/sites-available/${HOST_NAME}.conf"
  sudo cp $OLD $NEW

  # Configure new file
  sudo sed -i -r 's/drupal7_prebuild/'$SUBDOMAIN_NAME'/g' $NEW
  sudo sed -i -r 's/misystems/'$DOMAIN_NAME'/g' $NEW
  sudo sed -i -r 's/net/'$TOP_LEVEL_DOMAIN_NAME'/g' $NEW
  if [[ "$SUBDOMAIN_NAME" == "www" ]]; then
    # Uncomment the alias ($DOMAIN_NAME.$TOP_LEVEL_DOMAIN_NAME)
    sudo sed -i -r 's/#ServerAlias/ServerAlias/' $NEW
  fi

  sudo a2ensite $HOST_NAME
}

function _restart_apache {
  msg "COMMENT" "Apache: Restarting"
  sudo /etc/init.d/apache2 restart
}

function _print_summary {
    msg "SUCCESS" "Success! A new instance of the drupal prebuild has been generated."
    echo ""
    echo ""
    msg "COMMENT" "Credentials"
    msg "COMMENT" "=================================================="
    echo ""
    msg "COMMENT" "    Site Name : $DOMAIN_NAME"
    msg "COMMENT" "    Site URL  : $HOST_NAME"
    echo ""
    msg "COMMENT" "    DB Name     : $DB_NAME"
    msg "COMMENT" "    DB Username : $DB_USER_NAME"
    msg "COMMENT" "    DB Password : $DB_USER_PASSWORD"
    echo ""
    msg "COMMENT" "    SFTP User Name     : $SFTP_USER_NAME"
    msg "COMMENT" "    SFTP User Password : $SFTP_USER_PASSWORD"
    echo ""
    msg "COMMENT" "    Drupal admin account info:"
    msg "COMMENT" "        Username: ${config[web_administrator_username]}_admin"
    msg "COMMENT" "        Username: $DRUPAL_ADMIN_PASSWORD"
    echo ""
    echo ""
    msg "COMMENT" "DNS"
    msg "COMMENT" "=================================================="
    msg "COMMENT" "    This script doesn't set up DNS. You must do that manually:"
    msg "COMMENT" "    Visit: https://my.rackspace.com/portal/domain/show/342525"
    echo "" 
    msg "COMMENT" "    Alternatively, you can set up a local hostfile if the website"
    msg "COMMENT" "    isn't ready for live DNS:"
    msg "COMMENT" "        Add the following to your Windows hostfile"
    msg "COMMENT" "        located at C:\\Windows\\System32\\drivers\\etc:"
    msg "COMMENT" "            50.56.195.186 $HOST_NAME"
}

function _set_ownership {
  msg "COMMENT" "Creating new sftp user: $SFTP_USER_NAME"
  sudo useradd -M -N -g sftponly $SFTP_USER_NAME --home=/var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME
  echo $SFTP_USER_NAME:$SFTP_USER_PASSWORD | sudo chpasswd

  msg "COMMENT" "Setting ownership and permissions for /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html and sub-folders"
  cd /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME
  sudo chown -R $SFTP_USER_NAME:${config[web_administrator_username]} public_html
  sudo chmod 775 public_html
  sudo find public_html -type d -exec chmod u=rwx,g=rwx,o=rx '{}' \;
  sudo find public_html -type f -exec chmod u=rw,g=rw,o=r '{}' \;

  msg "COMMENT" "Setting ownership and permissions for /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/sites/default/files and sub-folders"
  sudo chown -R :www-data public_html/sites/default/files
  sudo chmod 775 -R public_html/sites/default/files
  sudo find public_html/sites/default/files -type d -exec chmod ug=rwx,o= '{}' \;
  sudo find public_html/sites/default/files -type f -exec chmod ug=rw,o= '{}' \;

  sudo find public_html -type d -exec chmod g+s '{}' \;
}

function _install_drupal {
  cd /var/www/

  msg "COMMENT" "Creating /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME"
  sudo mkdir -p $DOMAIN_NAME/$SUBDOMAIN_NAME

  local PREBUILD_PUBLIC_HTML_PATH="/var/www/misystems/drupal7_prebuild/public_html/"
  msg "COMMENT" "Copying drupal prebuild files"
  sudo cp -r $PREBUILD_PUBLIC_HTML_PATH /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html/
}


function _configure_drupal {
  if [[ "$SUBDOMAIN_NAME" == "www" ]]; then
    local THEME_NAME="${DOMAIN_NAME}"
  else
    local THEME_NAME="${SUBDOMAIN_NAME}"
  fi

  msg "COMMENT" "Renaming theme files"
  cd /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html/sites/all/themes/
  sudo mv drupal7_prebuild $THEME_NAME
  sudo mv $THEME_NAME/drupal7_prebuild.info $THEME_NAME/$THEME_NAME.info

  msg "COMMENT" "Updating sites/default/settings.php"
  local SETTINGS_PHP=/var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html/sites/default/settings.php
  # Update database credentials
  sudo sed -i -r 's/misystems_drupal7_prebuild/'$DB_NAME'/g' $SETTINGS_PHP
  sudo sed -i -r 's/pre_d7_tNG0dwR0/'$DB_USER_NAME'/g' $SETTINGS_PHP
  sudo sed -i -r 's/V7KhRVAD9CGYvZpC/'$DB_USER_PASSWORD'/g' $SETTINGS_PHP
  # Update $base_url
  sudo sed -i -r 's/drupal7_prebuild.misystems.net/'$SUBDOMAIN_NAME'.'$DOMAIN_NAME'.'$TOP_LEVEL_DOMAIN_NAME'/' $SETTINGS_PHP

  msg "COMMENT" "Updating $THEME_NAME.info"
  local THEME_INFO=/var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html/sites/all/themes/$THEME_NAME/$THEME_NAME.info
  sudo sed -i -r "s/DrupalPrebuildTheme/$SITE_NAME/" $THEME_INFO

  msg "COMMENT" "Updating template.php"
  local TEMPLATE_PHP=/var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html/sites/all/themes/$THEME_NAME/template.php
  sudo sed -i -r "s/drupal7_prebuild/$THEME_NAME/" $TEMPLATE_PHP

  msg "COMMENT" "Database: Dumping prebuild database into /tmp"
  cd /var/www/misystems/drupal7_prebuild/public_html/
  drush cc all
  local PREBUILD_DATABASE_PATH=/tmp/drupal7_prebuild-$DOMAIN_NAME-$SUBDOMAIN_NAME.sql
  drush sql-dump > $PREBUILD_DATABASE_PATH -y

  msg "COMMENT" "Database: Installing prebuild database"
  cd /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/public_html
  drush sql-drop -y
  drush sql-cli < $PREBUILD_DATABASE_PATH -y

  msg "COMMENT" "Updating Drupal and all Plugins"
  drush up -y

  msg "COMMENT" "Setting and configuring theme"
  # Set theme
  drush pm-enable $THEME_NAME -y
  drush vset theme_default $THEME_NAME

  # Set theme variables
  drush vset --yes site_name "$SITE_NAME"
  drush vset --yes maintenance_mode_message "$SITE_NAME is currently under maintenance. We should be back shortly. Thank you for your patience."
  drush vset --yes webform_default_from_name "$SITE_NAME"

  msg "COMMENT" "Setting admin credentials"
  DRUPAL_ADMIN_PASSWORD=$(apg -m 16 -x 16 -n 1 -M ncl)
  drush upwd "${config[web_administrator_username]}_admin" --password="$DRUPAL_ADMIN_PASSWORD"
}

function _create_new_drupal_site_from_prebuild {
  #------------------------------------------------------------------------------
  # Gather information about new site and database, store in variables
  msg "COMMENT" "To create a clone of the Drupal prebuild,"
  _gather_site_credentials

  #------------------------------------------------------------------------------
  # Create database
  _create_database

  #------------------------------------------------------------------------------
  # Install wp to new dir
  _install_drupal
  _set_ownership
  _configure_drupal

  #------------------------------------------------------------------------------
  # Create new entry in apache2
  _create_apache_entry
  _restart_apache

  #------------------------------------------------------------------------------
  # Done. Print summary message
  _print_summary
}

function _install_fresh_drupal {
  cd /var/www/

  msg "COMMENT" "Creating /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME"
  sudo mkdir -p $DOMAIN_NAME/$SUBDOMAIN_NAME

  cd /var/www/$DOMAIN_NAME/$SUBDOMAIN_NAME/
  msg "COMMENT" "Downloading drupal-7.x files"
  sudo drush dl drupal-7.x
  sudo mv drupal-7.x-dev public_html

  drush site-install standard --account-name=admin --account-pass=admin --db-url=mysql://$DB_USER_NAME:$DB_USER_PASSWORD@localhost/$DB_NAME
}

function _create_new_drupal_site_from_source {
  msg "COMMENT" "To create a fresh Drupal installation,"
  _gather_site_credentials
  _create_database

  _install_fresh_drupal
  _set_ownership

  _create_apache_entry
  _restart_apache

  _print_summary
}
