#!/bin/bash
# Kdump configuration reporting script by Steve Barcomb (sbarcomb@redhat.com)



echo Kdump version:
echo --------------
echo $ grep kexec installed-rpms 
grep kexec installed-rpms | awk '{print $1}'
echo
echo

echo Checking for saved vmcore-dmesg.txt:
echo ------------------------------------
vmcore=$(find . -name vmcore*dmesg.txt 2>/dev/null)
if [ -z "$vmcore" ]
then
        echo No vmcore data found.
	echo
	echo
else
	for i in $vmcore;do echo $i;done
	echo
	echo
fi


echo Checking to see if the kdump service is running:
echo ------------------------------------------------

if [ ! -f sos_commands/systemd/systemctl_list-units ] 
then
	grep kdump chkconfig

else
	grep kdump ./sos_commands/systemd/systemctl_list-units | awk '{print $2,$3,$4}'
fi

echo
echo
echo Printing /etc/kdump.conf:
echo -------------------------
echo '$ grep -v ^# etc/kdump.conf | grep -v ^$'
grep -v ^# etc/kdump.conf | grep -v ^$
echo
echo

if [ ! -f proc/iomem ] 
then 
	echo Crashkernel reservation from /proc/cmdline:
	echo -------------------------------------------
	cat proc/cmdline
	echo
	echo
else
	reservation_count=$(grep -i crash proc/iomem | wc -l)
        if [ $reservation_count -eq 0 ]
        then
		echo Crashkernel reservation:
		echo ------------------------
                echo No crashkernel reservation found
		echo
		echo
	elif [ $reservation_count -eq 1 ]
	then
		BIGGER=$(grep -i crash proc/iomem | awk -F '-' '{print $2}' | sed 's/\ \:\ Crash\ kernel//g'| tr /a-z/ /A-Z/)
		SMALLER=$(grep -i crash proc/iomem | awk -F '-' '{print $1}' | sed 's/\ //g'| tr /a-z/ /A-Z/)
		echo Crashkernel reservation:
		echo ------------------------	
		SIZE=$(echo "ibase=16;$BIGGER - $SMALLER"|bc)
		VALUE=$(echo $SIZE/1024/1024|bc)
		echo The crashkernel value from /proc/iomem is $VALUE MiB
		echo
		echo
	else
		BIGGER1=$(grep -i crash proc/iomem | head -n1 | awk -F '-' '{print $2}' | sed 's/\ \:\ Crash\ kernel//g'| tr /a-z/ /A-Z/)
		SMALLER1=$(grep -i crash proc/iomem | head -n1 | awk -F '-' '{print $1}' | sed 's/\ //g'| tr /a-z/ /A-Z/)
		BIGGER2=$(grep -i crash proc/iomem | tail -n1 | awk -F '-' '{print $2}' | sed 's/\ \:\ Crash\ kernel//g'| tr /a-z/ /A-Z/)
		SMALLER2=$(grep -i crash proc/iomem | tail -n1 | awk -F '-' '{print $1}' | sed 's/\ //g'| tr /a-z/ /A-Z/)
		SIZE1=$(echo "ibase=16;$BIGGER1 - $SMALLER1"|bc)
		SIZE2=$(echo "ibase=16;$BIGGER2 - $SMALLER2"|bc)
		VALUE1=$(echo $SIZE1/1024/1024|bc)
		VALUE2=$(echo $SIZE2/1024/1024|bc)
		TVALUE=$[$VALUE1+$VALUE2]
		echo Crashkernel reservation:
		echo ------------------------
		echo The crashkernel has two reservations and the value from /proc/iomem is $TVALUE MiB
		echo
		echo
	fi
fi

memtotalkb=$(grep MemTotal proc/meminfo | awk '{print $2}')
memtotalgb=$(echo "scale=2;$memtotalkb/1024/1024" | bc)
echo Total memory on the system:
echo ---------------------------
echo $memtotalgb GiB
echo
echo

nettarget=$(grep -e nfs -e net -e ssh etc/kdump.conf | grep -v sshkey | grep -v ^#) 
uuidtarget=$(grep UUID etc/kdump.conf | grep -v ^# |awk '{print $2}' | awk -F "=" '{print $2}')
devicetarget=$(grep -e ext4 -e xfs etc/kdump.conf | grep '/' | grep -v ^# | awk '{print $2}' | awk -F"/" '{print $NF}')
pathtarget=$(grep path etc/kdump.conf | grep -v ^# | awk '{print $2}')
dfexists=$(ls | grep df | wc -l)

if [[ $nettarget ]] && [ "$dfexists" -ne 0 ]
then 
	echo Dump target size:
	echo -----------------
	echo Remote dump target, please check this manually 

elif [[ $uuidtarget ]] && [ "$dfexists" -ne 0 ]
then uuidfs=$(grep $uuidtarget ./sos_commands/block/blkid* | awk '{print $1}'| tr -d ':') 	
	uuidfszkb=$(grep $uuidfs df | awk '{print $4}')
	uuidfszgb=$(echo "scale=2;$uuidfszkb"/1024/1024 | bc)
	echo Dump target size:
	echo -----------------
	echo $uuidfszgb GiB
	if [ $memtotalkb -gt $uuidfszkb ]
	then
		echo
		echo
		echo *WARNING* dump target may not be sufficiently sized
	else
		:
	fi
elif [[ $devicetarget ]]  && [ "$dfexists" -ne 0 ]
# this is a hack for device mapper names where df output spans 2 lines
then devicefszkb=$(grep -A1 $devicetarget df | tr '\n' ' '| awk '{print $4}')
	devicefszgb=$(echo "scale=2;$devicefszkb"/1024/1024 | bc)
        echo Dump target size:
        echo -----------------
        echo $devicefszgb GiB	
        if [ $memtotalkb -gt $devicefszkb ]
        then
                echo
                echo
                echo *WARNING* dump target may not be sufficiently sized
        else
                :
        fi
elif [[ $pathtarget ]] && [ "$dfexists" -ne 0 ]
then paths=$(echo "$pathtarget" | sed 's/\// /g' | awk '{for(i=NF;i>=1;i--) printf "%s ", $i;print ""}')
	j=0
	for i in $paths
	do
		number=$(grep "$i"$ df | awk '{print $(NF)}' | grep -v ^'/sys' | grep -v ^'/var/lib' | wc -l)
		if [ $number -ne 0 ]
		then	
			if [ $number -ne 0 ] && [ $j -eq 0 ]
			then
				dir=$(grep $i df | grep -v '^/dev' | awk '{print $(NF)}')
				break
			else
				dir=$i
				break
			fi
		else 
			dir="root"
			let "j=j+1"

		fi
	done
	if [ $dir = root ]
	then
        	pathszkb=$(cat df | grep -v rootfs | awk '{print $6, $4}' | grep ^/[[:space:]] | awk '{print $2}')
        	pathszgb=$(echo "scale=2;$pathszkb"/1024/1024 | bc)
        	echo Dump target size:
        	echo -----------------
	        echo $pathszgb GiB
		if [ $memtotalkb -gt $pathszkb ]
		then
			echo
			echo
			echo *WARNING* dump target may not be sufficiently sized
		else
			:
		fi
	else
		pathszkb=$(grep "$dir"$ df | awk '{print $(NF-2)}')
		pathszgb=$(echo "scale=2;$pathszkb"/1024/1024 | bc)
		echo Dump target size:
		echo -----------------
		echo $pathszgb GiB
	                if [ $memtotalkb -gt $pathszkb ]
	                then
	                        echo
  				echo
				echo *WARNING* dump target may not be sufficiently sized
			else
				:
			fi
fi
else
	echo Dump target size:
	echo -----------------
	echo Either the dump target is not local or not found in the sosreport	
fi
echo
echo
echo NMI Panic Tunables:
echo -------------------
grep panic ./sos_commands/kernel/sysctl_-a  | grep nmi
echo
echo
hpwdt=$(grep hpwdt lsmod)
if [ -z "$hpwdt" ]
then
	:
else
	echo HP system found, checking for hpwdt module:
	echo -------------------------------------------
	echo hpwdt module loaded
	echo
	echo
fi
echo The rest of the panic tunables:
echo -------------------------------
grep panic ./sos_commands/kernel/sysctl_-a | grep -v nmi
echo
echo
echo Is the sysrq keybind enabled?  Do not use this for kdump:
echo ---------------------------------------------------------
grep sysrq ./sos_commands/kernel/sysctl_-a
echo
echo
echo Generating a blacklist for third party modules:
echo -----------------------------------------------
modulesexists=$(ls proc | grep modules | wc -l)
if [ $modulesexists -eq 0 ]
then 
	echo "/proc/modules not found in sosreport"
else
	blacklist=$(grep $')' proc/modules | awk '{print $1}'| tr '\n' ' ')
	if [ -z "$blacklist" ]
	then
		echo "No third party modules found in /proc/modules"
	else 
	echo $blacklist
	fi
fi
echo
echo

if grep --quiet cciss lsmod;
then
	echo 'CCISS firmware version:'
	echo '---------------------'
	cciss=$(grep -s -i version proc/driver/cciss/cciss0)
	if [ -z "$cciss" ]
	then	
		echo CCISS module loaded, but unable to determine firmware version
		echo
		echo
	else
		echo CCISS Version $cciss
		echo
		echo
	fi
else
	:
fi

if grep --quiet hpsa lsmod;
then
	echo 'HPSA firmware version:'
	echo '----------------------'
	hpsa=$(grep -s scsi ./sos_commands/kernel/dmesg | grep RAID | grep HP | sed -e 's/\[[^][]*\]//g' | grep -v hpsa | sed -e s/scsi//g | sed -e s/RAID//g | awk '{print $2,$3,"Firmware Version",$4}')
	if [ -z "$hpsa" ]
	then 
		echo HPSA module loaded, but unable to determine firmware version
		echo
		echo
	else
		echo $hpsa
		echo
		echo
	fi
else
	:
fi



