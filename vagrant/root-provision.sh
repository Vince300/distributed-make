#!/bin/bash
# This file is a provisioning script that setups required software for this project to run on a x64 jessie system.

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# List of packages to install
apt_required=""

# A function that installs requirements through apt-get
apt_get_require () {
  test_name="$1"; shift
  if [[ -z "$1" ]]; then
    apt_name="$test_name"
  else
    apt_name="$1"; shift
  fi

  if ! hash "$test_name" 2>/dev/null; then
    apt_required="$apt_required $apt_name"
  else
    echo "$apt_name is already installed, skipping."
  fi
}

apt_get_install () {
  # Only install packages if there are packages to install
  if [[ -n "$apt_required" ]]; then
    # Update before install
    apt-get update

    # Install packages
    apt-get install -y $apt_required
  fi
}

# Disable progress on curl
echo "-s
-S
" >~/.curlrc

if [[ -d ~vagrant ]]; then
  cp ~/.curlrc ~vagrant/.curlrc
  chown vagrant:vagrant ~vagrant/.curlrc
fi

# Install required packages

# First requirements
apt_get_require curl
apt_get_require git

# Requirements for various example Makefiles
apt_get_require convert ImageMagick
apt_get_require unzip
apt_get_require ffmpeg
apt_get_require bc

# Use gawk as the testing tool for ruby dependencies
apt_get_require gawk "gawk g++ libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev"

# Use mesa-utils as the testing tool for blender dependencies
apt_get_require glxinfo "libjpeg62-turbo libsdl1.2debian mesa-utils"

# Install all apt packages (saves reading the database multiple times)
apt_get_install

# Install RVM
if ! hash rvm 2>/dev/null; then
  curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  curl -sSL https://get.rvm.io | bash -s stable

  # Activate RVM
  if ! type rvm 2>/dev/null; then
    source /etc/profile.d/rvm.sh
  fi
else
  echo "rvm is already installed, skipping."

   # Activate RVM
   source /etc/profile.d/rvm.sh
fi

# Install Ruby 2.3.1
if ! rvm list default | grep "ruby-2.3.1" >/dev/null 2>/dev/null; then
  # Install Ruby
  rvm install 2.3.1

  # Use installed Ruby
  rvm use 2.3.1
fi

# Install Bundler
if ! hash bundle 2>/dev/null; then
  gem install bundler
fi

blender_install () {
  version="$1"; shift
  source_url="$1"; shift

  if ! hash blender-$version 2>/dev/null; then
    # Download tarball
    curl -sS -o /tmp/blender-$version.tar.bz2 "$source_url"

    # Extract Blender
    mkdir -p /opt/blender-$version
    tar -C /opt/blender-$version --strip-components 1 -xf /tmp/blender-$version.tar.bz2
    rm -f /opt/blender-$version.tar.bz2

    # Make link
    ln -s /opt/blender-$version/blender /usr/local/bin/blender-$version
  else
    echo "blender-$version is already installed, skipping."
  fi
}

# Install Blender 2.49
blender_install "2.49" "http://download.blender.org/release/Blender2.49/blender-2.49-linux-glibc236-py26-x86_64.tar.bz2"

# Install Blender 2.59
blender_install "2.59" "http://download.blender.org/release/Blender2.59/blender-2.59-linux-glibc27-x86_64.tar.bz2"

# Install "premier"
if ! hash premier 2>/dev/null; then
  echo "#include<stdio.h>
#include<stdlib.h>
#include<math.h>

int main(int argc, char **argv) {

	if (argc != 3) {
		fprintf(stderr, \"usage : %s début fin\\n\", argv[0]);
		exit(1);
	}

	int debut = atoi(argv[1]);
	int fin = atoi(argv[2]);
	int i;
	for(i = debut; i <= fin ; i++) {
		int j;
		char i_premier = 1;
		if (i % 2 == 0) {
			i_premier = 0;
		} else {
			for(j = 3 ; j < sqrt(i) ; j+=2) {
				if (i % j == 0) {
					i_premier = 0;
					break;
				}
			}
		}
		if (i_premier) printf(\"%d\\n\", i);
	}
	exit(0);
}
" >/tmp/premier.c

  gcc -o /usr/local/bin/premier -lm -O3 /tmp/premier.c
  echo "installed premier to /usr/local/bin/premier."
else
  echo "premier is already installed, skipping."
fi
