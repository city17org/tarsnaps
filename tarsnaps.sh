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
maxdailyarchives=${archivelimit}
maxweeklyarchives=${archivelimit}
maxmonthlyarchives=${archivelimit}

datefmt=%Y-%m-%d-%Hh%M
weeklybackupday=Sun # +%a
monthlybackupday=01 # +%d

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
	local _archive _archives _archivecount _maxarchives="$2"
	local _policy="$1" _prunecount _prunelist

	_archives=$(echo "${archives}" | \
		grep -- "^$(hostname)-.*-${_policy}$") || true
	[ -n "${_archives}" ] || return 0

	_archivecount=$(echo "${_archives}" | wc -l)
	if [ "${_archivecount}" -gt "${_maxarchives}" ]; then
		_prunecount=$((_archivecount - _maxarchives))
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
		maxdailyarchives=$(verifyarg "${OPTARG}")
		dflag=1 ;;
	m)	[ "${mflag}" -eq 0 ] || usage
		maxmonthlyarchives=$(verifyarg "${OPTARG}")
		mflag=1 ;;
	v)	vflag=1 ;;
	w)	[ "${wflag}" -eq 0 ] || usage
		maxweeklyarchives=$(verifyarg "${OPTARG}")
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
for max in ${maxdailyarchives} ${maxweeklyarchives} ${maxmonthlyarchives}; do
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
done

if [ "${purge}" -eq 3 ]; then
	echo "enter 'NUKE' to continue"
	IFS= read -r line
	if [ "${line}" != "NUKE" ]; then
		die "${0##*/}: incorrect input"
	fi
fi

case $(uname -s) in
*BSD)	datetime=$(date "+${datefmt}")
	dayofweek=$(date -j -f "${datefmt}" "${datetime}" "+%a")
	dayofmonth=$(date -j -f "${datefmt}" "${datetime}" "+%d") ;;
Linux)	timestamp=$(date "+%s")
	datetime=$(date -d "@${timestamp}" "+${datefmt}")
	dayofweek=$(date -d "@${timestamp}" "+%a")
	dayofmonth=$(date -d "@${timestamp}" "+%d") ;;
*)	die "${0##*/}: unsupported operating system" ;;
esac

if ! command -v tarsnap >/dev/null; then
	die "${0##*/}: tarsnap: command not found"
fi

if [ "${maxdailyarchives}" -gt 0 ]; then
	backup daily
fi

if [ "${dayofweek}" = "${weeklybackupday}" ]; then
	if [ "${maxweeklyarchives}" -gt 0 ]; then
		backup weekly
	fi
fi

if [ "${dayofmonth}" = "${monthlybackupday}" ]; then
	if [ "${maxmonthlyarchives}" -gt 0 ]; then
		backup monthly
	fi
fi

archives=$(tarsnap --list-archives)
if [ -n "${archives}" ]; then
	for policy in daily weekly monthly; do
		case ${policy} in
		daily) maxarchives=${maxdailyarchives} ;;
		weekly) maxarchives=${maxweeklyarchives} ;;
		monthly) maxarchives=${maxmonthlyarchives} ;;
		esac
		prune "${policy}" "${maxarchives}"
	done
fi
