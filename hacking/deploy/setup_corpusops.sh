#!/usr/bin/env bash
set -e

if [ -e .ansible/scripts/ansible_deploy_env ];then
    . .ansible/scripts/ansible_deploy_env
fi

if [[ -n ${SKIP_COPS_SETUP-} ]];then die_ 0 "-> Skip corpusops setup";fi

# Run install only
if [[ -z "${SKIP_COPS_INSTALL}" ]] \
    && [ ! -e $LOCAL_COPS_ROOT/venv/bin/ansible ];then
    log "Install corpusops"
    if ! call_cops_installer $COPS_INSTALL_ARGS;then die_ 23 "Install error";fi
fi

# Update corpusops code, ansible & roles
if [[ -z "${SKIP_COPS_UPDATE}" ]];then
    log "Refesh corpusops"
    if ! call_cops_installer  $COPS_UPDATE_ARGS;then die_ 24 "Update error";fi
else
    log "-> Skip corpusops update"
fi
