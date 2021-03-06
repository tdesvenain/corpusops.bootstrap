#!/usr/bin/env bash
set -e


COPS_SCRIPTS_DIR="${COPS_SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
if [ -e "$COPS_SCRIPTS_DIR/ansible_deploy_env" ];then
    . "$COPS_SCRIPTS_DIR/ansible_deploy_env"
fi


usage() {
    NO_HEADER=y die '

    '$0''"

$(call_cops_installer --help)
"
}
parse_cli $@

if [[ -n ${SKIP_COPS_SETUP-} ]];then die_ 0 "-> Skip corpusops setup";fi

# Run install only
if [[ -z "${SKIP_COPS_INSTALL}" ]] \
    && [ ! -e $LOCAL_COPS_ROOT/venv/bin/ansible ];then
    log "Install corpusops"
    if ! call_cops_installer $COPS_INSTALL_ARGS $@;then die_ 23 "Install error";fi
fi

# Update corpusops code, ansible & roles
if [[ -z "${SKIP_COPS_UPDATE}" ]];then
    log "Refresh corpusops"
    if ! call_cops_installer  $COPS_UPDATE_ARGS $@;then die_ 24 "Update error";fi
else
    log "-> Skip corpusops update"
fi
