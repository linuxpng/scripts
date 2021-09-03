#!/bin/bash
# Steve Barcomb (sbarcomb@redhat.com)


hugepagesz=$(grep Hugepagesize proc/meminfo | awk '{print $2}')
hugepagenr=$(grep HugePages_Total proc/meminfo | awk '{print $2}')
hugepagegb=$(echo "scale=2;$hugepagesz*$hugepagenr/1024/1024" | bc)

mem=$(cat free|grep Mem|awk '{print $2}')
totmem=$(echo "$mem*1024"|bc)
huge=$(grep Hugepagesize proc/meminfo|awk '{print $2}')
max=$(echo "$totmem*75/100"|bc)
all=$(echo "$max/$huge"|bc)

tunedinstalled=$(grep tuned installed-rpms | wc -l)
rhelversion=$(cat uname | awk '{print $3}' | awk -F '.' '{print $1}')
rhel56check=$(cat etc/redhat-release | awk '{print $7}' | awk -F '.' '{print $1}')
thpcheck=$(grep -q transparent_hugepage proc/cmdline | wc -l)
filecheck=$(ls sys/kernel/mm/transparent_hugepage/enabled | wc -l)

syscheck=$(ls sys | grep block | wc -l)
cmdlinecheck=$(grep elevator proc/cmdline | wc -l)
elevator=$(grep elevator proc/cmdline | sed 's/^.*\(elevator.*\).*$/\1/' | awk '{print $1}' | awk -F "=" '{print $2}')

filedescriptors=$(grep oracle etc/security/limits.conf | grep hard | grep nofile)

if [ "$rhel56check" -eq "5" ]
then
	echo Transparent Huge Page detection:
	echo --------------------------------
	echo Red Hat Enterprise Linux 5 system, no THP

elif [ "$rhel56check" -eq "6" ] && [ "$thpcheck" -eq 0 ]
then
	echo Transparent Huge Page detection:
	echo --------------------------------
	echo Red Hat Enterprise Linux 6 system, THP enabled.

elif [ "$rhel56check" -eq "6" ] && [ "$thpcheck" -eq 1 ]
then
	echo Transparent Huge Page detection:
	echo --------------------------------
	echo Red Hat Enterprise Linux 6 system, THP disabled via kernel command line.

elif [ "$filecheck" -eq 0 ] && [ "$thpcheck" -eq 0 ]
then 
	echo Transparent Huge Page detection:
	echo --------------------------------
	echo Red Hat Enterprise Linux 7 system, THP enabled.

elif [ "$filecheck" -eq 0 ] && [ "$thpcheck" -eq 1 ]
then
        echo Transparent Huge Page detection:
        echo --------------------------------
        echo Red Hat Enterprise Linux 7 system, THP disabled via kernel command line.

else
	echo Transparent hugepages setting in /sys/kernel/mm/transparent_hugepage/enabled:
        echo -----------------------------------------------------------------------------
	cat sys/kernel/mm/transparent_hugepage/enabled | grep -Po '\[\K[^]]*'

fi

echo
echo
echo Printing i/o schedulers of block devices:
echo -----------------------------------------
if [ "$syscheck" -eq 0 ] && [ "$cmdlinecheck" -eq 0 ]
then 
	echo No elevator found on kernel command line.  Using CFQ.
elif [ "$syscheck" -eq 0 ] && [ "$cmdlinecheck" -eq 1 ]
then
	echo Elevator $elevator found on kernel command line.
else
	for i in sys/block/*; do cat $i/queue/scheduler | grep -Po '\[\K[^]]*' | tr '\n' ' '; echo $i; done | grep -v ^sys | sed s/sys//g | sed s/block//g | sed 's/\///g' | awk '{print $1}' | uniq -c | sed -e 's/^[ \t]*//'
fi

echo
echo
echo Number of allocated hugepages:
echo ------------------------------
echo $hugepagenr
echo
echo
echo Total hugepage allocation:
echo --------------------------
echo $hugepagegb GiB,  hugepages are $hugepagesz KiB in size
echo
echo
echo Swappiness value of 1-10 is recommended:
echo ----------------------------------------
echo "$(grep swappiness ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Dirty ratio value of 15 for large memory systems is recommended:
echo ----------------------------------------------------------------
echo "$(grep dirty_ratio ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Dirty background ratio value should be 3:
echo ----------------------------------------
echo "$(grep dirty_background_ratio ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Dirty writeback centisecs value should be 100:
echo ----------------------------------------------
echo "$(grep dirty_writeback_centisecs ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Dirty expire centisecs value should be 500:
echo -------------------------------------------
echo "$(grep dirty_expire_centisecs ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Shmax value based on sosreport:
echo -------------------------------
echo $max
echo
echo
echo Shmall value based on sosreport:
echo --------------------------------
echo $all
echo
echo
echo Shmmni value should be 4096:
echo --------------------------------
echo "$(grep kernel.shmmni ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Semaphore values should be "250 32000 100 128":
echo ---------------------------------------------
echo "$(grep -w kernel.sem ./sos_commands/kernel/sysctl_-a)"
echo
echo
echo Checking open file descriptors for the Oracle user:
echo ---------------------------------------------------
if [ -z "$filedescriptors" ]
then
	echo Oracle user not found in limits.conf
else
	echo $filedescriptors
fi
echo
echo
echo Checking the GID value for hugetlb_shm_group.  This should correspond to the GID of the Oracle user:
echo ----------------------------------------------------------------------------------------------------
grep vm.hugetlb_shm_group ./sos_commands/kernel/sysctl_-a | awk '{print $3}'
echo
echo
echo Tuned status:
echo -------------
if [ "$tunedinstalled" -eq 0 ]
then
	echo Tuned is not installed
else 
	if [ "$rhelversion" -eq "3" ]
	then
		grep tuned ./sos_commands/systemd/systemctl_list-units | grep -v ksmtuned | awk '{print $2,$3,$4}'
	elif [ "$rhelversion" -eq "2" ]
	then
		grep tuned chkconfig
	else
		echo tuned information not found in sosreport, manually verify
	fi
fi
