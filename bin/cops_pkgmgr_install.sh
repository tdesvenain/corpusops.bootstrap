#!/usr/bin/env bash
# BEGIN: corpusops common glue
# scripts vars
SCRIPT=$0
LOGGER_NAME=${LOGGER_NAME-$(basename $0)}
SCRIPT_NAME=$(basename "${SCRIPT}")
SCRIPT_DIR=$(cd "$(dirname $0)" && pwd)
SCRIPT_ROOT=${SCRIPT_ROOT:-$(dirname $SCRIPT_DIR)}
# OW: from where script was called (must be defined from callee)
OW="${OW:-$(pwd)}"
# W is script_dir/..
W=${OVERRIDEN_W:-$(cd "$SCRIPT_DIR/.." && pwd)}
#
#
DEFAULT_COPS_ROOT="/srv/corpusops/corpusops.bootstrap"
DEFAULT_COPS_URL="https://github.com/corpusops/corpusops.bootstrap"
#
SYSTEM_COPS_ROOT=${SYSTEM_COPS_ROOT-$DEFAULT_COPS_ROOT}
DOCKER_COPS_ROOT=${DOCKER_COPS_ROOT-$SYSTEM_COPS_ROOT}
COPS_URL=${COPS_URL-$DEFAULT_COPS_URL}
BASE_PREPROVISION_IMAGES="ubuntu:latest_preprovision"
BASE_PREPROVISION_IMAGES="$BASE_PREPROVISION_IMAGES corpusops/ubuntu:18.04_preprovision"
BASE_PREPROVISION_IMAGES="$BASE_PREPROVISION_IMAGES corpusops/ubuntu:16.04_preprovision"
BASE_PREPROVISION_IMAGES="$BASE_PREPROVISION_IMAGES corpusops/ubuntu:14.04_preprovision"
BASE_PREPROVISION_IMAGES="$BASE_PREPROVISION_IMAGES corpusops/centos:7_preprovision"
BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/ubuntu:latest"

BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/ubuntu:latest"
BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/ubuntu:18.04"
BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/ubuntu:16.04"
BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/ubuntu:14.04"
BASE_CORE_IMAGES="$BASE_CORE_IMAGES corpusops/centos:7"
BASE_IMAGES="$BASE_PREPROVISION_IMAGES $BASE_CORE_IMAGES"
EXP_PREPROVISION_IMAGES=""
EXP_PREPROVISION_IMAGES="$EXP_PREPROVISION_IMAGES archlinux:latest_preprovision"
EXP_PREPROVISION_IMAGES="$EXP_PREPROVISION_IMAGES debian:latest_preprovision"
EXP_PREPROVISION_IMAGES="$EXP_PREPROVISION_IMAGES debian:stretch_preprovision"
EXP_PREPROVISION_IMAGES="$EXP_PREPROVISION_IMAGES debian:jessie_preprovision"
EXP_CORE_IMAGES=""
EXP_CORE_IMAGES="$EXP_CORE_IMAGES corpusops/archlinux:latest"
EXP_CORE_IMAGES="$EXP_CORE_IMAGES corpusops/debian:latest"
EXP_CORE_IMAGES="$EXP_CORE_IMAGES corpusops/debian:stretch"
EXP_CORE_IMAGES="$EXP_CORE_IMAGES corpusops/debian:jessie"
EXP_IMAGES="$EXP_PREPROVISION_IMAGES $EXP_CORE_IMAGES"
#
# colors
RED="\\e[0;31m"
CYAN="\\e[0;36m"
YELLOW="\\e[0;33m"
NORMAL="\\e[0;0m"
NO_COLOR=${NO_COLORS-${NO_COLORS-${NOCOLOR-${NOCOLORS-}}}}
LOGGER_NAME=${LOGGER_NAME:-corpusops_build}
ERROR_MSG="There were errors"
uniquify_string() {
    local pattern=$1
    shift
    echo "$@" \
        | sed -e "s/${pattern}/\n/g" \
        | awk '!seen[$0]++' \
        | tr "\n" "${pattern}" \
        | sed -e "s/^${pattern}\|${pattern}$//g"
}
do_trap_() { rc=$?;func=$1;sig=$2;${func};if [ "x${sig}" != "xEXIT" ];then kill -${sig} $$;fi;exit $rc; }
do_trap() { rc=${?};func=${1};shift;sigs=${@};for sig in ${sigs};do trap "do_trap_ ${func} ${sig}" "${sig}";done; }
is_ci() {
    return $( ( [[ -n ${TRAVIS-} ]] || [[ -n ${GITLAB_CI} ]] );echo $?;)
}
log_() {
    reset_colors;msg_color=${2:-${YELLOW}};
    logger_color=${1:-${RED}};
    logger_slug="${logger_color}[${LOGGER_NAME}]${NORMAL} ";
    shift;shift;
    if [[ -n ${NO_LOGGER_SLUG} ]];then logger_slug="";fi
    printf "${logger_slug}${msg_color}$(echo "${@}")${NORMAL}\n" >&2;
    printf "" >&2;  # flush
}
reset_colors() { if [[ -n ${NO_COLOR} ]];then BLUE="";YELLOW="";RED="";CYAN="";fi; }
log() { log_ "${RED}" "${CYAN}" "${@}"; }
get_chrono() { date "+%F_%H-%M-%S"; }
cronolog() { log_ "${RED}" "${CYAN}" "($(get_chrono)) ${@}"; }
debug() { if [[ -n "${DEBUG// }" ]];then log_ "${YELLOW}" "${YELLOW}" "${@}"; fi; }
warn() { log_ "${RED}" "${CYAN}" "${YELLOW}[WARN] ${@}${NORMAL}"; }
bs_log(){ log_ "${RED}" "${YELLOW}" "${@}"; }
bs_yellow_log(){ log_ "${YELLOW}" "${YELLOW}" "${@}"; }
may_die() {
    reset_colors
    thetest=${1:-1}
    rc=${2:-1}
    shift
    shift
    if [ "x${thetest}" != "x0" ]; then
        if [[ -z "${NO_HEADER-}" ]]; then
            NO_LOGGER_SLUG=y log_ "" "${CYAN}" "Problem detected:"
        fi
        NO_LOGGER_SLUG=y log_ "${RED}" "${RED}" "$@"
        exit $rc
    fi
}
die() { may_die 1 1 "${@}"; }
die_in_error_() {
    ret=${1}; shift; msg="${@:-"$ERROR_MSG"}";may_die "${ret}" "${ret}" "${msg}";
}
die_in_error() { die_in_error_ "${?}" "${@}"; }
die_() { NO_HEADER=y die_in_error_ $@; }
sdie() { NO_HEADER=y die $@; }
parse_cli() { parse_cli_common "${@}"; }
parse_cli_common() {
    USAGE=
    for i in ${@-};do
        case ${i} in
            --no-color|--no-colors|--nocolor|--no-colors)
                NO_COLOR=1;;
            -h|--help)
                USAGE=1;;
            *) :;;
        esac
    done
    reset_colors
    if [[ -n ${USAGE} ]]; then
        usage
    fi
}
has_command() {
    ret=1
    if which which >/dev/null 2>/dev/null;then
      if which "${@}" >/dev/null 2>/dev/null;then
        ret=0
      fi
    else
      if command -v "${@}" >/dev/null 2>/dev/null;then
        ret=0
      else
        if hash -r "${@}" >/dev/null 2>/dev/null;then
            ret=0
        fi
      fi
    fi
    return ${ret}
}
pipe_return() {
    local filter=$1;shift;local command=$@;
    (((($command; echo $? >&3) | $filter >&4) 3>&1) | (read xs; exit $xs)) 4>&1;
}
output_in_error() { ( do_trap output_in_error_post EXIT TERM QUIT INT;\
                      output_in_error_ "${@}" ; ); }
output_in_error_() {
    if [[ -n ${OUTPUT_IN_ERROR_DEBUG-} ]];then set -x;fi
    if is_ci;then
        DEFAULT_CI_BUILD=y
    fi
    CI_BUILD="${CI_BUILD-${DEFAULT_CI_BUILD-}}"
    if [[ -n $CI_BUILD ]];then
        DEFAULT_NO_OUTPUT=y
        DEFAULT_DO_OUTPUT_TIMER=y
    fi
    VERBOSE="${VERBOSE-}"
    TIMER_FREQUENCE="${TIMER_FREQUENCE:-120}"
    NO_OUTPUT="${NO_OUTPUT-${DEFAULT_NO_OUTPUT-1}}"
    DO_OUTPUT_TIMER="${DO_OUTPUT_TIMER-$DEFAULT_DO_OUTPUT_TIMER}"
    LOG=${LOG-}
    if [[ -n $NO_OUTPUT ]];then
        if [[ -z "${LOG}" ]];then
            LOG=$(mktemp)
            DEFAULT_CLEANUP_LOG=y
        else
            DEFAULT_CLEANUP_LOG=
        fi
    else
        DEFAULT_CLEANUP_LOG=
    fi
    CLEANUP_LOG=${CLEANUP_LOG:-${DEFAULT_CLEANUP_LOG}}
    if [[ -n $VERBOSE ]];then
        log "Running$([[ -n $LOG ]] && echo "($LOG)"; ): $@";
    fi
    TMPTIMER=
    if [[ -n ${DO_OUTPUT_TIMER} ]]; then
        TMPTIMER=$(mktemp)
        ( i=0;\
          while test -f $TMPTIMER;do\
           i=$((++i));\
           if [ `expr $i % $TIMER_FREQUENCE` -eq 0 ];then \
               log "BuildInProgress$([[ -n $LOG ]] && echo "($LOG)"; ): ${@}";\
             i=0;\
           fi;\
           sleep 1;\
          done;\
          if [[ -n $VERBOSE ]];then log "done: ${@}";fi; ) &
    fi
    # unset NO_OUTPUT= LOG= to prevent output_in_error children to be silent
    # at first
    reset_env="NO_OUTPUT LOG"
    if [[ -n $NO_OUTPUT ]];then
        ( unset $reset_env;"${@}" ) >>"$LOG" 2>&1;ret=$?
    else
        if [[ -n $LOG ]] && has_command tee;then
            ( unset $reset_env; pipe_return "tee -a $tlog" "${@}"; )
            ret=$?
        else
            ( unset $reset_env; "${@}"; )
            ret=$?
        fi
    fi
    if [[ -e "$TMPTIMER" ]]; then rm -f "${TMPTIMER}";fi
    if [[ -z ${OUTPUT_IN_ERROR_NO_WAIT-} ]];then wait;fi
    if [ -e "$LOG" ] &&  [[ "${ret}" != "0" ]] && [[ -n $NO_OUTPUT ]];then
        cat "$LOG" >&2
    fi
    if [[ -n ${OUTPUT_IN_ERROR_DEBUG-} ]];then set +x;fi
    return ${ret}
}
output_in_error_post() {
    if [[ -e "$TMPTIMER" ]]; then rm -f "${TMPTIMER}";fi
    if [[ -e "$LOG" ]] && [[ -n $CLEANUP_LOG ]];then rm -f "$LOG";fi
}
test_silent_log() { ( [[ -z ${NO_SILENT-} ]] && ( [[ -n ${SILENT_LOG-} ]] || [[ -n "${SILENT_DEBUG}" ]] ) ); }
test_silent() { ( [[ -z ${NO_SILENT-} ]] && ( [[ -n ${SILENT-} ]] || test_silent_log ) ); }
silent_run_() {
    (LOG=${SILENT_LOG:-${LOG}};
     NO_OUTPUT=${NO_OUTPUT-};\
     if test_silent;then NO_OUTPUT=y;fi;output_in_error "$@";)
}
silent_run() { ( silent_run_ "${@}" ; ); }
run_silent() {
    (
    DEFAULT_RUN_SILENT=1;
    if [[ -n ${NO_SILENT-} ]];then DEFAULT_RUN_SILENT=;fi;
    SILENT=${SILENT-DEFAULT_RUN_SILENT} silent_run "${@}";
    )
}
vvv() { debug "${@}";silent_run "${@}"; }
vv() { log "${@}";silent_run "${@}"; }
silent_vv() { SILENT=${SILENT-1} vv "${@}"; }
quiet_vv() { if [[ -z ${QUIET-} ]];then log "${@}";fi;run_silent "${@}";}
version_lte() { [  "$1" = "$(printf "$1\n$2" | sort -V | head -n1)" ]; }
version_lt() { [ "$1" = "$2" ] && return 1 || version_lte $1 $2; }
version_gte() { [  "$2" = "$(printf "$1\n$2" | sort -V | head -n1)" ]; }
version_gt() { [ "$1" = "$2" ] && return 1 || version_gte $1 $2; }
is_archlinux_like() { echo $DISTRIB_ID | egrep -iq "archlinux|arch"; }
is_debian_like() { echo $DISTRIB_ID | egrep -iq "debian|ubuntu|mint"; }
is_redhat_like() { echo $DISTRIB_ID \
        | egrep -iq "((^ol$)|rhel|redhat|red-hat|centos|fedora)"; }
set_lang() { locale=${1:-C};export LANG=${locale};export LC_ALL=${locale}; }
detect_os() {
    # this function should be copiable in other scripts, dont use adjacent functions
    UNAME="${UNAME:-"$(uname | awk '{print tolower($1)}')"}"
    PATH="${PATH}:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:/usr/local/games"
    SED="sed"
    if [ "x${UNAME}" != "xlinux" ] && hash -r gsed >/dev/null 2>&1; then
        SED=gsed
    fi
    DISTRIB_CODENAME=""
    DISTRIB_ID=""
    DISTRIB_RELEASE=""
    if hash -r lsb_release >/dev/null 2>&1; then
        DISTRIB_ID=$(lsb_release -si)
        DISTRIB_CODENAME=$(lsb_release -sc)
        DISTRIB_RELEASE=$(lsb_release -sr)
    elif [ -e /etc/lsb-release ];then
        debug "No lsb_release, sourcing manually /etc/lsb-release"
        DISTRIB_ID=$(. /etc/lsb-release;echo ${DISTRIB_ID})
        DISTRIB_CODENAME=$(. /etc/lsb-release;echo ${DISTRIB_CODENAME})
        DISTRIB_RELEASE=$(. /etc/lsb-release;echo ${DISTRIB_RELEASE})
    elif [ -e /etc/os-release ];then
        DISTRIB_ID=$(. /etc/os-release;echo $ID)
        DISTRIB_CODENAME=$(. /etc/os-release;echo $VERSION)
        DISTRIB_CODENAME=$(echo $DISTRIB_CODENAME |sed -e "s/.*(\([^)]\+\))/\1/")
        DISTRIB_RELEASE=$(. /etc/os-release;echo $VERSION_ID)
    elif [ -e /etc/redhat-release ];then
        RHRELEASE=$(cat /etc/redhat-release)
        DISTRIB_CODENAME=${RHRELEASE}
        DISTRIB_RELEASE=${RHRELEASE}
        DISTRIB_ID=${RHRELEASE}
        DISTRIB_CODENAME=$(echo $DISTRIB_CODENAME |sed -e "s/.*(\([^)]\+\))/\1/")
        DISTRIB_RELEASE=$(echo $DISTRIB_RELEASE |sed -e "s/release \([0-9]\)/\1/")
        DISTRIB_ID=$(echo $DISTRIB_ID | awk '{print tolower($1)}')
    else
        if ! ( echo ${@-} | grep -q no_fail );then
            echo "unexpected case, no lsb_release" >&2
            exit 1
        fi
    fi
    export DISTRIB_ID DISTRIB_CODENAME DISTRIB_RELEASE
}
get_command() {
    local p=
    local cmd="${@}"
    if which which >/dev/null 2>/dev/null;then
        p=$(which "${cmd}" 2>/dev/null)
    fi
    if [ "x${p}" = "x" ];then
        p=$(export IFS=:;
            echo "${PATH-}" | while read -ra pathea;do
                for pathe in "${pathea[@]}";do
                    pc="${pathe}/${cmd}";
                    if [ -x "${pc}" ]; then
                        p="${pc}"
                    fi
                done
                if [ "x${p}" != "x" ]; then echo "${p}";break;fi
            done )
    fi
    if [ "x${p}" != "x" ];then
        echo "${p}"
    fi
}
cleanup_docker_tag() { echo "${@}"|sed -re "s/\.|[-_]//g"|awk '{print tolower($0)}'; }
get_container_id() { local n=${1};local cid=$(docker ps -q -a --filter 'name='$n); echo "${cid}"; }
sane_container_name() { local n=${1};n=${n//:/};n=${n//_/};n=${n//-/};n=${n//\//};n=${n//\./};echo $n; }
get_images() { docker images --no-trunc -q "${@}" 2>/dev/null|awk '!seen[$0]++'; }
get_image() { get_images "${@}" | head -n 1; }
get_docker_ids() { docker inspect -f '{{.Id}}' "${@}" 2>/dev/null; }
save_container() {
    local n="${1}"
    local d="${2:-${n}}"
    local running=$(docker ps -q    --filter 'name='$n)
    if [[ -n "${running}" ]];then
        vv docker kill "${running}"
    fi
    local cid=$(get_container_id $n)
    if [[ -n "${cid}" ]];then
        vv docker commit "$cid" "$d"
        vv docker rm "$cid"
    else
        img=${initial_img}
    fi
}
get_git_changeset() { ( cd "${1:-$(pwd)}" && git log HEAD|head -n1|awk '{print $2}'); }
get_git_branch() {
   ( cd "${1:-$(pwd)}" &&\
     git rev-parse --abbrev-ref HEAD | grep -v HEAD || \
     git describe --exact-match HEAD 2> /dev/null || \
     git rev-parse HEAD)
}
get_git_branchs() { ( cd "${1:-$(pwd)}" && git branch|sed -e "s/^\*\? \+//g"); }
get_full_chrono() { date "+%F_%H-%M-%S-%N"; }
get_random_slug() { len=${1:-32};strings=${2:-'a-zA-Z0-9'};echo "$(cat /dev/urandom|tr -dc "$strings"|fold -w ${len}|head -n 1)"; }
may_sudo() {
    if [ "$(whoami)" != "root" ] && [ -z "${NO_SUDO-}" ];then
        echo "sudo $([[ -z $DIRECT_SUDO ]] && echo "-HE")"
    fi
}
get_ancestor_from_dockerfile() {
    local dockerfile=${1}
    local ancestor=
    if [[ -e "${dockerfile}" ]] && egrep -q ^FROM "${dockerfile}"; then
        ancestor=$(egrep ^FROM "${dockerfile}"\
            | head -n1 | awk '{print $2}' | xargs -n1| sort -u )
    fi
    echo ${ancestor}
}
do_tmp_cleanup() {
    local tmp_dockers=$2
    local tmp_files=$1
    local tmp_imgs=$3
    log "Post cleanup"
    for tmp_file in ${tmp_files};do
        if [ -e "${tmp_file}" ]; then
            vv rm -f "${tmp_file}"
        fi
    done
    for test_docker in ${tmp_dockers};do
        test_dockerid=$(vvv get_container_id ${test_docker})
        if [[ "${test_dockerid}" != "" ]]; then
            log "Removing produced test docker ${test_docker}"
            docker rm -f "${test_dockerid}"
        fi
    done
    for test_tag in ${tmp_imgs};do
        test_tagid=$(vvv get_image ${test_tag})
        if [[ "${test_tagid}" != "" ]]; then
            log "Removing produced test image: ${test_tag}"
            docker rmi "${test_tagid}"
        fi
    done
}
may_autoadd_git_author() {
    if [ "x$(git config user.email)" = "x" ];then
        echo "-c user.name=Corpusops -c user.email=autocommiter@corpousops"
    fi
}
update_wd_to_br() {
    (
        local wd="${2:-$(pwd)}"
        local up_branch="${1}"
        cd "${wd}" || die "${wd} does not exists"
        if ! git diff --quiet;then
            vvv git $(may_autoadd_git_author) stash
            die_in_error "${wd}: changes can't be stashed"
        fi &&\
            vv git $(may_autoadd_git_author) pull origin "${up_branch}"
    )
}
upgrade_wd_to_br() {
    (
        local wd="${2:-$(pwd)}"
        local up_branch="${1}"
        cd "${wd}" || die "${wd} does not exists"
        local test_branch="${3:-$(get_git_branch)}"
        local existing_gitmodules="$(git submodule status|awk '{print $2}')"
        if [ "x${test_branch}" != "x${up_branch}" ];then
            warn "Upgrading $wd to branch: $up_branch"
            git fetch --all || die "git fetch in $wd failed"
            if get_git_branchs | egrep -q "^${up_branch}$";then
                vv git checkout ${up_branch} &&\
                    vv git reset --hard origin/${up_branch}
            else
                vv git checkout origin/${up_branch} -b ${up_branch}
            fi
        fi
        update_wd_to_br "$up_branch" "$wd" &&\
        while read subdir;do
            subdir=$(echo $subdir|sed -e "s/^\.\///g")
            if [ -h "${subdir}/.git" ] || [ -f "${subdir}/.git" ];then
                debug "Checking if ${subdir} is always a submodule"
                if [ -e .gitmodules ] && ( grep -q -- "${subdir}" .gitmodules );then
                    debug "${subdir} is always a gitmodule"
                else
                    warn "${subdir} is not a git submodule anymore"
                    vv rm -rf "${subdir}"
                fi
            fi
        done < <( echo "${existing_gitmodules}" )
        if [ -e .gitmodules ];then
            warn "Upgrading submodules in $wd"
            vv git submodule update --recursive
        fi
    )
}
get_python2() {
    local py2=
    for i in python2.7 python2.6 python-2.7 python-2.6 python-2;do
        local lpy=$(get_command $i 2>/dev/null)
        if [[ -n $lpy ]] && ( ${lpy} -V 2>&1| egrep -qi 'python 2' );then
            py2=${lpy}
            break
        fi
    done
    echo $py2
}
upgrade_pip() {
    local py="${1:-python}"
    local pip="${2:-pip}"
    local pipc="$(get_command $pip)"
    if [[ -z "$pipc" ]];then
        local PIP_URL="https://bootstrap.pypa.io/get-pip.py"
        local GET_PIP="${GET_PIP-$PIP_URL}"
        local PIP_INST="$(mktemp)"
        if ! ( "$py" -c "import urllib; print urllib.urlopen('$GET_PIP').read()" > "$PIP_INST" );then
            log "Error downloading pip installer"
            return 1
        fi
        "$py" "$PIP_INST"
        local pipc="$(get_command $pip)"
        if [[ -z "$pipc" ]];then
            log "pip not found"
            return 1
        fi
    fi
	local dpip="$(dirname $pipc)"
	local pipo=""
    log "ReInstalling pip ($pipc) for $py"
	# force reinstalling pip in same place where it is (not /usr/local but /usr)
	if ( echo "$dpip" | egrep -q  "^/" );then
		pipo="--install-option=--install-scripts=$dpip"
	fi
    "${py}" "${pipc}" install -U $pipo --ignore-installed --force-reinstall setuptools &&\
    "${py}" "${pipc}" install -U $pipo --ignore-installed --force-reinstall pip
}
make_virtualenv() {
    local py=${1:-$(get_python2)}
    local DEFAULT_VENV_PATH=$SCRIPT_ROOT/venv
    local venv_path=${2-${VENV_PATH:-$DEFAULT_VENV_PATH}}
    local venv=$(get_command $(basename ${VIRTUALENV_BIN:-virtualenv}))
    local PIP_CACHE=${PIP_CACHE:-${venv_path}/cache}
    if [ "x${DEFAULT_VENV_PATH}" != "${venv_path}" ];then
        if [ ! -e "${venv_path}" ];then
            mkdir -p "${venv_path}"
        fi
        if [ -e "${DEFAULT_VENV_PATH}" ] && \
            [ "$DEFAULT_VENV_PATH" != "$venv_path" ] &&\
            [ ! -h "${DEFAULT_VENV_PATH}" ];then
            die "$DEFAULT_VENV_PATH is not a symlink but we want to create it"
        fi
        if [ -h $DEFAULT_VENV_PATH ] &&\
            [ "x$(readlink $DEFAULT_VENV_PATH)" != "$venv_path" ];then
            rm -f "${DEFAULT_VENV_PATH}"
        fi
        if [ ! -e $DEFAULT_VENV_PATH ];then
            ln -s "${venv_path}" "${DEFAULT_VENV_PATH}"
        fi
    fi
    if     [ ! -e "${venv_path}/bin/activate" ] \
        || [ ! -e "${venv_path}/lib" ] \
        || [ ! -e "${venv_path}/include" ] \
        ; then
        bs_log "Creating virtualenv in ${venv_path}"
        if [ ! -e "${PIP_CACHE}" ]; then
            mkdir -p "${PIP_CACHE}"
        fi
        if [ ! -e "${venv_path}" ]; then
            mkdir -p "${venv_path}"
        fi
    $venv \
        $( [[ -n $py ]] && echo "--python=$py"; ) \
        --system-site-packages --unzip-setuptools \
        "${venv_path}" &&\
    ( . "${venv_path}/bin/activate" &&\
      upgrade_pip "${venv_path}/bin/python" "${venv_path}/bin/pip" &&\
      deactivate; )
    fi
}
ensure_last_python_requirement() {
    local PIP=${PIP:-pip}
    local COPS_PYTHON=${COPS_PYTHON:-python}
    local i=
    local PIP_CACHE=${PIP_CACHE:-${VENV_PATH:-$(pwd)}/cache}
    # inside the for loop as at first pip can not have the opts
    # but can be upgraded to have them after
    local copt=
    if "$py" "$PIP" --help | grep -q download-cache; then
        copt="--download-cache"
    elif $PIP --help | grep -q cache-dir; then
        copt="--cache-dir"
    fi
    log "Installing last version of $@"
    if [[ -n "$copt" ]];then
        vvv "$COPS_PYTHON" "$PIP" install \
            --src "$(get_eggs_src_dir)" -U $copt "${PIP_CACHE}" $@
    else
        vvv "$COPS_PYTHON" "$PIP" install \
            --src "$(get_eggs_src_dir)" -U $@
    fi
}
usage() { die 128 "No usage found"; }
# END: corpusops common glue

usage() {
    echo '
Universal shell wrapper to manage OS package manager
OS SUPPORT: debian(& ubuntu) / archlinux / red-hat (centos/rh/fedora)

[NONINTERACTIVE="y"] \
[WANTED_EXTRA_PACKAGES="vim"] \
[WANTED_EXTRA_PACKAGES="nano"] \
[DO_SETUP=y] [SKIP_SETUP=y] \
[DO_UPDATE=y] [SKIP_UPDATE=y] \
[DO_UPGRADE=y] [SKIP_UPGRADE=y] \
[DO_INSTALL=y] [SKIP_INSTALL=y] \
[DEBUG=y"] \
    '"${0}"' [--check-os] [--help] [packagea] [packageb]'
}

APT_CONF_FILE="/etc/apt/apt.conf.d/01buildconfig"
REQS_PATH="/srv/corpusops.bootstrap/requirements"
NONINTERACTIVE=${NONINTERACTIVE-}
SKIP_SETUP=${SKIP_SETUP-}
SKIP_INSTALL=${SKIP_INSTALL-}
SKIP_UPDATE=${SKIP_UPDATE-}
SKIP_UPGRADE=${SKIP_UPGRADE-}
DO_SETUP=${DO_SETUP-default}
DO_UPGRADE=${DO_UPGRADE-}
DO_UPDATE=${DO_UPDATE-default}
DO_INSTALL=${DO_INSTALL-default}
CHECK_OS=${CHECK_OS-}
container=${container-}

###
i_y() {
    if [[ -n ${NONINTERACTIVE} ]]; then
        if is_archlinux_like;then
            echo "--noconfirm"
        else
            echo "-y"
        fi
    fi
}

###
is_pacman_available() {
    for i in $@;do
        if ! ( pacman -Si $(i_y) "$i" >/devnull 2>&1 ||\
                pacman -Sg $(i_y) "$i" >/devnull 2>&1; );then
            return 1
        fi
    done
    return 0
}

is_pacman_installed() {
    for i in $@;do
        if ! ( pacman -Qi $(i_y) "$i" >/devnull 2>&1; ); then
            return 1
        fi
    done
    return 0
}

pacman_update() {
    vv pacman -Sy $(i_y)
}

pacman_upgrade() {
    vv pacman -Syu $(i_y)
}

pacman_install() {
    vvv pacman -S $(i_y) $@
}

ensure_command() {
    local cmd=${1}
    shift
    local pkgs=${@}
    if ! has_command ${cmd}; then
        ${INSTALLER}_install ${pkgs}
    fi
}

pacman_setup() {
    ensure_command awk core/gawk
    ensure_command sort core/coreutils
    ensure_command egrep core/grep
    ensure_command which core/which
}

###
dnf_repoquery() {
    vvv dnf repoquery -q "${@}"
}

is_dnf_available() {
    if ! ( dnf list available ${@} \
           || rh_is_available_but_maybe_provided_by_other ${@}; ) \
           >/dev/null 2>&1; then
        return 1
    fi
}

is_dnf_installed() {
    if ! ( dnf list installed ${@} \
           || rh_is_installed_but_maybe_provided_by_other ${@}; ) \
           >/dev/null 2>&1; then
        return 1
    fi
}

dnf_update() {
    vvv dnf check-update $(i_y)
    ret=$?
    if echo ${ret} | egrep -q '^(0|100)$'; then
        return 0
    fi
    return 1
}

dnf_upgrade() {
    vvv dnf upgrade $(i_y)
}

dnf_install() {
    vvv dnf install $(i_y) $@
}

dnf_ensure_repoquery() {
    if ! ( dnf --help 2>&1 | grep -q repoquery ); then
        dnf_install 'dnf-command(repoquery)'
    fi
}

dnf_setup() {
    rh_setup
}

###
yum_repoquery() {
    repoquery -q "${@}"
}

is_yum_available() {
    if ! ( yum list all ${@} \
           || rh_is_available_but_maybe_provided_by_other ${@}; ) \
        >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

is_yum_installed() {
    if ! ( yum list installed ${@} \
           || rh_is_installed_but_maybe_provided_by_other ${@}; ) \
           >/dev/null 2>&1; then
        return 1
    fi
}

yum_update() {
    vvv yum check-update $(i_y)
    ret=$?
    if echo ${ret} | egrep -q '^(0|100)$'; then
        return 0
    fi
    return 1
}

yum_upgrade() {
    vvv yum upgrade $(i_y)
}

yum_install() {
    yum install $(i_y) $@
}

yum_ensure_repoquery() {
    if ! has_command repoquery; then
        ${INSTALLER}_install yum-utils
    fi
}

yum_setup() {
    rh_setup
}

###
rh_is_available_but_maybe_provided_by_others() {
    ${INSTALLER}_repoquery -q --all       --whatprovides ${@}
}

rh_is_available_but_maybe_provided_by_other() {
    if [[ -z "$(rh_is_available_but_maybe_provided_by_others $@)" ]];then
        return 1
    fi
    return 0
}

rh_is_installed_but_maybe_provided_by_others() {
    ${INSTALLER}_repoquery -q --installed --whatprovides ${@}
}

rh_is_installed_but_maybe_provided_by_other() {
    if [[ -z "$(rh_is_installed_but_maybe_provided_by_others $@)" ]];then
        return 1
    fi
    return 0
}

###
is_aptget_available() {
    if ! apt-cache show ${@} >/dev/null 2>&1; then
        return 1
    else
        return 0
    fi
}

is_aptget_installed() {
    if ! dpkg-query -s ${@} 2>/dev/null|egrep "^Status:"|grep -q installed; then
        return 1
    fi
}

aptget_add_conf() {
    if [[ -n "$2" ]] && grep -q "$2" $APT_CONF_FILE 2>/dev/null;then
        log "test $2 success, skip adding slug $1"
    else
        echo "${1}" >> $APT_CONF_FILE
    fi
}

aptget_update() {
    vvv apt-get update
}

aptget_upgrade() {
    vvv apt-get dist-upgrade
}

aptget_install() {
    vvv apt-get install ${@}
}

aptget_setup() {
    if [[ -n "${NONINTERACTIVE}" ]];then
        export DEBIAN_FRONTEND=noninteractive
        aptget_add_conf "APT::Install-Recommends "0";" "APT::Install-Recommends"
        aptget_add_conf "APT::Get::Assume-Yes "true";" "APT::Get::Assume-Yes"
        aptget_add_conf "APT::Get::force-yes "true";"  "APT::Get::force-yes"
        aptget_add_conf "APT::Install-Suggests "0";"   "APT::Install-Suggests"
    fi
}

rh_setup() {
    ${INSTALLER}_ensure_repoquery
    ensure_command xargs findutils
    ensure_command awk gawk
    ensure_command sort coreutils
    ensure_command egrep grep
    ensure_command which which
}

###
parse_cli() {
    parse_cli_common "${@}"
    if [ "x${DEBIAN_FRONTEND-}" = "noninteractive" ] \
        || [ "x${container-}" = "xdocker" ];then
        NONINTERACTIVE=y
    fi
    WANTED_EXTRA_PACKAGES=${WANTED_EXTRA_PACKAGES-}
    WANTED_PACKAGES=${WANTED_PACKAGES-}
    for i in ${@-};do
        case $i in
            --check-os) CHECK_OS=1;;
            --help|-h) :;;
            *) WANTED_PACKAGES="${WANTED_PACKAGES} ${i}";;
        esac
    done
    if ( is_debian_like; );then
        INSTALLER=aptget
    elif ( is_archlinux_like; );then
        INSTALLER=pacman
    elif ( is_redhat_like; );then
        INSTALLER=yum
        if has_command dnf;then
            INSTALLER=dnf
        fi
    else
        sdie "Not supported os: ${DISTRIB_ID}"
    fi
    debug "INSTALLER: ${INSTALLER}"
    if [[ -n $CHECK_OS ]];then
        warn "OS is supported"
        exit 0
    fi
}

update() {
    if [[ -z "${SKIP_UPDATE}" ]] && [[ -n "${DO_UPDATE}" ]];then
        log ${INSTALLER}_update
        ${INSTALLER}_update
        may_die $? $? "Update failed"
    else
        debug "Skip update"
    fi
}

prepare_install() {
    candidates=""
    already_installed=""
    secondround=""
    secondround_extra=""
    if [[ -z "${SKIP_INSTALL}" ]];then
        # test if all packages are there
        if [[ -n "${WANTED_PACKAGES}" ]]; then
            for i in $WANTED_PACKAGES;do
                if ! is_${INSTALLER}_installed $i;then
                    if is_${INSTALLER}_available ${i}; then
                        candidates="${candidates} ${i}"
                    else
                        secondround="${secondround} ${i}"
                    fi
                else
                    debug "Package '${i}' found"
                    already_installed="${already_installed} ${i}"
                fi
            done
        fi
        if [[ -n "${WANTED_EXTRA_PACKAGES}" ]]; then
            for i in $WANTED_EXTRA_PACKAGES;do
                if ! is_${INSTALLER}_installed ${i}; then
                    if is_${INSTALLER}_available ${i};then
                        candidates="${candidates} ${i}"
                    else
                        secondround_extra="${secondround_extra} ${i}"
                    fi
                else
                    debug "EPackage '${i}' found"
                    already_installed="${already_installed} ${i}"
                fi
            done
        fi
        # skip update & rest if everything is there
        if [[ -z "${candidates}" ]];then
            if [ "x${DO_UPDATE}" = "xdefault" ];then
                DO_UPDATE=""
            fi
        fi
        if [[ -n $secondround ]];then
            warn "Packages $(echo ${secondround}) not found before update"
        fi
        if [[ -n $secondround_extra ]];then
            warn "EXTRA Packages $(echo ${secondround_extra}) not found before update"
        fi
        #
        #
        update
        #
        #
        # after update, check for packages that werent found at first
        # if we can now resolve them
        if [[ -n "${secondround}" ]]; then
            for i in ${secondround};do
                if ! is_${INSTALLER}_installed $i;then
                    if is_${INSTALLER}_available ${i}; then
                        candidates="${candidates} ${i}"
                    else
                        sdie "Package '${i}' not found"
                    fi
                else
                    debug "PostPackage '${i}' found"
                    already_installed="${already_installed} ${i}"
                fi
            done
        fi
        if [[ -n "${secondround_extra}" ]]; then
            for i in ${secondround_extra};do
                if ! is_${INSTALLER}_installed ${i}; then
                    if is_${INSTALLER}_available ${i};then
                        candidates="${candidates} ${i}"
                    else
                        warn "EXTRA Package '${i}' not found"
                    fi
                else
                    debug "PostEPackage '${i}' found'"
                    already_installed="${already_installed} ${i}"
                fi
            done
        fi

    else
        debug "Skip pre-flight install"
    fi
    candidates=$( echo "${candidates}" | xargs -n1 | sort -u )
    already_installed=$( echo "${already_installed}" | xargs -n1 | sort -u )
    if [[ -n "${candidates}" ]]; then
        log "Will install: $(echo ${candidates})"
    fi
    if [[ -n "${already_installed}" ]]; then
        log "Already installed: $(echo ${already_installed})"
    fi
}

setup() {
    if [[ -z "${SKIP_SETUP}" ]] &&  [[ -n "${DO_SETUP}" ]];then
        debug ${INSTALLER}_setup
        ${INSTALLER}_setup
        may_die $? $? "setup failed"
    else
        debug "Skip setup"
    fi
    # be sure to use xargs only after we installed it
    WANTED_PACKAGES="$(echo "$(echo "${WANTED_PACKAGES}" | xargs -n1 | sort -u)")"
    WANTED_EXTRA_PACKAGES="$(echo "$(echo "${WANTED_EXTRA_PACKAGES}" | xargs -n1 | sort -u)")"
}

upgrade() {
    if [[ -z "${SKIP_UPGRADE}" ]] &&  [[ -n "${DO_UPGRADE}" ]];then
        log ${INSTALLER}_upgrade
        ${INSTALLER}_upgrade
        may_die $? $? "upgrade failed"
    else
        debug "Skip upgrade"
    fi
}

install() {
    upgrade
    if [[ -z "${SKIP_INSTALL}" ]] \
        && [[ -n "${DO_INSTALL}" ]] \
        && [[ -n "${candidates}" ]]; then
        log ${INSTALLER}_install ${candidates}
        ${INSTALLER}_install ${candidates}
        may_die $? $? "install failed"
    else
        debug "Skip install"
    fi
}

detect_os
parse_cli "${@}"
setup
prepare_install  # calls: update
upgrade
install
# vim:set et sts=4 ts=4 tw=80:
