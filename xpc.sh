#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

main(){
  cd "$( dirname "$( readlink -f "${BASH_SOURCE[0]}" )")"
  export _XPC_DIR="$PWD"
  if [ -f "$_XPC_DIR"/.xpc.conf ]; then source "$_XPC_DIR"/.xpc.conf; fi
	export _R="$(tput setaf 1)"
	export _G="$(tput setaf 2)"
	export _Y="$(tput setaf 3)"
	export _B="$(tput setaf 4)"
	export _Z="$(tput sgr0)"
  export _XPC_TARGET=${_XPC_TARGET:-x86_64-xpc-linux-gnu}
  export _XPC_TOOLCHAIN=${_XPC_TOOLCHAIN:-"$_XPC_DIR"/toolchain}
  export _XPC_SYSROOT=${_XPC_SYSROOT:-"$_XPC_TOOLCHAIN"/$_XPC_TARGET/sysroot}
  export _XPC_ROOTFS=${_XPC_ROOTFS:-"$_XPC_DIR"/rootfs}
  export _XPC_TMP=${_XPC_TMP:-"$_XPC_DIR"/.tmp}
  export _XPC_DOWNLOADS=${_XPC_DOWNLOADS:-"$_XPC_DIR"/.download}
  export _XPC_CPU=${_XPC_CPU:-atom}
  export PATH="$_XPC_TOOLCHAIN"/bin:$PATH
  mkdir -p "$_XPC_ROOTFS"/{dev,proc,run,sys,usr/bin} "$_XPC_TMP" "$_XPC_DOWNLOADS"
  set +e
  for item in "$_XPC_TOOLCHAIN"/bin/$_XPC_TARGET*; do
    local _target="$(basename $item)"
    local _var=$(echo ${_target##*-} | tr [:lower:] [:upper:])
    export "$_var"="$_target" 2>/dev/null
  done
  set -e
  trap _atexit INT TERM EXIT
  $*
  return 0
}

_atexit(){
  local _ret=$?
  if [ "0" != "$_ret" ]; then
    echo -e "${_R}Exiting with code: $_ret $_Z"
    exit $_ret
  fi
  set +e
  printenv | sort | grep "^_XPC_" > "$_XPC_DIR"/.xpc.conf

  exit 0
}


help(){
  echo -e "
Usage: $0 $_G<command>$_Z

Commands:
  $_G help $_Z                - this information
  $_G qemu $_Z                - enter emulated chroot
  $_G shell $_Z               - enter dev shell
  $_G bootstrap $_B<options>$_Z
bootstrap options:
    $_B toolchain $_Z         - build ct-ng toolchain
    $_B rootfs $_Z            - core root file system
  "
}

-help(){ help; }
--help(){ help; }
-h(){ help; }
--h(){ help; }
-?(){ help; }
--?(){ help; }

shell(){
  export PS1="${_R}xpc shell${_G} \w ${_Z}> "
  reset
  echo -e "Entering xpc dev shell. Type '${_R}exit${_Z}' to return.
  
  Environment:
${_Y}$(printenv | sort | grep "^_XPC_")${_Z}

  "
  
  bash -norc -noprofile
}

bgprocess(){
  local _msg="$1"
  shift
  ($*) > /dev/null 2>&1 &
  local _pid=$!

  local _spin='-\|/'

  local i=0
  while kill -0 $_pid 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r$_Y $_msg ${_spin:$i:1} $_Z"
    sleep .1
  done
  wait $_pid
  echo ""
}



bgdelete(){
  if [ ! -e "$1" ]; then return 0; fi
  #santiy check, ensure deleting only a project subdirectory
  for item in "$*"; do
    local tmpdir=${item:0:${#B}}
    if [ "$B" !=  "$tmpdir" ]; then
      echo -e "$_R ERROR $_Z attempt to delete an invalid directory or file:"
      echo -e "$_Y $1 $_Z"
      return 2
    fi
  done
  local tmpdir=$(mktemp -d -p "$B"/.tmp)
  mv $* $tmpdir
  rm -rf $tmpdir > /dev/null &
}



bootstrap(){
  bootstrap-$*
}

bootstrap-toolchain(){
  cd "$_XPC_TOOLCHAIN"/src
  ct-ng build
}

bootstrap-rootfs(){
  echo "bootstrap-rootfs"
}

main $*
exit 0