#!/bin/sh
#
# (c) 2008-2010 Adam Cécile for Mandriva, http://www.mandriva.com
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
# This script must be run from a Windows box running Cygwin and all
# the required packages
# A "log" file contains all needed .exe must be present as well
# It will create the whole cygwin tree in "agent-tree" subdir
# It will also create README.Rebuild file

DESTDIR="agent-tree"

# Create directories
rm -rf ${DESTDIR}
mkdir -p ${DESTDIR}/bin
mkdir -p ${DESTDIR}/usr/sbin
mkdir -p ${DESTDIR}/etc/defaults/etc
mkdir -p ${DESTDIR}/usr/share/csih
mkdir -p ${DESTDIR}/var/run
mkdir -p ${DESTDIR}/var/log

rm -f README.Rebuild

# Add /usr/sbin to path
export PATH="${PATH}:/usr/sbin"

# Force use of /bin instead of /usr/bin (which)
export PATH="/bin:${PATH}"

# Return full binary path
returnfullpath() {
  fullpath=`which ${1} 2>/dev/null`
  if [ ! -z ${fullpath} ]; then
    echo "${fullpath}"
  else
    # Special case for 7z binaries
    fullpath=`find /usr/lib/p7zip/ -name "${1}"`
    if [ ! -z ${fullpath} ]; then
      echo "${fullpath}"
    else
      continue
    fi
  fi
}

# Return space separated list of full path for required DLL
returndlldeps() {
  for line in `ldd ${1} | grep -v '/cygdrive/c/' | awk '{ print $1 }' | sed 's/ //g'`; do
    dllname="${line}"
    dllpath=`find /bin /usr/lib /usr/sbin -name ${dllname}`
    list="$list $dllpath"
  done
  if [ ! -z "${list}" ];then
    echo "${list}"
  fi
}

# Copy binary and all its deps to DESTDIR
copyall() {
  deps=`returndlldeps ${1}`
  allfiles="${1}${deps}"
  for file in ${allfiles}; do
    if [ ! -f ${DESTDIR}/${file} ]; then
      cp -v --parents ${file} ${DESTDIR}/
      # Fix broken perms
      chmod -R 755 ${DESTDIR}/${file}
      if [ `echo ${file} | wc -m` -gt 21 ]; then
        echo -e "${file}\t\tCygwin: `cygcheck -f ${file}`" >> README.Rebuild
      else
        echo -e "${file}\t\t\tCygwin: `cygcheck -f ${file}`" >> README.Rebuild
      fi
    else
      echo "${file} already in tree."
    fi
  done
}


# Check if all binaries exists and copy them
for binary in `cat binaries-list`; do
  fullpath=`returnfullpath $binary`
  if [ ! -z  ${fullpath} ]; then
    echo "${binary} found at ${fullpath}"
  else
    echo "${binary} not found anywhere."
    exit 1
  fi
  copyall ${fullpath}
done

# A few more regular needed files
for FILE in `which gunzip` `which awk` /etc/defaults/etc/ssh_config /etc/defaults/etc/sshd_config /etc/moduli /usr/share/terminfo/63/cygwin /usr/share/csih/cygwin-service-installation-helper.sh /etc/postinstall/000-cygwin-post-install.sh.done /bin/ssh-host-config /lib/csih/getAccountName /lib/csih/getVolInfo /lib/csih/winProductName /etc/profile /etc/bash.bashrc /usr/bin/7z /usr/bin/7za /usr/bin/7zr /usr/share/misc/magic.mgc; do
  cp -v --parents ${FILE} ${DESTDIR}
  chmod -R 755 ${DESTDIR}/${FILE}
  if [ "${FILE}" == "/etc/moduli" ]; then
    echo -e "${FILE} \t\t\t\tCygwin: `cygcheck -f ${FILE}`" >> README.Rebuild
  elif [ "${FILE}" == "`which gunzip`" ] || [ "${FILE}" == "`which egrep`" ]; then
    echo -e "${FILE} \t\t\tCygwin: `cygcheck -f ${FILE}`" >> README.Rebuild
  elif [ "${FILE}" == "/etc/postinstall/000-cygwin-post-install.sh.done" ]; then 
    echo -e "${FILE} \tCygwin: `cygcheck -f /etc/postinstall/000-cygwin-post-install.sh`" >> README.Rebuild
  else
    echo -e "${FILE} \tCygwin: `cygcheck -f ${FILE}`" >> README.Rebuild
  fi
done

# And some empty file
for FILE in /var/log/wtmp /var/run/utmp /etc/banner.txt; do
  touch ${DESTDIR}/${FILE}
  chmod -R 755 ${DESTDIR}/${FILE}
  echo -e "${FILE} \t\t\tEmpty file" >> README.Rebuild
done

# Vim config
mkdir ${DESTDIR}/etc/skel/
echo 'set nocompatible' > ${DESTDIR}/etc/skel/.vimrc
echo 'syn on' >> ${DESTDIR}/etc/skel/.vimrc

chmod -R 755 ${DESTDIR}

cat README.Rebuild | sed 's!^!data/cygwin!' | sort > README.Rebuild2
mv README.Rebuild2 README.Rebuild

echo "Done!!"
echo "However you still need to patch ssh-host-config, cygwin-service-installation-helper.sh and cygwin1.dll"
