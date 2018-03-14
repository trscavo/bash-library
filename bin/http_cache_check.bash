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
	This script checks to see if a previously cached HTTP resource 
	is up-to-date. It is intended to be run as a cron job.
	
	$usage_string
	
	The script takes a single command-line argument, which is the 
	absolute URL of an HTTP resource. Assuming the resource is
	already cached, the script requests the resource via an HTTP 
	conditional request [RFC 7232]. The resource is deemed up-to-date 
	if (and only if) the web server responds with 304 Not Modified.
	
	If the resource is cached and up-to-date, the script exits 
	normally with exit code 0. If the server responds with 200 
	(instead of 304), the script logs a warning and exits with 
	code 1, indicating that the cache is dirty and in need of 
	update. If any other HTTP response is received, the script 
	logs an error and exits with code greater than 1.
	
	Regardless of the exit status, this script produces no output 
	and, moreover, no cache write occurs.
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG logging
	   -W      Enable WARN logging
	   -z      Enable "Compressed Mode"

	Option -h is mutually exclusive of all other options.
	
	Options -D or -W enable DEBUG or WARN logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable.
	
	Compressed Mode (option -z) enables HTTP Compression by adding an 
	Accept-Encoding header to the request; that is, if option -z is 
	enabled, the client merely indicates its support for HTTP Compression 
	in the request. The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	requests for the same resource as two distinct cachable resources.
	
	ENVIRONMENT
	
	The following environment variables are REQUIRED:
	
	$( printf "  %s\n" ${env_vars[*]} )
	
	The optional LOG_LEVEL variable defaults to LOG_LEVEL=3.
	
	The following directories will be used:
	
	$( printf "  %s\n" ${dir_paths[*]} )
	
	The following log file will be used:
	
	$( printf "  %s\n" $LOG_FILE )
	
	INSTALLATION
	
	At least the following source library files MUST be installed 
	in LIB_DIR:
	
	$( printf "  %s\n" ${lib_filenames[*]} )
	
	EXAMPLES
	
	For some HTTP location:
	
	  \$ cget.bash \$url              # prime the cache
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  0                             # the cache is up-to-date
	
	When the resource on the server changes:
	
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  1                             # the cache is NOT up-to-date
	  \$ cget.bash \$url              # update the cache
	  \$ ${0##*/} \$url
	  \$ echo \$?
	  0                             # the cache is up-to-date
HELP_MSG
}

#######################################################################
# Bootstrap
#######################################################################

script_name=${0##*/}  # equivalent to basename $0

# required environment variables
env_vars[1]="LIB_DIR"
env_vars[2]="CACHE_DIR"
env_vars[3]="TMPDIR"
env_vars[4]="LOG_FILE"

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
dir_paths[3]="$TMPDIR"

# check required directories
for dir_path in ${dir_paths[*]}; do
	if [ ! -d "$dir_path" ]; then
		echo "ERROR: $script_name: directory does not exist: $dir_path" >&2
		exit 2
	fi
done

# check the log file
if [ ! -f "$LOG_FILE" ]; then
	echo "ERROR: $script_name: file does not exist: $LOG_FILE" >&2
	exit 2
fi

# default to INFO logging
if [ -z "$LOG_LEVEL" ]; then
	LOG_LEVEL=3
fi

# library filenames
lib_filenames[1]=core_lib.bash
lib_filenames[2]=http_tools.bash
lib_filenames[3]=http_cache_tools.bash
#lib_filenames[4]=compatible_date.bash

# check lib files
for lib_filename in ${lib_filenames[*]}; do
	lib_file="$LIB_DIR/$lib_filename"
	if [ ! -f "$lib_file" ]; then
		echo "ERROR: $script_name: file does not exist: $lib_file" >&2
		exit 2
	fi
done

#######################################################################
# Process command-line options and arguments
#######################################################################

usage_string="Usage: $script_name [-hDWz] HTTP_LOCATION"

# defaults
help_mode=false

while getopts ":hDWz" opt; do
	case $opt in
		h)
			help_mode=true
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
	lib_file="$LIB_DIR/$lib_filename"
	source "$lib_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $script_name failed ($status_code) to source lib file $lib_file" >&2
		exit 2
	fi
done

# create a temporary subdirectory
tmp_dir="${TMPDIR%%/}/${script_name%%.*}_$$"
/bin/mkdir "$tmp_dir"
status_code=$?
if [ $status_code -ne 0 ]; then
	echo "ERROR: $script_name failed ($status_code) to create tmp dir $tmp_dir" >&2
	exit 2
fi

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

# temporary file
tmp_header_file="${tmp_dir}/http_response_header"

#######################################################################
#
# Main processing
#
# 1. Issue an HTTP conditional HEAD request
# 2. Determine the response code by inspecting the header
# 3. Process the response code
#
#######################################################################

print_log_message -I "$initial_log_message"

# issue a HEAD request
http_conditional_head $compression_opt -d "$CACHE_DIR" -T "$tmp_dir" "$location" > "$tmp_header_file"
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: http_conditional_head failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# sanity check
if [ ! -f "$tmp_header_file" ]; then
	print_log_message -E "$script_name unable to find header file $tmp_header_file"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# compute the HTTP response code
response_code=$( get_response_code "$tmp_header_file" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: get_response_code failed ($status_code)"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi

# process the response code
if [ "$response_code" = 200 ]; then
	print_log_message -W "$script_name: cache is NOT up-to-date for resource: $location"
	status_code=1
elif [ "$response_code" = 304 ]; then
	print_log_message -I "$script_name: cache is up-to-date for resource: $location"
	status_code=0
else
	print_log_message -E "$script_name failed with HTTP response code $response_code"
	status_code=4
fi

clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $status_code
