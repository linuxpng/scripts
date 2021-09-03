#!/bin/bash

# Create a TOTP token and read the secret using a QR code scanner, this will be <yoursecret>
# You can optionally stick this in cron or wrap it in a 'while do' loop if you want to keep it running in a tmux session like I do
# If your connection relies on a CA SSL certificate install that first with update-ca-certificates

token=$(oathtool --base32 --totp <yoursecret>)
pin=<yourpin>
user=<yourusername>
homedir="<directory with configuration files>"
vpnup=$(ip addr | grep tun0 | grep inet | awk '{print $2}')
config=<nameofconf>

if [ -z "$vpnup" ]
then
	echo $user > $homedir/pass.txt
	echo $pin$token >> $homedir/pass.txt
	sudo openvpn --client --config $homedir/$config --auth-user-pass $homedir/pass.txt --setenv PATH '/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin' --script-security 2 --up /etc/openvpn/update-resolv-conf --down /etc/openvpn/update-resolv-conf --down-pre
else
	:
fi

sleep 60
