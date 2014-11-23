#!/bin/bash

# Backs up seed file. Can be later used for cleanup if desired.
cp /home/user/scripts/migratedata/logs.out /home/user/scripts/migratedata/logs-yesterday.out

# Finds all files meeting search criteria, dumps into file. Lower the -mtime +# to increase how much data is found and moved.
find -L /file/path -iname "*uniq-string*" -mtime +185 > /home/user/scripts/migratedata/logs.out

# Trims out trailing file names, leaving only unique directories and cleans up a
# weird $1 artifact where it mangles the first line. It doesn't like the field
# seperator being "/" when awk looks at the first line.
awk '{ FS="/" } { print "/" $2 "/" $3 "/" $4 "/" $5 "/" $6 "/" $7 "/" $8 "/"}' /home/user/scripts/migratedata/logs.out | uniq | grep "/file/path" > /home/user/scripts/migratedata/logstrim.out

# Iterates through "dir only" file, pops into array
while read line 
do
  logArray[$index]="$line"
  index=$(($index+1))
done < "/home/user/scripts/migratedata/logstrim.out"

# Marches down the array rsync dir after dir.
for ((i = 0; i < ${index}; i++))
  {
  rsync -avuKL ${logArray[i]} host_name:${logArray[i]};
  }

# Drops completion timestamp
rm -f /home/user/scripts/migratedata/lastcompleted-*
export DATE=`date +%Y%m%d`
touch /home/user/scripts/migratedata/lastcompleted-$DATE
