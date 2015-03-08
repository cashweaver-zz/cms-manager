#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Configuration variables

declare -A config

#=============================================================================
#===  Sanity checks
#=============================================================================
config[web_administrator_username]="bidwelltech"


#=============================================================================
#===  Backups
#=============================================================================
config[backup_basepath]="/home/bidwelltech/website_backups"


#=============================================================================
#===  For testing website types
#=============================================================================
config[website_signature_wordpress]="./wp-config.php"
config[website_signature_drupal]="./sites/default/settings.php"
