# (c) 2007-2008 Mandriva, http://www.mandriva.com/
#
# $Id: pulse2-output-wrapper 165 2008-07-30 09:07:57Z nrueff $
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

# Some useful functions
isWindows() {
    uname | grep -qi CYGWIN
    return $?
}
isMacOS() {
    uname | grep -qi Darwin
    return $?
}

# Get computer's hostname
# Strip trailing spaces because Windows "hostname" command
# return a \r, ONLY when run thru SSH, it works when run locally -_-'
getHostname() {
    if isWindows; then
        hostname | tr "[a-z]" "[A-Z]" | sed 's/[[:space:]]\+$//'
    else
        hostname -f | tr "[a-z]" "[A-Z]" | sed 's/[[:space:]]\+$//'
    fi
}
getShortHostname() {
    if isWindows; then
        hostname | tr "[a-z]" "[A-Z]" | sed 's/[[:space:]]\+$//'
    else
        hostname -s | tr "[a-z]" "[A-Z]" | sed 's/[[:space:]]\+$//'
    fi
}

# Case insensitive match
# Return 0 if match, 1 otherwise
istrcompare() {
    # Need two params
    if [ -z "${1}" ] || [ -z "${2}" ]; then
      return 1
    fi
    ival1=`echo "${1}" | tr "[a-z]" "[A-Z]"`
    ival2=`echo "${2}" | tr "[a-z]" "[A-Z]"`
    if [ "${ival1}" = "${ival2}" ]; then
        return 0
    else
        return 1
    fi
}

# Get IP addresses
getIP() {
    if isWindows; then
        # Windows
        pulse2-ether-list.exe | tail -n +2 | awk -F'\\|\\|\\|' '{ print $4 }' | tr "\n" " "
        echo
    elif isMacOS; then
        interfaces=`LANG=C ifconfig -a | grep -v '^[[:space:]]' | awk -F: '{ print $1 }'`
        for interface in ${interfaces}; do 
            ifconfig $interface | grep -q '^[[:space:]]ether' \
              && ifconfig $interface | grep '^[[:space:]]inet[[:space:]]' | awk '{ print $2 }' | sed 's/[[:space:]]//g' | tr "\n" " "
        done
        echo
    else
        # Linux
	interfaces=`LANG=C ifconfig -a | grep 'Link encap:' | grep -v 'Link encap:Local Loopback' | awk '{ print $1 }' | tr "\n" " "`
        for interface in ${interfaces}; do 
            LANC=C ifconfig $interface | grep -e 'inet addr:' -e 'inet adr:' | awk '{ print $2 }' | awk -F: '{ print $2 }' | tr "\n" " ";
        done
        if which ipmitool >/dev/null; then
            ipmitool lan print 2>/dev/null | grep '^IP Address[[:space:]]\+:' |cut -d: -f2- | tr -d '[[:space:]]' | sed 's!$! !' | tr "[a-z]" "[A-Z]"
        fi
        echo
    fi
    echo
}

# Get MAC addresses
getMac() {
    if isWindows; then
        # Windows
        pulse2-ether-list.exe | tail -n +2 | awk -F'\\|\\|\\|' '{ print $3 }' | sed 's/-/:/g' | tr "[a-z]" "[A-Z]" | tr "\n" " "
        echo
    elif isMacOS; then
        interfaces=`LANG=C ifconfig -a | grep -v '^[[:space:]]' | awk -F: '{ print $1 }'`
        for interface in ${interfaces}; do
            ifconfig ${interface} | grep '^[[:space:]]ether' | awk '{ print $2 }' | sed 's/[[:space:]]//g' | tr "[a-z]" "[A-Z]" | tr "\n" " "
        done
        echo
    else
        # Linux
	LANG=C ifconfig -a | grep 'Link encap:Ethernet' | awk -F'HWaddr' '{ print $2 }' | sed 's/[[:space:]]//g' | tr "[a-z]" "[A-Z]" | tr "\n" " "
        if which ipmitool >/dev/null; then
            ipmitool lan print 2>/dev/null | grep '^MAC Address' |cut -d: -f2- | tr -d '[[:space:]]' | sed 's!$! !' | tr "[a-z]" "[A-Z]"
        fi
        echo
    fi
}

# show a requested value
showValue() {
    case "$var" in
        HOSTNAME)
            echo -n ${var}=
            getHostname
        ;;
        IP)
            ips=`getIP | tr -s '[[:space:]]'`
            for ip in ${ips}; do
                echo IP=${ip}
            done
        ;;
        MAC)
            macs=`getMac | tr -s '[[:space:]]'`
            for mac in ${macs}; do
                echo MAC=${mac}
            done
        ;;
        *)
            # I don't know what to do
            continue
        ;;
    esac
}

# check the current action
checkAction() {
    case "${var}" in
        INVENTORY)
            # I don't know what to do
            continue
        ;;
        COPY)
            # I don't know what to do
            continue
        ;;
        EXEC)
            # I don't know what to do
            continue
        ;;
        CLEAN)
            # I don't know what to do
            continue
        ;;
        LOGOFF)
            # I don't know what to do
            continue
        ;;
        REBOOT)
            # I don't know what to do
            continue
        ;;
        *)
            # I don't know what to do
            continue
        ;;
    esac
}

# verify given value
verifyValue() {
    case "${var}" in
        HOSTNAME)
            mismatch=1
            # Default Hostname
            hostname=`getHostname`
            if `istrcompare "${value}" "${hostname}"`; then mismatch=0; fi
            # Short Hostname
            shorthostname=`getShortHostname`
            if `istrcompare "${value}" "${shorthostname}"`; then mismatch=0; fi
            # Return
            if [ ${mismatch} -eq 1 ]; then
                echo "HOSTNAME MISMATCH: $hostname"
                exit 1
            fi
        ;;
        IP)
            mismatch=1
            ips=`getIP | tr -s '[[:space:]]' | sed 's/[[:space:]]\+$//'`
            for ip in ${ips}; do
                if `istrcompare "${value}" "${ip}"`; then mismatch=0; fi
            done
            if [ ${mismatch} -eq 1 ]; then
                echo "IP Address mismatch ! Wanted \"${value}\", found \"${ips}\""
                exit 1
            fi
        ;;
        MAC)
            mismatch=1
            macs=`getMac | tr -s '[[:space:]]' | sed 's/[[:space:]]\+$//'`
            for mac in ${macs}; do
                if `istrcompare "${value}" "${mac}"`; then mismatch=0; fi
            done
            if [ ${mismatch} -eq 1 ]; then
                echo "MAC Address mismatch ! Wanted \"${value}\", found \"${macs}\""
                exit 1
            fi
        ;;
        *)
            # I don't know what to do
            continue
        ;;
    esac
}

# parse CLI args
parseArgs() {
    for arg in $@; do
        # Looks likes it's a parameter, let's see which one
        if `echo ${arg} | grep -qE '^-'`; then
            type=`echo ${arg} | sed 's/-//g'`
            # Asking for help? Print usage
            if [ "${type}" = "help" ] || [ "${type}" = "h" ]; then
                usage
                exit 0
            # Verbose mode
            elif [ "${type}" = "verbose" ]; then
                verbose=1
            # Debug mode
            elif [ "${type}" = "debug" ]; then
                debug=1
                verbose=1
            fi
        elif [ "${type}" = "verify" ]; then
            if [ -z "${verifys}" ] ; then verifys=${arg}; else verifys="${verifys},${arg}"; fi
        elif [ "${type}" = "show" ]; then
            if [ -z "${shows}" ] ; then shows=${arg}; else shows="${shows},${arg}"; fi
        elif [ "${type}" = "action" ]; then
            if [ -z "${actions}" ] ; then actions=${arg}; else actions="${actions},${arg}"; fi
        else
            # Crap
            continue
        fi
    done
}

# print usage
usage() {
    echo "Usage: $0 [--verify arg=value[,arg2=value2,...]] [--show arg[,arg2,...]] [--action action[,action2,...]]"
}
