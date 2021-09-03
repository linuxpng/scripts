#!/bin/bash
# 07/26/2019 - Initial version
# Work in progress

rebootevents=$(for i in $(find . -type f -name sar* | grep -v xml); do grep RESTART $i | awk '{print $1,$2}' | tr '\n' ' '; echo $i;done | grep -v ^'./')
sarfilename=$(echo $rebootevents | awk '{print $NF}')
reboottime=$(echo $rebootevents | awk '{print $1,$2}')

echo 
echo
echo Reboot time:
echo ------------
echo $reboottime
echo
echo
echo Data being used:
echo ----------------
head -n1 $sarfilename | awk '{print $3,$4}'
echo
echo
echo Number of CPUs:
echo ---------------
head -n1 $sarfilename | awk '{print $(NF-1)}' | sed 's/(//g'
echo
echo
echo Load averages:
echo --------------
grep -m1 ldavg $sarfilename;sed -n -e '/ldavg/,/Average/ p' $sarfilename | grep -m 1 -B 10 Average 
echo
echo
echo Memory Usage:
echo -------------
grep -m1 mem $sarfilename;sed -n -e '/mem/,/Average/ p' $sarfilename | grep -m 1 -B 10 Average 
echo
echo
echo Swap Usage:
echo -----------
grep -m1 swpfree $sarfilename;sed -n -e '/swpfree/,/Average/ p' $sarfilename | grep -m 1 -B 10 Average
