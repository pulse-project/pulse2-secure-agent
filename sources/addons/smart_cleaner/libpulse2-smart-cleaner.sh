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

TOOL_DELLATER="/usr/bin/dellater.exe"

ERROR_BAD_OPTION=1
ERROR_MISSING_CONTENT=2
ERROR_ADDITIONNAL_CONTENT=2
ERROR_DELETING_CONTENT=3

PARAM_DIRECTORY=''
PARAM_FILES=''
PARAM_USAGE=0
PARAM_VERBOSE=0
PARAM_DEBUG=0
PARAM_QUIET=0
PARAM_ERROR_ON_ADDITIONNAL=0
PARAM_ERROR_ON_MISSING=0
PARAM_ERROR_ON_DELETING=0

# print usage
usage() {
    echo "Usage: ${0} pulse2-smart-cleaner --directory <top_level_folder> [--files <file01> <file02> ...] [--error-on-missing-content] [--error-on-additionnal-content] [--error-on-deleting-content] [--error-on-locked-tld] [--verbose] [--quiet] [--debug] [--help]"
}

# handle error
error() {
    # $msg is the message
    # $exitcode the exit code
    echo "ERROR : ${1}" >&2
    exit ${2}
}

# handle warning
warning() {
    # $msg is the message
    [ "${PARAM_QUIET}" -eq "1" ] || echo "WARNING : ${1}" >&2
}

# handle debug message
debug() {
    # $msg is the message
    [ "${PARAM_VERBOSE}" -eq "1" ] && echo "DEBUG : ${1}"
}

# handle info message
info() {
    # $msg is the message
    [ "${PARAM_QUIET}" -eq "1" ] || echo "INFO : ${1}"
}

# split ${2} on ',', filling ${1}
splitOnComma() {
    local varname=${1}
    local tosplit=${2}

    OLD_IFS=$IFS
    IFS=','
    set -f ; # disable filename
    set x $tosplit;
    shift
    IFS=$OLD_IFS

    eval "${varname}=\"${@}\""
}

# handle command line arguments
# FIXME: should relay on getopts ?
parseArgs() {
    local next_arg_is_directory=0
    local next_args_are_files=0
    for arg in "${@}"; do
        if [ ${next_arg_is_directory} -eq 1 ]; then
            PARAM_DIRECTORY=${arg}
            next_arg_is_directory=0
        elif [ ${next_args_are_files} -eq 1 ]; then
            # Replace all spaces by pattern '°°°°°'
            arg="`echo ${arg} | sed 's/ /°°°°°/g'`"
            splitOnComma PARAM_FILES ${arg}
            local next_args_are_files=0
        elif `echo ${arg} | grep -qE '^--'`; then
        # Looks likes it's a parameter, let's see which one
            parameter=`echo ${arg} | sed 's/--//g'`
            # Asking for help ? Print usage
            if [ ${parameter} = "help" ] || [ ${parameter} = "usage" ]; then
                PARAM_USAGE=1
            # Verbose mode
            elif [ ${parameter} = "verbose" ]; then
                PARAM_VERBOSE=1
            # Debug mode
            elif [ ${parameter} = "debug" ]; then
                PARAM_DEBUG=1
            # Quiet mode
            elif [ ${parameter} = "quiet" ]; then
                PARAM_QUIET=1
            # Error on additionnal file found
            elif [ ${parameter} = "error-on-additionnal-content" ]; then
                PARAM_ERROR_ON_ADDITIONNAL=1
            # Error on missing file found
            elif [ ${parameter} = "error-on-missing-content" ]; then
                PARAM_ERROR_ON_MISSING=1
            elif [ ${parameter} = "error-on-deleting-content" ]; then
                PARAM_ERROR_ON_DELETING=1
            # next arg is the top level folder
            elif [ ${parameter} = "directory" ] || [ ${parameter} = "folder" ] || [ ${parameter} = "tlf" ]; then
                next_arg_is_directory=1
            # next arg is the files list
            elif [ ${parameter} = "files" ]; then
                next_args_are_files=1
            fi
        else
            continue
        fi
    done
}

# recursive func to obtain our folder content
# args:
#  ${1} name of the var to fill with space_separated list
#  ${2} name of the root folder
# as current folder is always the last to be processed, the list will
# always be organized with sub-elements first, then the current folder
# thanks to this, the list elemnts can be natually deleted (using the
# list order) without conflict
listFolder() {
    local varname=${1}
    local startpoint=${2}

    # Convert name back to the real one (strip spaces replacement chars)
    realstartpoint="`echo ${startpoint} | sed 's/°°°°°/ /g'`"
    # process file (and file-like stuff)
    # file
    [ -f "${realstartpoint}" ] && eval "${varname}=\"\$$varname $startpoint\"" && return
    # symlink
    [ -h "${realstartpoint}" ] && eval "${varname}=\"\$$varname $startpoint\"" && return
    # fifo
    [ -p "${realstartpoint}" ] && eval "${varname}=\"\$$varname $startpoint\"" && return
    # socket
    [ -S "${realstartpoint}" ] && eval "${varname}=\"\$$varname $startpoint\"" && return

    # don't process if not folder
    [ ! -d "${realstartpoint}" ] && return

    # process sub-elements (folders and files)
    for file in $(ls ${startpoint} | sed 's/ /°°°°°/g'); do
        listFolder ${varname} ${startpoint}/${file}
    done

    # at last, tag current folder
    eval "${varname}=\"\$${varname} ${startpoint}/\""
}

buildExpected() {
    local varname="${1}"
    local startpoint="${2}"
    shift
    shift

    for file in $@; do
        eval "${varname}=\"\$${varname} ${startpoint}/$file\""
    done
    
    eval "${varname}=\"\$${varname} ${startpoint}/\""
}

# check if space-separated list ${1} is included into space-separated list ${2}
isIncludedIn() {
    local first_array_name=${1}
    local second_array_name=${2}
    local -a first_array
    local -a second_array
    local retval=0

    # split first array
    set -f ; # disable filename
    eval "set x \$$first_array_name";
    shift
    for i in ${@}; do
        first_array[${#first_array[@]}]=$i
    done

    # split second array
    set -f ; # disable filename
    eval "set x \$$second_array_name";
    shift
    for i in $@; do
        second_array[${#second_array[@]}]=$i
    done

    for initial_value in ${first_array[@]}; do
        local found_in_array=0 # will be set to 1 in value is found
        for final_value in ${second_array[@]}; do
            [ "$initial_value" = "$final_value" ] && found_in_array=1
        done
        # value was not found, thus first_array not included into second_array, thus giving up
        if [ ! $found_in_array -eq 1 ]; then
            warning "$initial_value from $first_array_name not found in $second_array_name"
            retval=1
        fi
    done
    return ${retval}
}

# put windows path of ${1} into var ${2}
getWinPath() {
    local cygpath=${1}
    local varname=${2}
    local finalpath=`mount | grep " on / type"  | sed "s| on / type.*$||"`

    # translate '/' into '\', then removed trailing '\'
    finalpath="${finalpath}\\${cygpath}"
    finalpath=`echo "${finalpath}" | sed 's|/|\\\|g' | sed "s|[\\\]\+$||"`
   
    eval "${varname}=\"${finalpath}\""
}

smart_cleanup() {
    local list_name=${1}
    local -a list

    # generate deletion list
    set -f ; # disable filename
    eval "set x \$$list_name";
    shift
    for i in $@; do
        list[${#list[@]}]=$i
    done

    for filename in ${list[@]]}; do
        filename="`echo ${filename} | sed 's/°°°°°/ /g'`"
        if `echo ${filename} | grep -qE '/$'`; then # this is a folder (ends with /)
            local removeme_later=0
            `rmdir "${filename}" 2>/dev/null` || removeme_later=1
            [ -e "${filename}" ] && removeme_later=1 # sometimes append, unknown reason
            # from here, filename if windows-formated
            getWinPath "${filename}" filename
            if [ ${removeme_later} -eq 0 ]; then
	            info "Removed folder ${filename}"
            else
                if [ ${PARAM_ERROR_ON_DELETING} -eq 1 ]; then
            	    warning "Error removing ${filename}"
            	    return 1
            	fi
                if `$TOOL_DELLATER "${filename}"`; then
                    info "Will remove folder ${filename} during the next reboot"
                else
                    info "Folder ${filename} will never be deleted !"
                fi
            fi
        else # this is a file
            local removeme_later=0
            `rm "${filename}" 2>/dev/null` || removeme_later=1
            [ -e "${filename}" ] && removeme_later=1 # sometimes append, unknown reason
            # from here, filename if windows-formated
            getWinPath "${filename}" filename
            if [ ${removeme_later} -eq 0 ]; then
                info "Removed file ${filename}"
            else
                if [ ${PARAM_ERROR_ON_DELETING} -eq 1 ]; then
            	    warning "Error removing ${filename}"
            	    return 1
            	fi
                if `${TOOL_DELLATER} "${filename}"`; then
                    info "Will remove file ${filename} during the next reboot"
                else
                    info "File ${filename} will never be deleted !"
                fi
            fi
        fi
    done
}
