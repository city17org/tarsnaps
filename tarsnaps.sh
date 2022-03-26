#!/bin/sh
#
# Copyright (c) 2021 Sean Davies <sean@city17.org>
#
# Permission to use, copy, modify, and distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE

set -e

__version=0.12

PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

archivelimit=99999
archivemax_daily=${archivelimit}
archivemax_weekly=${archivelimit}
archivemax_monthly=${archivelimit}

backupday_weekly=Sun # +%a
backupday_monthly=01 # +%d

datefmt=%Y-%m-%d-%Hh%M
datetime=$(date "+${datefmt}")
dayofweek=$(date -j -f "${datefmt}" "${datetime}" "+%a")
dayofmonth=$(date -j -f "${datefmt}" "${datetime}" "+%d")

die()
{
	echo "$1" 1>&2
	exit 1
}

usage()
{
	die \
	"usage:	${0##*/} [-d max -m max -w max] target ...
	${0##*/} -v"
}

verifyarg()
{
	local _arg="$1" _num

	case ${_arg} in
	''|*[!0-9]*) die "${0##*/}: ${_arg}: invalid number" ;;
	esac

	_num=$(echo "${_arg}" | sed 's/^0*//')
	if [ "${#_num}" -gt "${#archivelimit}" ]; then
		die "${0##*/}: ${_num}: out of range"
	fi
	echo "${_num:-0}"
}

backup()
{
	local _archivename _policy="$1"

	_archivename=$(hostname)-${datetime}-${_policy}
	tarsnap -c -f "${_archivename}" --quiet -- ${targets}
}

prune()
{
	local _archive _archives _archivecount _archivemax="$2"
	local _policy="$1" _prunecount _prunelist

	_archives=$(echo "${archives}" | \
		grep -- "^$(hostname)-.*-${_policy}$") || true
	[ -n "${_archives}" ] || return 0

	_archivecount=$(echo "${_archives}" | wc -l)
	if [ "${_archivecount}" -gt "${_archivemax}" ]; then
		_prunecount=$((_archivecount - _archivemax))
		echo "${_archives}" | sort -r | tail -n "${_prunecount}" | \
			while read -r _prunelist; do
			for _archive in ${_prunelist}; do
				tarsnap -d -f "${_archive}"
			done
		done
	fi
}

dflag=0
mflag=0
vflag=0
wflag=0
while getopts d:m:vw: arg; do
	case ${arg} in
	d)	[ "${dflag}" -eq 0 ] || usage
		archivemax_daily=$(verifyarg "${OPTARG}")
		dflag=1 ;;
	m)	[ "${mflag}" -eq 0 ] || usage
		archivemax_monthly=$(verifyarg "${OPTARG}")
		mflag=1 ;;
	v)	vflag=1 ;;
	w)	[ "${wflag}" -eq 0 ] || usage
		archivemax_weekly=$(verifyarg "${OPTARG}")
		wflag=1 ;;
	*)	usage ;;
	esac
done
shift $((OPTIND - 1))

if [ "${vflag}" -eq 1 ]; then
	[ "$#" -eq 0 ] || usage
	echo "${0##*/}-${__version}"
	exit 0
fi

purge=0
for max in ${archivemax_daily} ${archivemax_weekly} ${archivemax_monthly}; do
	if [ "${max}" -gt 0 ]; then
		targets="$*"
		[ -n "${targets}" ] || usage
		for target in ${targets}; do
			if [ ! -d "${target}" ] && [ ! -f "${target}" ]; then
				die "${0##*/}: ${target}: no such file or directory"
			fi
		done
		break
	fi
	purge=$((purge + 1))
	if [ "${purge}" -eq 3 ]; then
		echo "enter 'NUKE' to continue"
		IFS= read -r line
		if [ "${line}" != "NUKE" ]; then
			die "${0##*/}: incorrect input"
		fi
	fi
done

if ! command -v tarsnap >/dev/null; then
	die "${0##*/}: tarsnap: command not found"
fi

if [ "${archivemax_daily}" -gt 0 ]; then
	backup daily
fi

if [ "${dayofweek}" = "${backupday_weekly}" ]; then
	if [ "${archivemax_weekly}" -gt 0 ]; then
		backup weekly
	fi
fi

if [ "${dayofmonth}" = "${backupday_monthly}" ]; then
	if [ "${archivemax_monthly}" -gt 0 ]; then
		backup monthly
	fi
fi

archives=$(tarsnap --list-archives)
if [ -n "${archives}" ]; then
	for policy in daily weekly monthly; do
		case ${policy} in
		daily) archivemax=${archivemax_daily} ;;
		weekly) archivemax=${archivemax_weekly} ;;
		monthly) archivemax=${archivemax_monthly} ;;
		esac
		prune "${policy}" "${archivemax}"
	done
fi
