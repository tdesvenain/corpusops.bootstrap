#!/usr/bin/env bash
# SEE CORPUSOPS DOCS FOR FURTHER INSTRUCTIONS

LOGGER_NAME=cs


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
    local pyc="$(get_command "$py")"
	local dpy="$(dirname $pyc)"
    local pip="${2:-pip}"
    local pipc="$(get_command "$pip")"
    local pipo="--ignore-installed --force-reinstall"
    # force reinstalling pip in same place where it is (not /usr/local but /usr)
    if (  echo "$dpy" | egrep -q  "^/" );then
		pipo="$pipo --install-option=--prefix=$(dirname $dpy)"
	fi
    if ( [[ -n "$pipc" ]] && ( version_lt "$($pipc --version|awk '{print $2}')" "2.0" ) );then
        log "Upgrading from legacy pre2 pip"
        easy_install -U --force-installation-into-system-dir -s "$dpy" pip\
            && easy_install -U --force-installation-into-system-dir -s "$dpy" six
        die_in_error "Upgrading legacy pip failed"
    fi
    if [[ -z "$pipc" ]];then
        local DEFAULT_PIP_URL="https://bootstrap.pypa.io/get-pip.py"
        local PIP_URL="${PIP_URL-$DEFAULT_PIP_URL}"
        local PIP_INST="$(mktemp)"

        log "Reinstalling pip via $PIP_URL"
        if ! ( "$py" -c "import urllib; print urllib.urlopen('$PIP_URL').read()" > "$PIP_INST" );then
            log "Error downloading pip installer"
            return 1
        fi
        "$py" "$PIP_INST" -U $pipo
        local pipc="$(get_command $pip)"
        if [[ -z "$pipc" ]];then
            log "pip not found"
            return 1
        fi
    fi
    local dpip="$(dirname $pipc)"
    log "ReInstalling pip ($pipc) for $py"
    "${py}" "${pipc}" install -U $pipo setuptools &&\
    "${py}" "${pipc}" install -U $pipo pip
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

CORPUSOPS_VERSION="1.0"
THIS="$(readlink -f "${0}")"
LAUNCH_ARGS=${@}

get_cops_pip() {
    pip=$(get_command $(basename ${PIP:-pip2}))
    if [[ -z $pip ]]; then
        pip=$(get_command $(basename ${PIP:-pip}))
    fi
    echo $pip
}

ensure_last_virtualenv() {
    venv=$(get_command $(basename ${VIRTUALENV_BIN:-virtualenv}))
    py=$(get_cops_orig_python)
    pip=$(get_cops_pip)
    ez=$(get_command $(basename ${EASY_INSTALL:-easy_install}))
    if ( [[ "x${venv}" == "x/usr/bin/virtualenv" ]] \
         || [[ "x${venv}" == "x/bin/virtualenv" ]] ); then
        if version_lt "$($venv --version)" "15.1.0"; then
            log "Installing last version of virtualenv"
            if [[ -n $pip ]];then
                $(may_sudo) "$py" "$pip" install --upgrade virtualenv
            elif [[ -n $ez ]];then
                $(may_sudo) "$py" "$ez" -U virtualenv
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

get_corpusops_use_venv() {
    ret=$(get_default_knob corpusops_use_venv "${CORPUSOPS_USE_VENV}" "yes")
    if echo $ret | egrep -q "^(yes|1)$";then
        echo yes
    else
        echo no
    fi
}

corpusops_use_venv() {
    ( [[ "$(get_corpusops_use_venv)" == "yes" ]] )
}

get_eggs_src_dir() {
    if corpusops_use_venv;then
        echo "${VENV_PATH}/src"
    else
        echo "${EGGS_SRC_DIR:-/usr/src/corpusops}"
    fi
}

get_corpusops_branch() {
    get_default_knob corpusops_branch "${CORPUSOPS_BRANCH}" "master"
}

get_ansible_branch() {
    get_default_knob ansible_branch "${ANSIBLE_BRANCH}" "stable-2.4"
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
    DO_SYNC_ROLES="${DO_SYNC_ROLES-${DO_SYNC_CODE}}"
    DO_SYNC_ANSIBLE="${DO_SYNC_ANSIBLE-${DO_SYNC_ANSIBLE}}"
    DO_SYNC_CORE="${DO_SYNC_CORE-${DO_SYNC_CODE}}"
    DO_INSTALL_PREREQUISITES="${DO_INSTALL_PREREQUISITES-"y"}"
    DO_SETUP_VIRTUALENV="${DO_SETUP_VIRTUALENV-"y"}"
    NONINTERACTIVE="${NONINTERACTIVE-${DO_NOCONFIRM}}"
    CORPUSOPS_ORGA_URL="${CORPUSOPS_ORGA_URL-}"
    CORPUSOPS_URL="${CORPUSOPS_URL-}"
    CORPUSOPS_BRANCH="${CORPUSOPS_BRANCH-}"
    CORPUSOPS_USE_VENV="${CORPUSOPS_USE_VENV-}"
    ANSIBLE_URL="${ANSIBLE_URL-}"
    ANSIBLE_BRANCH="${ANSIBLE_BRANCH-}"
    PYTESTRPM="${PYTESTRPM:-python-test-2.7.5-48.el7.x86_64.rpm}"
    CENTOSMIRROR="${CENTOSMIRROR:-http://centos.mirrors.ovh.net/ftp.centos.org/7/os/x86_64/Packages/}"
    if [ "x${DO_VERSION}" != "xy" ];then
        DO_VERSION="no"
    fi
    TMPDIR="${TMPDIR:-"/tmp"}"
    BASE_PACKAGES_FILE="${W}/requirements/os_packages.${DISTRIB_ID}"
    DEV_PACKAGES_FILE="${W}/requirements/os_packages_dev.${DISTRIB_ID}"
    EXTRA_PACKAGES_FILE="${W}/requirements/os_extra_packages.${DISTRIB_ID}"
    if [ -e "${BASE_PACKAGES_FILE}" ];then
        BASE_PACKAGES=$(cat "${BASE_PACKAGES_FILE}")
    else
        BASE_PACKAGES=""
    fi
    if [ -e "${DEV_PACKAGES_FILE}" ];then
        DEV_PACKAGES=$(cat "${DEV_PACKAGES_FILE}")
    else
        DEV_PACKAGES=""
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
    export CORPUSOPS_USE_VENV
    #
    export ANSIBLE_URL ANSIBLE_BRANCH
    #
    export EGGS_GIT_DIRS
    #
    export BASE_PACKAGES EXTRA_PACKAGES DEV_PACKAGES
    #
    export DO_NOCONFIRM
    export DO_VERSION
    export DO_ONLY_RECONFIGURE
    export DO_ONLY_SYNC_CODE
    export DO_SYNC_CODE
    export DO_SYNC_ROLES
    export DO_SYNC_ANSIBLE
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

get_cops_orig_python() {
    local default_py=$(
        deactivate 2>/dev/null || :;
        get_python2
        )
    echo ${COPS_ORIG_PYTHON:-${COPS_PYTHON:-$default_py}}
}

get_cops_python() {
    local default_py=$(get_cops_orig_python)
    if ( corpusops_use_venv; );then
        default_py="$VENV_PATH/bin/python"
    fi
    echo ${COPS_PYTHON:-$default_py}
}

check_py_modules() {
    # test if salt binaries are there & working
    bin="$(get_cops_python)"
    if [[ -z $bin ]];then
        sdie "No python2 interpreter found"
    fi
    "${bin}" << EOF
import six
import mitogen
import corpusops
import ansible
import dns
import enum
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
    if ! corpusops_use_venv;then
        bs_yellow_log "   use venv: ${RED}no${NORMAL}"
    fi
    bs_yellow_log "----------------------------------------------------------"
    bs_log "DATE: ${CHRONO}"
    bs_log "W: ${W}"
    bs_yellow_log "---------------------------------------------------"
    if [ "x${DO_SYNC_CODE}" != "xno" ];then
        msg="Syncing:"
        if [ "x${DO_SYNC_ANSIBLE}" != "xno" ];then
            msg="${msg} ansible -"
        fi
        if [ "x${DO_SYNC_CORE}" != "xno" ];then
            msg="${msg} core -"
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

reconfigure() {
    for i in ${W}/requirements/*.in;do
        ${SED} -r \
            -e "s#^\# (-e.*__(ANSIBLE))#\1#g" \
            -e "s#__CORPUSOPS_ORGA_URL__#$(get_corpusops_orga_url)#g" \
            -e "s#__CORPUSOPS_URL__#$(get_corpusops_url)#g" \
            -e "s#__CORPUSOPS_BRANCH__#$(get_corpusops_branch)#g" \
            -e "s#__CORPUSOPS_USE_VENV__#$(get_corpusops_use_venv)#g" \
            -e "s#__ANSIBLE_URL__#$(get_ansible_url)#g" \
            -e "s#__ANSIBLE_BRANCH__#$(get_ansible_branch)#g" \
            "${i}" > "${W}/requirements/$(basename "${i}" .in)"
    done
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

install_prerequisites_() {
    if ! ( $(may_sudo) $W/bin/cops_pkgmgr_install.sh \
                --check-os >/dev/null 2>&1; );then
        warn "Untested OS, assuming everything is in place"
        return 0
    fi
    _PACKAGES=${BASE_PACKAGES}
    if [[ -n ${FORCE_PACKAGES_INSTALL-} ]] || ! is_python_install_complete;then
        log "Virtualenv not complete, installing also system dev packages"
        _PACKAGES="${_PACKAGES} ${DEV_PACKAGES}"
    else
        log "Virtualenv complete, dev packages won't be installed"
    fi
    local pkgs="$(echo $EXTRA_PACKAGES $_PACKAGES)"
    if [ "x${DO_INSTALL_PREREQUISITES}" != "xy" ]; then
        log "prerequisites setup skipped"
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
    SKIP_UPDATE=y SKIP_UPGRADE=y\
        WANTED_EXTRA_PACKAGES="$(echo ${EXTRA_PACKAGES})" \
        WANTED_PACKAGES="$(echo ${_PACKAGES})" \
        vv $(may_sudo) $W/bin/cops_pkgmgr_install.sh 2>&1\
        || sdie "-> Failed install prerequisites"
    # we need either python-software-properties or
    # its software-properties-common replacement
    if is_debian_like;then
        log "installing python pkgs (python-software-properties or software-properties-common)"
        if ! ( SKIP_UPDATE=y SKIP_UPGRADE=y\
            WANTED_PACKAGES="python-software-properties" \
            $(may_sudo) $W/bin/cops_pkgmgr_install.sh >/dev/null 2>&1 );then
                SKIP_UPDATE=y SKIP_UPGRADE=y\
                    WANTED_PACKAGES="software-properties-common" \
                    vv $(may_sudo) $W/bin/cops_pkgmgr_install.sh >/dev/null 2>&1 \
                    || sdie "-> Failed install python apt pkgs"
        fi
    fi
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

checkouter() { (checkouter_ "${@}";) }
checkouter_() {
    export PATH=$SCRIPT_DIR:$PATH;
    ansible-playbook \
        $( [[ -n "${DEBUG}" ]] && echo "-vvvvv" ) \
        -i localhost, -c local "${@}" \
        -e "$( [[ -n "${DEBUG}" ]] && echo "cops_debug=true " \
        )prefix='$(pwd)' venv='${VENV_PATH}'"
}

upgrade_ansible() {
    w="$(pwd)"
    if [ ! -e  "$(get_eggs_src_dir)/ansible/.git" ] && [ -e "$(get_eggs_src_dir)/ansible/lib" ];then
        warn "Ansible is not a checkout but seems there, bypassing"
        return 0
    fi
    upgrade_wd_to_br $(get_ansible_branch) "$(get_eggs_src_dir)/ansible" &&\
        cd "$(get_eggs_src_dir)/ansible" &&\
        ensure_ansible_is_usable
    ret=$?
    cd "$w"
    return $ret
}

checkout_code() {
    if corpusops_use_venv;then
        if ! ( test_ansible_state );then
            bs_yellow_log "Cant sync code, bootstrap core is not done"
            return 1
        fi
    fi
    cd "${W}"
    TO_CHECKOUT=""
    if [ "x$DO_SYNC_ANSIBLE" != "xno" ];then
        if [ -e "$(get_eggs_src_dir)/ansible" ] && ! upgrade_ansible;then
            sdie "Upgrading ansible failed"
        fi
    fi
    if [ "x$DO_SYNC_CORE" != "xno" ];then
        TO_CHECKOUT="${TO_CHECKOUT} checkouts_core.yml"
    fi
    if [ "x$DO_SYNC_ROLES" != "xno" ];then
        TO_CHECKOUT="${TO_CHECKOUT} checkouts_roles.yml"
    fi
    for co in $TO_CHECKOUT;do
        local retries=1
        if [ "x${co}" = "xcheckouts_core.yml" ];then
            retries=2
        fi
        local ret=1
        while [ ${retries} -gt 0 ];do
            retries=$(($retries - 1))
            if ! (\
                SILENT=${SILENT_CHECKOUT-${SILENT-1}} vv\
                checkouter "requirements/${co}" );then
                bs_log "Code failed to update for <$co>"
                ret=2
                if [ "x${co}" = "xcheckouts_core.yml" ];then
                    vv reconfigure || sdie "Reconfigure while updating failed"
                fi
            else
                if [ "x${QUIET}" = "x" ]; then
                    bs_log "Code updated for <$co>"
                    ret=0
                    break
                fi
            fi
        done
        if [ "x${ret}" != "x0" ];then
            return ${ret}
        fi
    done
}

may_activate_venv() {
    if corpusops_use_venv;then
        if [ -e "${VENV_PATH}/bin/activate" ];then
            if [ "x${QUIET}" = "x" ]; then
                bs_log "Activating virtualenv in ${VENV_PATH}"
            fi
            . "${VENV_PATH}/bin/activate"
        else
            export PATH="${VENV_PATH}/bin:${PATH}"
        fi
    fi
}

test_ansible_state() {
    ( QUIET=y may_activate_venv;\
      ansible-playbook --help >/dev/null 2>&1 &&\
      ansible --help >/dev/null 2>&1 )
}

reinstall_egg_path() {
    ( cd "$1" && \
        if corpusops_use_venv;then export PATH=$VENV_PATH/bin:$PATH;fi; \
        vv "$(get_cops_python)" "$(get_cops_pip)" \
               install -U --force-reinstall --no-deps -e . )
}

try_fix_ansible()  {
    bs_log "Try to fix ansible tree"
    local pip="$(get_cops_pip)"
    if ( test_ansible_state| grep -iq pkg_resources.DistributionNotFound ) &&
        [ -e "$(get_eggs_src_dir)/ansible/.git" ] && \
        [ -e "$pip" ];then
        bs_log "Try to reinstall ansible egg"
        vv reinstall_egg_path "$(get_eggs_src_dir)/ansible"
    fi
}

ensure_ansible_is_usable() {
    if ! ( test_ansible_state >/dev/null );then
        bs_log "Error trying to call ansible, will try to fix install"
        try_fix_ansible
        if ! ( test_ansible_state );then
            die "ansible is unusable"
        fi
    fi
}

synchronize_code() {
    ensure_ansible_is_usable
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
            checkout_code && ensure_ansible_is_usable
        fi
    fi
}

ensure_has_virtualenv() {
    # handle specially the mess python-virtualenv/virtualenv on Ubuntu
    if ! has_command virtualenv;then
        if is_debian_like;then
            SKIP_UPGRADE=y\
                WANTED_PACKAGES="virtualenv python-virtualenv" \
                vv $(may_sudo) "$W/bin/cops_pkgmgr_install.sh" 2>&1\
                || die " [bs] Failed install virtualenv extra pkgs"
        fi
        if ! has_command virtualenv;then
            sdie "virtualenv command not found !"
        fi
    fi
}

is_python_install_complete() {
    if corpusops_use_venv && [ ! -e "${VENV_PATH}/bin/activate" ];then
        return 1
    fi
    if ! ( check_py_modules );then
        return 2
    fi
    if ! ( ensure_ansible_is_usable );then
        return 3
    fi
    return 0
}

setup_virtualenv_() {
    ensure_has_virtualenv
    ensure_last_virtualenv
    if [ "x${DO_SETUP_VIRTUALENV}" != "xy" ]; then
        bs_log "virtualenv setup skipped"
        return 0
    fi
    make_virtualenv $(get_cops_orig_python)
}

setup_virtualenv() {
    if ! ( corpusops_use_venv; );then
        warn "corpusops wont be isolated inside a virtualenv"
        return 0
    fi
    ( deactivate >/dev/null 2>&1;\
        set_lang C && setup_virtualenv_; )
    die_in_error "virtualenv setup failed"
}

install_python_libs_() {
    uflag=""
    local PIP=$(get_cops_pip)
    # install requirements
    cd "${W}"
    # virtualenv is present, activate it
    may_activate_venv
    install_git=""
    for i in ${EGGS_GIT_DIRS};do
        if [ ! -e "$(get_eggs_src_dir)/${i}" ]; then
            install_git="x"
        fi
    done
    if [[ -z "$(get_cops_python)" ]];then
        sdie "Python not found (missing python2 interpreter)"
    fi
    if check_py_modules; then
        if [ "x${QUIET}" = "x" ]; then
            bs_log "Pip install in place"
        fi
    else
        bs_log "Python install incomplete"
        local pip=$(get_cops_pip)
        local py=$(get_cops_python)
        if ! ( corpusops_use_venv ) && \
            ! ( $pip --version >/dev/null 2>&1 ) && \
            ( has_command easy_install );then
            upgrade_pip "$py" "$pip" || sdie "upgrading pip failed"
        fi
        local pip=$(get_cops_pip)
        if ! ( $pip --version >/dev/null 2>&1 );then
            sdie "pip not found"
        fi
        upgrade_pip "$py" "$pip" &&\
            COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement six
        die_in_error "base pip python pkgs failed install"
        if $(get_cops_python) --version 2>&1| egrep -iq "python 2\.";then
            COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement enum34
            die_in_error "installing enum on python2"
        fi
        COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement \
            -r requirements/python_requirements.txt
        die_in_error "requirements/python_requirements.txt doesn't install"
        COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement --no-deps -e .
        die_in_error "corpusops egg doesn't install"
        if [ "x${install_git}" != "x" ]; then
            # ansible, salt & docker had bad history for
            # their deps in setup.py we ignore them and manage that ourselves
            COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement \
                --no-deps -r requirements/python_git_requirements.txt
            die_in_error "requirements/python_git_requirements.txt doesn't install"
        else
            cwd="${PWD}"
            for i in ${EGGS_GIT_DIRS};do
                if [ -e "$(get_eggs_src_dir)/${i}" ]; then
                    cd "$(get_eggs_src_dir)/${i}"
                    COPS_PYTHON="$py" PIP="$pip" ensure_last_python_requirement \
                        --no-deps -e .
                    die_in_error "requirements/src eggs doesn't install"
                fi
            done
            cd "${cwd}"
        fi
    fi
}

install_python_libs() {
    ( deactivate >/dev/null 2>&1;\
        set_lang C && install_python_libs_; )
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
                sdie "ln ${origin} -> ${destination} failed"
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
    bs_help "     --skip-sync-ansible" "Do not sync ansible (ansible)" \
        "$(print_contrary ${DO_SYNC_ANSIBLE})"  y
    bs_help "     --skip-sync-core" "Do not sync core (bootstrap)" \
        "$(print_contrary ${DO_SYNC_CORE})"  y
    bs_help "     --skip-sync-roles" "Do not sync roles" \
        "$(print_contrary ${DO_SYNC_ROLES})"  y
    bs_help "    -s|--only-synchronize-code|--only-sync-code|--synchronize-code" "Only sync sourcecode" "${DO_ONLY_SYNC_CODE}" y
    bs_help "    -h|--help / -l/--long-help" "this help message or the long & detailed one" "" y
    bs_help "    --version" "show corpusops version & exit" "${DO_VERSION}" y
    echo
    bs_log "  General settings"
    bs_help "    --orga_url <url>" "corpusops orga  fork git url" \
        "$(get_corpusops_orga_url)" y
    bs_help "    --url <url>" "corpusops orga fork git url" "$(get_corpusops_url)" y
    bs_help "    -b|--branch <branch>" "corpusops fork git branch" "$(get_corpusops_branch)" y
    bs_help "    -u|--use-venv yes/no" "do we use venv" "$(get_corpusops_use_venv)" y
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
        if [ "x${1}" = "x--skip-sync-ansible" ]; then
            DO_SYNC_ANSIBLE="no"
            argmatch="1"
        fi
        if [ "x${1}" = "x--skip-sync-core" ]; then
            DO_SYNC_CORE="no"
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
        if [ "x${1}" = "x--orga-url" ] || [ "x${1}" = "x--corpusops-orga-url" ]; then
            CORPUSOPS_ORGA_URL="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x--url" ] || [ "x${1}" = "x--corpusops-url" ]; then
            CORPUSOPS_URL="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x-u" ] || [ "x${1}" = "x--use-venv" ]; then
            CORPUSOPS_USE_VENV="${2}";sh="2";argmatch="1"
        fi
        if [ "x${1}" = "x--branch" ] || [ "x${1}" = "x-b" ] || [ "x${1}" = "x--corpusops-branch" ]; then
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
        install_prerequisites || die "System prerequisites failed"
        setup_virtualenv || die "setup_virtualenv failed"
        install_python_libs || die "python libs incomplete install"
        ensure_ansible_is_usable
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
s## vim:set et sts=5 ts=4 tw=0:
