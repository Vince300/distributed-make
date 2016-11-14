#!/bin/bash
# Supplementary steps for running distributed-make on g5k

# Fail if any command fail
set -eo pipefail

FIRST=1
while read -r MACHINE; do
  ssh root@$MACHINE 'bash -s' < 'root-provision.sh'
  ssh root@$MACHINE 'bash -s' < 'g5k-provision.sh'

  if [[ $FIRST -gt 0 ]]; then
    scp ~/.ssh/id_rsa dismake@$MACHINE:~/.ssh/
    scp -r ../../distributed-make dismake@$MACHINE:~/distributed-make-src
    FIRST=0
  fi
done