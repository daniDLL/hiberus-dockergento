#!/usr/bin/env bash
set -euo pipefail

source "$COMPONENTS_DIR"/print_message.sh

print_info "Rebuilding and starting containers in detached mode\n"

if [ "$#" == 0 ]; then
    "$COMMANDS_DIR"/stop.sh
    $DOCKER_COMPOSE up --build -d nginx
else
    "$COMMANDS_DIR"/stop.sh "$@"
    $DOCKER_COMPOSE up --build -d "$@"
fi

"$TASKS_DIR"/validate_bind_mounts.sh

if [[ "$MACHINE" == "linux" ]]; then
    print_default "Waiting for everything to spin up...\n"
    sleep 5
    print_processing "Fixing permissions"
    "$TASKS_DIR"/fix_linux_permissions.sh
    print_processing "Permissions fix finished"
    print_processing "Configuring self-routing domains..."
    "$TASKS_DIR"/set_etc_hosts.sh
fi
