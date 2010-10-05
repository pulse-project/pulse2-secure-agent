#!/bin/sh
#
# (c) 2009 Mandriva, http://www.mandriva.com
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

grep 'data\\cygwin' openssh.nsi | sed 's!^.*\(data\\cygwin\\.*\).*$!\1!' | awk '{ print $1 }' | sed 's/ //g' | sort > /tmp/diff-cygwin.nsi
find data/cygwin/ -type f | sed 's!/!\\!g' | sed 's/ //g' | sort > /tmp/diff-cygwin.file

diff -u /tmp/diff-cygwin.nsi /tmp/diff-cygwin.file

rm -f /tmp/diff-cygwin.nsi /tmp/diff-cygwin.file
