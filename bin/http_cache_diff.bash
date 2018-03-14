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
	This script is a wrapper around the diff command-line tool.
	Like diff, this script compares two files and outputs a 
	summary of the differences on stdout. Unlike diff, however,
	this script fetches one of the documents from an HTTP server
	and assumes the other document is already cached.
	
	$usage_string
	
	This script takes one command-line argument. The HTTP_LOCATION 
	argument is the absolute URL of an HTTP resource. If the resource 
	is not cached, the script does nothing and returns a nonzero 
	error code.
	
	The script fetches the resource at the given URL using HTTP 
	Conditional GET [RFC 7232]. If the server responds with 200, the 
	document in the response body is compared to the cached document
	using diff. In that case, the script returns whatever exit code 
	diff returns.
	
	If the server responds with 304, the script short-circuits with
	exit code zero (since the two documents are the same).
	
	Note: This script does not update the cache under any circumstances!
	
	Options:
	   -h      Display this help message
	   -D      Enable DEBUG level logging
	   -W      Enable WARN level logging
	   -z      Enable HTTP Compression

	Option -h is mutually exclusive of all other options.
	
	Options -D or -W enable DEBUG or WARN level logging, respectively.
	This temporarily overrides the LOG_LEVEL environment variable,
	whatever it may be.
		
	Option -z enables HTTP Compression by adding an Accept-Encoding 
	header to the HTTP request; that is, if option -z is enabled, the 
	client indicates its support for HTTP Compression in the request. 
	The server may or may not compress the response.
	
	Important! This implementation treats compressed and uncompressed 
	resources as two distinct resources.
	
	The remaining options are specific to the diff command-line tool.
	Consult the diff man page for details.
	
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

	  \$ url=http://md.incommon.org/InCommon/InCommon-metadata.xml
	  ${0##*/} \$url
	  ${0##*/} -z \$url
	  
	Note that the two examples above involve completely different
	cache files since compressed resources are cached separately.
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
[ -z "$LOG_LEVEL" ] && LOG_LEVEL=3

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

usage_string="Usage: $script_name [-hDWzb] [-c|-e|-f|-u] HTTP_LOCATION"

# defaults
help_mode=false

while getopts ":hDWzbcefu" opt; do
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
		[bcefu])
			diff_opts="$diff_opts -$opt"
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
if [ "$#" -ne 1 ]; then
	echo "ERROR: $script_name found $# command-line arguments (1 required)" >&2
	exit 2
fi
location=$1

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

# temporary files
http_file_path="${tmp_dir}/http_file"

# special log messages
initial_log_message="$script_name BEGIN"
final_log_message="$script_name END"

#######################################################################
#
# Main processing
#
# 1. If the resource is not cached, exit with nonzero exit code
# 2. Fetch the resource using HTTP Conditional GET
# 3. If the cached resource is up to date, exit with exit code 0
# 4. Compute the diff and exit with the diff exit code
#
#######################################################################

print_log_message -I "$initial_log_message"

# Check if resource is cached
cache_file_path=$( cache_response_body_file $compression_opt -d "$CACHE_DIR" "$location" )
status_code=$?
if [ $status_code -ne 0 ]; then
	print_log_message -E "$script_name: cache_response_body_file failed ($status_code) on location $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
if [ ! -f "$cache_file_path" ]; then
	print_log_message -E "$script_name: file does not exist: $cache_file_path"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 4
fi
print_log_message -I "$script_name using cached file $cache_file_path"

# Fetch the resource, do not write to cache
print_log_message -D "$script_name fetching HTTP resource $location"
http_conditional_get $compression_opt -F -x -d "$CACHE_DIR" -T "$tmp_dir" "$location" > "$http_file_path"
status_code=$?
if [ $status_code -gt 1 ]; then
	print_log_message -E "$script_name http_conditional_get failed ($status_code) on location $location"
	clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 3
fi
# if HTTP 304 response, short-circuit with exit code 0
[ $status_code -eq 1 ] && clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" 0

# Compute the diff and exit
/usr/bin/diff $diff_opts "$cache_file_path" "$http_file_path"
clean_up_and_exit -d "$tmp_dir" -I "$final_log_message" $?
