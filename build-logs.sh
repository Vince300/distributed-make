#!/bin/bash

# Create the log directory
rm -rf log
mkdir -p log

# For each environment
for ENV_FILE in config/grid5000-*.yml; do
  # Get environment name
  ENV=$(basename "$ENV_FILE" .yml)
  echo "Computing statistics for $ENV..." >2

  # Clean working folders
  RAKE_ENV=$ENV rake examples:clean

  for FOLDER in spec/fixtures/*; do
    # Start daemons
    RAKE_ENV=$ENV rake daemon:start
    (cd $FOLDER && bundle exec distributed-make >log/$ENV-$(basename $FOLDER).log
    # Stop daemons
    RAKE_ENV=$ENV rake daemon:stop
  done
done

# Tar the logs
tar cJf "$(date '+%y-%m-%d-%H-%M-%S').tar.bz2" log
rm -rf log
