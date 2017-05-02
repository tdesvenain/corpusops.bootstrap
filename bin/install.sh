#!/usr/bin/env bash
# SEE CORPUSOPS DOCS FOR FURTHER INSTRUCTIONS

LOGGER_NAME=cs

cd "$(dirname "$(readlink -f ${0})")/.."
sc=bin/cops_shell_common
[[ ! -e $sc ]] && echo "missing $sc" >&2
. $sc || exit 1

CORPUSOPS_VERSION="1.0"
THIS="$(readlink -f "${0}")"
LAUNCH_ARGS=${@}

ensure_last_virtualenv() {
    venv=$(get_command virtualenv)
    if ( [[ "x${venv}" == "x/usr/bin/virtualenv" ]] \
         || [[ "x${venv}" == "x/bin/virtualenv" ]] ); then
        if version_lt "$(virtualenv --version)" "15.1.0"; then
            log "Installing last version of virtualenv"
            if has_command pip;then
                vv $(may_sudo) pip install --upgrade virtualenv
            elif has_command easy_install;then
                vv $(may_sudo) easy_install -U virtualenv
            fi
        fi
    fi
}

test_online() {
    ping -W 10 -c 1 8.8.8.8 1>/dev/null 2>/dev/null
    if [ "x${?}" = "x0" ] || [ "x${TRAVIS}" != "x" ]; then
        return 0
    fi
    return 1
}

get_conf() {
    key="${1}"
    echo $(cat "${W}/.corpusops/$key" 2>/dev/null)
}

store_conf() {
    key="${1}"
    val="${2}"
    if [ ! -e "${W}/.corpusops" ]; then
        mkdir -p "${W}/.corpusops"
        chmod 700 "${W}/.corpusops"
    fi
    if [ -e "${W}/.corpusops" ]; then
        echo "${val}">"${W}/.corpusops/${key}"
    fi
}

remove_conf() {
    for key in $@;do
        if [ -e "${W}/.corpusops/${key}" ]; then
            rm -f "${W}/.corpusops/${key}"
        fi
    done
}

get_default_knob() {
    key="${1}"
    stored_param="$(get_conf ${key})"
    cli_param="${2}"
    default="${3:-}"
    if [ "x${cli_param}" != "x" ]; then
        setting="${cli_param}"
    elif [ "x${stored_param}" != "x" ]; then
        setting="${stored_param}"
    else
        setting="${default}"
    fi
    if [ "x${stored_param}" != "x${setting}" ];then
        store_conf "${key}" "${setting}"
        stored_param="$(get_conf ${key})"
    fi
    if [ "x${stored_param}" == "x${default}" ]; then
        remove_conf "${key}"
    fi
    echo "${setting}"
}

get_corpusops_orga_url() {
    get_default_knob corpusops_orga_url "${CORPUSOPS_ORGA_URL}" \
        "https://github.com/corpusops"
}

get_corpusops_url() {
    get_default_knob corpusops_url "${CORPUSOPS_URL}" \
        "$(get_corpusops_orga_url)/corpusops.bootstrap.git"
}

get_ansible_url() {
    get_default_knob ansible_url "${ANSIBLE_URL}" \
        "$(get_corpusops_orga_url)/ansible.git"
}

get_corpusops_branch() {
    get_default_knob corpusops_branch "${CORPUSOPS_BRANCH}" "master"
}

get_ansible_branch() {
    get_default_knob ansible_branch "${ANSIBLE_BRANCH}" "stable-2.2"
}

set_vars() {
    reset_colors
    SCRIPT_DIR="${W}/bin"
    QUIET=${QUIET:-}
    CHRONO="$(get_chrono)"
    DEBUG="${DEBUG-}"
    TRAVIS_DEBUG="${TRAVIS_DEBUG:-}"
    DO_NOCONFIRM="${DO_NOCONFIRM-}"
    DO_VERSION="${DO_VERSION-"no"}"
    DO_ONLY_RECONFIGURE="${DO_ONLY_RECONFIGURE-""}"
    DO_ONLY_SYNC_CODE="${DO_ONLY_SYNC_CODE-""}"
    DO_SYNC_CODE="${DO_SYNC_CODE-"y"}"
    DO_SYNC_PLAYBOOKS="${DO_SYNC_PLAYBOOKS-${DO_SYNC_CODE}}"
    DO_SYNC_ROLES="${DO_SYNC_ROLES-${DO_SYNC_CODE}}"
    DO_SYNC_CORE="${DO_SYNC_CORE-${DO_SYNC_CODE}}"
    DO_INSTALL_PREREQUISITES="${DO_INSTALL_PREREQUISITES-"y"}"
    DO_SETUP_VIRTUALENV="${DO_SETUP_VIRTUALENV-"y"}"
    NONINTERACTIVE="${NONINTERACTIVE-${DO_NOCONFIRM}}"
    CORPUSOPS_ORGA_URL="${CORPUSOPS_ORGA_URL-}"
    CORPUSOPS_URL="${CORPUSOPS_URL-}"
    CORPUSOPS_BRANCH="${CORPUSOPS_BRANCH-}"
    ANSIBLE_URL="${ANSIBLE_URL-}"
    ANSIBLE_BRANCH="${ANSIBLE_BRANCH-}"
    PYTESTRPM="${PYTESTRPM:-python-test-2.7.5-48.el7.x86_64.rpm}"
    CENTOSMIRROR="${CENTOSMIRROR:-http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64/Packages/}"
    if [ "x${DO_VERSION}" != "xy" ];then
        DO_VERSION="no"
    fi
    TMPDIR="${TMPDIR:-"/tmp"}"
    BASE_PACKAGES_FILE="${W}/requirements/os_packages.${DISTRIB_ID}"
    EXTRA_PACKAGES_FILE="${W}/requirements/os_extra_packages.${DISTRIB_ID}"
    if [ -e "${BASE_PACKAGES_FILE}" ];then
        BASE_PACKAGES=$(cat "${BASE_PACKAGES_FILE}")
    else
        BASE_PACKAGES=""
    fi
    if [ -e "${EXTRA_PACKAGES_FILE}" ];then
        EXTRA_PACKAGES=$(cat "${EXTRA_PACKAGES_FILE}")
    else
        EXTRA_PACKAGES=""
    fi
    VENV_PATH="${VENV_PATH:-"${W}/venv"}"
    EGGS_GIT_DIRS="ansible"
    PIP_CACHE="${VENV_PATH}/cache"
    if [ "x${QUIET}" = "x" ]; then
        QUIET_GIT=""
    else
        QUIET_GIT="-q"
    fi
    # export variables to survive a restart/fork
    export NONINTERACTIVE
    export SED PATH UNAME
    export DISTRIB_CODENAME DISTRIB_ID DISTRIB_RELEASE
    #
    export CORPUSOPS_ORGA_URL CORPUSOPS_URL CORPUSOPS_BRANCH
    #
    export ANSIBLE_URL ANSIBLE_BRANCH
    #
    export EGGS_GIT_DIRS
    #
    export BASE_PACKAGES EXTRA_PACKAGES
    #
    export DO_NOCONFIRM
    export DO_VERSION
    export DO_ONLY_RECONFIGURE
    export DO_ONLY_SYNC_CODE
    export DO_SYNC_CODE
    export DO_SYNC_PLAYBOOKS
    export DO_SYNC_ROLES
    export DO_SYNC_CORE
    export DO_INSTALL_PREREQUISITES
    export DO_SETUP_VIRTUALENV
    #
    export TRAVIS_DEBUG TRAVIS
    #
    export QUIET DEBUG
    export PYTESTRPM PYTESTURL
    #
    export VENV_PATH PIP_CACHE W
}

check_py_modules() {
    # test if salt binaries are there & working
    bin="${VENV_PATH}/bin/python"
    "${bin}" << EOF
import corpusops
import ansible
import dns
import docker
import chardet
import OpenSSL
import urllib3
import ipaddr
import ipwhois
import pyasn1
from distutils.version import LooseVersion
OpenSSL_version = LooseVersion(OpenSSL.__dict__.get('__version__', '0.0'))
if OpenSSL_version <= LooseVersion('0.15'):
    raise ValueError('trigger upgrade pyopenssl')
# futures
import concurrent
EOF
    return ${?}
}

recap_(){
    need_confirm="${1}"
    bs_yellow_log "----------------------------------------------------------"
    bs_yellow_log " CORPUSOPS BOOTSTRAP"
    bs_yellow_log "   - ${THIS} [--help] [--long-help]"
    bs_yellow_log "   version: ${RED}$(get_corpusops_branch)${YELLOW} ansible: ${RED}$(get_ansible_branch)${NORMAL}"
    bs_yellow_log "----------------------------------------------------------"
    bs_log "DATE: ${CHRONO}"
    bs_log "W: ${W}"
    bs_yellow_log "---------------------------------------------------"
    if [ "x${DO_SYNC_CODE}" != "xno" ];then
        msg="Syncing:"
        if [ "x${DO_SYNC_CORE}" != "xno" ];then
            msg="${msg} core -"
        fi
        if [ "x${DO_SYNC_PLAYBOOKS}" != "xno" ];then
            msg="${msg} playbooks -"
        fi
        if [ "x${DO_SYNC_ROLES}" != "xo" ];then
            msg="${msg} roles"
        fi
        bs_log "${msg}"
        bs_yellow_log "---------------------------------------------------"
    fi
    if [ "x${need_confirm}" != "xno" ] && [ "x${DO_NOCONFIRM}" = "x" ]; then
        bs_yellow_log "To avoid this confirmation message, do:"
        bs_yellow_log "    export DO_NOCONFIRM='1'"
    fi


}

recap() {
    will_do_recap="x"
    if [ "x${QUIET}" != "x" ]; then
        will_do_recap=""
    fi
    if [ "x${will_do_recap}" != "x" ]; then
        recap_
        travis_sys_info
    fi
}

may_sudo() {
    if [ "$(whoami)" != "root" ];then
        echo "sudo"
    fi
}

install_prerequisites_() {
    local pkgs="$(echo $EXTRA_PACKAGES $BASE_PACKAGES)"
    if [ "x${DO_INSTALL_PREREQUISITES}" != "xy" ]; then
        bs_log "prerequisites setup skipped"
        return 0
    fi

    if echo ${DISTRIB_ID} | egrep -iq "^ol$";then
        if ! ( rpm -ql python-test 1>/dev/null 2>&1 );then
            PYTESTURL="${CENTOSMIRROR}/${PYTESTRPM}"
            log "Installing python-test on $DISTRIB_ID"
            curl -LO  "${PYTESTURL}"
            die_in_error "Can't get $PYTESTURL"
            rpm -ivh --nodeps "$PYTESTRPM"
            die_in_error "Can't install $PYTESTRPM"
        fi
    fi
    debug "Ensuring system packages are installed: ${pkgs}"
    SKIP_UPGRADE=y\
        WANTED_EXTRA_PACKAGES="$(echo ${EXTRA_PACKAGES})" \
        WANTED_PACKAGES="$(echo ${BASE_PACKAGES})" \
        vv $(may_sudo) $W/bin/cops_pkgmgr_install.sh 2>&1\
        || die " [bs] Failed install prerequisites"
}

install_prerequisites() {
    ( set_lang C && install_prerequisites_; )
}

sys_info(){
    set -x
    ps aux
    netstat -pnlt
    set +x
}

travis_sys_info() {
    if [ "x${TRAVIS}" != "xtravis" ] && [ "x${TRAVIS_DEBUG}" != "x" ]; then
        sys_info
    fi
}

get_git_branch() {
    cd "${1}" 1>/dev/null 2>/dev/null
    br="$(git branch | grep "*"|grep -v grep)"
    echo "${br}" | "${SED}" -e "s/\* //g"
    cd - 1>/dev/null 2>/dev/null
}

filtered_ansible_playbook_custom() {
    filter=${1:-${ANSIBLE_FILTER_OUTPUT}}
    shift
    if [[ -n ${DEBUG} ]]; then
        SILENT="${SILENT_CHECKOUTS-${SILENT-1}}" \
        SILENT_LOG="${SILENT_CHECKOUTS_LOG-${SILENT_LOG-1}}" \
            vv bin/ansible-playbook "${@}"
    else
        (((( \
            SILENT="${SILENT_CHECKOUTS-${SILENT-1}}" \
            SILENT_LOG="${SILENT_CHECKOUTS_LOG-${SILENT_LOG-1}}" \
            vv bin/ansible-playbook "${@}" ; echo $? >&3) \
            | egrep -iv "${filter}" >&4) 3>&1) \
            | (read xs; exit $xs)) 4>&1
    fi
    return $?
}

filtered_ansible_playbook() {
    filtered_ansible_playbook_ "" "${@}"
}

checkouter () {
    filter=""
    filter="${filter}(${ANSIBLE_FILTER_OUTPUT}|"
    filter="${filter}^("
    filter="${filter}task.*(command|stash|git|checkout|switch|submod|merging|configur|remote|change)"
    filter="${filter})"
    filter="${filter})"
    filtered_ansible_playbook_custom "${filter}" \
           $( [[ -n "${DEBUG}" ]] && echo "-vvvvv" ) \
           -i localhost, -c local "${@}" \
           -e "$( [[ -n "${DEBUG}" ]] && echo "cops_debug=true " \
           )prefix='$PWD' venv='${VENV_PATH}'"
}

checkout_code() {
    if "${VENV_PATH}/bin/ansible-playbook" --help 2>&1 >/dev/null;then
        cd "${W}" &&\
            TO_CHECKOUT=""
            if [ "x$DO_SYNC_CORE" != "xno" ];then
                TO_CHECKOUT="${TO_CHECKOUT} checkouts_core.yml"
            fi
            if [ "x$DO_SYNC_PLAYBOOKS" != "xno" ];then
                TO_CHECKOUT="${TO_CHECKOUT} checkouts_playbooks.yml"
            fi
            if [ "x$DO_SYNC_ROLES" != "xno" ];then
                TO_CHECKOUT="${TO_CHECKOUT} checkouts_roles.yml"
            fi
            for co in $TO_CHECKOUT;do
                if ! checkouter "requirements/${co}";then
                    bs_log "Code failed to update for <$co>"
                    return 1
                else
                    if [ "x${QUIET}" = "x" ]; then
                        bs_log "Code updated for <$co>"
                    fi
                fi
            done
    else
        bs_yellow_log "Cant sync code, bootstrap core is not done"
        return 1
    fi
}

synchronize_code() {
    if [ "x${DO_SYNC_CODE}" = "xno" ]; then
        if [ "x${QUIET}" = "x" ];then
            bs_log "Sync code skipped"
        fi
        return 0
    fi
    if [ "x${CORPUS_OPS_IN_RESTART}" = "x" ]; then
        if ! test_online; then
            bs_log "Sync code skipped as we seems not to be connected"
        else
            if [ "x${QUIET}" = "x" ];then
                bs_yellow_log "If you want to skip checkouts, next time, do export DO_SYNC_CODE=no"
            fi
            checkout_code
        fi
    fi
}

setup_virtualenv_() {
    ensure_last_virtualenv
    if [ "x${DO_SETUP_VIRTUALENV}" != "xy" ]; then
        bs_log "virtualenv setup skipped"
        return 0
    fi
    make_virtualenv
    # virtualenv is present, activate it
    if [ -e "${VENV_PATH}/bin/activate" ]; then
        if [ "x${QUIET}" = "x" ]; then
            bs_log "Activating virtualenv in ${VENV_PATH}"
        fi
        . "${VENV_PATH}/bin/activate"
    fi
    # install requirements
    cd "${W}"
    install_git=""
    for i in ${EGGS_GIT_DIRS};do
        if [ ! -e "${VENV_PATH}/src/${i}" ]; then
            install_git="x"
        fi
    done
    uflag=""
    if check_py_modules; then
        if [ "x${QUIET}" = "x" ]; then
            bs_log "Pip install in place"
        fi
    else
        bs_log "Python install incomplete"
        if pip --help | grep -q download-cache; then
            copt="--download-cache"
        else
            copt="--cache-dir"
        fi
        pip install -U $copt "${PIP_CACHE}" -r requirements/python_requirements.txt
        die_in_error "requirements/python_requirements.txt doesn't install"
        pip install -U $copt "${PIP_CACHE}" --no-deps -e .
        die_in_error "corpusops egg doesn't install"
        if [ "x${install_git}" != "x" ]; then
            # ansible, salt & docker had bad history for
            # their deps in setup.py we ignore them and manage that ourselves
            pip install -U $copt "${PIP_CACHE}" --no-deps \
                -r requirements/python_git_requirements.txt
            die_in_error "requirements/python_git_requirements.txt doesn't install"
        else
            cwd="${PWD}"
            for i in ${EGGS_GIT_DIRS};do
                if [ -e "${VENV_PATH}/src/${i}" ]; then
                    cd "${VENV_PATH}/src/${i}"
                    pip install --no-deps -e .
                fi
            done
            cd "${cwd}"
        fi
    fi
}

setup_virtualenv() {
    ( set_lang C && setup_virtualenv_; )
}

reconfigure() {
    for i in ${W}/requirements/*.in;do
        ${SED} -r \
            -e "s#^\# (-e.*__(ANSIBLE))#\1#g" \
            -e "s#__CORPUSOPS_ORGA_URL__#$(get_corpusops_orga_url)#g" \
            -e "s#__CORPUSOPS_URL__#$(get_corpusops_url)#g" \
            -e "s#__CORPUSOPS_BRANCH__#$(get_corpusops_branch)#g" \
            -e "s#__ANSIBLE_URL__#$(get_ansible_url)#g" \
            -e "s#__ANSIBLE_BRANCH__#$(get_ansible_branch)#g" \
            "${i}" > "${W}/requirements/$(basename "${i}" .in)"
    done
}

link_dir() {
    where="${2}"
    vpath="${3:-${VENV_PATH}}"
    for i in $1;do
        origin="${vpath}/${i}"
        linkname=$(echo ${i} | ${SED} -re "s|${vpath}/?||g")
        destination="${where}/${linkname}"
        if [ ! -e ${origin} ];then
            mkdir -pv "${origin}"
        fi
        if [ -d "${destination}" ] && [ ! -h "${destination}" ]; then
            if [ ! -e "${where}/nobackup" ]; then
                mkdir "${where}/nobackup"
            fi
            echo "moving old directory; \"${where}/${linkname}\" to \"${where}/nobackup/${linkname}-$(date "+%F-%T-%N")\""
            mv "${destination}" "${where}/nobackup/${linkname}-$(date "+%F-%T-%N")"
        fi
        do_link="1"
        if [ -h "${destination}" ]; then
            if [ "x$(readlink ${destination})" = "x${origin}" ]; then
                do_link=""
            else
                rm -v "${destination}"
            fi
        fi
        if [ "x${do_link}" != "x" ]; then
            ln -sfv "${origin}" "${destination}" ||
                die "ln ${origin} -> ${destination} failed"
        fi
    done
}

bs_help() {
    title=${1}
    shift
    help=${1}
    shift
    default=${1}
    shift
    opt=${1}
    shift
    msg="     ${YELLOW}${title} ${NORMAL}${CYAN}${help}${NORMAL}"
    if [ "x${opt}" = "x" ]; then
        msg="${msg} ${YELLOW}(mandatory)${NORMAL}"
    fi
    if [ "x${default}" != "x" ]; then
        msg="${msg} ($default)"
    fi
    printf "${msg}\n"
}

print_contrary() {
    if [ "x${1}" = "xno" ];then
        echo "y"
    elif [ "x${1}" = "x" ];then
        echo "y"
    else
        echo "n"
    fi
}

usage() {
    reset_colors
    bs_log "${THIS}:"
    echo
    bs_yellow_log "This script will install corpusops & prerequisites"
    echo
    bs_log "  Actions (no action means install)"
    bs_help "    -r|--reconfigure" "Only reconfigure without doing any action" "${DO_ONLY_RECONFIGURE}" y
    bs_help "    --skip-prereqs" "Skip prereqs install" "${DO_INSTALL_PREREQUISITES}" y
    bs_help "    --skip-venv" "Do not run the virtualenv setup"  "${DO_SETUP_VIRTUALENV}" y
    bs_help "    -S|--skip-checkouts|--skip-sync-code" "Skip code synchronnization" \
        "$(print_contrary ${DO_SYNC_CODE})"  y
    bs_help "     --skip-sync-core" "Do not sync core (ansible, bootstrap)" \
        "$(print_contrary ${DO_SYNC_CORE})"  y
    bs_help "     --skip-sync-playbooks" "Do not sync playbooks" \
        "$(print_contrary ${DO_SYNC_PLAYBOOKS})"  y
    bs_help "     --skip-sync-roles" "Do not sync roles" \
        "$(print_contrary ${DO_SYNC_ROLES})"  y
    bs_help "    -s|--only-synchronize-code|--only-sync-code|--synchronize-code" "Only sync sourcecode" "${DO_ONLY_SYNC_CODE}" y
    bs_help "    -h|--help / -l/--long-help" "this help message or the long & detailed one" "" y
    bs_help "    --version" "show corpusops version & exit" "${DO_VERSION}" y
    echo
    bs_log "  General settings"
    bs_help "    --corpusops-orga_url <url>" "corpusops orga  fork git url" \
        "$(get_corpusops_orga_url)" y
    bs_help "    --corpusops-url <url>" "corpusops orga fork git url" "$(get_corpusops_url)" y
    bs_help "    -b|--corpusops-branch <branch>" "corpusops fork git branch" "$(get_corpusops_branch)" y
    bs_help "    --ansible-url <url>" "ansible fork git url" "$(get_ansible_url)" y
    bs_help "    --ansible-branch <branch>" "ansible fork git branch" "$(get_ansible_branch)" y
    bs_help "    -C|--no-confirm" "Do not ask for start confirmation" "" y
    bs_help "    --no-colors" "No terminal colors" "${NO_COLORS}" y
    bs_help "    -d|--debug" "activate debug" "${DEBUG}" y
}

parse_cli_opts() {
    #set_vars # to collect defaults for the help message
    args="${@}"
    PARAM=""
    while true
    do
        sh=1
        argmatch=""
        if [ "x${1}" = "x${PARAM}" ]; then
            break
        fi
        if [ "x${1}" = "x-q" ] || [ "x${1}" = "x--quiet" ]; then
            QUIET="1";argmatch="1"
        fi
        if [ "x${1}" = "x--version" ];then
            DO_VERSION="y";argmatch="1"
        fi
        if [ "x${1}" = "x-d" ] || [ "x${1}" = "x--debug" ];then
            DEBUG="y";argmatch="1"
        fi
        if [ "x${1}" = "x-h" ] || [ "x${1}" = "x--help" ]; then
            USAGE="1";argmatch="1"
        fi
        if [ "x${1}" = "x-l" ] || [ "x${1}" = "x--long-help" ]; then
            CORPUS_LONG_HELP="1";USAGE="1";argmatch="1"
        fi
        if [ "x${1}" = "x--no-colors" ]; then
            NO_COLORS="1";argmatch="1"
        fi
        if [ "x${1}" = "x-C" ] || [ "x${1}" = "x--no-confirm" ]; then
            DO_NOCONFIRM="y";argmatch="1"
        fi
        # do not remove yet for retro compat
        if [ "x${1}" = "x--skip-prereqs" ]; then
            DO_INSTALL_PREREQUISITES="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-sync-code" ] \
            || [ "x${1}" = "x--no-synchronize-code" ] \
            || [ "x${1}" = "x-S" ] \
            || [ "x${2}" = "x--skip-checkouts" ]; then
            DO_SYNC_CODE="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-sync-core" ]; then
            DO_SYNC_CORE="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-sync-playbooks" ]; then
            DO_SYNC_PLAYBOOKS="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-sync-roles" ]; then
            DO_SYNC_ROLES="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x-r" ] || [ "x${1}" = "x--reconfigure" ]; then
            DO_ONLY_RECONFIGURE="y"
            argmatch="1"
        fi
        if [ "x${1}" = "x-s" ] \
            || [ "x${1}" = "x--synchronize-code" ] \
            || [ "x${1}" = "x--only-sync-code" ] \
            || [ "x${1}" = "x--only-synchronize-code" ]; then
            DO_ONLY_SYNC_CODE="y"
            DO_SYNC_CODE="y"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-venv" ]; then
            DO_SETUP_VIRTUALENV="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--corpusops-orga-url" ]; then
            CORPUSOPS_ORGA_URL="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x--corpusops-url" ]; then
            CORPUSOPS_URL="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x-b" ] || [ "x${1}" = "x--corpusops-branch" ]; then
            CORPUSOPS_BRANCH="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x--ansible-url" ]; then
            ANSIBLE_URL="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x--ansible-branch" ]; then
            ANSIBLE_BRANCH="${2}";sh="2";argmatch="1"
        fi
        if [ "x${argmatch}" != "x1" ]; then
            USAGE="1"
            break
        fi
        PARAM="${1}"
        OLD_ARG="${1}"
        for i in $(seq $sh);do
            shift
            if [ "x${1}" = "x${OLD_ARG}" ]; then
                break
            fi
        done
        if [ "x${1}" = "x" ]; then
            break
        fi
    done
    if [ "x${USAGE}" != "x" ]; then
        set_vars
        usage
        exit 0
    fi
}

setup() {
    detect_os
    parse_cli_opts $LAUNCH_ARGS
    set_vars # real variable affectation
}

main() {
    reconfigure || die "reconfigure failed"
    if [ "x${DO_ONLY_RECONFIGURE}" != "x" ]; then
        NO_HEADER=1 may_die 1 0 "Reconfigured"
    fi
    if [ "x${DO_ONLY_SYNC_CODE}" != "x" ]; then
        synchronize_code || die "synchronize_code failed"
    else
        install_prerequisites || die "install_prerequisites failed"
        setup_virtualenv || die "setup_virtualenv failed"
        synchronize_code || die "synchronize_code failed"
    fi
    if [ "x${QUIET}" = "x" ]; then
        bs_log "end - sucess"
    fi
}

if [ "x${CORPUS_OPS_AS_FUNCS}" = "x" ]; then
    reset_colors
    setup
    if [ "x${DO_VERSION}" = "xy" ];then
        echo "${CORPUSOPS_VERSION}"
        exit 0
    fi
    recap
    main
fi
exit $?
## vim:set et sts=5 ts=4 tw=0:
