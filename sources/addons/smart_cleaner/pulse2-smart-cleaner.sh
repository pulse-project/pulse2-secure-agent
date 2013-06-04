#!/bin/bash
# (c) 2009 Mandriva, http://www.mandriva.com/
#
# $Id$
#
# This file is part of Pulse 2, http://pulse2.mandriva.org
#
# Pulse 2 is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# Pulse 2 is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Pulse 2; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA 02110-1301, USA.

# sources misc functions
# global
[ -r /usr/share/pulse2/libpulse2-smart-cleaner.sh ] && . /usr/share/pulse2/libpulse2-smart-cleaner.sh
# local override
[ -r /usr/share/pulse2/libpulse2-smart-cleaner.local.sh ] && . /usr/share/pulse2/libpulse2-smart-cleaner.local.sh

# Parse args
parseArgs "$@"

# Show help if asked
[ "${PARAM_USAGE}" -eq "1" ] && usage && exit 0

# Initialize env
[ "${PARAM_DEBUG}" -eq "1" ] && set -x
CURRENT_FOLDER="${PWD}"

debug "PARAM_DIRECTORY : ${PARAM_DIRECTORY}"
debug "PARAM_FILES : ${PARAM_FILES[*]}"

# sanity check
[ "${PARAM_DIRECTORY}" = '' ] && error "Missing parameter directory" ${ERROR_BAD_OPTION}
[ ! -d "${PARAM_DIRECTORY}" ] && error "directory ${PARAM_DIRECTORY} is not a folder" ${ERROR_BAD_OPTION}
[ ! -f "${TOOL_DELLATER}" ] && warning "dellater.exe was not found (supposed to be $TOOL_DELLATER)"

# build real list
listFolder REAL_LIST $PARAM_DIRECTORY
debug "REAL_LIST : ${REAL_LIST}"

# build expected list
buildExpected EXPECTED_LIST $PARAM_DIRECTORY $PARAM_FILES
debug "EXPECTED_LIST : ${EXPECTED_LIST}"

isIncludedIn EXPECTED_LIST REAL_LIST
if [ ! $? -eq 0 ]; then
    if [ ! $PARAM_ERROR_ON_MISSING -eq 0 ]; then
        isIncludedIn REAL_LIST EXPECTED_LIST
        error "Found at least one missing file" ${ERROR_MISSING_CONTENT}
    fi
fi

isIncludedIn REAL_LIST EXPECTED_LIST
if [ ! $? -eq 0 ]; then
    [ $PARAM_ERROR_ON_ADDITIONNAL -eq 0 ] || error "Found at least one additionnal file" ${ERROR_ADDITIONNAL_CONTENT}
fi

smart_cleanup REAL_LIST || error "Failed to removed at least one file" ${ERROR_DELETING_CONTENT}
