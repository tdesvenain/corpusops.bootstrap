#!/usr/bin/env bash
set -e

COPS_SCRIPTS_DIR="${COPS_SCRIPTS_DIR:-$(cd "$(dirname "$0")" && pwd)}"
if [ -e "$COPS_SCRIPTS_DIR/ansible_deploy_env" ];then
    . "$COPS_SCRIPTS_DIR/ansible_deploy_env"
fi

usage() {
    NO_HEADER=y die '
[A_ENV_NAME= ] \\
[A_CRYPTED_VAULTS= ] \\
    '$0' [vaultfile1] [vaultfile2] ...

Wrapper to call ansible-vault with the selected vault password file, according to $A_ENV_NAME


'
}

parse_cli $@
ensure_ansible_env

A_CRYPTED_VAULTS=${@:-${A_CRYPTED_VAULTS}}

edit_vault() {
    local vault=$1
    if [ -e $vault ];then mode=edit;else mode=create;fi
    debug "${mode}: $vault"
    vv ansible-vault $mode $vaultpwfiles $vault
}

for VAULT in $A_CRYPTED_VAULTS;do edit_vault $VAULT;done
