#!/bin/bash
if [ "$#" -ne "1" ]; then
   echo ""
   echo -e "\033[01;32mLimit checker\033[00m"
   echo -e "\033[01;37mUsage:\033[01;33m $0 process_name\033[00m"
   echo ""
   exit 0
fi

return-limits(){
   for process in $@; do
      process_pids=`ps -C $process -o pid --no-headers | cut -d " " -f 2`

      if [ -z $@ ]; then
         echo "[no $process running]"
      else
         for pid in $process_pids; do
            echo "[$process #$pid -- limits]"
            cat /proc/$pid/limits
      done
      fi
   done
}

return-limits $1
