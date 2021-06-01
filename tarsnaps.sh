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

__version=0.5

archivelimit=32767

archivemax_daily=${archivelimit}
archivemax_weekly=${archivelimit}
archivemax_monthly=${archivelimit}

backupday_weekly=Sun	# +%a
backupday_monthly=01	# +%d

datefmt='%Y-%m-%d-%Hh%M'
datetime=$(date "+${datefmt}")

# crontab(5) may define a restricted PATH
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

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

backup()
{
	local _archivename _policy=$1 _targets=$2

	_archivename=$(hostname)-${datetime}-${_policy}
	tarsnap -c -f ${_archivename} --quiet ${_targets} || exit 1
}

prune()
{
	local _archive _archives _archivecount _archivemax=$2
	local _policy=$1 _prunecount _prunelist

	_archives=$(echo "${archives}" | grep -- "^$(hostname)-.*-${_policy}$")
	_archivecount=$(echo "${_archives}" | wc -l)

	if [ "${_archivecount}" -gt "${_archivemax}" ]; then
		_prunecount=$((_archivecount - _archivemax))

		echo "${_archives}" \
		  | sort -r \
		  | tail -n ${_prunecount} \
		  | while read -r _prunelist; do
			for _archive in ${_prunelist}; do
				tarsnap -d -f ${_archive} || exit 1
			done
		done
	fi
}

unsignedint()
{
	local _arg=$1

	case ${_arg} in
	''|*[!0-9]*)	die "${0##*/}: ${_arg}: invalid number" ;;
	*)		inrange ${_arg} ;;
	esac
}

inrange()
{
	local _num=$1

	# if $_num is too long, test(1) will fail and continue
	if [ "${#_num}" -gt 8 ] || [ "${_num}" -gt "${archivelimit}" ]; then
		die "${0##*/}: ${_num}: out of range"
	fi
}

stripzeros()
{
	local _num=$1

	_num=$(echo ${_num} | sed 's/^0*//')
	echo "${_num:-0}"
}

if ! command -v tarsnap >/dev/null; then
	die "${0##*/}: tarsnap: command not found"
fi

while getopts "d:m:vw:" arg; do
	case ${arg} in
	d)	unsignedint $OPTARG
		archivemax_daily=$(stripzeros $OPTARG) ;;
	m)	unsignedint $OPTARG
		archivemax_monthly=$(stripzeros $OPTARG) ;;
	v)	vflag=1 ;;
	w)	unsignedint $OPTARG
		archivemax_weekly=$(stripzeros $OPTARG) ;;
	*)	usage ;;
	esac
done
shift $((OPTIND - 1))

if [ "${vflag:-0}" -eq 1 ]; then
	[ "$#" -eq 0 ] || usage
	echo "${0##*/}-${__version}"
	exit 0
fi

for max in ${archivemax_daily} ${archivemax_weekly} ${archivemax_monthly}; do
	if [ "${max}" -gt 0 ]; then
		targets="$*"
		[ -n "${targets}" ] || usage
		break
	fi
done

for target in ${targets:-}; do
	if [ ! -d "${target}" ] && [ ! -f "${target}" ]; then
		die "${0##*/}: ${target}: no such file or directory"
	fi
done

if [ "${archivemax_daily}" -gt 0 ]; then
	backup daily "${targets}"
fi

if [ "${archivemax_weekly}" -gt 0 ]; then
	dayofweek=$(date -j -f ${datefmt} ${datetime} "+%a")
	if [ "${dayofweek}" = "${backupday_weekly}" ]; then
		backup weekly "${targets}"
	fi
fi

if [ "${archivemax_monthly}" -gt 0 ]; then
	dayofmonth=$(date -j -f ${datefmt} ${datetime} "+%d")
	if [ "${dayofmonth}" = "${backupday_monthly}" ]; then
		backup monthly "${targets}"
	fi
fi

archives=$(tarsnap --list-archives) || exit 1
if [ -n "${archives}" ]; then
	for policy in daily weekly monthly; do
		case ${policy} in
		daily)		archivemax=${archivemax_daily} ;;
		weekly)		archivemax=${archivemax_weekly} ;;
		monthly)	archivemax=${archivemax_monthly} ;;
		esac

		prune ${policy} ${archivemax}
	done
fi
