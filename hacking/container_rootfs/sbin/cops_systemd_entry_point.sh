#!/usr/bin/env bash
set -ex
W=${COPS_ROOT:-/srv/corpusops/corpusops.bootstrap}
R=$W/hacking/container_rootfs
IMG_DEBUG=${IMG_DEBUG-}
IMG_QUIET=${IMG_QUIET}
DEFAULT_SYSTEMD_LOGTARGET=journal
DEFAULT_SYSTEMD_LOGLEVEL=err
if [[ -z ${IMG_QUIET} ]] && [[ -n ${IMG_DEBUG} ]];then
    DEFAULT_SYSTEMD_LOGLEVEL=debug
    #DEFAULT_SYSTEMD_LOGTARGET=console
fi
SYSTEMD_LOGTARGET=${SYSTEMD_LOGTARGET:-"$DEFAULT_SYSTEMD_LOGTARGET"}
SYSTEMD_LOGLEVEL=${SYSTEMD_LOGLEVEL:-${DEFAULT_SYSTEMD_LOGLEVEL}}
SYSTEMD_SHOWSTATUS=${SYSTEMD_SHOWSTATUS:-1}
DEFAULT_SYSTEMD_ARGS="--system --show-status=$SYSTEMD_SHOWSTATUS"
DEFAULT_SYSTEMD_ARGS="$DEFAULT_SYSTEMD_ARGS --log-target=$SYSTEMD_LOGTARGET"
DEFAULT_SYSTEMD_ARGS="$DEFAULT_SYSTEMD_ARGS --log-level=$SYSTEMD_LOGLEVEL"
SYSTEMD_ARGS="${SYSTEM_ARGS:-$DEFAULT_SYSTEMD_ARGS}"
if [[ -n ${CORPUSOPS_IN_DEV-} ]];then
    if [ -e "${R}" ];then
        rsync -av $R/ /
    fi
fi
if [ -e /sbin/init ] && \
    ( /sbin/init --version 2>&1 | grep -iq upstart; ) ;then
    exec /sbin/upstart
else
    if [[ -n $IMG_DEBUG ]];then
        exec strace -f /lib/systemd/systemd $SYSTEMD_ARGS
    else
        /lib/systemd/systemd $SYSTEMD_ARGS
    fi
fi
# vim:set et sts=4 ts=4 tw=80:
