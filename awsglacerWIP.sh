#!/bin/bash 

## This script is designed to find pixelator/skyfall log files, upload them to their respective AWS Glacier
## vaults, update a corresponding SimpleDB domain instance, validate treehash of vault archive vs. local log
## .gz, and remove local .gz log files once confirmed.

## Future needs:
## -Logic to identify which SAN and in which Data Center it's being run on and adjust dir paths.
## -Logic to remove X year old AWS Glacier archive vaults.

# Print timestamp of initiation, set controls incase you want to test the script as a dry run.
date
FIRE_UPLOAD="no"
FIRE_DELETE="no"

# Validate that enough arguments were given

if (($# == 0)); then
   printf "\n""You are missing the age of archive you wish to target (-a <arg>), the Geo location (-g <arg>), and log path version (-v <arg>).""\n""Try using -h for help. ""\n\n"
   exit 1
elif (($# >=2 && $# <= 5)); then
   printf "\n""You may be missing one or more aguments.""\n""Try using -h for help.""\n\n"
   exit 1
elif (($# >= 7)); then
   printf "\n""You have too many arguments.""\n""Try using -h for help.""\n\n"
   exit 1
fi

# Evaluate arguments passed to script
while getopts ":a:d:v:t:h" opt; do
  case $opt in
    h)
      printf "\n""This tool is for uploading Skyfall logs to AWS Glacier.""\n\n"
      printf "Usage #1: $ ./glacier-automation.sh -a <# of days old logs> -d <DC location> -v <Version of log location>""\n"
      printf "Usage #2: $ ./glacier-automation.sh -t <specific target date of logs> -d <DC location> -v <Version of log location>""\n\n"
      printf "Age of logs to upload in days:""\n""  30""\n""  1""\n""  etc""\n\n"
      printf "Datacenter locations:""\n""  iad""\n""  lax""\n\n"
      printf "Versions of logs:""\n""  V4 - /san/link/<DC>/skyfall-logs-kafka/skyfall/year/month/day""\n"
      printf "  V3 - /san/link/<DC>/redir-logs-kafka/pixelator-extra/year/month/day""\n"
      printf "  V2 - /san/link/<DC>/redir-logs-kafka/pixelator_all/year/month/day""\n"
      printf "  V2a - (for Xsf02's large backup volume) - /san/link/old-<DC>/redir-logs-kafka/pixelator-extra/year/month/day""\n"
      printf "  V1 - /san/link/<DC>/redir-logs/year/month/day""\n\n"
      exit 0
      ;;

    a)
      test $TARGET_DATE; USING_T=$?
      if [[ $USING_T -eq 0 ]]; then
        printf "\n""You can't use both -a and -t. Either hunt for logs that are X days old OR tell me exactly what you want to be uploaded""\n"
        exit 1       
      else
      ARCHIVE_AGE=$OPTARG
      printf "\n""Find stuff $ARCHIVE_AGE day(s) old to upload""\n"      
      fi
      ;;

    t)
      test $ARCHIVE_AGE; USING_A=$?
      if [[ $USING_A -eq 0 ]]; then
        printf "\n""You can't use both -a and -t. Either hunt for logs that are X days old or tell me exactly what you want to be uploaded""\n"
        exit 1
      else
        TARGET_DATE=$OPTARG
        printf "\n""Find stuff from this specific date: $TARGET_DATE""\n"
      fi  
      ;;

    d)
      if [[ $OPTARG == "iad" || $OPTARG == "lax" ]]; then
        GEO_LOCATION=$OPTARG
        printf "\n""Geograhic source:  $GEO_LOCATION""\n"
      else
        printf "WRONG STUFF""\n"
        printf "You need to input 'iad' or 'lax' as the argument for -d""\n"
        exit 1
      fi
      ;;

    v)
      if [[ $OPTARG == "V4" || $OPTARG == "V3" || $OPTARG == "V2" || $OPTARG == "V2a" || $OPTARG == "V1" ]]; then
        LOG_VERSION=$OPTARG
        printf "\n""Log version:  $LOG_VERSION""\n"

        if [[ $LOG_VERSION == "V4" ]]; then
          LOG_PATH="/san/link/$GEO_LOCATION/skyfall-logs-kafka/skyfall/"
          VAULT_DATE=`find -L "$LOG_PATH" -iname "*skyfall*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7$8$9 }' | head -1`
          VAULT_TARGET=`find -L "$LOG_PATH" -iname "*skyfall*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7"/"$8"/"$9"/" }' | head -1`
          printf "Log path:  ""$LOG_PATH""\n\n"

        elif [[ $LOG_VERSION == "V3" ]]; then
          LOG_PATH="/san/link/$GEO_LOCATION/redir-logs-kafka/pixelator-extra/"
          VAULT_DATE=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7$8$9 }' | head -1`
          VAULT_TARGET=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7"/"$8"/"$9"/" }' | head -1`
          printf "Log path:  ""$LOG_PATH""\n\n"

        elif [[ $LOG_VERSION == "V2" ]]; then
          LOG_PATH="/san/link/$GEO_LOCATION/redir-logs-kafka/pixelator_all/"
          VAULT_DATE=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7$8$9 }' | head -1`
          VAULT_TARGET=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7"/"$8"/"$9"/" }' | head -1`
          printf "Log path:  ""$LOG_PATH""\n\n"

        elif [[ $LOG_VERSION == "V2a" ]]; then
          LOG_PATH="/san/link/old-$GEO_LOCATION/redir-logs-kafka/pixelator_all/"
          VAULT_DATE=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7$8$9 }' | head -1`
          VAULT_TARGET=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $7"/"$8"/"$9"/" }' | head -1`
          printf "Log path:  ""$LOG_PATH""\n\n"

        elif [[ $LOG_VERSION == "V1" ]]; then
          LOG_PATH="/san/link/$GEO_LOCATION/redir-logs/"
          VAULT_DATE=`find -L "$LOG_PATH" -iname "*redirector*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $6$7$8 }' | head -1`
          VAULT_TARGET=`find -L "$LOG_PATH" -iname "*redirector*" -mtime "$ARCHIVE_AGE" | awk -F"/" '{ print $6"/"$7"/"$8"/" }' | head -1`
          printf "Log path:  ""$LOG_PATH""\n\n"

        fi

      else
        printf "WRONG STUFF""\n"
        printf "You need to input 'V4', 'V3', 'V2', 'V2a'  or 'V1', capitalized, as the argument for -v""\n"
        exit 1
      fi
      ;;

    \?)
      printf "Invalid option: -$OPTARG""\n""Try using -h for help.""\n"
      exit 1
      ;;

    :)
      printf "Option -$OPTARG requires an argument.""\n""Try using -h for help.""\n"
      exit 1
      ;;

  esac
done


# Where am I stuff for future needs?
BOX_NAME=`hostname | awk -F"." '{ print $1 }'`
#printf $BOX_NAME


#VAULT_DATE=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime 30 | awk -F"/" '{ print $7$8$9 }' | head -1`
#VAULT_TARGET=`find -L "$LOG_PATH" -iname "*pixelator*" -mtime 30 | awk -F"/" '{ print $7"/"$8"/"$9"/" }' | head -1`


# This confirms that something was actually found.
test $VAULT_DATE; FOUND_ANYTHING=$?
if [[ $FOUND_ANYTHING -eq 1 ]]; then
  printf "Found no files to upload! Try a different age or version of logs. Try -h for options.""\n"
  exit 1
else
  printf $VAULT_DATE"\n"
  printf $VAULT_TARGET"\n"
  VAULT_NAME="$VAULT_DATE""-pixelator-""$LOG_VERSION""-""$GEO_LOCATION"
  printf $VAULT_NAME"\n\n"
  FULL_PATH=$LOG_PATH$VAULT_TARGET
  printf $FULL_PATH
  printf "\n"
fi

sudo glacier-cmd mkvault $VAULT_NAME
sleep 15

## Fire off glacier upload
# printf "sudo glacier-cmd --bookkeeping-domain-name=""$VAULT_NAME"" upload --partsize 32 ""$VAULT_NAME"" ""$LOG_PATH$VAULT_TARGET""* > /home/csadmin/glacier-logs/""$VAULT_NAME""\n\n"
#if [[ $FIRE_UPLOAD = "yes" || $FIRE_UPLOAD = "YES" || $FIRE_UPLOAD = "y" || $FIRE_UPLOAD = "Yes" ]]; then
#  sudo glacier-cmd mkvault $VAULT_NAME
#  sleep 15
#  sudo glacier-cmd --bookkeeping-domain-name=$VAULT_NAME upload --partsize 1 $VAULT_NAME "$FULL_PATH*" > /home/csadmin/glacier-logs/$VAULT_NAME
#else
#  printf "\n""sudo glacier-cmd --bookkeeping-domain-name=$VAULT_NAME upload --partsize 1 $VAULT_NAME "$FULL_PATH*" > /home/csadmin/glacier-logs/$VAULT_NAME""\n"
#  printf "\n""This was a dry run, change FIRE_UPLOAD to 'yes' to execute for real""\n"
#  exit 0
#fi

sudo glacier-cmd --bookkeeping-domain-name=$VAULT_NAME upload --partsize 1 $VAULT_NAME "$FULL_PATH*" > /home/csadmin/glacier-logs/$VAULT_NAME

## Confirm Stuff uploaded properly
# LOCAL_TREEHASH=`sudo glacier-cmd treehash $LOG_PATH$VAULT_DATE/firstfile | awk $3
# VLAUT_TREEHASH=`awk first link of /home/csadmin/glacier-logs/$VAULT_NAME
# if LOCAL_TREEHASH = VAULT, delete /$LOG_PATH$VAULT_DATE/*; else EMAIL YO CAN'T DELETE $VAULT_DATE
#printf "Checking if uploades were valid""\n"
#printf "sudo glacier-cmd treehash ""$LOG_PATH$VAULT_TARGET""pixelator.00-log.000.gzi""\n""diff local_treehash with line 2 of glacier-logs/""$VAULT_NAME"" output""\n\n"
