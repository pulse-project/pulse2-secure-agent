#!/bin/bash
#
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
#
# This is a documentation / example script to build the ssh-agent binary
# installer.
#
# Process description:
# - export the main tree into ssh-agent-build-env
# - export the binaries tree into ssh-agent-build-env
# - using wine, launches nsis to compil the installer
#
# Hav a nice day !

set -e

WGET_CMD=${WGET_CMD:=$(which wget)}
SED_CMD=${SED_CMD:=$(which sed)}
WINE_CMD=${WINE_CMD:=$(which wine)}

SVN_REPO_URI=http://mds.mandriva.org/svn/mmc-projects/pulse2/client/pulse2-secure-agent
SVN_REPO_LPATH=ssh-agent-build-env
VERSION_TARGET='!define PRODUCT_VERSION'

VERSION_STRING=$($WGET_CMD $SVN_REPO_URI/trunk/openssh.nsi -O- 2>/dev/null | grep "$VERSION_TARGET" | sed "s/$VERSION_TARGET \"\(.*\)\"$/\1/")

echo "Exporting main tree"
svn export ${SVN_REPO_URI}/trunk ${SVN_REPO_LPATH} >/dev/null

echo "Exporting binaries tree using tag $VERSION_STRING"
svn export --force ${SVN_REPO_URI}/binaries/trunk ${SVN_REPO_LPATH} >/dev/null

pushd ${SVN_REPO_LPATH} >/dev/null
echo "Compiling stuff"
${WINE_CMD} nsis/makensis openssh.nsi >/dev/null

echo "Got target"
ls -l pulse2-secure-agent-${VERSION_STRING}.exe
popd >/dev/null
