#!/bin/bash
# Supplementary steps for running distributed-make on g5k

# Fail if any command fail
set -eo pipefail

# This script must be run as root.
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" 1>&2
  exit 1
fi

if ! [[ -d "/home/dismake" ]]; then
  # Create dismake user
  useradd -m -s /bin/bash -G rvm dismake

  # Deploy the authorized_keys for SSH login
  cp -r /root/.ssh ~dismake/
fi

# Ensure we are running under the right RAKE_ENV
echo "export RAKE_ENV=grid5000" >~dismake/.bash_profile
echo "export RAKE_ENV=grid5000" >~dismake/.profile

# Fix permissions
chown -R dismake:dismake ~dismake