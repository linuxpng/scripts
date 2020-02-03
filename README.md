# Some work scripts
* case_cleanup.sh - A simple script to delete old customer data
* getcase2 - Grabs attachments from the portal bypassing tokenization from AWS
* getcase3 - Grabs attachments from the portal and uses aria2 for parallel downloads and multiple connections per download
* kdump-checker - Prints out information related to a customer's kdump configuration
* oracle-checker - Looks at values and makes suggestions based upon our tuning guide
* rca - The base script that will call kdump-checker and sar-checker
* sar-checker - This will report sysstat data around the time of the last reboot, eventually
* sar4 - The sar binary for converting RHEL4 sysstat data
* sar5 - RHEL 5 sysstat binary
* sar65 - RHEL 6 sysstat binary
* sar71 - RHEL 7 sysstat binary
* sar -A -t -f sa01 > sar01
* saucetool.py from Sterling will compare a "good" and "bad" sosreport for differences
