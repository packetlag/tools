##/bin/bash
#Init symlink basket
basket=
#Hunts for broken symlinks
basket=`find /san/link/ -type l -xtype l`
#Numerizes result
test $basket; bitflip=$?

if [[ $bitflip -eq 1 ]]; then
  exit 0
else
  exit 1
fi
