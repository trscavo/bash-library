#!/bin/bash

#######################################################################
# Copyright 2012--2018 Tom Scavo
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#######################################################################

#######################################################################
# A compatibility wrapper around the date command.
#
# This script refers to the "canonical dateTime string format" given by:
#
#   YYYY-MM-DDThh:mm:ssZ
#
# where "T" and "Z" are literals. Such a date is implicitly an UTC
# dateTime string.
#
# This script is compatible with Mac OS and GNU/Linux.
#######################################################################

# today's date (UTC) in canonical string format (YYYY-MM-DD)
date_today () {
	local dateStr

	dateStr=$( /bin/date -u +%Y-%m-%d )

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to produce date string" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

# NOW in locale-specific string format
dateTime_now_locale () {
	local dateStr

	dateStr=$( /bin/date )

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to produce date string" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

# NOW in canonical dateTime string format
dateTime_now_canonical () {
	local dateStr

	dateStr=$( /bin/date -u +%Y-%m-%dT%TZ )

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to produce date string" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

# on a 32-bit system, the maximum representable dateTime in canonical string format
dateTime_max32_canonical () {
	echo 2038-01-19T03:14:07Z
	return 0
}

# convert openssl dateTime string to canonical dateTime string
dateTime_openssl2canonical () {
	local in_date="$1"
	if [ -z "${in_date}" ] ; then
		echo "ERROR: ${0##*/}:$FUNCNAME requires command-line arg" >&2
		return 1
	fi

	local dateStr
	if [[ ${OSTYPE} = darwin* ]] ; then
		dateStr=$( /bin/date -ju -f "%b %e %T %Y GMT" "${in_date}" +%Y-%m-%dT%TZ )
	elif [[ ${OSTYPE} = linux* ]] ; then
		# GNU date(1) understands openssl implicitly
		dateStr=$( /bin/date -u -d "${in_date}" +%Y-%m-%dT%TZ )
	else
		echo "Error: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to convert date string ${in_date}" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

# convert apache dateTime string to canonical dateTime string
dateTime_apache2canonical () {
	local in_date="$1"
	if [ -z "${in_date}" ] ; then
		echo "ERROR: ${0##*/}:$FUNCNAME requires command-line arg" >&2
		return 1
	fi

	local dateStr
	if [[ ${OSTYPE} = darwin* ]] ; then
		dateStr=$( /bin/date -ju -f "%a, %e %b %Y %T GMT" "${in_date}" +%Y-%m-%dT%TZ )
	elif [[ ${OSTYPE} = linux* ]] ; then
		# GNU date(1) understands apache implicitly UNTESTED
		dateStr=$( /bin/date -u -d "${in_date}" +%Y-%m-%dT%TZ )
	else
		echo "Error: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to convert date string ${in_date}" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

# convert canonical dateTime string to a "friendly" date
dateTime_canonical2friendlyDate () {
	local in_date
	local secs
	local friendlyDate
	local exit_status
	
	# check argument
	if [ -z "$1" ] ; then
		echo "ERROR: ${0##*/}:$FUNCNAME requires command-line arg" >&2
		return 1
	fi
	in_date="$1"

	if [[ ${OSTYPE} = darwin* ]] ; then
		# filter fractional seconds
		in_date=$( echo ${in_date} | /usr/bin/sed 's/\.[0-9][0-9]*Z$/Z/' )
		friendlyDate=$( /bin/date -ju -f %Y-%m-%dT%TZ "${in_date}" +'%B %d, %Y' )
	elif [[ ${OSTYPE} = linux* ]] ; then
		# The GNU date(1) command will not parse a "canonical dateTime
		# string" so we convert the input string to a string that the
		# GNU date(1) command will understand: 'YYYY-MM-DD hh:mm:ss UTC'
		in_date=$( echo ${in_date} | /bin/sed 's/^\([^T]*\)T\([^Z]*\)Z$/\1 \2 UTC/' )
		friendlyDate=$( /bin/date -u -d "${in_date}" +'%B %d, %Y' )
	else
		echo "Error: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to convert date string ${in_date}" >&2
		return $exit_status
	fi

	echo "$friendlyDate"
	return
}

# convert canonical dateTime string to seconds past the epoch
dateTime_canonical2secs () {
	local in_date
	
	# check argument
	if [ -z "$1" ] ; then
		echo "ERROR: ${0##*/}:$FUNCNAME requires command-line arg" >&2
		return 1
	fi
	in_date="$1"

	local secs
	if [[ ${OSTYPE} = darwin* ]] ; then
		# filter fractional seconds
		in_date=$( echo ${in_date} | /usr/bin/sed 's/\.[0-9][0-9]*Z$/Z/' )
		secs=$( /bin/date -ju -f %Y-%m-%dT%TZ "${in_date}" +%s )
	elif [[ ${OSTYPE} = linux* ]] ; then
		# The GNU date(1) command will not parse a "canonical dateTime
		# string" so we convert the input string to a string that the
		# GNU date(1) command will understand: 'YYYY-MM-DD hh:mm:ss UTC'
		in_date=$( echo ${in_date} | /bin/sed 's/^\([^T]*\)T\([^Z]*\)Z$/\1 \2 UTC/' )
		secs=$( /bin/date -u -d "${in_date}" +%s )
	else
		echo "Error: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to convert date string ${in_date}" >&2
		return $exit_status
	fi

	echo $secs
	return 0
}

# convert seconds past the epoch to canonical dateTime string
dateTime_secs2canonical () {
	local in_secs="$1"
	if [ -z "${in_secs}" ] ; then
		echo "ERROR: ${0##*/}:$FUNCNAME requires command-line arg" >&2
		return 2
	fi
	
	# check for negative secs
	if [ "$in_secs" -lt 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME: negative secs not allowed: $in_secs" >&2
		return 2
	fi
	

	local dateStr
	if [[ ${OSTYPE} = darwin* ]] ; then
		dateStr=$( /bin/date -ju -r ${in_secs} +%Y-%m-%dT%TZ )
	elif [[ ${OSTYPE} = linux* ]] ; then
		dateStr=$( /bin/date -u -d "1970-01-01 ${in_secs} seconds" +%Y-%m-%dT%TZ )
	else
		echo "Error: OS not supported: ${OSTYPE}" >&2
		return 1
	fi

	local exit_status=$?
	if [ $exit_status -ne 0 ]; then
		echo "ERROR: ${0##*/}:$FUNCNAME failed to convert seconds ${in_secs}" >&2
		return $exit_status
	fi

	echo $dateStr
	return 0
}

#######################################################################
#
# Given a time instant and a duration, compute the time displacement.
#
# Usage: dateTime_delta -b begDateTime duration
#        dateTime_delta -e endDateTime duration
#
# The dateTime argument (begDateTime or endDateTime) is an ISO 8061
# dateTime string in "canonical dateTime string format" as described
# above. The duration argument is an ISO 8061 duration.
#
# If the -b option is specified, the duration is added to the
# begDateTime argument to obtain endDateTime. OTOH, if the -e
# option is specified, the duration is subtracted from the
# given endDateTime argument.
#
# If the duration is zero (PT0S), the computed dateTime value is
# identical to the given dataTime value.
#
#######################################################################
dateTime_delta () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local forward_displacement
	local dateTime_in
	local dateTime_in_secs
	local duration
	local secs
	local dateTime_out
	local dateTime_out_secs
	local exit_status
	
	local opt
	local OPTARG
	local OPTIND
	
	while getopts ":be" opt; do
		case $opt in
			b)
				forward_displacement=true
				;;
			e)
				forward_displacement=false
				;;
			\?)
				print_log_message -E "$FUNCNAME: Unrecognized option: -$OPTARG"
				return 2
				;;
			:)
				print_log_message -E "$FUNCNAME: Option -$OPTARG requires an argument"
				return 2
				;;
		esac
	done
	
	# check option
	if [ -z "$forward_displacement" ]; then
		print_log_message -E "$FUNCNAME: one of options -b or -e required"
		return 2
	fi
	
	# check the number of command-line arguments
	shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	dateTime_in=$1
	duration=$2

	# convert the given dateTime to seconds past the Epoch
	dateTime_in_secs=$( dateTime_canonical2secs $dateTime_in )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) on dateTime: $dateTime_in"
		return 3
	fi
	print_log_message -D "$FUNCNAME: dateTime $dateTime_in is $dateTime_in_secs secs past the Epoch"

	# convert duration to seconds
	secs=$( duration2secs $duration )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: duration2secs failed ($exit_status) on duration: $duration"
		return 3
	fi
	print_log_message -D "$FUNCNAME: duration $duration is $secs secs in length"

	# compute the resulting dateTime
	if $forward_displacement; then
		dateTime_out_secs=$(( dateTime_in_secs + secs ))
	else
		dateTime_out_secs=$(( dateTime_in_secs - secs ))
	fi
	dateTime_out=$( dateTime_secs2canonical $dateTime_out_secs )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_secs2canonical failed ($exit_status)"
		return 3
	fi
	print_log_message -D "$FUNCNAME: dateTime $dateTime_out is $dateTime_out_secs secs past the Epoch"

	echo $dateTime_out
	return 0
}

#######################################################################
#
# Compute the elapsed time (in secs) between two dateTime values.
#
# Usage: secsBetween dateTime1 dateTime2
#
# The dateTime arguments are ISO 8061 dateTime strings in
# "canonical dateTime string format" as described above.
#
# Note: The order of the command line arguments matters.
#
#   if dateTime1 < dateTime2, then the result is positive
#   if dateTime1 > dateTime2, then the result is negative
#   if dateTime1 == dateTime2, then the result is zero
#
#######################################################################
secsBetween () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local dateTime1
	local dateTime2
	local secs1
	local secs2
	#local dateTime1confirm
	#local dateTime2confirm
	local exit_status
	
	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	dateTime1=$1
	dateTime2=$2

	# convert dateTime1 to seconds past the Epoch
	secs1=$( dateTime_canonical2secs $dateTime1 )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) on dateTime: $dateTime1"
		return 3
	fi
	#print_log_message -D "$FUNCNAME: dateTime $dateTime1 is $secs1 secs past the Epoch"

	# sanity check (for logging)
	#dateTime1confirm=$( dateTime_secs2canonical $secs1 )

	# convert dateTime1 to seconds past the Epoch
	secs2=$( dateTime_canonical2secs $dateTime2 )
	exit_status=$?
	if [ $exit_status -ne 0 ]; then
		print_log_message -E "$FUNCNAME: dateTime_canonical2secs failed ($exit_status) on dateTime: $dateTime2"
		return 3
	fi
	#print_log_message -D "$FUNCNAME: dateTime $dateTime2 is $secs2 secs past the Epoch"

	# sanity check (for logging)
	#dateTime2confirm=$( dateTime_secs2canonical $secs2 )

	# compute time difference (which may be negative)
	echo $(( secs2 - secs1 ))

	return 0
}

#######################################################################
#
# Convert seconds into an ISO 8061 duration.
#
# Usage: secs2duration SECONDS
#
#######################################################################
secs2duration () {

	local days
	local hours
	local mins
	local secs
	local remainder
	
	# make sure there is exactly one command-line argument
	if [ $# -eq 1 ]; then
		secs="$1"
	else
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	
	# check for negative secs
	if [ "$secs" -lt 0 ]; then
		echo "ERROR: $FUNCNAME: negative secs not allowed: $secs" >&2
		return 2
	fi
	
	# handle zero secs separately
	if [ "$secs" -eq 0 ]; then
		printf 'PT0S\n'
		return
	fi
	
	# begin duration
	printf 'P'
	
	# compute days
	days=$(( secs / 86400 ))
	if [ "$days" -gt 0 ]; then
		printf '%dD' $days
	fi
	
	# any seconds left over?
	let "remainder = $secs % 86400"
	if [ "$remainder" -gt 0 ]; then
		printf 'T'

		# compute hours
		hours=$(( secs % 86400 / 3600 ))
		if [ "$hours" -gt 0 ]; then
			printf '%dH' $hours
		fi
	
		# compute minutes
		mins=$(( secs % 3600 / 60 ))
		if [ "$mins" -gt 0 ]; then
			printf '%dM' $mins
		fi
	
		# compute seconds
		secs=$(( secs % 60 ))
		if [ "$secs" -gt 0 ]; then
			printf '%dS' $secs
		fi
	fi
	
	# end duration
	printf '\n'

	# an ISO 8601 duration
	#printf 'P%dDT%dH%dM%dS\n' $days $hours $mins $secs
	
	return
}

#######################################################################
#
# Convert an ISO 8061 duration into seconds.
#
# Usage: duration2secs DURATION
#
#######################################################################
duration2secs () {

	local weekPattern
	local datePattern
	local timePattern
	local dateTimePattern
	local duration
	local secs
	
	# make sure there is exactly one command-line argument
	if [ $# -eq 1 ]; then
		duration="$1"
	else
		echo "ERROR: $FUNCNAME: incorrect number of arguments: $# (1 required)" >&2
		return 2
	fi
	
	# regular expression for ISO 8601 duration (week format)
	weekPattern='P([0-9]+)W'

	if [[ $duration =~ $weekPattern ]]; then
		secs=$(( ${BASH_REMATCH[1]} * 7 * 24 * 60 * 60  ))
		echo "$secs"
		return 0
	fi
	
	# regular expression for ISO 8601 duration (dateTime format)
	datePattern='(([0-9]+)Y)?(([0-9]+)M)?(([0-9]+)D)?'
	timePattern='(([0-9]+)H)?(([0-9]+)M)?(([0-9]+)S)?'
	dateTimePattern="P$datePattern(T$timePattern)?"

	if [[ $duration =~ $dateTimePattern ]]; then
		
		secs=0
		
		# years (Y)
		if [ -n "${BASH_REMATCH[1]}" ]; then
			echo "ERROR: $FUNCNAME: years (Y) in duration not supported" >&2
			return 4
		fi

		# months (M)
		if [ -n "${BASH_REMATCH[3]}" ]; then
			echo "ERROR: $FUNCNAME: months (M) in duration not supported" >&2
			return 4
		fi

		# days (D)
		if [ -n "${BASH_REMATCH[5]}" ]; then
			secs=$(( $secs + ${BASH_REMATCH[6]} * 24 * 60 * 60 ))
		fi

		# hours (H)
		if [ -n "${BASH_REMATCH[8]}" ]; then
			secs=$(( $secs + ${BASH_REMATCH[9]} * 60 * 60 ))
		fi

		# minutes (M)
		if [ -n "${BASH_REMATCH[10]}" ]; then
			secs=$(( $secs + ${BASH_REMATCH[11]} * 60 ))
		fi

		# seconds (S)
		if [ -n "${BASH_REMATCH[12]}" ]; then
			secs=$(( $secs + ${BASH_REMATCH[13]} ))
		fi

		echo "$secs"
		return 0

	fi
	
	echo "ERROR: $FUNCNAME: ISO 8601 duration not recognized" >&2
	return 5
}

secs2hours () {
	echo "$1 / ( 60 * 60 )" | /usr/bin/bc -l | /usr/bin/xargs printf "%.2f\n"
}

secs2days () {
	echo "$1 / ( 24 * 60 * 60 )" | /usr/bin/bc -l | /usr/bin/xargs printf "%.2f\n"
}
