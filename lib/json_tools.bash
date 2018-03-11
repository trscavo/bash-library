#!/bin/bash

#######################################################################
# Copyright 2017--2018 Tom Scavo
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
#
# Print an array of JSON objects.
#
# Usage: print_json_array FILE FUNCTION
#
# Each line in the FILE becomes an element of the array.
# The FUNCTION is applied to each line to construct a JSON object.
#
# Dependency:
#   core_lib.bash
# 
#######################################################################
print_json_array () {

	# core_lib dependency
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		exit 2
	fi
	
	local in_file
	local in_func
	local line
	
	# check the number of command-line arguments
	#shift $(( OPTIND - 1 ))
	if [ $# -ne 2 ]; then
		print_log_message -E "$FUNCNAME: incorrect number of arguments: $# (2 required)"
		return 2
	fi
	in_file="$1"
	in_func="$2"
	
	# check arguments
	if [ ! -f "$in_file" ]; then
		print_log_message -E "$FUNCNAME: file not found: $in_file"
		return 4
	fi
	if [ "$(type -t $in_func)" != function ]; then
		print_log_message -E "$FUNCNAME: $in_func is not a function"
		return 4
	fi
	
	# begin JSON array
	printf "[\n"

	$in_func $( /usr/bin/head -n 1 "$in_file" )
	/usr/bin/tail -n +2 "$in_file" | while read -r line; do
		printf "  ,\n"
		$in_func $line
	done

	# end JSON array
	printf "]\n"
}

escape_special_json_chars () {
	local str="$1"
	
	# backslash (\) and double quote (") are special
	echo "$str" | $_SED -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

#######################################################################
# Given a file of HTTP headers (such as that output by the curl
# command-line tool), convert the headers to a JSON object.
#
# Usage: convert_http_headers_json FILE
#
# UNUSED
#
#######################################################################
convert_http_headers_json () {

	# external dependencies
	if [ "$(type -t print_log_message)" != function ]; then
		echo "ERROR: $FUNCNAME: function print_log_message not found" >&2
		return 2
	fi
	if [ "$(type -t get_response_code)" != function ]; then
		echo "ERROR: $FUNCNAME: function get_response_code not found" >&2
		return 2
	fi
	if [ "$(type -t get_header_value)" != function ]; then
		echo "ERROR: $FUNCNAME: function get_header_value not found" >&2
		return 2
	fi

	local headers_file
	local header_name
	local response_code
	local response_date
	local last_modified
	local etag
	local content_length
	local content_type
	local content_encoding
	local status_code
	
	# check arguments
	if [ $# -ne 1 ]; then
		echo "ERROR: $FUNCNAME: wrong number of arguments: $# (1 required)" >&2
		return 2
	fi
	headers_file="$1"
	
	# check file
	if [ ! -f "$headers_file" ]; then
		echo "ERROR: $FUNCNAME: file does not exist: $headers_file" >&2
		return 2
	fi
	
	# get the HTTP response code
	response_code=$( get_response_code $headers_file )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_response_code failed ($status_code) to parse response code from response: $headers_file"
	fi

	# get the Date response header
	header_name=Date
	response_date=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi

	# get the Last-Modified response header
	header_name=Last-Modified
	last_modified=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi

	# get the ETag response header
	header_name=ETag
	etag=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi

	# get the Content-Length response header
	header_name=Content-Length
	content_length=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi

	# get the Content-Type response header
	header_name=Content-Type
	content_type=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi

	response_code=$( escape_special_json_chars "$response_code" )
	response_date=$( escape_special_json_chars "$response_date" )
	last_modified=$( escape_special_json_chars "$last_modified" )
	etag=$( escape_special_json_chars "$etag" )
	content_length=$( escape_special_json_chars "$content_length" )
	content_type=$( escape_special_json_chars "$content_type" )

	# get the Content-Encoding response header
	header_name=Content-Encoding
	content_encoding=$( get_header_value $headers_file $header_name )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		print_log_message -E "$FUNCNAME: get_header_value failed ($status_code) to parse $header_name from response: $headers_file"
	fi
	
	echo  # emit a blank line
	if [ -n "$content_encoding" ]; then
	
		content_encoding=$( escape_special_json_chars "$content_encoding" )
		
		/bin/cat <<- JSON_OBJECT
		    {
		      "ResponseCode": "$response_code",
		      "Date": "$response_date",
		      "LastModified": "$last_modified",
		      "ETag": "$etag",
		      "ContentLength": "$content_length",
		      "ContentType": "$content_type",
		      "ContentEncoding": "$content_encoding"
		    }
JSON_OBJECT
	else
	
		/bin/cat <<- JSON_OBJECT
		    {
		      "ResponseCode": "$response_code",
		      "Date": "$response_date",
		      "LastModified": "$last_modified",
		      "ETag": "$etag",
		      "ContentLength": "$content_length",
		      "ContentType": "$content_type"
		    }
JSON_OBJECT
	fi
	
	return	
}

#######################################################################
#
# Given a SAML metadata file, produce a corresponding JSON object.
#
# Usage: samlmd2json FILE
#
# UNUSED
#
#######################################################################
samlmd2json () {

	# external dependencies
	if [ "$(type -t secsBetween)" != function ]; then
		echo "ERROR: $FUNCNAME: function secsBetween not found" >&2
		return 2
	fi

	local status_code
	local tstamps
	local validityIntervalSecs
	local secsUntilExpiration
	local secsSinceCreation

	print_log_message -I "$FUNCNAME parsing cached metadata for resource: $md_location"

	# extract @ID, @creationInstant, @validUntil (in that order)
	tstamps=$( /usr/bin/xsltproc $xsl_file $xml_file )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to parse metadata"
		print_log_message -E "$FUNCNAME: xsltproc failed ($status_code) on script: $xsl_file"
		return 0
	fi

	# get @validUntil
	validUntil=$( echo "$tstamps" | $_CUT -f3 )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to parse @validUntil"
		print_log_message -E "$FUNCNAME: cut failed ($status_code) on validUntil"
		return 0
	fi

	# if @validUntil is missing, then FAIL
	if [ -z "$validUntil" ]; then
		success=false
		message="XML attribute @validUntil not found"
		print_log_message -E "$FUNCNAME: @validUntil not found"
		return 0
	fi
	print_log_message -D "$FUNCNAME found @validUntil: $validUntil"

	# get @creationInstant
	creationInstant=$( echo "$tstamps" | $_CUT -f2 )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to parse @creationInstant"
		print_log_message -E "$FUNCNAME: cut failed ($status_code) on creationInstant"
		return 0
	fi

	# if @creationInstant is missing, then FAIL
	if [ -z "$creationInstant" ]; then
		success=false
		message="XML attribute @creationInstant not found"
		print_log_message -E "$FUNCNAME: @creationInstant not found"
		return 0
	fi
	print_log_message -D "$FUNCNAME found @creationInstant: $creationInstant"

	# compute length of the validityInterval (in secs)
	validityIntervalSecs=$( secsBetween $creationInstant $validUntil )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to compute validity interval"
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) on validityInterval"
		return 0
	fi

	# convert secs to duration
	validityInterval=$( secs2duration $validityIntervalSecs )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to convert validity interval"
		print_log_message -E "$FUNCNAME: secs2duration failed ($status_code) on validityInterval"
		return 0
	fi
	print_log_message -D "$FUNCNAME computed validity interval: $validityInterval"

	# compute current dateTime
	currentTime=$( dateTime_now_canonical )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to compute current time"
		print_log_message -E "$FUNCNAME: dateTime_now_canonical failed ($status_code) on currentTime"
		return 0
	fi
	print_log_message -D "$FUNCNAME computed current time: $currentTime"

	# compute secsUntilExpiration
	secsUntilExpiration=$( secsBetween $currentTime $validUntil )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to compute time to expiration"
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) on untilExpiration"
		return 0
	fi

	# convert secs to duration
	untilExpiration=$( secs2duration "$secsUntilExpiration" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to convert secs until expiration"
		print_log_message -E "$FUNCNAME: secs2duration failed ($status_code) on untilExpiration"
		return 0
	fi
	print_log_message -D "$FUNCNAME computed time until expiration: $untilExpiration"

	# compute secsSinceCreation
	secsSinceCreation=$( secsBetween $currentTime $creationInstant )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to compute time since creation"
		print_log_message -E "$FUNCNAME: secsBetween failed ($status_code) on sinceCreation"
		return 0
	fi

	# convert secs to duration
	sinceCreation=$( secs2duration "$secsSinceCreation" )
	status_code=$?
	if [ $status_code -ne 0 ]; then
		success=false
		message="Unable to convert secs since creation"
		print_log_message -E "$FUNCNAME: secs2duration failed ($status_code) on sinceCreation"
		return 0
	fi
	print_log_message -D "$FUNCNAME computed time since creation: $sinceCreation"
	
	return 0
}
