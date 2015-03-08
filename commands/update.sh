#!/usr/bin/env bash
# Author: cbweaver (https://github.com/cbweaver)
# Description: Apply all pending updates

function _update {
  #opt_string=":a"
  #while getopts $opt_string opt; do
    #case $opt in
      #a)
        #echo "-a was triggered!" >&1
        #;;
      #\?)
        #echo "Invalid option: -$OPTARG" >&2
        #exit $errorcode_invalid_args
        #;;
    #esac
  #done

  # Fail without any arguments
  if [ $# -eq 0 ]; then
    usage update
    exit ${error[no_args]}
  fi

  # TODO: this function
}


# Description:
# Does function name
function update_drupal {
    cd $selected_site_path

    # Update without creating a backup.
    sudo su <<EOF
sudo su $owner
cd $selected_site_path
drush up --no-backup -y
EOF

    msg "SUCCESS" "Updates completed."
}

# Does function name
function update_wordpress {
    cd $selected_site_path

    # Update without creating a backup.
sudo su <<EOF
su $owner
cd $selected_site_path
wp core update
wp core update-db
EOF

    msg "SUCCESS" "Updates completed."
}


