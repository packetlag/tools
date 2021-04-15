#!/bin/bash

## Sample usage:
## ./SearchingIPs.sh -i ipSearchWciv | awk '{print $2 " " $3}'

while getopts ":i:" opt; do
  case $opt in
    i)
      fileName=$OPTARG
      while read line 
      do
        logArray[$index]="$line"
        index=$(($index+1))
      done < $fileName

      for ((i = 0; i < ${index}; i++))
        {
          ping -c 1 ${logArray[i]} | grep PING
        }
      ;;
  esac
done
