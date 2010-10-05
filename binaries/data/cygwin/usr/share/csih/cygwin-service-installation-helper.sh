#    --  #!/bin/bash  --
# cygwin-service-installation-helper.sh
#
# Copyright (c) 2008 Charles S. Wilson, Corinna Vinschen,
#                    Pierre Humblett, and others listed in
#                    AUTHORS
# 
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use,
# copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following
# conditions:
# 
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
# HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE
#
# -#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
# 
# This is a script library used to assist installing cygwin
# services, such as sshd.  It is derived in part from various
# other sources (see AUTHORS).
#
# Do not attempt to run this file. Instead, it should be "sourced" by
# configuration scripts (such as a newer version of ssh-host-config,
# syslog-config, or iu-config) -- and that script should then use
# the shell functions defined here.
#
# -#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
#
# REQUIREMENTS:
#   SHELL must be bash
#
# PROVIDES:
#    csih_error
#    csih_error_multi
#    csih_error_recoverable
#    csih_warning
#    csih_inform
#    csih_verbose
#    csih_request
#    csih_get_value
#    csih_get_cygenv
#    csih_is_nt
#    csih_is_2k
#    csih_is_xp
#    csih_is_nt2003
#    csih_is_vista
#    csih_is_windows7
#    csih_is_exactly_vista
#    csih_is_exactly_server2008
#    csih_is_exactly_windows7
#    csih_is_exactly_server2008r2
#    csih_version_ge
#    csih_version_le
#    csih_version_gt
#    csih_version_lt
#    csih_version_eq
#    csih_check_program
#    csih_check_program_or_warn
#    csih_check_program_or_error
#    csih_invoke_helper
#    csih_get_localized_account_name
#    csih_get_guest_account_name
#    csih_guest_account_active
#    csih_install_config
#    csih_make_dir
#    csih_sanity_check
#    csih_get_system_and_admins_ids
#    csih_check_passwd_and_group
#    csih_check_user
#    csih_check_dir_perms
#    csih_check_access
#    csih_check_sys_mount
#    csih_check_basic_mounts
#    csih_privileged_accounts
#    csih_privileged_account_exists
#    csih_account_has_necessary_privileges
#    csih_select_privileged_username
#    csih_create_privileged_user
#    csih_create_unprivileged_user
#    csih_service_should_run_as
#    csih_disable_color
#    csih_enable_color
#    csih_path_supports_acls
#    csih_cygver
#    csih_cygver_is_oneseven
#    csih_win_product_name
#
# DEBUG SUPPORT:
#    csih_stacktrace
#    csih_trace_on
#    csih_trace_off
#
# MUTABLE VARIABLES:
#   csih_FORCE_PRIVILEGED_USER
#	if "yes", then create a privileged user even on NT/2k/XP
#       where it is not required (on those versions, LocalSystem
#	will do fine).
#       Set by caller foo-config.
#       NOTE: on NT/2k/XP, IF a well-known privileged user already
#             exists and has all necessary capabilities, then it will
#             be used regardless. This variable forces the creation
#             and use of a privileged user, on NT/2k/XP, when one does
#             not already exist.
#   SYSCONFDIR
#	default value = "/etc", or set by caller foo-config.
#   LOCALSTATEDIR
#	default value = "/var", or set by caller foo-config.
#   csih_auto_answer
#	default value = "" (no automatic answers)
#       Set by caller foo-config
#   csih_value
#       set by csih_get_value
#       foo-config should treat as read-only
#   csih_cygenv
#       set by csih_get_cygenv
#       foo-config should treat as read-only
#   csih_localized_account_name
#       set by csih_get_localized_account_name, csih_get_guest_account_name
#       foo-config should treat as read-only
#   csih_helper_stdout
#   csih_helper_stderr
#       set by csih_invoke_helper and stores the stdout/stderr of the target
#       program. However, if csih_invoke_helper is called in a subshell (e.g.
#           myResult=$(csih_invoke_helper target arg1 arg2)
#       then these values are not available to the caller outside that subshell.
#       foo-config should treat as read-only
#   csih_ADMINSGID
#   csih_ADMINSUID
#   csih_SYSTEMGID
#   csih_SYSTEMUID
#       these four are set by csih_get_system_and_admins_ids (called by _csih_setup)
#       foo-config should treat as read-only
#   csih_PRIVILEGED_USERNAME
#       Set by csih_select_privileged_username (or by calling
#       csih_create_privileged_user, or as a side-effect of calling 
#       csih_service_should_run_as) but may be set explicitly by foo-config
#       foo-config should treat as read-only after first call to any csih_*
#       function
#   csih_PRIVILEGED_PASSWORD
#       Set by csih_create_privileged_user
#       foo-config treat as read-only. To "prime" the value, pass as first argument
#       when calling csih_create_privileged_user
#   csih_WIN32_VOLS_WITH_ACLS
#       a ;-separated list of windows volumes that are guaranteed to support
#       ACLS, even if the getVolInfo program doesn't think so. Used to override
#       getVolInfo when it is wrong (use only as a last resort; getVolInfo is
#       actually faster)
#       Set by caller foo-config
#   csih_WIN32_VOLS_WITHOUT_ACLS=
#       a ;-separated list of windows volumes that do NOT support ACLS, even if
#       the getVolInfo program thinks so. Used to override getVolInfo when it
#       is wrong (use only as a last resort; getVolInfo is actually faster)
#       Set by caller foo-config
#
# CONST variables
#   csih_VERSION
#   csih_progname
#   csih_progname_base
#
# ======================================================================
# Initial setup, default values, etc.
# ======================================================================
csih_progname=$0
csih_progname_base=$(basename -- $csih_progname)
csih_VERSION=0.9.1
readonly csih_progname csih_progname_base csih_VERSION

csih_auto_answer=""
csih_value=
csih_cygenv=
csih_localized_account_name=
csih_FORCE_PRIVILEGED_USER=no
csih_ADMINSGID=
csih_ADMINSUID=
csih_SYSTEMGID=
csih_SYSTEMUID=
csih_PRIVILEGED_USERNAME=
csih_PRIVILEGED_PASSWORD=
csih_helper_stdout=
csih_helper_stderr=
csih_WIN32_VOLS_WITH_ACLS=
csih_WIN32_VOLS_WITHOUT_ACLS=

# delay initialization
_csih_exec_dir=
_csih_script_dir=

_csih_trace=
_csih_sys="`uname`"
_csih_nt=`expr "${_csih_sys}" : "CYGWIN_NT"`
_csih_2k=0
_csih_xp=0
_csih_nt2003=0
_csih_vista=0
_csih_windows7=0
_csih_exactly_server2008=0
_csih_exactly_server2008r2=0
_csih_exactly_vista=0
_csih_exactly_windows7=0
_csih_win_product_name="unknown"

# If running on NT, check if running under 2003 Server or later
if [ ${_csih_nt} -gt 0 ]
then
    _csih_2k=`uname | awk -F- '{print ( $2 >= 5.0 ) ? 1 : 0;}'`
    _csih_xp=`uname | awk -F- '{print ( $2 >= 5.1 ) ? 1 : 0;}'`
    _csih_nt2003=`uname | awk -F- '{print ( $2 >= 5.2 ) ? 1 : 0;}'`
    _csih_vista=`uname | awk -F- '{print ( $2 >= 6.0 ) ? 1 : 0;}'`
    _csih_windows7=`uname | awk -F- '{print ( $2 >= 6.1 ) ? 1 : 0;}'`
fi
readonly _csih_sys _csih_nt _csih_2k _csih_xp _csih_nt2003 _csih_vista

_csih_cygver="1.7.0"
_csih_cygver_is_oneseven=`echo ${_csih_cygver} | awk -F. '{print ( $1 > 1 || ($1 == 1 && $2 >= 7) ) ? 1 : 0;}'`
readonly _csih_cygver _csih_cygver_is_oneseven


if [ -z "${SYSCONFDIR}" ]
then 
  SYSCONFDIR=/etc
fi

if [ -z "${LOCALSTATEDIR}" ]
then
  LOCALSTATEDIR=/var
fi

_csih_all_preexisting_privileged_accounts=
_csih_preferred_preexisting_privileged_account=
_csih_setup_already_called=0
_csih_version_parse_pkg_major=
_csih_version_parse_pkg_minor=
_csih_version_parse_pkg_micro=
_csih_w32vol_as_shell_pattern=
_csih_w32vol_as_shell_pattern_trailing_slash=

_csih_well_known_privileged_accounts="cyg_server sshd_server cron_server"
_csih_well_known_privileged_accounts_quoted="'cyg_server' 'sshd_server' 'cron_server'"
readonly _csih_well_known_privileged_accounts _csih_well_known_privileged_accounts_quoted

_csih_ERROR_STR_COLOR="\e[1;31m*** ERROR:\e[0;0m"
_csih_WARN_STR_COLOR="\e[1;33m*** Warning:\e[0;0m"
_csih_INFO_STR_COLOR="\e[1;32m*** Info:\e[0;0m"
_csih_QUERY_STR_COLOR="\e[1;35m*** Query:\e[0;0m"
_csih_STACKTRACE_STR_COLOR="\e[1;36m*** STACKTRACE:\e[0;0m"
readonly _csih_ERROR_STR_COLOR _csih_WARN_STR_COLOR
readonly _csih_INFO_STR_COLOR _csih_QUERY_STR_COLOR _csih_STACKTRACE_STR_COLOR

_csih_ERROR_STR_PLAIN="*** ERROR:"
_csih_WARN_STR_PLAIN="*** Warning:"
_csih_INFO_STR_PLAIN="*** Info:"
_csih_QUERY_STR_PLAIN="*** Query:"
_csih_STACKTRACE_STR_PLAIN="*** STACKTRACE:"
readonly _csih_ERROR_STR_PLAIN _csih_WARN_STR_PLAIN
readonly _csih_INFO_STR_PLAIN _csih_QUERY_STR_PLAIN _csih_STACKTRACE_STR_PLAIN

_csih_ERROR_STR="${_csih_ERROR_STR_COLOR}"
_csih_WARN_STR="${_csih_WARN_STR_COLOR}"
_csih_INFO_STR="${_csih_INFO_STR_COLOR}"
_csih_QUERY_STR="${_csih_QUERY_STR_COLOR}"
_csih_STACKTRACE_STR="${_csih_STACKTRACE_STR_COLOR}"

# ======================================================================
# Routine: csih_disable_color
#   Provided so that scripts which are invoked via postinstall
#   can prevent escape codes from showing up in /var/log/setup.log
# ======================================================================
csih_disable_color()
{
  _csih_ERROR_STR="${_csih_ERROR_STR_PLAIN}"
  _csih_WARN_STR="${_csih_WARN_STR_PLAIN}"
  _csih_INFO_STR="${_csih_INFO_STR_PLAIN}"
  _csih_QUERY_STR="${_csih_QUERY_STR_PLAIN}"
  _csih_STACKTRACE_STR="${_csih_STACKTRACE_STR_PLAIN}"
} # === End of csih_disable_color() === #
readonly -f csih_disable_color

# ======================================================================
# Routine: csih_enable_color
# ======================================================================
csih_enable_color()
{
  _csih_ERROR_STR="${_csih_ERROR_STR_COLOR}"
  _csih_WARN_STR="${_csih_WARN_STR_COLOR}"
  _csih_INFO_STR="${_csih_INFO_STR_COLOR}"
  _csih_QUERY_STR="${_csih_QUERY_STR_COLOR}"
  _csih_STACKTRACE_STR="${_csih_STACKTRACE_STR_COLOR}"
} # === End of csih_enable_color() === #
readonly -f csih_enable_color

# ======================================================================
# Routine: csih_stacktrace
# ======================================================================
csih_stacktrace()
{
  set +x # don''t trace this!
  local -i n=$(( ${#FUNCNAME} - 1 ))
  local val=""
  if [ -n "$_csih_trace" ]
  then
    while [ $n -gt 0 ]
    do
      if [ -n "${FUNCNAME[$n]}" ]
      then
        if [ -z "$val" ]
        then
          val="${FUNCNAME[$n]}[${BASH_LINENO[$(($n-1))]}]"
        else
          val="${val}->${FUNCNAME[$n]}[${BASH_LINENO[$(($n-1))]}]"
        fi
      fi
    n=$(($n-1))
    done
    echo -e "${_csih_STACKTRACE_STR} ${val} ${@}"
  fi
} # === End of csih_stacktrace() === #
readonly -f csih_stacktrace

# ======================================================================
# Routine: csih_trace_on
#   turns on shell tracing of csih functions
# ======================================================================
csih_trace_on()
{
  _csih_trace='set -x'
  trap 'csih_stacktrace "returning with" $?; set -x' RETURN
  set -T
  csih_stacktrace "${@}"
} # === End of csih_trace_on() === #
readonly -f csih_trace_on

# ======================================================================
# Routine: csih_trace_off
#   turns off shell tracing of csih functions
# ======================================================================
csih_trace_off()
{
  trap '' RETURN
  csih_stacktrace "${@}"
  _csih_trace=
  set +x
  set +T
} # === End of csih_trace_off() === #
readonly -f csih_trace_off


# ======================================================================
# Routine: csih_is_nt
#   returns 0 (true) if the system is Windows NT or above
#   returns 1 (false) otherwise
# ======================================================================
csih_is_nt()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_nt} -gt 0
} # === End of csih_is_nt() === #
readonly -f csih_is_nt
# ======================================================================
# Routine: csih_is_2k
#   returns 0 (true) if the system is Windows 2000 or above
#   returns 1 (false) otherwise
# ======================================================================
csih_is_2k()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_2k} -gt 0
} # === End of csih_is_2k() === #
readonly -f csih_is_2k
# ======================================================================
# Routine: csih_is_xp
#   returns 0 (true) if the system is Windows XP or above
#   returns 1 (false) otherwise
# ======================================================================
csih_is_xp()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_xp} -gt 0
} # === End of csih_is_xp() === #
readonly -f csih_is_xp
# ======================================================================
# Routine: csih_is_nt2003
#   returns 0 (true) if the system is Windows Server 2003 or above
#   returns 1 (false) otherwise
# ======================================================================
csih_is_nt2003()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_nt2003} -gt 0
} # === End of csih_is_nt2003() === #
readonly -f csih_is_nt2003
# ======================================================================
# Routine: csih_is_vista
#   returns 0 (true) if the system is Windows Vista/Windows Server 2008
#   or above.
#   returns 1 (false) otherwise
# ======================================================================
csih_is_vista()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_vista} -gt 0
} # === End of csih_is_vista() === #
readonly -f csih_is_vista
# ======================================================================
# Routine: csih_is_windows7
#   returns 0 (true) if the system is Windows 7/Windows Server 2008r2
#   or above.
#   returns 1 (false) otherwise
# ======================================================================
csih_is_windows7()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_windows7} -gt 0
} # === End of csih_is_windows7() === #
readonly -f csih_is_windows7
# ======================================================================
# Routine: csih_cygver
#   returns the dotted-triple version number of the currently-running
#      cygwin dll. Avoids forking uname multiple times.
# ======================================================================
csih_cygver()
{
  csih_stacktrace "${@}"
  $_csih_trace
  echo $_csih_cygver
} # === End of csih_cygver() === #
readonly -f csih_cygver
# ======================================================================
# Routine: csih_cygver_is_oneseven
#   returns 0 (true) if the currently-running cygwin dll is version
#      1.7.0 or above (including pre-release betas).
#   returns 1 (false) otherwise
# ======================================================================
csih_cygver_is_oneseven()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_cygver_is_oneseven} -gt 0 
} # === End of csih_cygver_is_oneseven() === #
readonly -f csih_cygver_is_oneseven
# ======================================================================
# Routine: csih_is_exactly_vista
#   returns 0 (true) if the system is one of the variants of
#      Windows Vista (Home Basic, Home Premium, Business, etc) but NOT
#      Server2008 or some newer edition (like Windows7)
#   returns 1 (false) otherwise
# ======================================================================
csih_is_exactly_vista()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_exactly_vista} -gt 0
} # === End of csih_is_exactly_vista() === #
#NOTE: do not make _csih_exactly_vista readonly YET

# ======================================================================
# Routine: csih_is_exactly_server2008
#   returns 0 (true) if the system is one of the variants of
#      Windows Server 2008 but NOT one of the variants of Vista, nor
#      some newer edition (like Windows7)
#   returns 1 (false) otherwise
# ======================================================================
csih_is_exactly_server2008()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_exactly_server2008} -gt 0
} # === End of csih_is_exactly_server2008() === #
#NOTE: do not make _csih_exactly_server2008 readonly YET

# ======================================================================
# Routine: csih_is_exactly_windows7
#   returns 0 (true) if the system is one of the variants of
#      Windows 7 (Home Premium, Professional, etc) but NOT Server2008R2
#      or some newer edition (like Windows8, or whatever Microsoft
#      Marketing has decided to call it).
#   returns 1 (false) otherwise
# ======================================================================
csih_is_exactly_windows7()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_exactly_windows7} -gt 0
} # === End of csih_is_exactly_windows7() === #
#NOTE: do not make _csih_exactly_windows7 readonly YET

# ======================================================================
# Routine: csih_is_exactly_server2008r2
#   returns 0 (true) if the system is one of the variants of
#      Windows Server 2008 R2 but NOT one of the variants of Windows7,
#      nor some newer edition.
#   returns 1 (false) otherwise
# ======================================================================
csih_is_exactly_server2008r2()
{
  csih_stacktrace "${@}"
  $_csih_trace
  test ${_csih_exactly_server2008r2} -gt 0
} # === End of csih_is_exactly_server2008r2() === #
#NOTE: do not make _csih_exactly_server2008r2 readonly YET

# ======================================================================
# Routine: csih_win_product_name
#   Allows to cache the result of calling winProductName.
# ======================================================================
csih_win_product_name()
{
  csih_stacktrace "${@}"
  $_csih_trace
  echo $_csih_win_product_name
} # === End of csih_win_product_name() === #
#NOTE: do not make _csih_win_product_name readonly YET

# ======================================================================
# Routine: csih_error
#   Prints the (optional) error message $1, then
#   Exits with the error code contained in $? if $? is non-zero, otherwise
#     exits with status 1
#   All other arguments are ignored
# Example: csih_error "missing file"
# NEVER RETURNS
# ======================================================================
csih_error()
{
  local errorcode=$?
  set +x # don't trace this, but we are interested in who called
  csih_stacktrace # we'll see the arguments in the next statement
  if ((errorcode == 0))
  then
    errorcode=1
  fi
  echo -e "${_csih_ERROR_STR} ${1:-no error message provided}"
  exit ${errorcode};
} # === End of csih_error() === #
readonly -f csih_error

# ======================================================================
# Routine: csih_error_multi
#   Prints the (optional) error messages in the positional arguments, one
#     per line, and then
#   Exits with the error code contained in $? if $? is non-zero, otherwise
#     exits with status 1
#   All other arguments are ignored
# Example: csih_error_multi "missing file" "see documentation"
# NEVER RETURNS
# ======================================================================
csih_error_multi()
{
  local errrorcode=$?
  set +x # don't trace this, but we are interested in who called
  csih_stacktrace # we'll see the arguments in the next statement
  if ((errorcode == 0))
  then
    errorcode=1
  fi
  while test $# -gt 1
  do
    echo -e "${_csih_ERROR_STR} ${1}"
    shift
  done
  echo -e "${_csih_ERROR_STR} ${1:-no error message provided}"
  exit ${errorcode};
} # === End of csih_error_multi() === #
readonly -f csih_error_multi

# ======================================================================
# Routine: csih_error_recoverable
#   Prints the supplied errormessage, and propagates the $? value
# Example: csih_error_recoverable "an error message"
# ======================================================================
csih_error_recoverable()
{
  local errorcode=$?
  set +x # don't trace this, but we are interested in who called
  csih_stacktrace # we'll see the arguments in the next statement
  echo -e "${_csih_ERROR_STR} ${1}"
  $_csih_trace
  return $errorcode
} # === End of csih_error_recoverable() === #
readonly -f csih_error_recoverable


# ======================================================================
# Routine: csih_warning
#   Prints the supplied warning message
# Example: csih_warning "replacing default file foo"
# ======================================================================
csih_warning()
{
  set +x # don't trace this, but we are interested in who called
  csih_stacktrace # we'll see the arguments in the next statement
  echo -e "${_csih_WARN_STR} ${1}"
  $_csih_trace
} # === End of csih_warning() === #
readonly -f csih_warning

# ======================================================================
# Routine: csih_inform
#   Prints the supplied informational message
# Example: csih_inform "beginning dependency analysis..."
# ======================================================================
csih_inform()
{
  set +x # don't trace this, but we are interested in who called
  csih_stacktrace # we'll see the arguments in the next statement
  echo -e "${_csih_INFO_STR} ${1}"
  $_csih_trace
} # === End of csih_inform() === #
readonly -f csih_inform

# ======================================================================
# Routine: csih_verbose
#   prints the supplied command line
#   executes it
#   returns the error status of the command
# Example: csih_verbose rm -f /etc/config-file
# ======================================================================
csih_verbose()
{
  set +x # don't trace this, but we are interested in who called
  local rstatus
  csih_stacktrace # we'll see the arguments in the next statement
  echo "${@}" 1>&2
  "${@}"
  rstatus=$?
  $_csih_trace
  return $rstatus
} # === End of csih_verbose() === #
readonly -f csih_verbose

# ======================================================================
# Routine: csih_version_parse
#   safely parses a version string of the form x.y.z into three 
#   separate values.
# ======================================================================
csih_version_parse() {
  local pkg_version="$1"

  # remove any non-digit characters from the version numbers to permit numeric
  _csih_version_parse_pkg_major=`echo $pkg_version | cut -d. -f1 | sed s/[a-zA-Z\-].*//g`
  _csih_version_parse_pkg_minor=`echo $pkg_version | cut -d. -f2 | sed s/[a-zA-Z\-].*//g`
  _csih_version_parse_pkg_micro=`echo $pkg_version | cut -d. -f3 | sed s/[a-zA-Z\-].*//g`
  test -z "$_csih_version_parse_pkg_major" && _csih_version_parse_pkg_major=0
  test -z "$_csih_version_parse_pkg_minor" && _csih_version_parse_pkg_minor=0
  test -z "$_csih_version_parse_pkg_micro" && _csih_version_parse_pkg_micro=0
}

# ======================================================================
# Routine: csih_version_ge
#   Compares two version strings: $1 ad $2 should both be version
#   strings of the form x.y.z
#   returns true if $1 >= $2, when compared as normal version strings
#   returns false otherwise
# Intended use: if client script requires csih of vintage x.y.z or above,
#   if ! csih_version_ge $csih_VERSION x.y.z ; then some error ; fi
# ======================================================================
csih_version_ge() {
  local lh_pkg_version="$1"
  local rh_pkg_version="$2"
  local lh_pkg_major
  local lh_pkg_minor
  local lh_pkg_micro
  local rh_pkg_major
  local rh_pkg_minor
  local rh_pkg_micro

  csih_version_parse "$lh_pkg_version"
  lh_pkg_major=$_csih_version_parse_pkg_major
  lh_pkg_minor=$_csih_version_parse_pkg_minor
  lh_pkg_micro=$_csih_version_parse_pkg_micro

  csih_version_parse "$rh_pkg_version"
  rh_pkg_major=$_csih_version_parse_pkg_major
  rh_pkg_minor=$_csih_version_parse_pkg_minor
  rh_pkg_micro=$_csih_version_parse_pkg_micro

  if [ $lh_pkg_major -gt $rh_pkg_major ]
  then
    return 0
  elif [ $lh_pkg_major -eq $rh_pkg_major ]
  then
    if [ $lh_pkg_minor -gt $rh_pkg_minor ]
    then
      return 0
    elif [ $lh_pkg_minor -eq $rh_pkg_minor ]
    then
      if [ $lh_pkg_micro -ge $rh_pkg_micro ]
      then
        return 0
      fi
    fi
  fi
  return 1
} # === End of csih_version_ge() === #
readonly -f csih_version_ge

# ======================================================================
# Routine: csih_version_le
#   Compares two version strings: $1 ad $2 should both be version
#   strings of the form x.y.z
#   returns true if $1 <= $2, when compared as normal version strings
#   returns false otherwise
# Intended use: if new versions of csih (above x.y.z) break a client script,
# it can warn the user:
#   if ! csih_version_le $csih_VERSION x.y.z ; then some warning ; fi
# (However, rather than adding a warning about an incompatibility, it 
# would probably be better to fix the script, or csih...)
# ======================================================================
csih_version_le() {
  local lh_pkg_version="$1"
  local rh_pkg_version="$2"
  local lh_pkg_major
  local lh_pkg_minor
  local lh_pkg_micro
  local rh_pkg_major
  local rh_pkg_minor
  local rh_pkg_micro

  csih_version_parse "$lh_pkg_version"
  lh_pkg_major=$_csih_version_parse_pkg_major
  lh_pkg_minor=$_csih_version_parse_pkg_minor
  lh_pkg_micro=$_csih_version_parse_pkg_micro

  csih_version_parse "$rh_pkg_version"
  rh_pkg_major=$_csih_version_parse_pkg_major
  rh_pkg_minor=$_csih_version_parse_pkg_minor
  rh_pkg_micro=$_csih_version_parse_pkg_micro

  if [ $lh_pkg_major -lt $rh_pkg_major ]
  then
    return 0
  elif [ $lh_pkg_major -eq $rh_pkg_major ]
  then
    if [ $lh_pkg_minor -lt $rh_pkg_minor ]
    then
      return 0
    elif [ $lh_pkg_minor -eq $rh_pkg_minor ]
    then
      if [ $lh_pkg_micro -le $rh_pkg_micro ]
      then
        return 0
      fi
    fi
  fi
  return 1
} # === End of csih_version_le() === #
readonly -f csih_version_le

# ======================================================================
# Routine: csih_version_lt
#   Compares two version strings: $1 ad $2 should both be version
#   strings of the form x.y.z
#   returns true if $1 < $2, when compared as normal version strings
# ======================================================================
csih_version_lt() {
  if csih_version_ge "$1" "$2"
  then
    return 1
  fi
  return 0
} # === End of csih_version_lt() === #
readonly -f csih_version_lt
# ======================================================================
# Routine: csih_version_gt
#   Compares two version strings: $1 ad $2 should both be version
#   strings of the form x.y.z
#   returns true if $1 > $2, when compared as normal version strings
# ======================================================================
csih_version_gt() {
  if csih_version_le "$1" "$2"
  then
    return 1
  fi
  return 0
} # === End of csih_version_gt() === #
readonly -f csih_version_gt
# ======================================================================
# Routine: csih_version_eq
#   Compares two version strings: $1 ad $2 should both be version
#   strings of the form x.y.z
#   returns true if $1 == $2, when compared as normal version strings
# ======================================================================
csih_version_eq() {
  local lh_pkg_version="$1"
  local rh_pkg_version="$2"
  local lh_pkg_major
  local lh_pkg_minor
  local lh_pkg_micro
  local rh_pkg_major
  local rh_pkg_minor
  local rh_pkg_micro

  csih_version_parse "$lh_pkg_version"
  lh_pkg_major=$_csih_version_parse_pkg_major
  lh_pkg_minor=$_csih_version_parse_pkg_minor
  lh_pkg_micro=$_csih_version_parse_pkg_micro

  csih_version_parse "$rh_pkg_version"
  rh_pkg_major=$_csih_version_parse_pkg_major
  rh_pkg_minor=$_csih_version_parse_pkg_minor
  rh_pkg_micro=$_csih_version_parse_pkg_micro

  if [ $lh_pkg_major -eq $rh_pkg_major -a $lh_pkg_minor -eq $rh_pkg_minor -a $lh_pkg_micro -eq $rh_pkg_micro ]
  then
    return 0
  fi
  return 1
} # === End of csih_version_eq() === #
readonly -f csih_version_eq

# ======================================================================
# Routine: _csih_warning_for_etc_file
#   Display a warning message for the user about overwriting the 
#   specified file in /etc.
# ======================================================================
_csih_warning_for_etc_file()
{
  csih_stacktrace "${@}"
  csih_warning "The command above overwrites any existing /etc/$1."
  csih_warning "You may want to preserve /etc/$1 before generating"
  csih_warning "a new one, and then compare your saved /etc/$1 file"
  csih_warning "with the newly-generated one in case you need to restore"
  csih_warning "other entries."
} # === End of _csih_warning_for_etc_file() === #
readonly -f _csih_warning_for_etc_file

# ======================================================================
# Routine: csih_request
#   Retrieve user response to a question (in the optional argument $1)
#   Accepts only "yes" or "no", repeats until valid response
#   If csih_auto_answer=="yes", acts as though user entered "yes"
#   If csih_auto_answer=="no", acts as though user entered "no"
#   If "yes" then return 0 (true)
#   If "no" then return 1 (false)
# ======================================================================
csih_request()
{
  csih_stacktrace "${@}"
  local answer=""

  if [ "${csih_auto_answer}" = "yes" ]
  then
    echo -e "${_csih_QUERY_STR} $1 (yes/no) yes"
    return 0
  elif [ "${csih_auto_answer}" = "no" ]
  then
    echo -e "${_csih_QUERY_STR} $1 (yes/no) no"
    return 1
  fi

  while true
  do
    echo -n -e "${_csih_QUERY_STR} $1 (yes/no) "
    if read -e answer
    then
      if [ "X${answer}" = "Xyes" ]
      then
        return 0
      fi
      if [ "X${answer}" = "Xno" ]
      then
        return 1
      fi
    else
      # user did a ^D
      echo -e "Quitting.\n"
      exit 1
    fi
  done
} # === End of csih_request() === #
readonly -f csih_request

# ======================================================================
# Routine: csih_get_value
#   Get a verified non-empty string in variable "csih_value"
#   Prompt with the first argument.
#   The 2nd argument if not empty must be -s. (for "silent" password
#     entry)
# NO AUTOANSWER SUPPORT.
# SETS GLOBAL VARIABLE: csih_value
# ======================================================================
csih_get_value()
{
  csih_stacktrace "${@}"
  local value
  local verify
  while true
  do
    echo -n -e "${_csih_QUERY_STR} "
    if read $2 -p "$1 " value 
    then
      [ -n "$2" ] && echo 
      if [ -n "${value}" ]
      then
        echo -n -e "${_csih_QUERY_STR} "
        read $2 -p "Reenter: " verify
        [ -n "$2" ] && echo
        [ "${verify}" = "${value}" ] && break
      fi
    else
      # user did a ^D
      echo -e "Quitting.\n"
      exit 1
    fi
  done
  echo
  csih_value="${value}"
  return 0
} # === End of csih_get_value() === #
readonly -f csih_get_value

# ======================================================================
# Routine: csih_get_cygenv
#   Retrieves from user the appropriate value for the CYGWIN environment
#     variable to be used with the installed service.
#   All arguments are interpreted together as the desired default value
#     for CYGWIN.
#
# csih_auto_answer behavior:
#   if set (to either "yes" or "no"), use default value
#
# SETS GLOBAL VARIABLE: csih_cygenv
# ======================================================================
csih_get_cygenv()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local default=$*

  # if there is any auto_answer setting, then accept default
  if [ -n "${csih_auto_answer}" ]
  then
    echo -e "${_csih_QUERY_STR} Enter the value of CYGWIN for the daemon: [${default}] ${default}"
    csih_cygenv="${default}"
    return 0
  fi

  while true
  do
    echo -n -e "${_csih_QUERY_STR} Enter the value of CYGWIN for the daemon: [${default}] "
    if read csih_cygenv
    then
      if [ -z "${csih_cygenv}" ]
      then 
        csih_cygenv="${default}"
      fi
      return
    else
      # user did a ^D
      echo -e "Quitting.\n"
      exit 1
    fi
  done
} # === End of csih_get_cygenv() === #
readonly -f csih_get_cygenv


# ======================================================================
# Routine: csih_check_program
#   Check to see that a specified program(s) ($1, $2, ...) are installed 
#   and executable by this script.
# ======================================================================
csih_check_program()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local prog
  local fullpath

  for prog
  do
    if ! hash ${prog} &> /dev/null
    then
      return 1;
    else
      # file exists in PATH, but if it was not executable then
      # hash didn't actually store its value.  Check again...
      fullpath=$(hash -t ${prog} 2>/dev/null)
      if [ -z "${fullpath}" ]
      then
        # not executable
        return 1;
      fi
    fi 
  done

  return 0;
} # === End of csih_check_program() === #
readonly -f csih_check_program

# ======================================================================
# Routine: _csih_get_script_dir
#   private routine to initialize _csih_script_dir
# ======================================================================
_csih_get_script_dir() {
  # should be /usr/share/csih
  local d=$(dirname -- ${BASH_SOURCE[0]})
  local D=$(cd "$d" && pwd)
  echo "$D"
} # === End of csih_get_script_dir() === #
readonly -f _csih_get_script_dir
_csih_script_dir=$(_csih_get_script_dir)
readonly _csih_script_dir

# ======================================================================
# Routine: _csih_get_exec_dir
#   private routine to initialize _csih_exec_dir
# ======================================================================
_csih_get_exec_dir() {
  # should be /usr/lib/csih
  local d=$(dirname -- ${BASH_SOURCE[0]})
  local b=$(basename -- "$d")
  local D=$(cd "$d/../../lib/$b" >/dev/null 2>&1 && pwd)
  local fullpath=
  D=/lib/csih
  if [ -z "$D" ]
  then
    # try /usr/lib/csih explicitly
    if [ -f "/usr/lib/csih/getAccountName.exe" ]
    then
      D=/usr/lib/csih
    else
      # try $PATH
      if csih_check_program getAccountName
      then
        hash ${prog} 2>/dev/null
        fullpath=$(hash -t getAccountName 2>/dev/null)
        D=$(dirname -- "$fullpath") 
      else
        csih_error_recoverable "Could not locate csih helper programs!"
      fi
    fi
  fi
  echo "$D"
} # === End of csih_get_exec_dir() === #
readonly -f _csih_get_exec_dir
_csih_exec_dir=$(_csih_get_exec_dir)
readonly _csih_exec_dir

# ======================================================================
# Routine: csih_check_program_or_warn
#   Check to see that a specified program ($1) is installed and executable
#   by this script.  If not, warn the user that a particular package
#   ($2) is required and return non-zero (false)
#   Otherwise, return 0 (true)
# ======================================================================
csih_check_program_or_warn()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local prog=${1};
  local pkg=${2:-${1}};

  if ! csih_check_program "${prog}"
  then
    csih_warning "Could not find or execute required program $prog."
    csih_warning "Please install ${pkg}";
  fi

  return 0;
} # === End of csih_check_program_or_warn() === #
readonly -f csih_check_program_or_warn

# ======================================================================
# Routine: csih_check_program_or_error
#   Check to see that a specified program ($1) is installed and executable
#   by this script.  If not, inform the user that a particular package
#   ($2) is required, and exit with error
# ======================================================================
csih_check_program_or_error()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local prog=${1};
  local pkg=${2:-${1}};

  if ! csih_check_program "${prog}"
  then
    csih_error_multi "Could not find or execute required program $prog." \
                     "Please install ${pkg}";
  fi

  return 0;
} # === End of csih_check_program_or_error() === #
readonly -f csih_check_program_or_error

# ======================================================================
# Routine: csih_invoke_helper
#   Launches a helper program shipped with cish
#   returns the exit code of the helper program
#   output:
#     stores stdout in 'csih_helper_stdout', and copies to real stdout
#     stores stderr in 'csih_helper_stderr', and emits as a recoverable
#       error to the real stderr
#   Note that if csih_invoke_helper is executed in a subshell, then
#   the contents of csih_helper_stdout/csih_helper_stderr are not
#   available to the caller.
#
# SETS GLOBAL VARIABLE: csih_helper_stdout csih_helper_stderr
# ======================================================================
csih_invoke_helper()
{
  set +x # don''t trace this, but we are interested in who called
  local result
  local stdout
  local var_out
  local var_err
  local SEP="----- separator -----"
  local helper=
  csih_stacktrace "${@}"
  helper="$1"
  shift
  csih_helper_stdout=""
  csih_helper_stderr=""

  if [ -n "${_csih_exec_dir}" ]
  then
    if [ -f "${_csih_exec_dir}/${helper}" ]
    then
      result=$( { stdout=$("${_csih_exec_dir}/${helper}" "${@}"); } 2>&1; \
        printf "%s\n%d\n%s\n" "${SEP}" $? "${SEP}"; printf "%s" "$stdout" )
      var_out=${result##*${SEP}$'\n'}
      var_err=${result%%$'\n'${SEP}*}
      var_out=${var_out/*${SEP}/}
      var_err=${var_err/${SEP}*/}
      result=${result%$'\n'${SEP}*}
      result=${result#*${SEP}$'\n'}
      if [ -n "${var_err}" ]; then
        csih_helper_stderr=$(echo "$var_err" | sed -e 's/\r//g')
        csih_error_recoverable "${helper}: ${csih_helper_stderr//\\/\\\\}" 1>&2
      fi
      if [ -n "${var_out}" ]; then
        csih_helper_stdout=$(echo "$var_out" | sed -e 's/\r//g')
        echo "${csih_helper_stdout}"
      fi
    else
      csih_error "Could not find ${helper} in ${_csih_exec_dir}"
    fi
  else
    csih_error "Could not find csih helper programs!"
  fi

  $_csih_trace
  return $result
} # === End of csih_invoke_helper() === #
readonly -f csih_invoke_helper

# ======================================================================
# Routine: csih_sanity_check
#   Check for the set of programs that are used by this script.
#   Returns 0 on success, non-zero on failure
# ======================================================================
csih_sanity_check()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local ret=0
  # Check for programs that this script uses.
  csih_check_program_or_warn awk gawk || ret=1
  csih_check_program_or_warn ls coreutils || ret=1
  csih_check_program_or_warn grep grep || ret=1
  csih_check_program_or_warn sed sed || ret=1
  csih_check_program_or_warn id coreutils || ret=1
  csih_check_program_or_warn cut coreutils || ret=1
  csih_check_program_or_warn uname coreutils || ret=1
  csih_check_program_or_warn cygcheck cygwin || ret=1
  csih_check_program_or_warn getfacl cygwin || ret=1
  csih_check_program_or_warn regtool cygwin || ret=1
  csih_check_program_or_warn chmod coreutils || ret=1
  csih_check_program_or_warn chown coreutils || ret=1
  csih_check_program_or_warn mkdir coreutils || ret=1
  csih_check_program_or_warn stat coreutils || ret=1
  csih_check_program_or_warn cp coreutils || ret=1
  # do not check for editrights here -- clients which use this
  # library may not need the editrights functionality
  return "${ret}"
} # === End of csih_sanity_check() === #
readonly -f csih_sanity_check

# ======================================================================
# Routine: csih_get_localized_account_name
#   Obtains the localized account name for the specified well-known
#   account, where $1 indicates by number which account is of interest.
#   The account name is stored in the variable csih_localized_account_name
#   See WELL_KNOWN_SID_TYPE documentation for the association between
#   well known accounts and the $1 numbers accepted here. Of interest:
#      Local Guest:   39
#      Domain Guest:  43
#      Administrator: 38
#   Returns 0 on success, non-zero on failure
#
# SETS GLOBAL VARIABLE: csih_localized_account_name
# ======================================================================
csih_get_localized_account_name()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local rstatus
  local name

  name=$(csih_invoke_helper getAccountName --number $1)
  rstatus=$?
  if [ "$rstatus" -eq 0 ]
  then
    csih_localized_account_name="${name}"
  else
    csih_localized_account_name=""
  fi
  return $rstatus
} # === End of csih_get_localized_account_name() === #
readonly -f csih_get_localized_account_name

# ======================================================================
# Routine: csih_get_guest_account_name
#   Obtains the localized account name for the Guest user.
#   The account name is stored in the variable csih_localized_account_name
#   Returns 0 on success, non-zero on failure
#
# SETS GLOBAL VARIABLE: csih_localized_account_name
# ======================================================================
csih_get_guest_account_name()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local name
  local rstatus

  name=$(csih_invoke_helper getAccountName -g)
  rstatus=$?
  if [ "$rstatus" -eq 0 ]
  then
    csih_localized_account_name="${name}"
  else
    csih_localized_account_name=""
  fi
  return $rstatus
} # === End of csih_get_guest_account_name() === #
readonly -f csih_get_guest_account_name

# ======================================================================
# Routine: _csih_convert_w32vol_to_shell_pattern
#   Converts the path specified as $1 to a shell pattern suitable
#   for use in a case statement.  For instance:
#      E:             -> [Ee]:
#      //server/share -> [\\/][\\/]server[\\/]share
# $1 must be in win32 format
#
# SETS GLOBAL VARIABLES:
#   _csih_w32vol_as_shell_pattern
#   _csih_w32vol_as_shell_pattern_trailing_slash
# ======================================================================
_csih_convert_w32vol_to_shell_pattern()
{
  csih_stacktrace "${@}" 1>&2 # redirect to avoid clobbering stdout
  $_csih_trace
  local has_trailing_slash
  local upperD
  local lowerD
  local w32vol="$1"

  # determine if ends in '/'
  case "${w32vol}" in
  */ ) has_trailing_slash=yes
       w32vol="${w32vol%%/*}"
       ;;
  esac
  # replace all '/' with '[\\/]'
  w32vol="${w32vol//\//[\\\\\/]}"
  # replace leading 'X:' with '[Xx]:'
  if [ "${w32vol:1:1}" = ":" ]
  then
    case "${w32vol:0:1}" in
      [A-Za-z] )
        lowerD=$(echo "${w32vol:0:1}" | tr '[:upper:]' '[:lower:]')
        upperD=$(echo "${w32vol:0:1}" | tr '[:lower:]' '[:upper:]')
        w32vol="[${upperD}${lowerD}]:${w32vol:2}"
        ;;
    esac
  fi
  _csih_w32vol_as_shell_pattern="${w32vol}"
  _csih_w32vol_as_shell_pattern_trailing_slash="${has_trailing_slash}"
} # === End of _csih_convert_w32vol_to_shell_pattern() === #
readonly -f _csih_convert_w32vol_to_shell_pattern

# ======================================================================
# Routine: _csih_path_in_volumelist_core
#   Given:
#     $1 == a path in win32 format
#     $2 == a win32-format pathlist (;-separated)
#   Prints 'found' on stdout if
#     $1 is located on one of the volumes specified in $2
#   Silent otherwise
#
# Implementation note: matches are executed in a subshell, so
# we can't use variables to communicate the results. This is why
# stdout is used, and why stacktrace is redirected.
# ======================================================================
_csih_path_in_volumelist_core()
{
  csih_stacktrace "${@}" 1>&2 # redirect to avoid clobbering stdout
  $_csih_trace
  local w32path="$1"
  local volumelist="$2"

  echo "$volumelist" | tr ';' '\n' | while read p
  do
    _csih_convert_w32vol_to_shell_pattern "$p"
    case "$w32path" in
      ${_csih_w32vol_as_shell_pattern}* )
        printf "found\n"
        ;;
      ${_csih_w32vol_as_shell_pattern}[\\\\/]* )
        if [ -n "${_csih_w32vol_as_shell_pattern_trailing_slash}" ]
        then
          printf "found\n"
        fi
        ;;
    esac
  done
} # === End of _csih_path_in_volumelist_core() === #
readonly -f _csih_path_in_volumelist_core

# ======================================================================
# Routine: _csih_path_in_volumelist
#   Given:
#     $1 == a path in win32 format
#     $2 == a win32-format pathlist (;-separated)
#   Returns 0 if $1 is in $2
#   Returns 1 otherwise
#
# Implementation note; a simple wrapper around *_core(), to hide
# the use of stdout.
# ======================================================================
_csih_path_in_volumelist()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local result=$(_csih_path_in_volumelist_core "$1" "$2")
  if [ "x${result}" = "xfound" ]
  then
    return 0
  fi
  return 1
} # === End of _csih_path_in_volumelist() === #
readonly -f _csih_path_in_volumelist

# ======================================================================
# Routine: csih_path_supports_acls
#   Determines if the specified path is on a volume that supports
#   persistent ACLs. This is used to skip access-permission checks
#   if files are located on a volume that does not support them.
#   Returns 0 on success (yes, path is on a volume that supports ACLs),
#   non-zero on failure (no, it doesn't, or there was some problem making
#   the determination)
#
#   $1 may be in unix or win32 format
#
# NOTE:
#   first checks to see if $1, after conversion to win32 format,
#      is located on one of the volumes listed in the win32-format
#      pathlist csih_WIN32_VOLS_WITH_ACLS. If so, returns true (0).
#      NOTE: the elements of csih_WIN32_VOLS_WITH_ACLS need not
#            exist, although specifying non-existent shares will cause
#            execution delays.
#   then checks to see if $1, after conversion to win32 format,
#      is located on one of the volumes listed in the win32-format
#      pathlist csih_WIN32_VOLS_WITHOUT_ACLS. If so, returns false (1).
#      NOTE: the elements of csih_WIN32_VOLS_WITHOUT_ACLS need not
#            exist, although specifying non-existent shares will cause
#            execution delays.
#   finally, runs the helper program getVolInfo for $1. If the result
#      contains 'FILE_PERSISTENT_ACLS: TRUE', then returns true (0)
#      otherwise, returns false (1)
#      NOTE: this test will return false if $1 specifies a volume that
#            does not exist.
# ======================================================================
csih_path_supports_acls()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local output
  local rstatus
  if [ -z "$1" ]
  then
    csih_warning "Internal: csih_path_supports_acls called with no argument"
    return 1
  fi

  # convert to w32 format
  w32path=$(cygpath -m "$1")

  #if _csih_path_in_volumelist "$w32path" "$csih_WIN32_VOLS_WITH_ACLS"
  #then
  #  return 0
  #fi

  #if _csih_path_in_volumelist "$w32path" "$csih_WIN32_VOLS_WITHOUT_ACLS"
  #then
  #  return 1
  #fi

  output=$(csih_invoke_helper getVolInfo "$1" | grep "FILE_PERSISTENT_ACLS" 2>/dev/null)
  rstatus=$?
  if [ "$rstatus" -eq 0 ]
  then  
      echo "$output" | grep "TRUE" || rstatus=2
  fi    
  return $rstatus
} # === End of csih_path_supports_acls() === #
readonly -f csih_path_supports_acls

# ======================================================================
# Routine: csih_guest_account_active
#   Returns true (0) if the Guest account is active
#   Returns false (non-zero) otherwise, or if !csih_is_nt
#
# SETS GLOBAL VARIABLE: csih_localized_account_name
# ======================================================================
csih_guest_account_active() {
  csih_stacktrace "${@}"
  $_csih_trace
  local rstatus=1
  local str

  if csih_is_nt
  then
    if csih_get_guest_account_name 
    then
      str=$(net user "$csih_localized_account_name" |\
            sed -n -e '/^Account active/s/^Account active *//p' |\
            tr '[:upper:]' '[:lower:]')
      if [ "$str" = "yes" ]
      then
        rstatus=0
        return $rstatus
      fi
    fi
  fi
  return $rstatus
} # === End of csih_guest_account_active() === #
readonly -f csih_guest_account_active

# ======================================================================
# Routine: csih_install_config 
#   Installs the specified file ($1) by copying the default file
#   located in the defaults directory ($2). Asks before overwriting.
#   ${2}/${1} must exist. All directory components on ${1} must exist.
#   Returns 0 on success, non-zero on failure
# ======================================================================
csih_install_config()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local dest;
  local DEFAULTSDIR;

  if [ -z "$1" ]
  then
    return
  fi
  if [ -z "$2" ]
  then
    return
  fi

  dest=$1;
  DEFAULTSDIR=$2

  if [ -f "$dest" ]
  then
    if csih_request "Overwrite existing ${dest} file?"
    then
      rm -f "${dest}"
      if [ -f "${dest}" ]
      then
        csih_warning "Can't overwrite. ${dest} is write protected."
      fi
    fi
  fi


  if [ ! -f "${dest}" ]
  then
    if [ ! -f "${DEFAULTSDIR}/${dest}" ]
    then
      csih_warning "Can't create ${dest} because default version could not be found."
      csih_warning "Check '${DEFAULTSDIR}'"
    else
      csih_inform "Creating default ${dest} file"
      cp ${DEFAULTSDIR}/${dest} ${dest}
      return $?
    fi
  fi
  return 1
} # === End of csih_install_config() === #
readonly -f csih_install_config

# ======================================================================
# Routine: csih_make_dir
#   Creates the specified directory if it does not already exist.
#   Exits on failure.
# ======================================================================
csih_make_dir()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local DIR;
  if [ -z "$1" ]
  then
    return
  fi
  DIR=$1
  shift
  
  if [ -e "${DIR}" -a ! -d "${DIR}" ]
  then
    if [ -n "$1" ]
    then
      csih_error_multi "${DIR} exists, but is not a directory." "$1"
    else
      csih_error "${DIR} exists, but is not a directory."
    fi
  fi

  if [ ! -e "${DIR}" ]
  then
    mkdir -p "${DIR}"
    if [ ! -e "${DIR}" ]
    then
      csih_error "Creating ${DIR} directory failed."
    fi
  fi
} # === End of csih_make_dir() === #
readonly -f csih_make_dir

# ======================================================================
# Routine: csih_get_system_and_admins_ids
#   Get the ADMINs ids from /etc/group and /etc/passwd
#   Returns 0 (true) on success, 1 otherwise.
# SETS GLOBAL VARIABLES:
#   csih_ADMINSGID
#   csih_ADMINSUID
#   csih_SYSTEMGID
#   csih_SYSTEMUID
# ======================================================================
csih_get_system_and_admins_ids()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local ret=0
  for fname in ${SYSCONFDIR}/passwd ${SYSCONFDIR}/group
  do
    if stat -c "%A" "${fname}" | grep -Eq  '^-r..r..r..'
    then
      true
    else
      csih_warning "The file $fname is not readable by all."
      csih_warning "Please run 'chmod +r $fname'."
      ret=1
    fi
  done

  [ ! -r /etc/passwd -o ! -r  /etc/group ] && return 1;

  # require Administrators group and SYSTEM in /etc/group
  csih_ADMINSGID=$(sed -ne '/^[^:]*:S-1-5-32-544:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' ${SYSCONFDIR}/group)
  csih_SYSTEMGID=$(sed -ne '/^[^:]*:S-1-5-18:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' ${SYSCONFDIR}/group)
  if [ -z "$csih_ADMINSGID" -o -z "$csih_SYSTEMGID" ]
  then
    csih_warning "It appears that you do not have entries for the local"
    csih_warning "ADMINISTRATORS and/or SYSTEM sids in /etc/group."
    csih_warning ""
    csih_warning "Use the 'mkgroup' utility to generate them"
    csih_warning "   mkgroup -l > /etc/group"
    csih_warning ""
    _csih_warning_for_etc_file group
    ret=1;
  fi

  # only require SYSTEM in /etc/passwd; warn if either is missing
  csih_ADMINSUID=$(sed -ne '/^[^:]*:[^:]*:[0-9]*:[0-9]*:[^:]*,S-1-5-32-544:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/passwd)
  csih_SYSTEMUID=$(sed -ne '/^[^:]*:[^:]*:[0-9]*:[0-9]*:[^:]*,S-1-5-18:.*:/{s/[^:]*:[^:]*:\([0-9]*\):.*$/\1/p;q}' /etc/passwd)
  if [ -z "$csih_ADMINSUID" -o -z "$csih_SYSTEMUID" ]
  then
    csih_warning "It appears that you do not have an entry for the local"
    csih_warning "ADMINISTRATORS (group) and/or SYSTEM sids in /etc/passwd."
    csih_warning ""
    csih_warning "Use the 'mkpasswd' utility to generate it"
    csih_warning "   mkpasswd -l > /etc/passwd."
    csih_warning ""
    _csih_warning_for_etc_file passwd
    if [ -z "$csih_SYSTEMUID" ]
    then
      ret=1
    fi
  fi
  return "${ret}"
} # === End of csih_get_system_and_admins_ids() === #
readonly -f csih_get_system_and_admins_ids

# ======================================================================
# Routine: csih_check_passwd_and_group
#   Check to see whether the user's password ID and group exist in the
#   system /etc/passwd and /etc/group files, respectively.
#   Returns 0 (true) on success, 1 otherwise.
# ======================================================================
csih_check_passwd_and_group()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local ret=0
  if [ "$(id -gn)" = "mkpasswd" ]
  then
    csih_warning "It appears that you do not have an entry for your user ID"
    csih_warning "in /etc/passwd."
    csih_warning ""
    csih_warning "If so, use the 'mkpasswd' utility to generate an"
    csih_warning "entry for your User ID in the password file:"
    csih_warning "   mkpasswd -l -u User_ID >> /etc/passwd"
    csih_warning "or"
    csih_warning "   mkpasswd -d -u User_ID >> /etc/passwd."
    csih_warning ""
    _csih_warning_for_etc_file passwd
    ret=1
  elif [ -n "$USERDOMAIN" ] && [ -n "$USERNAME" ]
  then
    if ! grep -E -q -i "^$(id -un):.*U-${USERDOMAIN}\\\\${USERNAME}" /etc/passwd
    then
      csih_warning "It appears that you do not have an entry for:"
      csih_warning "   ${USERDOMAIN}\\${USERNAME}"
      csih_warning "in /etc/passwd."
      csih_warning ""
      csih_warning "Use the 'mkpasswd' utility to generate an entry for"
      csih_warning "your User ID in the password file:"
      csih_warning "   mkpasswd -d -u User_ID >> /etc/passwd."
      csih_warning ""
      _csih_warning_for_etc_file passwd
      ret=1
    fi
  fi

  if [ "$(id -gn)" = mkgroup ]
  then
    csih_warning "It appears that you do not have an entry for your group ID"
    csih_warning "in /etc/group.  If this check is incorrect, then re-run"
    csih_warning "this script with the '-f' command-line option."
    csih_warning ""
    csih_warning "Otherwise, use the 'mkgroup' utility to generate an"
    csih_warning "entry for your group ID in the password file:"
    csih_warning "   mkgroup -l -g Group_id  >> /etc/group"
    csih_warning "or"
    csih_warning "   mkgroup -d -g Group_id >> /etc/group."
    csih_warning ""
    _csih_warning_for_etc_file group
    ret=1
  fi
  return "${ret}"
} # === End of csih_check_passwd_and_group() === #
readonly -f csih_check_passwd_and_group


# ======================================================================
# Routine: csih_check_user
#   Check to see that the specified user exists once in /etc/passwd 
#   Returns 0 (true) if so, 1 otherwise.
# ======================================================================
csih_check_user()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local count=$(grep -ic "^$1:" /etc/passwd)
  if [ $count = 0 ]
  then
    csih_warning "User $1 does not appear in /etc/passwd."
    return 1;
  fi
  if [ $count -gt 1 ]
  then
    csih_warning "User $1 appears $count times in /etc/passwd."
    csih_warning "This may confuse the system."
    csih_warning "Edit /etc/passwd and assign unique user ids."
    return 1;
  fi
  return 0
} # === End of csih_check_user() === #
readonly -f csih_check_user

# ======================================================================
# Routine: _csih_warning_for_win9x_perms
#   Display a warning message for the user about permissions/ACL
#   non-support in Win9x/Me.
# ======================================================================
_csih_warning_for_win9x_perms()
{
  csih_stacktrace "${@}"
  csih_warning "Operating systems before Windows NT do not support"
  csih_warning "accurate permissions. Please consider updating your"
  csih_warning "operating system to something relevant to this century."
  csih_warning "Note also that cygwin-1.7 and above do not support Win9x/Me)."
} # === End of _csih_warning_for_win9x_perms() === #
readonly -f _csih_warning_for_win9x_perms

# ======================================================================
# Routine: _csih_warning_for_missing_ACL_support
#   Display a warning message for the user about files located on
#   volumes that do not support persistent ACLS -- e.g. FAT drives,
#   nosmbntsec (cygwin-1.5), noacl (cygwin-1.7).
# ======================================================================
_csih_warning_for_missing_ACL_support()
{
  csih_stacktrace "${@}"
  csih_warning "$1 exists on a volume that does not support accurate"
  csih_warning "permissions (perhaps formatted FAT?).  Therefore, we"
  csih_warning "cannot verify access to the file or directory."
  csih_warning "Please consider, if possible and appropriate, one of the"
  csih_warning "following remedies:"
  csih_warning "  1) converting to NTFS using 'convert.exe'"
  csih_warning "  2) removing nosmbntsec from the CYGWIN variable (cygwin-1.5)"
  csih_warning "  3) mounting the relevant volume using the 'acl' option (cygwin-1.7)"
}
# === End of _csih_warning_for_missing_ACL_support() === #
readonly -f _csih_warning_for_missing_ACL_support

# ======================================================================
# Routine: csih_check_dir_perms
#   Check to see that the specified directory ($1) exists and has the
#   permissions ($2).
#   Returns 0 (true) if so, 1 otherwise.
# ======================================================================
csih_check_dir_perms()
{
  csih_stacktrace "${@}"
  $_csih_trace
  if [ ! -e "$1" ]
  then
    csih_warning "Your computer is missing $1".
    return 1
  fi  

  if ! csih_is_nt
  then
    _csih_warning_for_win9x_perms
    csih_warning "Continuing, but something might break..."
    return 0
  fi

  if ! csih_path_supports_acls "$1"
  then
    _csih_warning_for_missing_ACL_support "$1"
    csih_warning "Continuing, but something might break..."
    return 0
  fi

  if stat -c "%A" "$1" | grep -Eq ^"$2"
  then
    true
  else
    csih_warning "The permissions on the directory $1 are not correct."
    csih_warning "They must match the regexp $2"
    return 1
  fi
} # === End of csih_check_dir_perms() === #
readonly -f csih_check_dir_perms

# ======================================================================
# Routine: csih_check_access
#   Check to see that the owner and Administrators have
#   proper access to the file or directory.
#     $1 -- the file or directory to check
#     $2 -- three character symbolic permissions: 'rwx'. '.w.', etc.
#   On installations older than Windows 2003 and Vista, allow access 
#   by System
# NOTE: must call csih_get_system_and_admins_ids first
# ======================================================================
csih_check_access()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local file="$1"
  local perm="$2"
  local msg="$3"
  local notify=0;
  local ls_result="$(ls -dLln "$file" 2> /dev/null)"

  if ! csih_is_nt
  then
    _csih_warning_for_win9x_perms
    csih_warning "Continuing, but something might break..."
    return 0
  fi

  if [ -z "$csih_ADMINSGID" ]
  then
    csih_get_system_and_admins_ids
    if [ $? -ne 0 ]
    then
      return $?
    fi
  fi

  if ! csih_path_supports_acls "$file"
  then
    _csih_warning_for_missing_ACL_support "$fild"
    csih_warning "Continuing, but something might break..."
    return 0
  fi

  # If the owner of the file does not have access,
  # then notify the user.
  if [ -z "$(echo "$ls_result" | sed -n /^."$perm"/p)" ]
  then
    notify=1;

  # If the 'Administrators' group has owner or group access to the file,
  # but does not have the desired access, then notify the user.

  elif ( [ -n "$csih_ADMINSUID" -a "$(echo "$ls_result" | awk '{ print $3 }')" -eq $csih_ADMINSUID ] || \
         ( ! csih_is_nt2003 && [ -n "$csih_SYSTEMUID" -a "$(echo "$ls_result" | awk '{ print $3 }')" -eq $csih_SYSTEMUID ] ))
  then
    # Administrators group owns the file, or (on < NT2003) SYSTEM owns the file
    # this is ok; do nothing.
    true;
  elif ( [ "$(echo "$ls_result" | awk '{ print $4 }')" -eq $csih_ADMINSGID ] || \
         ( ! csih_is_nt2003 && [ "$(echo "$ls_result" | awk '{ print $4 }')" -eq $csih_SYSTEMGID ] ))
  then
    # The Administrators group has group access to the file, or
    # (on < NT2003) SYSTEM has group access to the file.  Check to
    # see if the chmod bits for group allow these groups to have
    # "owner-like" access to the file.  If not, notify.
    [ -z "$(echo "$ls_result" | sed -n /^...."$perm"/p)" ] && notify=1
  elif ( [ -n "$(getfacl -n "$file" | sed -n /^group:"$csih_ADMINSGID":"$perm"/p )" ] || \
         ( ! csih_is_nt2003 && [ -n "$(getfacl -n "$file" | sed -e /^group:"$csih_SYSTEMGID":"$perm"/p )" ] ))
  then
    # There exists an extended ACL entry for the Administrators (or
    # SYSTEM group, pre 2003), with the desired owner-like permissions.
    # This is ok.
    true;
  else
    # otherwise, we do /not/ have sufficient access to the file.
    notify=1
  fi

  if [ "$notify" -eq 1 ]; then
    csih_warning "The owner and the Administrators need"
    csih_warning "to have $perm permission to $file."
    csih_warning "Here are the current permissions and ACLS:"
    ls_result=$(ls -dlL "${file}" 2>&1)
    csih_warning "    $ls_result"
    getfacl "${file}" 2>&1 | while read LN
    do
      csih_warning "    $LN"
    done
    csih_warning "Please change the user and/or group ownership, "
    csih_warning "permissions, or ACLs of $file."
    echo
    [ -z "${msg}" ] || csih_warning "${msg}"
    return 1;
  fi
} # === End of csih_check_access() === #
readonly -f csih_check_access

# ======================================================================
# Routine: csih_check_sys_mount
#   Check to see that the SYSTEM account has access to the specified
#   directory.
#   Returns 0 (true) if system mounts are correct; 1 otherwise.
# This function is specific to cygwin 1.5.x and below.
# If called for cygwin 1.7.x or above, always returns 0 (true).
# ======================================================================
csih_check_sys_mount()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local mnt_point=$1
  local dos_dir=$2
  if csih_cygver_is_oneseven
  then
    return 0
  fi

  if mount | grep -Eq "on ${mnt_point} type.*system"
  then
    true
  else
    csih_warning "The SYSTEM user cannot access the mount point ${mnt_point}."
    csih_warning "Please run the following command to add a system mount point:"
    csih_warning "   mount -f -s -b \"[DOS path to Cygwin]$dos_dir\" \"$mnt_point\""
    csih_warning "where [DOS path to Cygwin] is something like c:/cygwin."
    csih_warning
    csih_warning "For more information, run 'mount -m' and 'mount -h'"
    return 1
  fi
} # === End of csih_check_sys_mount() === #
readonly -f csih_check_sys_mount

# ======================================================================
# Routine: csih_check_basic_mounts
#   Check to see that the SYSTEM account has access to the basic
#   three mount points: /, /usr/bin, and /usr/lib.
#   Returns 0 (true) if system mounts are correct; nonzero otherwise.
# This function is specific to cygwin 1.5.x and below. If called 
# for cygwin 1.7.0 or above, always returns 0 (true).
# ======================================================================
csih_check_basic_mounts()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local ret=0
  if ! csih_cygver_is_oneseven
  then
    csih_check_sys_mount /usr/bin /bin || ret=$(($ret + 1))
    csih_check_sys_mount /usr/lib /lib || ret=$(($ret + 1))
    csih_check_sys_mount / /           || ret=$(($ret + 1))

    # if all three "basic" mounts failed, then give this overall warning:  
    if [ $ret -gt 2 ]
    then
      csih_warning "It appears that you have user mode mounts (\"Just me\" chosen"
      csih_warning "during install.)  Any daemons installed as services will fail"
      csih_warning "to function unless system mounts are used.  To change this,"
      csih_warning "re-run setup.exe and choose \"All users\"."
      csih_warning ""
      csih_warning "For more information, see http://cygwin.com/faq/faq0.html#TOC33"
    fi
  fi
  return $ret
} # === End of csih_check_basic_mounts() === #
readonly -f csih_check_basic_mounts

# ======================================================================
# Routine: csih_privileged_accounts [-u username]
#   On Windows NT and above, determines the names of all known 
#   "privileged" users already created on this system, or known to 
#   this system (e.g. domain users represented in /etc/passwd but not
#   in the local SAM).  Checks for
#     cyg_server, sshd_server, cron_server
#   as well as 'username' passed as an argument to the -u option, if
#   specified.  The -u username will preferred over the default names,
#   but of those default names, cyg_server is preferred.  However, it
#   is taken on faith that if 'username' exists, it is, in fact, 
#   privileged and not an "ordinary" user.
#   Avoids rechecking if already set.
#
# SETS GLOBAL (PRIVATE) VARIABLES: 
#   _csih_all_preexisting_privileged_accounts
#   _csih_preferred_preexisting_privileged_account
# ======================================================================
csih_privileged_accounts()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local username
  local accounts
  local first_account
  local in_passwd_status
  local in_sam_status
  local opt_username

  # always parse "command line"
  OPTIND=0
  while getopts ":u:" options; do
    case $options in
      u  ) opt_username="$OPTARG" ;;
      \? ) csih_warning "${FUNCNAME[0]} ignoring invalid option: $OPTARG" ;; 
      \: ) csih_warning "${FUNCNAME[0]} ignoring option missing required argument: $OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))
  [ -n "${1}" ] && opt_servicename="${1}"

  if csih_is_nt
  then
    if [ -z "${_csih_all_preexisting_privileged_accounts}" ]
    then
      for username in sshd_server
      do
        # because we quote opt_username (to allow spaces), then we
        # might have username="" if no -u option was specified. Check
        # for that case, and skip:
        if [ -z "$username" ]
        then
          continue
        fi

        in_passwd_status=1
        in_sam_status=1
        egrep "^${username}:" /etc/passwd 1>/dev/null 2>&1 && in_passwd_status=0
        net user "${username}" 1> /dev/null 2>&1 && in_sam_status=0
        if test $in_passwd_status -eq 0 || test $in_sam_status -eq 0
        then
          # however, if the caller specified opt_username, then we must
          # check that it actually has the required privileges...
          if [ "$username" = "$opt_username" ]
          then
            if ! csih_account_has_necessary_privileges "$username"
            then
              # -u $opt_username does NOT have the required privileges,
              # even though it exists.  Warn, and skip
              csih_warning "Privileged account '$opt_username' was specified,"
              csih_warning "but it does not have the necessary privileges."
              csih_warning "Continuing, but will probably use a different account."
              continue
            fi
          fi
          [ -z "${first_account}" ] && first_account="${username}"
          accounts="${accounts}'${username}' "
        fi
        if test $in_passwd_status -eq 0 && test $in_sam_status -ne 0
        then
          csih_warning "${username} is in /etc/passwd, but the local"
          csih_warning "machine's SAM does not know about ${username}."
          csih_warning "Perhaps ${username} is a pre-existing domain account."
          csih_warning "Continuing, but check if this is ok."
        fi
      done
      if [ -n "${accounts}" ]
      then
        _csih_all_preexisting_privileged_accounts="${accounts}"
        _csih_preferred_preexisting_privileged_account="${first_account}"
      fi
    fi
  fi
} # === End of csih_privileged_accounts() === #
readonly -f csih_privileged_accounts

# ======================================================================
# Routine: csih_privileged_account_exists
#   On Windows NT and above, determines if the specified
#   user ${1} exists and is one of the well-known privileged users
#   (cyg_server, sshd_server, cron_server), or actually does possess
#   the required privileges.
#   Returns 0 (true) if so, 1 otherwise.
# ======================================================================
csih_privileged_account_exists()
{
  csih_stacktrace "${@}"
  $_csih_trace
  csih_privileged_accounts -u "$1"
  if [ -n "${_csih_all_preexisting_privileged_accounts}" ]
  then
    case "${_csih_all_preexisting_privileged_accounts}" in
      *" '$1' "* | "'$1' "* | *" '$1'" | "'$1'") true;;
      *) false;;
    esac
  else
    false
  fi
} # === End of csih_privileged_account_exists() === #
readonly -f csih_privileged_account_exists

# ======================================================================
# Routine: csih_account_has_necessary_privileges
#   On Windows NT and above, checks whether the specified account $1
#   has the privileges necessary to change user contexts.
#   Returns 0 (true) if so, 1 otherwise.
#   Also returns false if $1 is unspecified, or $1 doesn't exist.
# ======================================================================
csih_account_has_necessary_privileges() {
  csih_stacktrace "${@}"
  $_csih_trace

  local user="$1"
  local admingroup=
  if [ -n "${user}" ]
  then
    if net user "${user}" >/dev/null 2>&1
    then
      if ! csih_check_program_or_warn editrights editrights
      then
        csih_warning "The 'editrights' program cannot be found or is not executable."
        csih_warning "Unable to insure that '${user}' has the appropriate privilegeds."
        return 1 
      else
        admingroup=`mkgroup -l | awk -F: '{if ( $2 == "S-1-5-32-544" ) print $1;}' `
        if [ -z "${admingroup}" ]
        then 
          csih_warning "Cannot obtain the Administrators group name from 'mkgroup -l'."
          return 1 
        fi
        if ! net localgroup "${admingroup}" | grep -Eiq "^${user}.?$"
        then
          # user not in Administrators group
          return 1
        else
          editrights -u "${user}" -t SeAssignPrimaryTokenPrivilege >/dev/null 2>&1 &&
          editrights -u "${user}" -t SeCreateTokenPrivilege        >/dev/null 2>&1 &&
          editrights -u "${user}" -t SeTcbPrivilege                >/dev/null 2>&1 &&
          editrights -u "${user}" -t SeServiceLogonRight           >/dev/null 2>&1
          return # status of previous command-list
        fi
      fi
    fi
  fi
  false
} # === End of csih_account_has_necessary_privileges() === #
readonly -f csih_account_has_necessary_privileges


# ======================================================================
# Routine: _csih_setup
#   Basic checks for all clients of this script.
#   Exits if anything is wrong.
# ======================================================================
_csih_setup()
{
  csih_stacktrace "${@}"
  $_csih_trace
  if [ "$_csih_setup_already_called" -eq 0 ]
  then
    if ! csih_check_basic_mounts
    then
      csih_error "Problem with mount points. Exiting"
    fi
  
    if ! csih_sanity_check
    then
      csih_error_multi "There is something badly wrong with your cygwin installation." \
                       "Please investigate the warnings above and correct."
    fi
    if [ -z "${SYSCONFDIR}" ]
    then
      csih_error "Variable SYSCONFDIR is empty (should be '/etc' ?)"
    fi
  
    if [ -z "${LOCALSTATEDIR}" ]
    then
      csih_error "Variable LOCALSTATEDIR is empty (should be '/var' ?)"
    fi

    if ! csih_get_system_and_admins_ids
    then
      csih_error "Problem with LocalSystem or Adminstrator IDs"
    fi
  
    if ! csih_check_dir_perms "${LOCALSTATEDIR}" "d..x..x..[xt]"
    then
      csih_error "Problem with ${LOCALSTATEDIR} directory. Exiting."
    fi

    # attempt to set permissions, but not an error if fail
    # will verify that we actually HAVE correct permissions below. 
    csih_make_dir "${LOCALSTATEDIR}/run"
    chmod 1777 "${LOCALSTATEDIR}/run" >&/dev/null || /bin/true
    setfacl -m u:system:rwx "${LOCALSTATEDIR}/run" >&/dev/null || /bin/true
    setfacl -m g:544:rwx "${LOCALSTATEDIR}/run" >&/dev/null || /bin/true

    csih_make_dir "${LOCALSTATEDIR}/log"
    chmod 1777 "${LOCALSTATEDIR}/log" >&/dev/null || /bin/true
    setfacl -m u:system:rwx "${LOCALSTATEDIR}/log" >&/dev/null || /bin/true
    setfacl -m g:544:rwx "${LOCALSTATEDIR}/log" >&/dev/null || /bin/true

    csih_make_dir "${LOCALSTATEDIR}/empty"
    chmod 755 "${LOCALSTATEDIR}/empty" >&/dev/null || /bin/true
    setfacl -m u:system:r-x "${LOCALSTATEDIR}/empty" >&/dev/null || /bin/true
    setfacl -m g:544:r-x "${LOCALSTATEDIR}/empty" >&/dev/null || /bin/true

    # daemons need write access to /var/run to create pid file 
    if ! csih_check_access "${LOCALSTATEDIR}/run" .w.
    then
      csih_error "Problem with ${LOCALSTATEDIR}/run directory. Exiting."
    fi
    # daemons need write access to /var/log if they do their own logging
    if ! csih_check_access "${LOCALSTATEDIR}/log" .w.
    then
      csih_error "Problem with ${LOCALSTATEDIR}/log directory. Exiting."
    fi
    # daemons need access to /var/empty for chrooting
    if ! csih_check_access "${LOCALSTATEDIR}/empty" r.x
    then
      csih_error "Problem with ${LOCALSTATEDIR}/empty directory. Exiting."
    fi
  
    # just ensure that /etc exists. It is up to clients of this
    # script to explicitly check accees to the specific configuration
    # files inside /etc... 
    csih_make_dir "${SYSCONFDIR}"
    chmod 755 "${SYSCONFDIR}" >&/dev/null || /bin/true
 
    _csih_setup_already_called=1
  fi
} # === End of _csih_setup() === #
readonly -f _csih_setup


# ======================================================================
# Routine: csih_select_privileged_username [-q] [-f] [-u default_user] [service_name]
#   On NT and above, get the desired privileged account name.
#
#   If the optional argument '-q' is specified, then this function will
#      operate in query mode, which is more appropriate for user-config
#      scripts that need information ABOUT a service, but do not 
#      themselves install the service.
#
#   If the optional argument '-f' is specified, then no confirmation 
#      questions will be asked about the selected username. This is
#      useful mainly in unattended installations.
#
#   If the optional argument '-u' is specified, then the next
#      argument will be used as the "privileged" username -- UNLESS
#      [service_name] is provided, and that service is already
#      installed under some OTHER username.  In the latter case, the
#      current user under which [service_name] is installed will be
#      used, and the value specified by -u will be IGNORED.
#
#   If the optional [service_name] argument is present, then that value
#      may be used in some of the messages. Also, this function will
#      then check to see if [service_name] is already installed. If so,
#      the account under which it is installed will be selected, assuming
#      it passes validation (has necessary permissions, group memberships,
#      etc)
#
# Usually [service_name] and [-q] should be specified together.
#    [-f] can be set regardless of other options.
#
# SETS GLOBAL VARIABLE:
#   csih_PRIVILEGED_USERNAME
#   OPTIND
#   OPTARG
#
# csih_auto_answer=no behavior
#   nt
#     if [service_name] and [-q] and [service_name] is installed
#       get account under which it is installed
#       validate account (may issue error!)
#       use that account name
#     elif $default_username is specified, exists, and has necessary privileges,
#       use $default_username
#     elif any(cyg_server cron_server sshd_server) exists,
#       use first in list
#     else
#       if nt2003 || csih_FORCE_PRIVILEGED_USER
#         if $default_username is specified
#            use $default_username
#         else
#            use cyg_server
#       else
#         do nothing (csih_PRIVILEGED_USERNAME="")
#   else
#     do nothing (csih_PRIVILEGED_USERNAME="")
#
# ======================================================================
csih_select_privileged_username()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local username
  local opt_query=0
  local opt_force=0
  local opt_servicename=""
  local opt_default_username=""
  local options
  local theservice

  _csih_setup

  # always parse "command line"
  OPTIND=0
  while getopts ":qfu:" options; do
    case $options in
      q  ) opt_query=1 ;;
      f  ) opt_force=1 ;;
      u  ) opt_default_username="$OPTARG" ;;
      \? ) csih_warning "${FUNCNAME[0]} ignoring invalid option: $OPTARG" ;; 
      \: ) csih_warning "${FUNCNAME[0]} ignoring option missing required argument: $OPTARG" ;;
    esac
  done
  shift $(($OPTIND - 1))
  [ -n "${1}" ] && opt_servicename="${1}"

  # save time if win9x
  if ! csih_is_nt
  then
    csih_PRIVILEGED_USERNAME=""
    return
  fi

  if csih_is_nt
  then
    # save time if csih_PRIVILEGED_USERNAME already set
    if [ -n "${csih_PRIVILEGED_USERNAME}" ]
    then
      return
    fi

    csih_privileged_accounts -u "$opt_default_username"

    # if query mode and opt_servicename has been specified,
    # first check to see if the service has already been 
    # installed.  If so, get the service's account name.
    # If (and only if) that account is privileged, then 
    # record it in csih_PRIVILEGED_USERNAME.
    if [ $opt_query -ne 0 -a -n "${opt_servicename}" ]
    then
      if cygrunsrv -Q "${opt_servicename}" >/dev/null 2>&1
      then
        username=$(cygrunsrv -V -Q "${opt_servicename}" 2>&1 | sed -n -e '/^Account/s/^.* : //p')
        username="${username/\.\\/${COMPUTERNAME}\\}"
        if [ "${username}" = "LocalSystem" ]
        then
          username=#empty; SYSTEM is not a "privileged user"
        else
          username=$(fgrep "${username}" /etc/passwd | cut -d: -f 1)
        fi
        if [ -n "${username}" ]
        then
          if csih_privileged_account_exists "${username}"
          then
            # ${opt_servicename} is installed under account "${username}",
            # which is one of the pre-declared privileged users -- or,
            # we have already validated that ${username} has the necessary
            # privilegeds. Great!
            csih_PRIVILEGED_USERNAME="${username}"
            return
          else
            if csih_account_has_necessary_privileges "${username}"
            then
              # ${opt_servicename} is installed under account "${username}",
              # but ${username} is not one of the pre-declared privileged users
              # (cyg_server, sshd_server, cron_server) -- nor had we previously
              # validated that it has the necessary privileges. However, we just
              # did validate that, and it DOES have the necessary privileges.
              # Add it to the list.
              csih_PRIVILEGED_USERNAME="${username}"
              _csih_all_preexisting_privileged_accounts="${_csih_all_preexisting_privileged_accounts}'${username}' "
              return
            else
              # ${opt_servicename} is installed under account "${username}", but
              # ${username} is not one of the pre-declared privileged users
              # (cyg_server, sshd_server, cron_server), nor does it have the
              # necessary privileges. Ignore it...
              return
            fi
          fi # privileged_user_exists
        else
          # ${opt_servicename} installed under LocalSystem, or there was
          # some error in determining the account name under which it is installed.
          return
        fi # $username empty
      fi # ${opt_servicename} is not installed
    fi # not (opt_query && opt_servicename)

    if [ $opt_query -eq 0 ]
    then
      if csih_is_nt2003
      then
        csih_inform "You appear to be running Windows 2003 Server or later.  On 2003"
        csih_inform "and later systems, it's not possible to use the LocalSystem"
        csih_inform "account for services that can change the user id without an"
        csih_inform "explicit password (such as passwordless logins [e.g. public key"
        csih_inform "authentication] via sshd)."
        echo ""
        csih_inform "If you want to enable that functionality, it's required to create"
        csih_inform "a new account with special privileges (unless a similar account"
        csih_inform "already exists). This account is then used to run these special"
        csih_inform "servers."
        echo ""
        csih_inform "Note that creating a new user requires that the current account"
        csih_inform "have Administrator privileges itself."
      elif [ "x$csih_FORCE_PRIVILEGED_USER" = "xyes" ]
      then
        csih_inform "You have requested that a special privileged user be used"
        csih_inform "by the service, and are running on Windows NT, 2k or XP where"
        csih_inform "this is not actually required (LocalSystem would also work)."
        echo ""
        csih_inform "Note that creating a new user requires that the current account"
        csih_inform "have Administrator privileges itself."
      else
        # hmm. NT/2k/XP, but not csih_FORCE_PRIVILEGED_USER
        # in this case, we emit no messages. If a privileged
        # user already exists, we'll use it. Otherwise, don't
        # specify a "privileged" user. Callers will know to
        # silently use LocalSystem.
        :
      fi
    fi

    if test -n "${_csih_all_preexisting_privileged_accounts}" && test -z "$opt_default_username"
    then
      echo ""
      csih_inform "The following privileged accounts were found: ${_csih_all_preexisting_privileged_accounts}."
      username="${_csih_preferred_preexisting_privileged_account}"
    else
      if ( csih_is_nt2003 || [ "x$csih_FORCE_PRIVILEGED_USER" = "xyes" ] )
      then
        if test $opt_query -eq 0 && test -z "$opt_default_username"
        then
          echo ""
          csih_inform "No privileged account could be found."
        fi
        if [ -n "$opt_default_username" ]
        then
          username="sshd_server"
        else
          username="sshd_server"
        fi
      else
        # nt/2k/xp and not csih_FORCE_PRIVILEGED_USER and username is empty
        # we couldn't find a pre-existing privileged user, but we don't 
        # really need one (nt/2k/xp) and haven't explicitly requested one
        # via csih_FORCE...  In this case, we're done: just return. (this
        # is true regardless of the value of $opt_query)
        return
      fi
    fi

    # if we get here, then $username WILL be set to something
    if [ $opt_query -eq 0 ]
    then
      echo ""
      csih_inform "This script plans to use '${username}'."
      csih_inform "'${username}' will only be used by registered services."
      #if [ $opt_force -eq 0 ]
      #then 
      #  if csih_request "Do you want to use a different name?"
      #  then
      #    csih_get_value "Enter the new user name:"
      #    username="${csih_value}"
      #  fi
      #fi
    else
      theservice=${opt_servicename:-the service}
      csih_inform "This script will assume that ${theservice} will run"
      csih_inform "under the '${username}' account."
      if [ $opt_force -eq 0 ]
      then
        if csih_request "Will ${theservice} run under a different account?"
        then
          csih_get_value "Enter the user name used by the service:"
          username="${csih_value}"
        fi
      fi
    fi
  
    # faster than checking SAM -- see if username is one that we
    # already know about
    if csih_privileged_account_exists "$username"
    then
      _csih_preferred_preexisting_privileged_account="${username}"
    else
      # perhaps user specified a pre-existing privileged account we
      # don't know about
      if egrep "^${username}:" /etc/passwd 1>/dev/null 2>&1 ||
         net user "${username}" >/dev/null 2>&1
      then
        if ! csih_account_has_necessary_privileges "${username}"
        then
          csih_warning "The specified account '${username}' does not have the"
          csih_warning "required permissions or group memberships. This may"
          csih_warning "cause problems if not corrected; continuing..."
        elif [ ${opt_query} -eq 0 ]
        then
          csih_inform "'${username}' already exists...and has all necessary permissions."
        fi
        # so, add it to our list, so that csih_privileged_account_exists
        # will return true...
        _csih_preferred_preexisting_privileged_account="${username}"
        _csih_all_preexisting_privileged_accounts="${_csih_all_preexisting_privileged_accounts}'${username}' "   
      fi
      # if it doesn't exist, we're probably in the midst of creating it.
      # so don't issue any warnings.
    fi
    csih_PRIVILEGED_USERNAME="${username}"
  fi
} # === End of csih_select_privileged_username() === #
readonly -f csih_select_privileged_username


# ======================================================================
# Routine: csih_create_privileged_user
#   On Windows Server 2003 and above (including Windows Vista), or if
#   csih_FORCE_PRIVILEGED_USER == "yes" for Windows NT and above,
#   allows user to select a pre-existing privileged user, or to
#   create a new privileged user.
#   $1 (optional) will be used as the password if non-empty
#   
#   NOTE: For using special behaviours triggered by optional parameters
#   to the csih_select_privileged_username function, you should first 
#   call that function with all required parameters, and then call this
#   function. The selected username will already be stored in
#   $csih_PRIVILEGED_USERNAME.
#
#   Exits on catastrophic error (or if user enters empty password)
#   Returns 0 on total success
#   Returns 1 on partial success (created user, but could not add
#     to admin group, or set privileges, etc).  Recommend caller
#     check return value, and offer user opportunity to quit.
#
#   On success, the username and password will be available in
#     csih_PRIVILEGED_USERNAME
#     csih_PRIVILEGED_PASSWORD
#
# csih_auto_answer=no behavior
#   if nt2003 || (nt && FORCE)
#     if pre-existing privileged user
#       make sure its group membership and perms are correct
#     else
#       do nothing, return 1
#   else
#     do nothing, return 1
# ======================================================================
csih_create_privileged_user()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local username_in_sam
  local username
  local admingroup
  local dos_var_empty
  local _password
  local password_value="$1"
  local passwd_has_expiry_flags
  local ret=0
  local username_in_admingroup
  local username_got_all_rights
  local pwd_entry
  local username_in_passwd
  local entry_in_passwd
  local temp

  _csih_setup
  csih_select_privileged_username

  if ( csih_is_nt2003 || [ csih_is_nt -a "x$csih_FORCE_PRIVILEGED_USER" = "xyes" ] )
  then
    username="${csih_PRIVILEGED_USERNAME}"

    if ! csih_privileged_account_exists "$csih_PRIVILEGED_USERNAME" 
    then
      username_in_sam=no

      # give auto-answer a chance to veto, because we can't enter password
      # from setup.exe...
      if csih_request "Create new privileged user account '${username}'?"
      then
 
        dos_var_empty=$(cygpath -w ${LOCALSTATEDIR}/empty)
        while [ "${username_in_sam}" != "yes" ]
        do
          if [ -n "${password_value}" ]
          then
            _password="${password_value}"
            # Allow to ask for password if first try fails
            password_value=""
          else
            csih_inform "Please enter a password for new user ${username}.  Please be sure"
            csih_inform "that this password matches the password rules given on your system."
            csih_inform "Entering no password will exit the configuration."
            csih_get_value "Please enter the password:" -s
            _password="${csih_value}"
            if [ -z "${_password}" ]
            then
              csih_error_multi "Exiting configuration.  No user ${username} has been created," \
                               "and no services have been installed."
            fi
          fi
          net user "${username}" "${_password}" /add /fullname:"Privileged server" \
                   "/homedir:${dos_var_empty}" /yes > /tmp/nu.$$ 2>&1 && username_in_sam=yes
          if [ "${username_in_sam}" != "yes" ]
          then
            csih_warning "Creating the user '${username}' failed!  Reason:"
            cat /tmp/nu.$$
            rm /tmp/nu.$$ 
            echo
          fi
        done
  
        csih_PRIVILEGED_PASSWORD="${_password}"
        csih_inform "User '${username}' has been created with password '${_password}'."
        csih_inform "If you change the password, please remember also to change the"
        csih_inform "password for the installed services which use (or will soon use)"
        csih_inform "the '${username}' account."
        echo ""
        csih_inform "Also keep in mind that the user '${username}' needs read permissions"
        csih_inform "on all users' relevant files for the services running as '${username}'."
        csih_inform "In particular, for the sshd server all users' .ssh/authorized_keys"
        csih_inform "files must have appropriate permissions to allow public key"
        csih_inform "authentication. (Re-)running ssh-user-config for each user will set"
        csih_inform "these permissions corrently. [Similary restrictions apply, for"
        csih_inform "instance, for .rhosts files if the rshd server is running, etc]."
        echo ""
  
        passwd_has_expiry_flags=`passwd -v | awk '/^passwd /{print ( $3 >= 1.5 ) ? "yes" : "no";}'`
        if [ "${passwd_has_expiry_flags}" != "yes" ]
        then
          csih_warning "User '${username}' has password expiry set to system default."
          csih_warning "Please check that password never expires or set it to your needs."
        elif ! passwd -e "${username}"
        then
          csih_warning "Setting password expiry for user '${username}' failed!"
          csih_warning "Please check that password never expires or set it to your needs."
        fi
      fi # user allowed us to create account
    else
      # ${username} already exists. Use it, and make no changes.
      # use passed-in value as first guess
      csih_PRIVILEGED_PASSWORD="${password_value}"
      # Update password to match current one
      if net user "${username}" "${password_value}" >/tmp/mdv1.$$ 2>&1; then
        csih_inform "${username}'s password has been updated to ${password_value}."
      else
        csih_warning "Unable to update ${username}'s password."
	cat /tmp/mdv1.$$
      fi
      rm /tmp/mdv1.$$
      return 0
    fi

    # username did NOT previously exist, but has been successfully created.
    # set group memberships, privileges, and passwd timeout.
    if [ "$username_in_sam" = "yes" ]
    then
      # always try to set group membership and privileges
      admingroup=`mkgroup -l | awk -F: '{if ( $2 == "S-1-5-32-544" ) print $1;}' `
      if [ -z "${admingroup}" ]
      then
        csih_warning "Cannot obtain the Administrators group name from 'mkgroup -l'."
        ret=1
      elif net localgroup "${admingroup}" | grep -Eiq "^${username}.?$"
      then
        true
      else
        net localgroup "${admingroup}" "${username}" /add > /dev/null 2>&1 && username_in_admingroup=yes
        if [ "${username_in_admingroup}" != "yes" ]
        then
          csih_warning "Adding user '${username}' to local group '${admingroup}' failed!"
          csih_warning "Please add '${username}' to local group '${admingroup}' before"
          csih_warning "starting any of the services which depend upon this user!"
          ret=1
        fi
      fi
  
      if ! csih_check_program_or_warn editrights editrights
      then
        csih_warning "The 'editrights' program cannot be found or is not executable."
        csih_warning "Unable to insure that '${username}' has the appropriate privilegeds."
        ret=1
      else
        editrights -a SeAssignPrimaryTokenPrivilege -u ${username} &&
        editrights -a SeCreateTokenPrivilege -u ${username} &&
        editrights -a SeTcbPrivilege -u ${username} &&
        editrights -a SeDenyRemoteInteractiveLogonRight -u ${username} &&
        editrights -a SeServiceLogonRight -u ${username} &&
        username_got_all_rights="yes"
        if [ "${username_got_all_rights}" != "yes" ]
        then
          csih_warning "Assigning the appropriate privileges to user '${username}' failed!"
          ret=1
        fi
      fi
 
      # we just created the user, so of course it's in the local SAM,
      # and mkpasswd -l is appropriate 
      pwd_entry="$(mkpasswd -l -u "${username}" | sed -n -e '/^'${username}'/s?\(^[^:]*:[^:]*:[^:]*:[^:]*:[^:]*:\).*?\1'${LOCALSTATEDIR}'/empty:/bin/false?p')"
      grep -Eiq "^${username}:" "${SYSCONFDIR}/passwd" && username_in_passwd=yes &&
        grep -Fiq "${pwd_entry}" "${SYSCONFDIR}/passwd" && entry_in_passwd=yes
      if [ "${entry_in_passwd}" != "yes" ]
      then
        if [ "${username_in_passwd}" = "yes" ]
        then
          if [ -w "${SYSCONFDIR}" ]
          then
            temp="${SYSCONFDIR}/passwd.$$.tmp"
          elif [ -d "${TMP}" -a -w "${TMP}" ]
          then
            temp="${TMP}/passwd.$$.tmp"
          elif [ -d "${HOME}" -a -w "${HOME}" ]
          then
            temp="${HOME}/passwd.$$.tmp"
          else
            csih_warning "Cannot find writable temporary directory"
            return 1;
          fi
          grep -Ev "^${username}:" "${SYSCONFDIR}/passwd" > "${temp}" &&
            mv -f "${temp}" "${SYSCONFDIR}/passwd" || return 1
        fi
        echo "${pwd_entry}" >> "${SYSCONFDIR}/passwd" || ret=1
      fi
      return "${ret}"
    fi # ! username_in_sam
    return 1 # failed to create user (or prevented by auto-answer veto)
  fi # csih_is_nt2003 || (csih_is_nt && csih_FORCE_PRIVILEGED_USER)
  return 1   # win9x, or nt/2k/xp without FORCE 
} # === End of csih_create_privileged_user() === #
readonly -f csih_create_privileged_user

# ======================================================================
# Routine: csih_create_unprivileged_user
#   On Windows NT and above, creates a new (unprivileged) user as specified
#     by $1.
#   Useful for running services that do not require elevated privileges,
#     or running servers like sshd in "privilege separation" mode.
#   
#   Exits on catastrophic error
#   Returns 0 on total success
#   Returns 1 on failure
#
# csih_auto_answer=no behavior
#   if nt
#     if already exists
#       use it
#     else
#       do nothing, return 1
#   else
#     do nothing, return 1
# ======================================================================
csih_create_unprivileged_user()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local unpriv_user="$1"
  local unpriv_user_in_passwd=no
  local unpriv_user_in_sam=no
  local dos_var_empty=
  local ret=0

  _csih_setup

  if csih_is_nt
  then
    grep -q "^${unpriv_user}:" "${SYSCONFDIR}/passwd" && unpriv_user_in_passwd=yes
    net user "${unpriv_user}" >/dev/null 2>&1 && unpriv_user_in_sam=yes
    if [ "${unpriv_user_in_passwd}" != "yes" ]
    then
      if [ "${unpriv_user_in_sam}" != "yes" ]
      then
        csih_inform "Note that creating a new user requires that the current account have"
        csih_inform "Administrator privileges.  Should this script attempt to create a"
        # give auto-answer a chance to veto
        if csih_request "new local account '${unpriv_user}'?"
        then
          dos_var_empty=$(cygpath -w ${LOCALSTATEDIR}/empty)
          net user "${unpriv_user}" /add /fullname:"${unpriv_user} privsep" \
            "/homedir:${dos_var_empty}" /active:no > /dev/null 2>&1 && unpriv_user_in_sam=yes
          if [ "${unpriv_user_in_sam}" != "yes" ]
          then
            csih_warning "Creating the user '${unpriv_user}' failed!"
          fi
        fi
      fi
      if [ "${unpriv_user_in_sam}" = "yes" ]
      then
        # user either already existed in local SAM, or we just created a new local
        # user.  Therefore, mkpasswd -l is appropriate.  However, the user does not
        # (yet) appear in /etc/passwd, so add it.
        mkpasswd -l -u "${unpriv_user}" | sed -n -e "/^${unpriv_user}/s/bash\$/false/p" >>\
          ${SYSCONFDIR}/passwd
        # make sure the previous command succeeded
        grep -q "^${unpriv_user}:" "${SYSCONFDIR}/passwd" && unpriv_user_in_passwd=yes
        if [ "${unpriv_user_in_passwd}" != "yes" ]
        then
          csih_warning "Created new user '${unpriv_user}', but failed to add"
          csih_warning "corresponding entry to /etc/passwd!"
        fi
      fi
    else
      if [ "${unpriv_user_in_sam}" != "yes" ]
      then
        # FIXME: Needs real domain awareness to not print spurious warnings
        csih_warning "${unpriv_user} is in ${SYSCONFDIR}/passwd, but the"
        csih_warning "local machine's SAM does not know about ${unpriv_user}."
        csih_warning "Perhaps ${unpriv_user} is a pre-existing domain account."
        csih_warning "Continuing, but check if this is ok."
      fi
    fi
    # as long as the user is in /etc/passwd, return success
    # if missing from SAM, we've already issued a diagnostic
    # and are assuming the user is a valid domain account.
    [ "x${unpriv_user_in_passwd}" = "xyes" ] && return 0
    return 1
  fi
  return 1 # not nt
} # === End of csih_create_unprivileged_user() === #
readonly -f csih_create_unprivileged_user


# ======================================================================
# Routine: csih_service_should_run_as [service_name]
#   On Windows9x, returns ""
#
#   If [service_name] is specified, check to see if service_name is
#     already installed.  If so, return that user (after verifying
#     that it has the necessary privileges). If not installed, behave
#     as described below.
#     Should call csih_select_privileged_username first, unless SURE
#     that [service_name] has already been installed.
#
#   Otherwise:
#
#     On Windows Server 2003 and above (including Windows Vista), or if
#     csih_FORCE_PRIVILEGED_USER == "yes" for Windows NT and above:
#       returns the selected privileged account name, IF it exists (e.g.
#       already existed, or was successfully created).  Otherwise,
#       returns "SYSTEM".  Callers should check this and warn.
#
#     On Windows NT/2k/XP, if csih_FORCE_PRIVILEGED_USER != yes, then
#       if a privileged user already exists, return it
#       else return "SYSTEM"
#
#     MUST call either  csih_select_privileged_username
#                   or  csih_create_privileged_user
#     first.
# ======================================================================
csih_service_should_run_as()
{
  csih_stacktrace "${@}"
  $_csih_trace
  local opt_servicename

  if ! csih_is_nt
  then
    return
  fi

  # caller specified a service, so first check to see if that service
  # is already installed, and if so, analyze that account.  (If not,
  # fall thru...)
  if [ -n "$1" ]
  then
    opt_servicename="$1"
    if cygrunsrv -Q "${opt_servicename}" >/dev/null 2>&1
    then
      username=$(cygrunsrv -V -Q ${opt_servicename} 2>&1 | sed -n -e '/^Account/s/^.* : //p')
      username="${username/\.\\/${COMPUTERNAME}\\}"
      if [ "${username}" = "LocalSystem" ]
      then
        username=SYSTEM
      else
        username=$(fgrep "${username}" /etc/passwd | cut -d: -f 1)
      fi
      if ( csih_is_nt2003 || [ csih_is_nt -a "x$csih_FORCE_PRIVILEGED_USER" = "xyes" ] )
      then
        if [ -n "${username}" -a "${username}" != SYSTEM ]
        then
          if csih_privileged_account_exists "${username}"
          then
            echo "${username}"
            return
          else
            if csih_account_has_necessary_privileges "${username}"
            then
              echo "${username}"
              return
            else
              csih_error_multi \
                "${opt_servicename} is installed under custom account '${username}'," \
                "but '${username}' does not have the necessary permissions or "    \
                "group membership. Please correct this problem before continuing." 1>&2
            fi
          fi
        else
          # two different error cases: -z $username, or $username=SYSTEM
          if [ -z "${username}" ]
          then
            csih_error_multi \
              "${opt_servicename} is installed, but there was a problem determining" \
              "the user account under which it runs. Please correct this problem" \
              "before continuing." 1>&2
          else
            csih_error_multi \
              "${opt_servicename} is installed under account 'SYSTEM', but that"  \
              "conflicts with privileged user requirement. ${opt_servicename}" \
              "must be installed under a special privileged account: either"  \
              "because the OS is Windows2003 or above, or you requested -privileged." 1>&2
          fi
        fi    
      else
        # not nt2003 nor (nt && csih_FORCE_PRIVILEGED_USER=yes)
        # we don't care about properties of $username...
        if [ -z "${username}" ]
        then
          csih_error_multi \
            "${opt_servicename} is installed, but there was a problem determining" \
            "the user account under which it runs. Please correct this problem" \
            "before continuing." 1>&2
        else
          echo "${username}"
          return
        fi
      fi
    fi # ${opt_servicename} not installed
  fi # ${opt_servicename} not specified

  # Caller did not specify a specific service, or the specified service
  # is not yet installed, so compute the "expected" account under which
  # privileged services should run.

  # use the following procedure if a privileged account is required:
  if ( csih_is_nt2003 || [ "x$csih_FORCE_PRIVILEGED_USER" = "xyes" ] )
  then
    if [ -z "${csih_PRIVILEGED_USERNAME}" ]
    then
      csih_warning "INTERNAL: should call 'csih_select_privileged_username()' before 'csih_service_should_run_as()'" 1>&2
    fi

    if csih_privileged_account_exists "$csih_PRIVILEGED_USERNAME" 1>&2
    then
      # it already existed before this script was launched
      echo "$csih_PRIVILEGED_USERNAME"
      return
    elif egrep "^${csih_PRIVILEGED_USERNAME}:" /etc/passwd 1>/dev/null 2>&1 ||
         net user "${csih_PRIVILEGED_USERNAME}" >/dev/null 2>&1
    then
      # we probably just created it
      echo "$csih_PRIVILEGED_USERNAME"
      return
    else
      # a failure somewhere
      csih_warning "Expected privileged user '${csih_PRIVILEGED_USERNAME}' does not exist." 1>&2
      csih_warning "Defaulting to 'SYSTEM'" 1>&2
      echo "SYSTEM"
      return
    fi
  fi 

  # not nt2003, and not (nt && csih_FORCE_PRIVILEGED=yes).
  # however, we know csih_is_nt is true, because we bailed out very
  # early if not.  Therefore, use fallback: if any privileged user
  # exists, report that. Otherwise, report SYSTEM
  csih_privileged_accounts
  if [ -n "${_csih_preferred_preexisting_privileged_account}" ]
  then
    echo "${_csih_preferred_preexisting_privileged_account}"
  else
    echo "SYSTEM"
  fi
} # === End of csih_service_should_run_as() === #
readonly -f csih_service_should_run_as

# ======================================================================
# Routine: _csih_late_initialization_code
# SETS GLOBAL VARIABLE: _csih_is_exactly_vista
#                       _csih_is_exactly_server2008
#                       _csih_is_exactly_windows7
#                       _csih_is_exactly_server2008r2
# ======================================================================
_csih_late_initialization_code()
{
  local rstatus
  local productName
  productName=$(csih_invoke_helper winProductName)
  rstatus=$?
  if [ "$rstatus" -eq 0 ]
  then
    if   echo "${productName}" | grep " Server 2008 R2 " >/dev/null 2>&1
    then
        _csih_is_exactly_server2008r2=1
    elif echo "${productName}" | grep " Windows 7 " >/dev/null 2>&1
    then
        _csih_is_exactly_windows7=1
    elif echo "${productName}" | grep " Server 2008 " >/dev/null 2>&1
    then
        _csih_is_exactly_server2008=1
    elif echo "${productName}" | grep " Vista " >/dev/null 2>&1
    then
        _csih_is_exactly_vista=1
    fi
    _csih_win_product_name="${productName}";
  fi
} # === End of _csih_late_initialization_code() === #
readonly -f _csih_late_initialization_code



_csih_late_initialization_code
readonly _csih_is_exactly_vista _csih_is_exactly_server2008
readonly _csih_is_exactly_server2008r2 _csih_is_exactly_windows7
readonly _csih_win_product_name
if [ "cygwin-service-installation-helper.sh" = "$csih_progname_base" ]
then
  csih_error "$csih_progname_base should not be executed directly"
fi
if !  csih_is_nt
then
  csih_error_multi \
	"$csih_progname_base is using csih-$csih_VERSION." \
	"csih-$csih_VERSION requires WinNT or above." \
	"The current operating system is:" \
	"$_csih_win_product_name."
fi
if ! csih_cygver_is_oneseven
then
  csih_error_multi \
	"$csih_progname_base is using csih-$csih_VERSION." \
	"csih-$csih_VERSION requires cygwin-1.7.0 or above." \
	"The current cygwin version is: $_csih_cygver"
fi

