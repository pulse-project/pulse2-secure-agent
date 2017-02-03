; Basic variables
!define PRODUCT_NAME "Siveo OpenSSH Agent"
!define PRODUCT_VERSION "2.3.0"
!define PRODUCT_PUBLISHER "Siveo"
!define PRODUCT_WEB_SITE "http://www.siveo.org"
!define PRODUCT_DIR_REGKEY "Software\Siveo\OpenSSH"
!define PRODUCT_UNINST_KEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\${PRODUCT_NAME}"
!define PRODUCT_UNINST_ROOT_KEY "HKLM"

; Third-party plugins
!addPluginDir ".\plugins"

; MUI
!include "MUI.nsh"

; To cleanly override in-use files (f.e. when this agent is deployed using itself)
!include "Library.nsh"

; Never try to figure out if a file must be updated or not according to its library version
!define LIBRARY_IGNORE_VERSION

; Lib to use if, else...
!include "LogicLib.nsh"
; Provides ${RunningX64} if statement
!include "x64.nsh"

; Use to get command line parameters (silent)
!include "FileFunc.nsh"
!insertmacro GetParameters
!insertmacro GetOptions

; Function to detect current windows version
!include "WinVer.nsh"

; A great function to compare versions
!include ".\libs\VersionCompare.nsh"
; StrReplace
!include ".\libs\StrRep.nsh"

; A custom macro that open a files as read to lock it,
; Upgrade it with copy-on-reboot and then, unlock it
!macro ForceCopyOnReboot SOURCE DESTINATION TEMPDIR
  FileOpen $0 ${DESTINATION} r
  !insertmacro InstallLib DLL NOTSHARED REBOOT_PROTECTED ${SOURCE} ${DESTINATION} ${TEMPDIR}
  FileClose $0
!macroend

; Either "install" or "update"
Var /GLOBAL INSTALLATION_KIND

; Force install or not
Var /GLOBAL FORCE_INSTALL

; A global variable containing version of the currently installed agent
; Will contains 1.0 if no registry key exists, which means either pre-1.1.0
; is installed, or not agent at all installed.
Var /GLOBAL PREVIOUSVERSION
; Another containing path of the previously installed agent
Var /GLOBAL PREVIOUSINSTDIR

; MUI Settings
!define MUI_ABORTWARNING
!define MUI_ICON ".\artwork\install.ico"
!define MUI_UNICON ".\artwork\uninstall.ico"
!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_HEADERIMAGE
!define MUI_WELCOMEFINISHPAGE_BITMAP ".\artwork\wizard.bmp"
!define MUI_HEADERIMAGE_RIGHT
!define MUI_HEADERIMAGE_BITMAP ".\artwork\header.bmp"

; Welcome page
!insertmacro MUI_PAGE_WELCOME
; Directory page
!insertmacro MUI_PAGE_DIRECTORY
; Instfiles page
!insertmacro MUI_PAGE_INSTFILES
; Uninstaller pages
!insertmacro MUI_UNPAGE_INSTFILES
; Language files
!insertmacro MUI_LANGUAGE "English"

Name "${PRODUCT_NAME} (${PRODUCT_VERSION})"
OutFile "pulse2-secure-agent-${PRODUCT_VERSION}.exe"
InstallDir "$PROGRAMFILES\Siveo\OpenSSH"
InstallDirRegKey HKLM "${PRODUCT_DIR_REGKEY}" ""
ShowInstDetails show
ShowUnInstDetails show

; First function run
Function .onInit
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; CHECK IF IT'S A NT-BASED OS ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Won't work on non-NT OS (ie win95/98/Me)
  ${IfNot} ${IsNT}
    MessageBox MB_OK|MB_ICONEXCLAMATION "You cannot install $(^Name) unless you're running Windows NT later."
    Abort
  ${EndIf}
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; DEFINE IF IT'S AN UPDATE OR NOT ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ClearErrors
  ${GetParameters} $R0
  ; Handle /UPDATE option
  ${GetOptions} $R0 /UPDATE $0
  ${If} ${Errors} ; "UPDATE" flag not set
    StrCpy $INSTALLATION_KIND "install"
  ${Else} ; "UPDATE" flag set
    StrCpy $INSTALLATION_KIND "update"
  ${EndIf}
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; CHECK IF /FORCE IS USED ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ClearErrors
  ${GetParameters} $R0
  ; Handle /FORCE option
  ${GetOptions} $R0 /FORCE $0
  ${If} ${Errors} ; "FORCE" flag not set
    StrCpy $FORCE_INSTALL "false"
  ${Else} ; "FORCE" flag set
    StrCpy $FORCE_INSTALL "true"
  ${EndIf}
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; GET PREVIOUS AGENT VERSION AND PATH ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; ReadRegStr will set the Errors flag if the key doesn't exist
  ClearErrors
  ReadRegStr $0 HKLM "Software\Siveo\OpenSSH" "CurrentVersion"
  ${If} ${Errors}
    ; The key doesn't exists, it means that previous version was older
    ; than 1.1.0 or no agent is currently installed
    ; Set dummy version to 1.0
    StrCpy $PREVIOUSVERSION "1.0"
  ${Else}
    ; Use $0 which contains the right version
    StrCpy $PREVIOUSVERSION $0
  ${EndIf}
  ; ReadRegStr will set the Errors flag if the key doesn't exist
  ClearErrors
  ReadRegStr $0 HKLM "Software\Siveo\OpenSSH" "InstallPath"
  ${If} ${Errors}
    ; The key doesn't exists, it means that previous version was older
    ; than 1.2.X
    ; Use default INSTDIR
    StrCpy $PREVIOUSINSTDIR $INSTDIR
  ${Else}
    ; Use $0 which contains the previous installation path
    StrCpy $PREVIOUSINSTDIR $0
  ${EndIf}
  ;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; DEFINE A FEW VARIABLES ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; Chop "C" part from C:\WINDOWS
  StrCpy $R0 $WINDIR 1
  var /GLOBAL WINDRIVE
  StrCpy $WINDRIVE $R0
  ; Chop "WINDOWS" part from C:\WINDOWS
  StrCpy $R1 $WINDIR 100 3
  var /GLOBAL WINSYSDIR
  StrCpy $WINSYSDIR $R1
  ; Compute Cygwin Windows path
  var /GLOBAL CYGWINSYSDIR
  StrCpy $CYGWINSYSDIR "/cygdrive/$WINDRIVE/$WINSYSDIR"
  ; Then compute a PATH variable to run Cygwin scripts
  var /GLOBAL CYGSCRIPTSPATH
  StrCpy $CYGSCRIPTSPATH "$CYGWINSYSDIR/system32:$CYGWINSYSDIR:$CYGWINSYSDIR/System32/Wbem:/usr/bin"
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ; WHEN OVERWRITING THE SAME VERSION AT THE SAME PATH WITHOUT /FORCE ;
  ; + IN SILENT MODE EXIT using Abort                                 ;
  ; + IN INTERACTIVE MODE EXIT using Abort                            ;
  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
  ${If} $FORCE_INSTALL == false
    ${If} $PREVIOUSINSTDIR == $INSTDIR
      ${If} $PREVIOUSVERSION == ${PRODUCT_VERSION}
        ${If} ${Silent}
          Abort
        ${Else}
          MessageBox MB_OK|MB_ICONSTOP 'The installer found that this version of Siveo Pulse2 Secure Agent (OpenSSH included) is already installed. Either remove it first, or run me using "/FORCE"'
          Abort
        ${EndIf}
      ${EndIf}
    ${EndIf}
  ${EndIf}
FunctionEnd

Section "Clean OpenSSH service" Clean
  SectionIn RO
  ; Find out if the SSHd Service is installed
  ${If} $INSTALLATION_KIND == "install"
    DetailPrint "No /UPDATE flag set. Cleaning old sshd service."
    Push 'sshd'
    Services::IsServiceInstalled
    Pop $0
    ; $0 now contains either 'Yes', 'No' or an error description
    ${If} $0 == 'Yes'
      ; This will stop and remove the SSHd service if it is running.
      push 'sshd'
      push 'Stop'
      Services::SendServiceCommand
      push 'sshd'
      push 'Delete'
      Services::SendServiceCommand
      Pop $0
      ${If} $0 != 'Ok'
        MessageBox MB_OK|MB_ICONSTOP 'The installer found the OpenSSH service, but was unable to remove it. Please stop it and manually remove it. Then try installing again.'
        Abort
      ${EndIf}
      ; Wait one second for the service to be really stopped
      Sleep 1000
    ${EndIf}
  ${Else}
    DetailPrint "/UPDATE detected! Skipping sshd service removal."
  ${EndIf}
SectionEnd

Section "Core" Core
  SectionIn RO

  SetOutPath "$INSTDIR\bin"
  SetOverwrite on

  ; Use copy-on-reboot for all DLLs. Theses files may be in use when upgrading.
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyglsa.dll "$OUTDIR\cyglsa.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyglsa64.dll "$OUTDIR\cyglsa64.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygwind-0.dll "$OUTDIR\cygwind-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygtasn1-3.dll "$OUTDIR\cygtasn1-3.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygstdc++-6.dll "$OUTDIR\cygstdc++-6.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygsqlite3-0.dll "$OUTDIR\cygsqlite3-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygroken-18.dll "$OUTDIR\cygroken-18.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygpcre-1.dll "$OUTDIR\cygpcre-1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygp11-kit-0.dll "$OUTDIR\cygp11-kit-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygncursesw-10.dll "$OUTDIR\cygncursesw-10.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygmpfr-4.dll "$OUTDIR\cygmpfr-4.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygmagic-1.dll "$OUTDIR\cygmagic-1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygkrb5-3.dll "$OUTDIR\cygkrb5-3.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygkafs-0.dll "$OUTDIR\cygkafs-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygidn-11.dll "$OUTDIR\cygidn-11.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyghx509-5.dll "$OUTDIR\cyghx509-5.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygheimntlm-0.dll "$OUTDIR\cygheimntlm-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygheimbase-1.dll "$OUTDIR\cygheimbase-1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggssapi-3.dll "$OUTDIR\cyggssapi-3.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggpg-error-0.dll "$OUTDIR\cyggpg-error-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggnutls-28.dll "$OUTDIR\cyggnutls-28.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygasn1-8.dll "$OUTDIR\cygasn1-8.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggmp-10.dll "$OUTDIR\cyggmp-10.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygedit-0.dll "$OUTDIR\cygedit-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggcrypt-11.dll "$OUTDIR\cyggcrypt-11.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygattr-1.dll "$OUTDIR\cygattr-1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygcom_err-2.dll "$OUTDIR\cygcom_err-2.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygwin1.dll "$OUTDIR\cygwin1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygintl-8.dll "$OUTDIR\cygintl-8.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygreadline7.dll "$OUTDIR\cygreadline7.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygiconv-2.dll "$OUTDIR\cygiconv-2.dll" "$OUTDIR" ; required by cygintl-3.dll/cygintl-8.dll
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygz.dll "$OUTDIR\cygz.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygcrypto-1.0.0.dll "$OUTDIR\cygcrypto-1.0.0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygcrypt-0.dll "$OUTDIR\cygcrypt-0.dll" "$OUTDIR" ; needed by sshd
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygwrap-0.dll "$OUTDIR\cygwrap-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggcc_s-1.dll "$OUTDIR\cyggcc_s-1.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cyggmp-3.dll "$OUTDIR\cyggmp-3.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygssp-0.dll "$OUTDIR\cygssp-0.dll" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygrunsrv.exe "$OUTDIR\cygrunsrv.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ssh.exe "$OUTDIR\ssh.exe" "$OUTDIR"

  ; Copy-on-reboot for theses essential binaries
  !insertmacro ForceCopyOnReboot data\cygwin\bin\rsync.exe "$OUTDIR\rsync.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\wget.exe "$OUTDIR\wget.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\bash.exe "$OUTDIR\bash.exe" "$OUTDIR"

  !insertmacro ForceCopyOnReboot data\cygwin\bin\getent.exe "$OUTDIR\getent.exe" "$OUTDIR"

  ; The following binaries doesn't work anymore when upgrading from 1.2.3 to 2.0.0
  !insertmacro ForceCopyOnReboot data\cygwin\bin\expr.exe "$OUTDIR\expr.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\awk "$OUTDIR\awk" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\rm.exe "$OUTDIR\rm.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\stat.exe "$OUTDIR\stat.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\grep.exe "$OUTDIR\grep.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygpath.exe "$OUTDIR\cygpath.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\tr.exe "$OUTDIR\tr.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\getfacl.exe "$OUTDIR\getfacl.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ls.exe "$OUTDIR\ls.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\uname.exe "$OUTDIR\uname.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\sed.exe "$OUTDIR\sed.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mount.exe "$OUTDIR\mount.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cmp.exe "$OUTDIR\cmp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cp.exe "$OUTDIR\cp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cat.exe "$OUTDIR\cat.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\chown.exe "$OUTDIR\chown.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\chgrp.exe "$OUTDIR\chgrp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\chmod.exe "$OUTDIR\chmod.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\echo.exe "$OUTDIR\echo.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\setfacl.exe "$OUTDIR\setfacl.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cygcheck.exe "$OUTDIR\cygcheck.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ssh-keygen.exe "$OUTDIR\ssh-keygen.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\sh.exe "$OUTDIR\sh.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\tail.exe "$OUTDIR\tail.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\head.exe "$OUTDIR\head.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\basename.exe "$OUTDIR\basename.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\cut.exe "$OUTDIR\cut.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\date.exe "$OUTDIR\date.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\diff.exe "$OUTDIR\diff.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\dirname.exe "$OUTDIR\dirname.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\editrights.exe "$OUTDIR\editrights.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\egrep.exe "$OUTDIR\egrep.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\env.exe "$OUTDIR\env.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\false.exe "$OUTDIR\false.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\gawk.exe "$OUTDIR\gawk.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\gzip.exe "$OUTDIR\gzip.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\id.exe "$OUTDIR\id.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\join.exe "$OUTDIR\join.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\less.exe "$OUTDIR\less.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\md5sum.exe "$OUTDIR\md5sum.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mkdir.exe "$OUTDIR\mkdir.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mkgroup.exe "$OUTDIR\mkgroup.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mkpasswd.exe "$OUTDIR\mkpasswd.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mv.exe "$OUTDIR\mv.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\passwd.exe "$OUTDIR\passwd.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ps.exe "$OUTDIR\ps.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\rebase.exe "$OUTDIR\rebase.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\regtool.exe "$OUTDIR\regtool.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\rmdir.exe "$OUTDIR\rmdir.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\scp.exe "$OUTDIR\scp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\seq.exe "$OUTDIR\seq.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\sftp.exe "$OUTDIR\sftp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\sleep.exe "$OUTDIR\sleep.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\split.exe "$OUTDIR\split.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ssh-add.exe "$OUTDIR\ssh-add.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ssh-agent.exe "$OUTDIR\ssh-agent.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\shutdown.exe "$OUTDIR\shutdown.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\tar.exe "$OUTDIR\tar.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\tee.exe "$OUTDIR\tee.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\touch.exe "$OUTDIR\touch.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\true.exe "$OUTDIR\true.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\umount.exe "$OUTDIR\umount.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\unzip.exe "$OUTDIR\unzip.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\uudecode.exe "$OUTDIR\uudecode.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\uuencode.exe "$OUTDIR\uuencode.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\wc.exe "$OUTDIR\wc.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\yes.exe "$OUTDIR\yes.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\zip.exe "$OUTDIR\zip.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\tree.exe "$OUTDIR\tree.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\vim.exe "$OUTDIR\vim.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\unix2mac.exe "$OUTDIR\unix2mac.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mac2unix.exe "$OUTDIR\mac2unix.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\unix2dos.exe "$OUTDIR\unix2dos.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\dos2unix.exe "$OUTDIR\dos2unix.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\file.exe "$OUTDIR\file.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\find.exe "$OUTDIR\find.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\mktemp.exe "$OUTDIR\mktemp.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\hostname.exe "$OUTDIR\hostname.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\ln.exe "$OUTDIR\ln.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\bin\su.exe "$OUTDIR\su.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\bin\7z "$OUTDIR\7z" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\bin\7za "$OUTDIR\7za" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\bin\7zr "$OUTDIR\7zr" "$OUTDIR"

  ; Files not depending on cygwin dlls
  File data\cygwin\bin\ssh-host-config
  File data\cygwin\bin\cyglsa-config
  File data\cygwin\bin\gunzip

  ; Pulse2 addons
  File addons\cyglsa-uninstall
  File addons\check\pulse2-client-check.sh
  File addons\dellater\Release\dellater.exe
  File addons\pulse2-ether-list\Release\pulse2-ether-list.exe
  File addons\smart_cleaner\pulse2-smart-cleaner.sh

  SetOutPath "$INSTDIR\lib\csih"
  SetOverwrite on
  File data\cygwin\lib\csih\getAccountName.exe
  !insertmacro ForceCopyOnReboot data\cygwin\lib\csih\getVolInfo.exe "$OUTDIR\getVolInfo" "$OUTDIR" ; Depends on cygwin1.dll
  File data\cygwin\lib\csih\winProductName.exe
  
  SetOutPath "$INSTDIR\usr\sbin"
  SetOverwrite on
  ; Copy-on-reboot for theses enssential binaries
  !insertmacro ForceCopyOnReboot data\cygwin\usr\sbin\sftp-server.exe "$OUTDIR\sftp-server.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\sbin\sshd.exe "$OUTDIR\sshd.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\sbin\ssh-keysign.exe "$OUTDIR\ssh-keysign.exe" "$OUTDIR"
  
  SetOutPath "$INSTDIR\lib\p7zip"
  SetOverwrite on
  !insertmacro ForceCopyOnReboot data\cygwin\usr\lib\p7zip\7za.exe "$OUTDIR\7za.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\lib\p7zip\7z.exe "$OUTDIR\7z.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\lib\p7zip\7zr.exe "$OUTDIR\7zr.exe" "$OUTDIR"
  !insertmacro ForceCopyOnReboot data\cygwin\usr\lib\p7zip\7z.so "$OUTDIR\7z.so" "$OUTDIR"

  SetOutPath $INSTDIR\usr\share\terminfo\63
  SetOverwrite on
  File data\cygwin\usr\share\terminfo\63\cygwin
  SetOutPath $INSTDIR\usr\share\terminfo\78
  SetOverwrite on
  File data\cygwin\usr\share\terminfo\78\xterm

  SetOutPath $INSTDIR\usr\share\csih
  SetOverwrite on
  File data\cygwin\usr\share\csih\cygwin-service-installation-helper.sh

  ; Pulse2 addons libs
  SetOutPath "$INSTDIR\usr\share\pulse2"
  SetOverwrite on
  File addons\check\libpulse2-client-check.sh
  File addons\smart_cleaner\libpulse2-smart-cleaner.sh

  SetOutPath $INSTDIR\etc\defaults\etc
  SetOverwrite on
  File data\cygwin\etc\defaults\etc\ssh_config
  File data\cygwin\etc\defaults\etc\sshd_config

  SetOutPath $INSTDIR\etc
  SetOverwrite on
  File data\cygwin\etc\banner.txt
  File data\cygwin\etc\bash.bashrc
  File data\cygwin\etc\profile
  File data\cygwin\etc\moduli
  
  SetOutPath $INSTDIR\etc\skel
  SetOverwrite on
  File data\cygwin\etc\skel\.vimrc
  
  SetOutPath $INSTDIR\usr\share\misc
  SetOverwrite on
  File data\cygwin\usr\share\misc\magic.mgc

  SetOutPath $INSTDIR\etc\postinstall
  SetOverwrite on
  File data\cygwin\etc\postinstall\000-cygwin-post-install.sh.done

  SetOutPath $INSTDIR\var\log
  SetOverwrite on
  File data\cygwin\var\log\wtmp

  SetOutPath $INSTDIR\var\run
  SetOverwrite on
  File data\cygwin\var\run\utmp

  ; Create an empty /tmp
  SetOutPath $INSTDIR\tmp
  SetOverwrite on

  ; /home (The Profiles directory for the machine)
  ; Do not try to use $PROFILE here, it will fails when installing through ssh
  ; Do not try to use $STARTMENU either, it fails when installing through ssh on Seven
  ; Query registry instead...
  ReadRegStr $R0 HKLM "Software\Microsoft\Windows NT\CurrentVersion\ProfileList" "ProfilesDirectory"
  ; Expand Windows environment variables (ie: %SYSTEMDRIVE%)
  ExpandEnvStrings $R1 $R0
  ; Replace spaces by \040
  ${StrReplace} $R0 " " "\040" $R1
  FileOpen $9 $INSTDIR\etc\fstab w
  ; Filesystem is useless here
  ; See http://cygwin.com/cygwin-ug-net/using.html#mount-table for documentation
  FileWrite $9 "$R0 /home ntfs binary,posix=0,auto 0 0$\n"
  FileClose $9

  ; Write the CYGWIN environment variable
  WriteRegStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "CYGWIN" "tty"

  ; Hide service user from windows logon screen
  ${If} ${AtLeastWinVista}
    ; Force 64 bits registry. This key must be written in the real registry on Windows X64, not in the compatibility one force 32 bits applications (google for wow6432node)
    ${If} ${RunningX64}
      SetRegView 64
    ${EndIf}
    WriteRegDWORD HKLM "Software\Microsoft\Windows NT\CurrentVersion\Winlogon\SpecialAccounts\UserList" "sshd_server" "0"
    ; Back to 32 bits registry
    ${If} ${RunningX64}
      SetRegView 32
    ${EndIf}
  ${EndIf}

  ; Run Cygwin sshd postinstall, skip if we're upgrading
  ${If} $INSTALLATION_KIND == "install"
    ; Random password: random md5 plus some special characters
    md5dll::GetMD5Random
    Pop $1
    StrCpy $2 $1 5
    StrCpy $3 $1 5 -5
    StrCpy $4 $1 -5
    StrCpy $0 "$2:/\;$3\+?$4"
    !define MDHASH $0
    ; Run Cygwin SSH config script (2003SRV compliant)
    DetailPrint 'Running $INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; MDVCURRENTDIR=\"$EXEDIR\" /usr/bin/ssh-host-config -y -c ntsec -w ${MDHASH}"'
    nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; MDVCURRENTDIR=\"$EXEDIR\" /usr/bin/ssh-host-config -y -c ntsec -w ${MDHASH}"'
    ; Run Cygwin LSA config (user context switch without password)
    DetailPrint 'Running $INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/cyglsa-config"'
    nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/cyglsa-config"'

    ; Try to open TCP/22 in Windows Firewall
    DetailPrint "WindowsFirewall: Let's try to open TCP/22 port..."
    SimpleFC::IsFirewallEnabled
    Pop $0
    Pop $1
    ; Command worked
    ${If} $0 == 0
        ; Firewall is enabled
        ${If} $1 == 1
            ; Check 22/TCP port status
            SimpleFC::IsPortAdded 22 6
            Pop $0
            Pop $1
            ; Command worked
            ${If} $0 == 0
                ; Port already open
                ${If} $1 == 1
                    DetailPrint "WindowsFirewall: Port TCP/22 is already open, not doing anything."
                ; Port isn't open yet
                ${Else}
                    ; Try to open the port
                    SimpleFC::AddPort 22 "Siveo Secure Agent (OpenSSH)" 6 0 2 "" 1
                    Pop $0
                    ${If} $1 == 1
                        DetailPrint "WindowsFirewall: Port 22/TCP couldn't be opened."
                    ${Else}
                        DetailPrint "WindowsFirewall: Port 22/TCP opened SUCCESSFULLY!"
                    ${EndIf}
                ${EndIf}
            ; Command failed
            ${Else}
                DetailPrint "WindowsFirewall: Unable to get current TCP/22 port status, not doing anything."
            ${EndIf}
        ; Firewall is disabled
        ${Else}
            DetailPrint "WindowsFirewall: Firewall looks being disabled, not doing anything."
        ${EndIf}
    ; Unable to get firewall status
    ${Else}    
        DetailPrint "WindowsFirewall: Unable to get firewall status, not doing anything."
    ${EndIF}

  ; We're updating, postinstall skipped but we may want to fix some stuff...
  ${Else}
    DetailPrint "/UPDATE detected! sshd post-installation skipped."
    ${If} $PREVIOUSVERSION == "1.0"
      DetailPrint "Previous version: 1.0.4 or older."
    ${Else}
      DetailPrint "Previous version: $PREVIOUSVERSION."
    ${EndIf}
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; < 1.1.0: FIX TRAILING SPACE IN PATH ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ; Fix service PATH, only useful if using /UPDATE
    ; If not ssh-host-config will reinstall the service anyway
    ${VersionCompare} $PREVIOUSVERSION "1.1.0" $R0
    ${If} $R0 == 2
      DetailPrint "Fixing broken service PATH environment variable"
      ReadRegStr $0 HKLM "SYSTEM\CurrentControlSet\Services\sshd\Parameters\Environment" "PATH"
      ; Get last PATH character
      StrCpy $1 $0 1 -1
      ; Check if it's really the broken trailing space
      ${If} $1 == ' '
        DetailPrint "Trailing space detected!"
        ; Remove last character and update the registry
        StrCpy $1 $0 -1
        WriteRegStr HKLM "SYSTEM\CurrentControlSet\Services\sshd\Parameters\Environment" "PATH" "$1"
        DetailPrint "PATH fixed."
      ${Else}
        DetailPrint "No trailing space detected. Skipping."
      ${EndIf}
    ${EndIf}
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; < 1.2.3: FIX SOME FILES PERMISSIONS                      ;;
    ;; < 1.2.3: REMOVE OBSOLETE cygncurses-8.dll AT NEXT REBOOT ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ${VersionCompare} $PREVIOUSVERSION "1.2.3" $R0
    ${If} $R0 == 2
      DetailPrint "Fixing some files permissions"
      nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/chmod 644 /etc/passwd"'
      nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/chmod 644 /etc/group"'
      nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/chmod 700 /etc/ssh_config"'
      nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/chmod 700 /etc/sshd_config"'
      DetailPrint "Removing obsolete cygncurses-8.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygncurses-8.dll"'
    ${EndIf}
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; < 2.0.0: REMOVE OBSOLETE DLLS AT NEXT REBOOT ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ${VersionCompare} $PREVIOUSVERSION "2.0.0" $R0
    ${If} $R0 == 2
      DetailPrint "Removing obsolete cygreadline6.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygreadline6.dll"'
      DetailPrint "Removing obsolete cygintl-2.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygintl-2.dll"'
      DetailPrint "Removing obsolete cygminires.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygminires.dll"'
      DetailPrint "Removing obsolete cygbz2-1.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygbz2-1.dll"'
      DetailPrint "Removing obsolete cygintl-3.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygintl-3.dll"'
    ${EndIf}
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ;; < 2.1.0: REMOVE OBSOLETE DLLS AT NEXT REBOOT ;;
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    ${VersionCompare} $PREVIOUSVERSION "2.1.0" $R0
    ${If} $R0 == 2
      DetailPrint "Removing obsolete awk.exe at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\awk.exe"'
      DetailPrint "Removing obsolete cygcrypto-0.9.8.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygcrypto-0.9.8.dll"'
      DetailPrint "Removing obsolete cygncurses-9.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygncurses-9.dll"'
      DetailPrint "Removing obsolete cygpcre-0.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygpcre-0.dll"'
      DetailPrint "Removing obsolete cygpopt-0.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygpopt-0.dll"'
      DetailPrint "Removing obsolete cygssl-0.9.8.dll at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\bin\cygssl-0.9.8.dll"'
      DetailPrint "Removing obsolete getAccountName at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\lib\csih\getAccountName"'
      DetailPrint "Removing obsolete winProductName at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\lib\csih\winProductName"'
      DetailPrint "Removing obsolete passwd-grp.sh.done at next reboot"
      nsExec::ExecToLog '"$INSTDIR\bin\dellater.exe" "$INSTDIR\etc\postinstall\passwd-grp.sh.done"'
      ; Run Cygwin LSA config (user context switch without password)
      DetailPrint 'Running $INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/cyglsa-config"'
      nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=$CYGSCRIPTSPATH; /usr/bin/cyglsa-config"'
    ${EndIf}
  ${EndIf}
SectionEnd

; Postinstall (create uninst.exe and register app in unistall registry database)
Section -Post
  WriteUninstaller "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayName" "$(^Name)"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "UninstallString" "$INSTDIR\uninst.exe"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "DisplayVersion" "${PRODUCT_VERSION}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "URLInfoAbout" "${PRODUCT_WEB_SITE}"
  WriteRegStr ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}" "Publisher" "${PRODUCT_PUBLISHER}"
  ; Write a CurrentVersion variable
  ; This must be done after installation, otherwise it would overwrite previous version number
  WriteRegStr HKLM "Software\Siveo\OpenSSH" "CurrentVersion" "${PRODUCT_VERSION}"
  WriteRegStr HKLM "Software\Siveo\OpenSSH" "InstallPath" "$INSTDIR"
SectionEnd

; Section descriptions
!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
!insertmacro MUI_DESCRIPTION_TEXT ${Clean} "Remove old Cygwin OpenSSH service if exists"
!insertmacro MUI_DESCRIPTION_TEXT ${Core} "OpenSSH and required Unix tools"
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; Postuninstall function
Function un.onUninstSuccess
  ${IfNot} ${Silent}
    HideWindow
    MessageBox MB_ICONINFORMATION|MB_OK "$(^Name) was successfully removed from your computer."
  ${EndIf}
FunctionEnd

; First function run at uninstall time (ask confirm)
Function un.onInit
  ${IfNot} ${Silent}
    MessageBox MB_ICONQUESTION|MB_YESNO|MB_DEFBUTTON2 "Are you sure you want to completely remove $(^Name) and all of its components?" IDYES +2
    Abort
  ${EndIf}
FunctionEnd

; What do to when unstalling
Section Uninstall
  ;Find out if the sshd service is installed
  Push 'sshd'
  Services::IsServiceInstalled
  Pop $0
  ; $0 now contains either 'Yes', 'No' or an error description
  ${If} $0 == 'Yes'
    ; This will stop and remove the SSHd service if it is running.
    push 'sshd'
    push 'Stop'
    Services::SendServiceCommand
    push 'sshd'
    push 'Delete'
    Services::SendServiceCommand
    Pop $0
    ${If} $0 != 'Ok'
      ${IfNot} ${Silent}
        MessageBox MB_OK|MB_ICONSTOP 'The uninstaller found the OpenSSH service, but was unable to remove it. Please stop it and manually remove it.'
      ${EndIf}
    ${EndIf}
    ; Wait one second for the service to be really stopped
    Sleep 1000
  ${EndIf}
  
  ; Try to remove Cygwin LSA package    
  DetailPrint 'Running $INSTDIR\bin\bash.exe -c "export PATH=/usr/bin; /usr/bin/cyglsa-uninstall"'
  nsExec::ExecToLog '$INSTDIR\bin\bash.exe -c "export PATH=/usr/bin; /usr/bin/cyglsa-uninstall"'

  ; Drop uninstaller and files
  Delete "$INSTDIR\uninst.exe"
  RMDir /r "$INSTDIR"
  DeleteRegKey ${PRODUCT_UNINST_ROOT_KEY} "${PRODUCT_UNINST_KEY}"

  ; Delete registry entries specific to the product
  DeleteRegKey HKLM "${PRODUCT_DIR_REGKEY}"

  SetAutoClose true
SectionEnd
