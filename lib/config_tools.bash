#!/bin/bash

#######################################################################
# Copyright 2013--2018 Tom Scavo
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
# Create a default config file.
#
# Usage: create_config [-v] CONFIG_PATH
#
# The CONFIG_PATH argument is the absolute path to the config file.
#######################################################################

create_config () {

	local config_file
	
	# process command-line options (if any)
	local OPTARG
	local OPTIND
	local opt
	local verbose_mode=false
	
	while getopts ":v" opt; do
		case $opt in
			v)
				verbose_mode=true
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done

	# make sure there's at least one command-line argument
	shift $(( OPTIND - 1 ))
	if [ $# -eq 0 ] ; then
		echo "ERROR: $FUNCNAME: no config file to create" >&2
		return 2
	fi
	config_file="$1"
	
	/bin/cat <<- DEFAULT_CONFIG_FILE > $config_file
	#!/bin/bash

	# default MDQ base URL
	[ -z "\$MDQ_BASE_URL" ] && MDQ_BASE_URL=http://mdq-beta.incommon.org/global
	
	# basic curl defaults
	[ -z "\$CONNECT_TIMEOUT_DEFAULT" ] && CONNECT_TIMEOUT_DEFAULT=2
	[ -z "\$MAX_REDIRS_DEFAULT" ] && MAX_REDIRS_DEFAULT=3
	
	# default SAML2 endpoint for testing
	[ -z "\$SAML2_SP_ENTITY_ID" ] && SAML2_SP_ENTITY_ID=https://service1.internet2.edu/shibboleth
	[ -z "\$SAML2_SP_ACS_URL" ] && SAML2_SP_ACS_URL=https://service1.internet2.edu/Shibboleth.sso/SAML2/POST
	[ -z "\$SAML2_SP_ACS_BINDING" ] && SAML2_SP_ACS_BINDING=urn:oasis:names:tc:SAML:2.0:bindings:HTTP-POST

	# default SAML1 endpoint for testing
	[ -z "\$SAML1_SP_ENTITY_ID" ] && SAML1_SP_ENTITY_ID=https://service1.internet2.edu/shibboleth
	[ -z "\$SAML1_SP_ACS_URL" ] && SAML1_SP_ACS_URL=https://service1.internet2.edu/Shibboleth.sso/SAML/POST
	[ -z "\$SAML1_SP_ACS_BINDING" ] && SAML1_SP_ACS_BINDING=urn:oasis:names:tc:SAML:1.0:profiles:browser-post
DEFAULT_CONFIG_FILE

	$verbose_mode && echo "$FUNCNAME created default config file $config_file"
	
	return 0
}

#######################################################################
# Load a config file.
#
# Usage: load_config [-v] CONFIG_PATH
#
# The CONFIG_PATH argument is the absolute path to the config file.
# The -v option produces verbose output, which is most useful for
# testing and debugging.
#######################################################################

load_config () {

	local config_file
	local status_code
	
	# process command-line options (if any)
	local OPTARG
	local OPTIND
	local opt
	local verbose_mode=false
	local local_opts
	
	while getopts ":v" opt; do
		case $opt in
			v)
				verbose_mode=true
				local_opts="-$opt"
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done

	# make sure there's at least one command-line argument
	shift $(( OPTIND - 1 ))
	if [ $# -eq 0 ]; then
		echo "ERROR: $FUNCNAME: no config file to load" >&2
		return 2
	fi
	config_file="$1"

	# create config file if necessary
	if [ -f "$config_file" ]; then
		$verbose_mode && echo "$FUNCNAME using config file $config_file"
	else
		$verbose_mode && echo "$FUNCNAME creating config file $config_file"
		create_config $local_opts $config_file
		status_code=$?
		if [ $status_code -ne 0 ]; then
			echo "ERROR: $FUNCNAME: failed to create config file $config_file" >&2
			return $status_code
		fi
	fi

	# load config file
	$verbose_mode && echo "$FUNCNAME sourcing config file $config_file"
	source "$config_file"
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $FUNCNAME failed to source config file $config_file" >&2
		return $status_code
	fi

	# validate config file
	$verbose_mode && echo "$FUNCNAME validating config file $config_file"
	validate_config $local_opts
	status_code=$?
	if [ $status_code -ne 0 ]; then
		echo "ERROR: $FUNCNAME failed to verify config file $config_file" >&2
		return $status_code
	fi

	return 0
}

#######################################################################
# Validate a previously loaded config file.
#
# Usage: validate_config [-v]
#
# If a required config parameter is missing, this function halts
# and returns a non-zero return code.
#######################################################################

validate_config () {

	local param_name
	local param_names
	local param_value
	
	# process command-line options (if any)
	local OPTARG
	local OPTIND
	local opt
	local verbose_mode=false
	
	while getopts ":v" opt; do
		case $opt in
			v)
				verbose_mode=true
				;;
			\?)
				echo "ERROR: $FUNCNAME: Unrecognized option: -$OPTARG" >&2
				return 2
				;;
			:)
				echo "ERROR: $FUNCNAME: Option -$OPTARG requires an argument" >&2
				return 2
				;;
		esac
	done

	# required config parameters
	param_names="MDQ_BASE_URL
	CONNECT_TIMEOUT_DEFAULT
	MAX_REDIRS_DEFAULT
	SAML2_SP_ENTITY_ID
	SAML2_SP_ACS_URL
	SAML2_SP_ACS_BINDING
	SAML1_SP_ENTITY_ID
	SAML1_SP_ACS_URL
	SAML1_SP_ACS_BINDING"
	
	# check required config parameters
	for param_name in $param_names; do
		eval "param_value=\${$param_name}"
		if [ ! "$param_value" ]; then
			echo "ERROR: $FUNCNAME parameter $param_name undefined" >&2
			return 3
		fi
		$verbose_mode && printf "$FUNCNAME checking $param_name=%s\n" "$param_value"
	done

	return 0
}
