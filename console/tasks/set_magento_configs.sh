#!/usr/bin/env bash
set -euo pipefail

#
# Set Domain in properties project file if DOMAIN variable is not setted
#
set_current_domain() {
    # Check if magento database is initialized
    exist_magento_db=$(query "SHOW TABLES LIKE 'core_config_data';")

    if [[ -n $exist_magento_db && -z ${DOMAIN+x} ]]; then
        # Get current domain
        url=$(query "SELECT value FROM core_config_data WHERE path='web/secure/base_url';")

        # Save domian
        DOMAIN=$(awk -F/ '{print $3}' <<< $url)

         # Add domain in properties project file
        echo "  DOMAIN=\"$DOMAIN\"" >> $docker_config_dir/properties
    fi
}

#
# Execute all neccesary commands to prepare local environment 
#
set_settings_for_develop() {
    source "$COMPONENTS_DIR"/print_message.sh

    # Get domain if not exists
    if [[ -z ${DOMAIN+x} ]]; then
        source "$COMPONENTS_DIR"/input_info.sh
        get_domain
    fi

    option_keys=$(jq -r 'keys[]' < "$DATA_DIR"/local_settings.json)

    for key in $option_keys; do
        # Replace '_' to ':' to get magento format command
        magento_command=$(echo $key | sed 's/_/:/')

        # Get all options to configurate
        command_data=$(jq -r '."'$key'"[] | 
            select(.value == "URL").value = "https://'$DOMAIN'/" |
            select(.value == "DOMAIN").value = "'$DOMAIN'" |
            "'$magento_command'=" + .path + "=" + .value' "$DATA_DIR"/local_settings.json)

        # Replace '=' to ' ' and execute each command
        for data in $command_data; do
            final_command=$(echo "$data" | sed 's/=/ /g')
            print_processing "bin/magento $final_command"
            "$COMMANDS_DIR"/magento.sh $final_command
        done
    done
}

set_settings_for_develop