#!/usr/bin/env bash
set -euo pipefail

if [[ "$MACHINE" == "mac" ]]; then
    BIND_MOUNT_PATH=$($TASKS_DIR/get_bind_mount_path.sh "${WORKDIR_PHP}/$MAGENTO_DIR/vendor")

    if [[ ${BIND_MOUNT_PATH} != false ]]; then
        echo ""
        echo -e "${RED}Vendor cannot be a bind mount. Please do the following:${COLOR_RESET}\n"
        echo ""
        echo "  1. Remove from your docker-compose configuration:"
        echo "      - ./<host_path>:${BIND_MOUNT_PATH}"
        echo ""
        echo "  2. Execute:"
        echo "      $COMMAND_BIN_NAME rebuild"
        echo ""
        exit 1
    fi
fi
