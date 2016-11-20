#!/usr/bin/env bash
for LOGDIR in $(find -type d -name "log-*" | sed 's/^\.\///'); do
  echo $LOGDIR
  cd $LOGDIR
  grep -R -P "completed in (.*)s" | sed 's/premier-small/premier_small/' | \
  sed 's/2.49-recurse/2.49_recurse/' | cut -d' ' -f1,13 | sed 's/:I, /-/' | \
  sed 's/s$//' | sed 's/.log//' | awk -F'-' '{print $3 ";" $2 ";" $4}' | \
  sed 's/\./,/g' | sort >../$LOGDIR.csv
  cd ..
done
