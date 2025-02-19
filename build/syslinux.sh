#!/bin/sh
set -e

# 'y' to enable or anything else to disable
INSTALL_TO_SYSTEM=n
INSTALL_TO_BOOT=n
INSTALL_WITH_SCRIPT=n
INSTALL_SYNC=n

_top_dir="$PWD"
_targets="bios efi64 efi32"
_checkout_commit="05ac953c23f90b2328d393f7eecde96e41aed067"  # ensure master
_revert_commit="458a54133ecdf1685c02294d812cb562fe7bf4c3"    # tag: syslinux-6.04-pre3
_src_url="https://gitlab.archlinux.org/archlinux/packaging/packages/syslinux/-/raw/main"
_patches="0002-gfxboot-menu-label.patch                                   \
          0017-single-load-segment.patch                                  \
          0016-strip-gnu-property.patch                                   \
          0018-prevent-pow-optimization.patch                             \
          0025-reproducible-build.patch                                   \
          0005-Workaround-multiple-definition-of-symbol-errors.patch      \
          0006-Replace-builtin-strlen-that-appears-to-get-optimized.patch \
          0026-add-missing-include.patch                                  \
          0027-use-correct-type-for-size.patch"
_scripts="syslinux-install_update"

_a () { :; }; _e () { :; }; _n () { :; }

_help ()
{
  local _name="./$(basename "$0")"
  echo "$_name [arg1 [arg2 ...]]"
  echo "  <no args> => do everything"
  echo "  *"
  echo "  a|e|n   => do nothing (useful for $_name a build install)"
  echo "  clean   => clean everything"
  echo "  setup   => clone syslinux repo and get patches"
  echo "  build   => build everything (buggy if not first time)"
  echo "  install => install (not in system root)"
  echo "  *"
  echo "  build|install|buildinstall [arg1 [arg2 ...]] => multiple targets, e.g."
  echo "  $_name build efi64 => only build efi64"
  echo "  $_name install efi64 efi32 => only install efi64 and efi32"
  echo "  $_name buildinstall efi64 efi32 => build and install efi64 and efi32"
  echo "  $_name a|e|n build install => build and install all targets"
}

_clean ()
{
  rm -rf "$_top_dir"/syslinux-build
}

_setup ()
{
  mkdir -p "$_top_dir"/syslinux-build
  cd "$_top_dir"/syslinux-build

  if [ ! -d syslinux ] ; then
    git clone --recursive https://repo.or.cz/syslinux.git
  fi

  for patch in $_patches ; do
    if [ ! -f $patch ] ; then
      if command -v wget &> /dev/null; then
        wget "$_src_url/$patch"
      else
        curl -fLO "$_src_url/$patch"
      fi
    fi
  done

  for script in $_scripts ; do
    if [ ! -f $script ] ; then
      if command -v wget &> /dev/null; then
        wget "$_src_url/$script"
      else
        curl -fLO "$_src_url/$script"
      fi
    fi
  done
}

_build ()
{
  cd "$_top_dir"/syslinux-build/syslinux

  if [ ! -f _built ] ; then
    touch _built && echo "/_built" >> .git/info/exclude
    git checkout -b build $_checkout_commit
    git revert -n $_revert_commit

    for _patch in $_patches ; do
      patch -p1 -i ../$_patch
    done

    # do not swallow efi compilation output to make debugging easier:
    sed 's|> /dev/null 2>&1||' -i efi/check-gnu-efi.sh

    # disable debug and development flags to reduce bootloader size:
    # truncate --size 0 mk/devel.mk
  fi

  export LDFLAGS="$LDFLAGS --no-dynamic-linker"
  export EXTRA_CFLAGS="$EXTRA_CFLAGS -fno-PIE"

  if [ $# -eq 0 ] ; then
    for _target in $_targets ; do
      make PYTHON=python3 $_target
    done
  else
    for _arg in $@ ; do
      make PYTHON=python3 $_arg
    done
  fi
}

_install ()
{
  cd "$_top_dir"/syslinux-build/syslinux

  sudo_cmd=
  if [ "x$INSTALL_TO_SYSTEM" = "xy" ] ; then
    sudo_cmd=sudo
    _install_root=/
  else
    _install_root="$_top_dir"/syslinux-build/installroot
    sudo rm -rf "$_install_root"
    mkdir -p "$_install_root"
  fi

  if [ $# -eq 0 ] ; then
    for _target in $_targets ; do
      $sudo_cmd make $_target install \
        INSTALLROOT="$_install_root" \
        SBINDIR=/usr/bin \
        MANDIR=/usr/share/man \
        AUXDIR=/usr/lib/syslinux
    done
  else
    for _arg in $@ ; do
      $sudo_cmd make $_arg install \
        INSTALLROOT="$_install_root" \
        SBINDIR=/usr/bin \
        MANDIR=/usr/share/man \
        AUXDIR=/usr/lib/syslinux
    done
  fi

  $sudo_cmd rm -r "$_install_root"/usr/lib/syslinux/{com32,dosutil,syslinux.com}
  $sudo_cmd install -D -m644 COPYING "$_install_root"/usr/share/licenses/syslinux/COPYING
  $sudo_cmd install -d "$_install_root"/usr/share/doc
  $sudo_cmd cp -ar doc "$_install_root"/usr/share/doc/syslinux

  $sudo_cmd install -d "$_install_root"/usr/lib/syslinux/bios
  $sudo_cmd mv "$_install_root"/usr/lib/syslinux/{*.bin,*.c32,*.0,memdisk} \
               "$_install_root"/usr/lib/syslinux/bios

  $sudo_cmd install -D -m0755 ../syslinux-install_update \
                              "$_install_root"/usr/bin/syslinux-install_update

  if [ "x$INSTALL_TO_BOOT" = "xy" ] ; then
    sudo rm -rf /boot/efi/EFI/syslinux
    sudo mkdir -p /boot/efi/EFI/syslinux
    sudo cp -rf "$_install_root"/usr/lib/syslinux/efi64/* /boot/efi/EFI/syslinux
    if [ -f "$_top_dir"/syslinux.cfg ] ; then
      sudo cp -f "$_top_dir"/syslinux.cfg /boot/efi/EFI/syslinux
    fi
  fi

  if [ "x$INSTALL_WITH_SCRIPT" = "xy" ] ; then
    sudo syslinux-install_update -i -a -m
  fi
  if [ "x$INSTALL_SYNC" = "xy" ] ; then
    sync
  fi
}

if [ $# -eq 0 ]; then
  _clean
  _setup
  _build
  _install
else
  if [ $1 = '-h' ] || [ $1 = '--help' ]; then
    _help
  elif [ $1 = build ]; then
    _build ${@:2}
  elif [ $1 = install ]; then
    _install ${@:2}
  elif [ $1 = buildinstall ]; then
    _build ${@:2}
    _install ${@:2}
  else
    for _arg in $@; do
      _$_arg
    done
  fi
fi
