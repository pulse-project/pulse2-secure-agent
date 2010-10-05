#!/bin/sh
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

# sources misc functions
# global
[ -r /usr/share/pulse2/libpulse2-client-check.sh ] && . /usr/share/pulse2/libpulse2-client-check.sh
# local override
[ -r /usr/share/pulse2/libpulse2-client-check.local.sh ] && . /usr/share/pulse2/libpulse2-client-check.local.sh

type=""     # Option type, initialize empty
debug=0     # Will be set to 1 if enable
verbose=0   # Will be set to 1 if enable
verifys=""  # Will contains parameters for each type
shows=""
actions=""

# Parse args
parseArgs $@

# Debug mode set -x
[ ${debug} -eq 1 ] && set -x

# Now we know what to do
[ ${verbose} -eq 1 ] && echo "Defined VERIFYS: ${verifys}"
[ ${verbose} -eq 1 ] && echo "Defined SHOWS: ${shows}"
[ ${verbose} -eq 1 ] && echo "Defined ACTIONS: ${actions}"

# Do checks first
for verify in `echo ${verifys} | sed 's/,/ /g'`; do
    var=`echo ${verify} | awk -F'=' '{ print $1 }'`
    value=`echo ${verify} | awk -F'=' '{ print $2 }'`
    verifyValue var value
done

# Check actions then
for action in `echo ${actions} | sed 's/,/ /g'`; do
    var=`echo ${action} | awk -F'=' '{ print $1 }'`
    value=`echo ${action} | awk -F'=' '{ print $2 }'`
    checkAction var
done

# And print values
for show in `echo ${shows} | sed 's/,/ /g'`; do
    var=`echo ${show} | awk -F'=' '{ print $1 }'`
    value=`echo ${show} | awk -F'=' '{ print $2 }'`
    showValue var
done
