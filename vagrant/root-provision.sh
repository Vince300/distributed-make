#!/bin/bash
# This file is a provisioning script that setups required software for this project to run on a x64 jessie system.

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

# Install required packages
apt-get update

if ! hash curl 2>/dev/null; then
  apt-get install -y curl
else
  echo "curl is already installed, skipping."
fi

if ! hash git 2>/dev/null; then
  apt-get install -y git
else
  echo "git is already installed, skipping."
fi

# Install RVM
if ! [[ -f /etc/profile.d/rvm.sh ]]; then
  curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  curl -sSL https://get.rvm.io | bash -s stable
else
  echo "rvm is already installed, skipping."
fi

# Activate RVM
if ! type rvm >/dev/null; then
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
if ! hash bundle; then
  gem install bundler
fi
