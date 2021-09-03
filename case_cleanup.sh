#/bin/bash

dirs=$( find /home/sbarcomb/cases -atime 14 -type d | awk -F '/' '{print $5}' | sort -u )
for i in $dirs;do sudo rm -rf /home/sbarcomb/cases"$i";done
