#!/bin/bash

#######################################################################
# Copyright 2018 Tom Scavo
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
# Help message
#######################################################################

display_help () {
/bin/cat <<- HELP_MSG
	Given the location of an HTTP resource, this script computes
	and returns the absolute path of the corresponding cache file.
	
	$usage_string
	
	The script exits with code 0 if (and only if) the cache file 
	exists. If the cache file does not exist, the script exits 
	with code 1 but it returns the cache file path in any case.
	
	Options:
	   -h      Display this help message
	   -q      Enable Quiet Mode; suppress normal output
	   -D      Enable DEBUG level logging
	   -W      Enable WARN level logging
	   -z      Enable HTTP Compression

	Option -h is mutually exclusive of all other options.
		
	Option -q enables Quiet Mode. In this case, the cach file path
	is not output.
	
	Options -D or -W enable DEBUG or WARN level logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	Option -z enables HTTP Compression by adding an Accept-Encoding 
	header to the HTTP request; that is, if option -z is enabled, the 
	client indicates its support for HTTP Compression in the request. 
	The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	resources as two distinct resources.
	
	ENVIRONMENT
	
	The following environment variables are REQUIRED:
	
	$( printf "  %s\n" ${env_vars[*]} )
	
	The following directories will be used:
	
	$( printf "  %s\n" ${dir_paths[*]} )
	
	The following log file will be used:
	
	$( printf "  %s\n" $LOG_FILE )
	
	INSTALLATION
	
	At least the following source library files MUST be installed 
	in LIB_DIR:
	
	$( printf "  %s\n" ${lib_filenames[*]} )
	
	EXAMPLES
	
	  \$ url=https://md.incommon.org/InCommon/InCommon-metadata.xml
	  \$ ${0##*/} \$url
	  
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="CACHE_DIR"

# check environment variables
for env_var in ${env_vars[*]}; do
	eval "env_var_val=\${$env_var}"
	if [ -z "$env_var_val" ]; then
		echo "ERROR: $script_name requires env var $env_var" >&2
		exit 2
	fi
done

# required directories
dir_paths[1]="$LIB_DIR"
dir_paths[2]="$CACHE_DIR"

# check required directories
for dir_path in ${dir_paths[*]}; do
	if [ ! -d "$dir_path" ]; then
		echo "ERROR: $script_name: directory does not exist: $dir_path" >&2
		exit 2
	fi
done

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=http_tools.bash
lib_filenames[3]=http_cache_tools.bash
#lib_filenames[4]=compatible_date.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="${LIB_DIR%%/}/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-hqDWz] HTTP_LOCATION"

# defaults
help_mode=false; quiet_mode=false

while getopts ":hqDWz" opt; do
	case $opt in
		h)
			help_mode=true
			;;
		q)
			quiet_mode=true
			;;
		D)
			LOG_LEVEL=4  # DEBUG
			;;
		W)
			LOG_LEVEL=2  # WARN
			;;
		z)
			compression_opt="$compression_opt -$opt"
			;;
		\?)
			echo "ERROR: $script_name: Unrecognized option: -$OPTARG" >&2
			exit 2
			;;
		:)
			echo "ERROR: $script_name: Option -$OPTARG requires an argument" >&2
			exit 2
			;;
	esac
done

if $help_mode; then
	display_help
	exit 0
fi

# check the number of remaining arguments
shift $(( OPTIND - 1 ))
if [ $# -ne 1 ]; then
	echo "ERROR: $script_name: wrong number of arguments: $# (1 required)" >&2
	exit 2
fi
location="$1"

#######################################################################
# Initialization
#######################################################################

# source lib files
for lib_filename in ${lib_filenames[*]}; do
	[[ ! $lib_filename =~ \.bash$ ]] && continue
	lib_file="${LIB_DIR%%/}/$lib_filename"
	source "$lib_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $script_name failed ($status_code) to source lib file $lib_file" >&2
		exit 2
	fi
done

# no temporary directory needed

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
# Main processing
#######################################################################

print_log_message -I "$initial_log_message"

cache_file=$( cache_response_body_file $compression_opt -d "$CACHE_DIR" "$location" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name cache_response_body_file failed ($status_code) to compute cache_file"
	print_log_message -I "$final_log_message"
	exit 3
fi

# success if (and only if) the file exists
status_code=0
[ ! -f "$cache_file" ] && status_code=1

# output the cache file path on stdout if not quiet mode
! $quiet_mode && echo "$cache_file"

print_log_message -I "$final_log_message"
exit $status_code
