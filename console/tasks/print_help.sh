#!/bin/bash
set -euo pipefail

#
# Print al all commands info (native and custom)
#
print_commands_info() {
  local COMMANDS_OUTPUT=""
  local COMMANDS_PATH="${COMMANDS_DIR}"
  local FILE_CONTENT="${FILE}"
  local COMMAND_COLOR="${GREEN}"
  local TITLE="Command list"
  local UNDERLINE="------------\n"

  if [ $# -gt 0 ] && [ "$1" == 'custom' ]; then
    COMMANDS_PATH="${CUSTOM_COMMANDS_DIR}"
    TITLE="Custom command list"
    UNDERLINE="-------------------\n"

    if [ -f "${CUSTOM_COMMANDS_DIR}/command_descriptions.json" ]; then
      FILE_CONTENT=$(cat "${CUSTOM_COMMANDS_DIR}/command_descriptions.json")
    else
      FILE_CONTENT="{}"
    fi

    COMMAND_COLOR="${PURPLE}"
  fi

  if [ ! -d "${COMMANDS_PATH}" ]; then
    exit 0
  fi

  local FILES
  FILES=$(find "${COMMANDS_PATH}" -name '*.sh' | wc -l)

  if [ "$FILES" -gt 0 ]; then
    echo -e "${COMMAND_COLOR}\n${TITLE}${COLOR_RESET}"
    echo -e "${COMMAND_COLOR}${UNDERLINE}${COLOR_RESET}"

    for script in "${COMMANDS_PATH}"/*.sh; do
      COMMAND_BASENAME=$(basename "${script}")
      COMMAND_NAME=${COMMAND_BASENAME%.sh}
      COMMAND_DESC_PROPERTY=$(echo "${FILE_CONTENT}" | jq -r 'if ."'"${COMMAND_NAME}"'".description then ."'"${COMMAND_NAME}"'".description else "" end')
      printf "   ${COMMAND_COLOR}%-20s${COLOR_RESET} %s\n" "${COMMAND_NAME}" "${COMMAND_DESC_PROPERTY}"
    done

    printf "\n\n"
  fi
}

#
# Print native commands and custom commands info
#
print_all_commands_help_info() {
  local COMMANDS_OUTPUT
  local COMMANDS_OUTPUT_ALL
  COMMANDS_OUTPUT=$(print_commands_info)
  COMMANDS_OUTPUT_ALL=$(print_commands_info "custom")
  echo "${COMMANDS_OUTPUT}"
  echo "${COMMANDS_OUTPUT_ALL}"
}

#
# Print options data array
#
print_opts() {
  local LENGTH
  LENGTH=$(echo "${FILE}" | jq -r '."'"$1"'".opts | length')

  if [[ $LENGTH -gt 0 ]]; then
    echo -e "${YELLOW}Options:${COLOR_RESET}\n"
  fi

  for ((i = 0; i < $LENGTH; i++)); do
    name=$(echo "${FILE}" | jq -r '."'"$1"'".opts['"$i"'].name')
    description=$(echo "${FILE}" | jq -r '."'"$1"'".opts['"$i"'].description')
    printf "   ${GREEN}%-20s${COLOR_RESET}%s\n" "${name}" "${description}"
  done

  if [[ $LENGTH -gt 0 ]]; then
    printf "\n"
  fi
}

#
# Print arguments data array
#
print_args() {
  local LENGTH
  LENGTH=$(echo "${FILE}" | jq -r '."'"$1"'".args | length')

  if [[ $LENGTH -gt 0 ]]; then
    echo -e "${YELLOW}Arguments:${COLOR_RESET}\n"
  fi

  for ((i = 0; i < $LENGTH; i++)); do
    name=$(echo "${FILE}" | jq -r '."'"$1"'".args['"$i"'].name')
    description=$(echo "${FILE}" | jq -r '."'"$1"'".args['"$i"'].description')
    printf "   ${GREEN}%-20s${COLOR_RESET}%s\n" "${name}" "${description}"
  done

  if [[ $LENGTH -gt 0 ]]; then
    printf "\n"
  fi
}

#
# Define usage
#
usage() {
  if [ $# == 0 ]; then
    print_all_commands_help_info
  else
    local PARAMS
    local COMMAND_NAME=$1

    PARAMS=$(echo "${FILE}" | jq -r '."'"${COMMAND_NAME}"'" | if length > 0 then keys[] else false end')

    if [[ $PARAMS ]]; then
      # Prinf usage seccion
      if [[ "$PARAMS" == *"usage"* ]]; then

        local usage
        usage=$(echo "${FILE}" | jq -r '."'"$COMMAND_NAME"'".usage')
        echo -e  "${YELLOW}Usage:${COLOR_RESET}"
        printf "%3s${COMMAND_BIN_NAME} ${usage}\n\n"
        
      fi

      # Prinf example seccion
      if [[ "$PARAMS" == *"example"* ]]; then
        local example
        example=$(echo "${FILE}" | jq -r '."'"$COMMAND_NAME"'".example')
        echo -e  "${YELLOW}Example:${COLOR_RESET}"
        printf "%3s${COMMAND_BIN_NAME} ${example}\n\n"
      fi

      # Prinf description seccion
      if [[ "$PARAMS" == *"description"* ]]; then
        local description
        description=$(echo "${FILE}" | jq -r '."'"$COMMAND_NAME"'".description')
        echo -e  "${YELLOW}Description:${COLOR_RESET}"
        printf "%3s${description}\n\n"
      fi

      # Prinf options seccion
      if [[ "$PARAMS" == *"opts"* ]]; then
        print_opts "$COMMAND_NAME"
      fi

      # Prinf options seccion
      if [[ "$PARAMS" == *"args"* ]]; then
        print_args "$COMMAND_NAME"
      fi
    fi
  fi
}

FILE="$(cat "${DATA_DIR}/command_descriptions.json")"

usage "$@"
