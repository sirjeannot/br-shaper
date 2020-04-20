#!/bin/ash

############################################
# Trafic shaper v4 TESTING                 #
# features : shaping per subnet and per IP #
#          2018/03/22                      #
############################################
# tc -s -d class show dev eth0

#binaries location
TC=/usr/sbin/tc
EBTABLES=/usr/sbin/ebtables
UCI=/sbin/uci

#interface connected to LAN
IFOUT=eth0
#interface connected to Internet
IFIN=eth2
#linespeed for line, in Kbps
LINESPEED=36000
#guaranteed bandwidth per building
GUAR=32000
#burst for each building, in Kbps
BURST=32000
#burst for each IP, in Kbps
BURST_IP=500
#ip ranges for total blocks
VPN_IP="141.227.0.0/16 146.249.0.0/16"
#ranges for buildings
RANGES="192.168.0.0/24 192.168.101.0/24 192.168.102.0/24 192.168.104.0/24 192.168.105.0/24 192.168.107.0/24 192.168.108.0/24 192.168.116.0/24 192.168.117.0/24 192.168.118.0/24 192.168.119.0/24 192.168.120.0/24"
#RANGES="192.168.0.0/24"

#environment variables
IP_ADMIN= $UCI get network.ADMIN.ipaddr
IP_BRIDGE= $UCI get network.lan.ipaddr

#computed values based on configuration
#add two ranges for default and admin purposes
NBRANGE=0
for RANGE in $RANGES
do
        NBRANGE=$(( $NBRANGE + 1 ))
done
#guaranteed bandwidth
GUAR=$(( $LINESPEED / $NBRANGE ))
GUAR_IP=$(( $GUAR / 8 ))

#config file
#source /root/shaper/shaper.conf

#print current config
echo "Current config"
echo " > line speed          : ${LINESPEED}Kbps"
echo " > guaranteed building : ${GUAR}Kbps"
echo " > burst building      : ${BURST}Kbps"
echo " > guaranteed client   : ${GUAR_IP}Kbps"
echo " > burst               : ${BURST_IP}Kbps"

#wipe previous config if any
echo "wiping previous configuration"
$TC qdisc del dev ${IFOUT} root
$TC qdisc del dev ${IFIN} root
$EBTABLES -F
$EBTABLES -X

#configure queueing
echo "setting up queues"

#create classes and brouting rules
#prio : lower value means higher priority
#create queues on interface and default class
$TC qdisc add dev ${IFIN} root handle 1: htb default 100
$TC class add dev ${IFIN} parent 1: classid 1:0 htb rate ${LINESPEED}Kbit ceil ${LINESPEED}Kbit
$TC class add dev ${IFIN} parent 1:0 classid 1:100 htb rate 1Kbit ceil ${LINESPEED}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 100 fw flowid 1:100

$TC qdisc add dev ${IFOUT} root handle 2: htb default 5100
$TC class add dev ${IFOUT} parent 2: classid 2:0 htb rate ${LINESPEED}Kbit ceil ${LINESPEED}Kbit
$TC class add dev ${IFOUT} parent 2:0 classid 2:5100 htb rate 1Kbit ceil ${LINESPEED}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 5100 fw flowid 2:5100

#loop for each subnet
I=100
for SUBNET in $RANGES
do
	$EBTABLES -N ${SUBNET}
	$EBTABLES -A FORWARD -i ${IFIN} -p IPV4 --ip-source ${SUBNET} -j ${SUBNET}
	$EBTABLES -A FORWARD -i ${IFOUT} -p IPV4 --ip-destination ${SUBNET} -j ${SUBNET}


        I=$(( $I + 100 ))
	J=$(( $I + 5000 ))
	$TC class add dev ${IFIN} parent 1:0 classid 1:${I} htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
	$TC filter add dev ${IFIN} parent 1: protocol ip handle ${I} fw flowid 1:${I}
	$EBTABLES -A ${SUBNET} -i ${IFIN} -p IPV4 --ip-source ${SUBNET} -j mark --set-mark ${J} --mark-target ACCEPT
	$TC class add dev ${IFOUT} parent 2:0 classid 2:${J} htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
	$TC filter add dev ${IFOUT} parent 2: protocol ip handle ${J} fw flowid 2:${J}
	$EBTABLES -A ${SUBNET} -i ${IFOUT} -p IPV4 --ip-destination ${SUBNET} -j mark --set-mark ${I} --mark-target ACCEPT

	#loop for each IP
	K=$I
	L=$J
	for HOST in `seq 1 9`
	do
		SUB=`echo $SUBNET | cut -d'.' -f1-3`
		IP=`echo "${SUB}.${HOST}"`
		K=$(( $K + 1 ))
		L=$(( $L + 1 ))
		$TC class add dev ${IFIN} parent 1:${I} classid 1:${K} htb rate ${GUAR_IP}Kbit ceil ${BURST_IP}Kbit prio 4
		$TC filter add dev ${IFIN} parent 1: protocol ip handle ${K} fw flowid 1:${K}
		$EBTABLES -I ${SUBNET} -2 -i ${IFIN} -p IPV4 --ip-source ${IP} -j mark --set-mark ${L} --mark-target ACCEPT
	        $TC class add dev ${IFOUT} parent 2:${J} classid 2:${L} htb rate ${GUAR_IP}Kbit ceil ${BURST_IP}Kbit prio 4
		$TC filter add dev ${IFOUT} parent 2: protocol ip handle ${L} fw flowid 2:${L}
		$EBTABLES -I ${SUBNET} -2 -i ${IFOUT} -p IPV4 --ip-destination ${IP} -j mark --set-mark ${K} --mark-target ACCEPT
	done
	echo "subnet ${SUBNET} configured"
done

echo "done"
