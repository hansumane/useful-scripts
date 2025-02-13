#!/bin/sh
set -e

VIM_PREFIX="/usr/local"
VIM_REPO="https://github.com/vim/vim.git"
VIM_GIT_BRANCH=$(git -c 'versionsort.suffix=-' ls-remote --tags \
                 --sort='v:refname' "$VIM_REPO" | tail -n1 \
                 | cut -d'/' -f3 | cut -d'^' -f1)
VIM_FOLDER="vim-$VIM_GIT_BRANCH"
VIM_ARCHIVE="$VIM_FOLDER.cpio.xz"

CFLAGS="-s -O3 -DSYS_VIMRC_FILE=\\\"/etc/vim/vimrc\\\""
CFGFLAGS="--prefix=$VIM_PREFIX \
          --with-features=small \
          --disable-gui \
          --disable-xsmp \
          --disable-xsmp-interact \
          --disable-netbeans \
          --disable-gpm \
          --enable-nls \
          --enable-acl \
          --disable-terminal \
          --disable-canberra \
          --disable-libsodium"

_get () {
  if [ ! -d "$VIM_FOLDER" ] ; then
    if [ -f "$VIM_ARCHIVE" ] ; then
      xzcat "$VIM_ARCHIVE" | cpio -i
    else
      git clone --depth=1 --recursive \
        --branch="$VIM_GIT_BRANCH" "$VIM_REPO" "$VIM_FOLDER"
      cd "$VIM_FOLDER"
      rm -rf .git
      cd -
      find "$VIM_FOLDER" -print0 | cpio -0oHnewc \
        | xz -ze9T$(getconf _NPROCESSORS_ONLN) > "$VIM_ARCHIVE"
    fi
  fi
}

_build () {
  cd "$VIM_FOLDER"
  CFLAGS="$CFLAGS" ./configure $CFGFLAGS
  make
  touch "_built"
  cd -
}

_install () {
  cd "$VIM_FOLDER"
  sudo make install
  if [ ! -f "$VIM_PREFIX/bin/vi" ] ; then
    sudo ln -srf "$VIM_PREFIX/bin/vim" "$VIM_PREFIX/bin/vi"
  fi
  cd -
}

_get
if [ ! -f "$VIM_FOLDER/_built" ] ; then _build ; fi
if [ "$1" = "install" ] ; then _install ; fi
