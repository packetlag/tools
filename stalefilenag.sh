##/bin/bash
#Init lockfile
lockfile=
#Hunts for stale lock file
lockfile=`find /home/hydra/scripts/dex-data-rsync/ -iname *.lock -mmin +540`
#Numerizes result
test $lockfile; bitflip=$?

if [[ $bitflip -eq 1 ]]; then
  exit 0
else
  exit 1
fi
