#!/usr/bin/env bash
set -euo pipefail

DOCKER_CONFIG_DIR="config/docker"

#
# Ask magento directory
#
get_magento_root_directory() {
    printf "${BLUE}Magento root dir: ${COLOR_RESET}[${MAGENTO_DIR}] "
    read ANSWER_MAGENTO_DIR

    MAGENTO_DIR=${ANSWER_MAGENTO_DIR:-${MAGENTO_DIR}}
    if [ "${MAGENTO_DIR}" != "." ];
    then
        printf "${GREEN}Setting custom magento dir: '${MAGENTO_DIR}'${COLOR_RESET}\n"
        MAGENTO_DIR=$(sanitize_path "${MAGENTO_DIR}")
        printf "${YELLOW}"
        echo "------ ${DOCKER_COMPOSE_FILE} ------"
        sed_in_file "s#/html/var/composer_home#/html/${MAGENTO_DIR}/var/composer_home#gw /dev/stdout" "${DOCKER_COMPOSE_FILE}"
        echo "--------------------"
        echo "------ ${DOCKER_COMPOSE_FILE_MAC} ------"
        sed_in_file "s#/app:#/${MAGENTO_DIR}/app:#gw /dev/stdout" "${DOCKER_COMPOSE_FILE_MAC}"
        sed_in_file "s#/vendor#/${MAGENTO_DIR}/vendor#gw /dev/stdout" "${DOCKER_COMPOSE_FILE_MAC}"
        echo "--------------------"
        echo "------ ${DOCKER_CONFIG_DIR}/nginx/conf/default.conf ------"
        sed_in_file "s#/var/www/html#/var/www/html/${MAGENTO_DIR}#gw /dev/stdout" "${DOCKER_CONFIG_DIR}/nginx/conf/default.conf"
        echo "--------------------"
        printf "${COLOR_RESET}"
    fi
}

#
# Check if exit docker-compose file in magento root
#
check_if_docker_enviroment_exist() {
    if [[ -f "${MAGENTO_DIR}/docker-compose.yml" ]];
    then
        while true;
        do
            printf "\n${RED}----------------------------------------------------------------------${COLOR_RESET}\n"
            printf "%14s${RED}WE HAVE DETECTED DOCKER COMPOSE FILES!!! ${COLOR_RESET}\n\n"
            printf "%4s${RED}If you continue with this proccess these files will be removed${COLOR_RESET}\n"
            printf "${RED}----------------------------------------------------------------------${COLOR_RESET}\n\n"
            printf "${BLUE}Do you want continue? [y/n] ${COLOR_RESET}"
            read yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

#
# Copy File
#
copy() {
    local SOURCE_PATH=$1
    local TARGET_PATH=$2
    mkdir -p $(dirname ${TARGET_PATH})
    cp -Rf ${SOURCE_PATH} ${TARGET_PATH}
}

#
# Sanitize path
#
sanitize_path() {
    SANITIZED_PATH=${$1#/}
    SANITIZED_PATH=${SANITIZED_PATH#./}
    SANITIZED_PATH=${SANITIZED_PATH%/}
    echo "${SANITIZED_PATH}"
}

#
# replace in file
#
sed_in_file() {
    local SED_REGEX=$1
    local TARGET_PATH=$2
    if [[ "${MACHINE}" == "mac" ]];
    then
        sed -i '' "${SED_REGEX}" "${TARGET_PATH}"
    else
        sed -i "${SED_REGEX}" "${TARGET_PATH}"
    fi
}

#
# Add git bind paths in file
#
add_git_bind_paths_in_file() {
    GIT_FILES=$1
    FILE_TO_EDIT=$2
    SUFFIX_BIND_PATH=$3

    BIND_PATHS=""
    while read FILENAME_IN_GIT; do
        if [[ "${MAGENTO_DIR}" == "${FILENAME_IN_GIT}" ]] || \
            [[ "${MAGENTO_DIR}" == "${FILENAME_IN_GIT}/"* ]] || \
            [[ "${FILENAME_IN_GIT}" == "vendor" ]] || \
            [[ "${FILENAME_IN_GIT}" == "${DOCKER_COMPOSE_FILE%.*}"* ]]; then
            continue
        fi
        NEW_PATH="./${FILENAME_IN_GIT}:/var/www/html/${FILENAME_IN_GIT}"
        BIND_PATH_EXISTS=$(grep -q -e "${NEW_PATH}" ${FILE_TO_EDIT} && echo true || echo false)
        if [ "${BIND_PATH_EXISTS}" == true ]; then
            continue
        fi
        if [ "${BIND_PATHS}" != "" ]; then
            BIND_PATHS="${BIND_PATHS}\\
      " # IMPORTANT: This must be a new line with 6 indentation spaces.
        fi
        BIND_PATHS="${BIND_PATHS}- ${NEW_PATH}${SUFFIX_BIND_PATH}"

    done <<< "${GIT_FILES}"

    printf "${YELLOW}"
    echo "------ ${FILE_TO_EDIT} ------"
    sed_in_file "s|# {FILES_IN_GIT}|${BIND_PATHS}|w /dev/stdout" "${FILE_TO_EDIT}"
    echo "--------------------"
    printf "${COLOR_RESET}"
}

#
# Print setup information
#
print_info() {
    echo ""
    printf "${YELLOW}-------------------------- IMPORTANT INFO: --------------------------${COLOR_RESET}\n"
    echo ""
    echo "   Docker bind paths were automatically added here:"
    echo ""
    echo "      * ${DOCKER_COMPOSE_FILE_MAC}"
    echo ""
    echo "   Please check that they are right or edit them accordingly."
    echo "   Be aware that vendor cannot be bound for performance reasons."
    echo ""
    printf "${YELLOW}----------------------------------------------------------------------${COLOR_RESET}\n"

    echo ""
    printf "${GREEN}Hiberus docker set up successfully!${COLOR_RESET}\n"
    echo ""
}

#
# If there are arguments
#
get_requeriments() {
    # Check if command "jq" exists
    if ! command -v jq  &> /dev/null
    then
        printf "${RED}Required 'jq' not found${COLOR_RESET}"
        printf "${BLUE}https://stedolan.github.io/jq/download/${COLOR_RESET}"
        exit
    fi

    if [ "$#" != 0 ];
    then
        requeriments=$(cat "${DATA_DIR}/requeriments.json" | jq -r '.['\"$1\"']')
        change_requeriments 
    else
        if [ -f "${MAGENTO_DIR}/composer.lock" ];
        then
            MAGENTO_VERSION=$(cat "${MAGENTO_DIR}/composer.lock" | \
            jq -r '.packages | map(select(.name == "magento/product-community-edition"))[].version')
            printf "\n${YELLOW}Version detected: ${COLOR_RESET} ${MAGENTO_VERSION}\n"
            
        else
            echo -e "\n${RED}--------------------------------------------${COLOR_RESET}"
            echo -e "\n${RED} We need a magento project in ${MAGENTO_DIR}/ path${COLOR_RESET}"
            echo -e "\n You can clone a project and after execute ${BROWN}${COMMAND_BIN_NAME} setup${COLOR_RESET} or"
            echo -e " create a new magento project with ${BROWN}${COMMAND_BIN_NAME} create-project${COLOR_RESET}"
            echo -e "\n${RED}--------------------------------------------${COLOR_RESET}\n"
            exit 1
        fi
        requeriments=$(cat "${DATA_DIR}/requeriments.json" | jq -r '.['\"${MAGENTO_VERSION}\"']')
        change_requeriments
    fi
}

#
# Update git setting in docker-compose
#
set_settings() {
    printf "${GREEN}Setting up docker config files${COLOR_RESET}\n"
    copy "${COMMAND_BIN_DIR}/${DOCKER_CONFIG_DIR}/" "${DOCKER_CONFIG_DIR}"

    printf "${GREEN}Setting bind configuration for files in git repository${COLOR_RESET}\n"

    if [[ -f ".git/HEAD" ]];
    then
        GIT_FILES=$(git ls-files | awk -F / '{print $1}' | uniq)
        if [[ "${GIT_FILES}" != "" ]];
        then
            add_git_bind_paths_in_file "${GIT_FILES}" "${DOCKER_COMPOSE_FILE_MAC}" ":delegated"
        else
            echo " > Skipped. There are no files added in this repository"
        fi
    else
        echo " > Skipped. This is not a git repository"
    fi
}

#
# Set propierties in <root_project>/<docker_config>/propierties
#
save_properties() {
    printf "${GREEN}Saving custom properties file: '${DOCKER_CONFIG_DIR}/properties'${COLOR_RESET}\n"
    cat << EOF > ./${DOCKER_CONFIG_DIR}/properties
    MAGENTO_DIR="${MAGENTO_DIR}"
    BIN_DIR="${BIN_DIR}"
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME}"
EOF
}

#
# Print current requeriments
# 
print_requeriments() {
    services=$(echo "${requeriments}" | jq -r 'keys|join(" ")')

    printf "\n${CYAN}-------------------------------${COLOR_RESET}\n"
    printf "%10s${CYAN}REQUERIMENTS${COLOR_RESET}\n"
    printf "${CYAN}-------------------------------${COLOR_RESET}\n"
    for index in ${services}
    do
        value=$(echo "${requeriments}" | jq -r '.'${index}'')
        printf "%3s${CYAN}$index:${COLOR_RESET} ${value}\n"
    done
    printf "${CYAN}-------------------------------${COLOR_RESET}\n\n"
}

#
# Ask if user wants to change requeriments
# 
change_requeriments() {
    print_requeriments
    state="continue"
    while [[ $state == "continue" ]];
    do
        printf "${BLUE}Are you satisfied with these versions? [y/n] ${COLOR_RESET}"
        read yn
        case $yn in
            [Yy]* ) state="exit";;
            [Nn]* ) edit_versions; break;;
            * ) echo "Please answer yes or no.";;
        esac
    done
}

#
# Changes especific service value
# 
edit_version() {
    SERVICE_NAME=$1
    OPTIONS="$(cat "${DATA_DIR}/requeriments.json" | jq -r '[.[] | .'${SERVICE_NAME}'] | unique  | join(" ")')"

    printf "${BLUE}${SERVICE_NAME} version:\n${COLOR_RESET}"

    select SELECT_RESULT in ${OPTIONS};
    do
        if $(${TASKS_DIR}/in_list.sh "${SELECT_RESULT}" "${OPTIONS}");
        then
            break
        fi
        if $(${TASKS_DIR}/in_list.sh "${REPLY}" "${OPTIONS}");
        then
            PHP_VERSION_SELECT=${REPLY}
            break
        fi
        echo "invalid option '${REPLY}'"
    done

    requeriments=$(echo "${requeriments}" | jq -r '.'${SERVICE_NAME}'="'${SELECT_RESULT}'"')
}

#
# Select editable services and changes her value
# 
edit_versions() {
    printf "${BLUE}Choose service:\n${COLOR_RESET}"

    OPTIONS=$(echo "${requeriments} " | jq -r 'keys | join(" ")')

    select SELECT_RESULT in ${OPTIONS};
    do
        if $(${TASKS_DIR}/in_list.sh "${SELECT_RESULT}" "${OPTIONS}");
        then
            break
        fi
        if $(${TASKS_DIR}/in_list.sh "${REPLY}" "${OPTIONS}");
        then
            PHP_VERSION_SELECT=${REPLY}
            break
        fi
        echo "invalid option '${REPLY}'"
    done

    edit_version $SELECT_RESULT

    change_requeriments
}

get_magento_root_directory
check_if_docker_enviroment_exist
if [ "$#" != 0 ];
then
    get_requeriments $1
else
    get_requeriments
fi
"${TASKS_DIR}/write_from_docker-compose_templates.sh" "${requeriments}"
set_settings
save_properties

# Stop running containers in case that setup was executed in an already running project
${COMMANDS_DIR}/stop.sh

print_info
