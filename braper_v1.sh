#!/bin/ash

#####################################
# initial version, for testing only #
# Y. FLEGEAU 2018/02                #
#####################################


#binaries location
TC=/usr/sbin/tc
EBTABLES=/usr/sbin/ebtables
UCI=/sbin/uci

#interface connected to LAN
IFOUT=eth0
#interface connected to Internet
IFIN=eth2
#linespeed for line, in Kbps
LINESPEED=10000
#guaranteed bandwidth per building
GUAR=1000
#burst for each building, in Kbps
BURST=9000
#ip ranges for total blocks
VPN_IP="141.227.0.0/16 146.249.0.0/16"

#environment variables
IP_ADMIN= $UCI get network.ADMIN.ipaddr
IP_BRIDGE= $UCI get network.lan.ipaddr

#config file
#source /root/shaper/shaper.conf

#print current config
echo "Current config"
echo " > line speed : ${LINESPEED}Kbps"
echo " > guaranteed : ${GUAR}Kbps"
echo " > burst      : ${BURST}Kbps"

#wipe previous config if any
echo "wiping previous configuration"
$TC qdisc del dev ${IFOUT} root
$TC qdisc del dev ${IFIN} root
$EBTABLES -F
$EBTABLES -X

#configure queueing
echo "setting up queues"
#prio : lower value means higher priority
$TC qdisc add dev ${IFIN} root handle 1: htb default 100
$TC class add dev ${IFIN} parent 1: classid 1:0 htb rate ${LINESPEED}Kbit ceil ${LINESPEED}Kbit
$TC class add dev ${IFIN} parent 1:0 classid 1:100 htb rate 1Kbit ceil ${LINESPEED}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 100 fw flowid 1:101

$TC class add dev ${IFIN} parent 1:0 classid 1:101 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 101 fw flowid 1:101
$TC class add dev ${IFIN} parent 1:0 classid 1:102 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 102 fw flowid 1:102
$TC class add dev ${IFIN} parent 1:0 classid 1:103 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 103 fw flowid 1:103
#testing
$TC class add dev ${IFIN} parent 1:0 classid 1:199 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFIN} parent 1: protocol ip handle 199 fw flowid 1:199

$TC qdisc add dev ${IFOUT} root handle 2: htb default 200
$TC class add dev ${IFOUT} parent 2: classid 2:0 htb rate ${LINESPEED}Kbit ceil ${LINESPEED}Kbit
$TC class add dev ${IFOUT} parent 2:0 classid 2:200 htb rate 1Kbit ceil ${LINESPEED}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 200 fw flowid 2:200

$TC class add dev ${IFOUT} parent 2: classid 2:0 htb rate ${LINESPEED}Kbit ceil ${LINESPEED}Kbit
$TC class add dev ${IFOUT} parent 2:0 classid 2:201 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 201 fw flowid 2:201
$TC class add dev ${IFOUT} parent 2:0 classid 2:202 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 202 fw flowid 2:202
$TC class add dev ${IFOUT} parent 2:0 classid 2:203 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 203 fw flowid 2:203
#testing
$TC class add dev ${IFOUT} parent 2:0 classid 2:299 htb rate ${GUAR}Kbit ceil ${BURST}Kbit prio 4
$TC filter add dev ${IFOUT} parent 2: protocol ip handle 299 fw flowid 2:299


#configure marking
echo "setting up marking"
$EBTABLES -A FORWARD -i ${IFIN} -p IPV4 --ip-source 192.168.101.0/24 -j mark --set-mark 201 --mark-target ACCEPT
$EBTABLES -A FORWARD -i ${IFIN} -p IPV4 --ip-source 192.168.102.0/24 -j mark --set-mark 202 --mark-target ACCEPT
$EBTABLES -A FORWARD -i ${IFIN} -p IPV4 --ip-source 192.168.103.0/24 -j mark --set-mark 203 --mark-target ACCEPT

$EBTABLES -A FORWARD -i ${IFOUT} -p IPV4 --ip-destination 192.168.101.0/24 -j mark --set-mark 101 --mark-target ACCEPT
$EBTABLES -A FORWARD -i ${IFOUT} -p IPV4 --ip-destination 192.168.102.0/24 -j mark --set-mark 102 --mark-target ACCEPT
$EBTABLES -A FORWARD -i ${IFOUT} -p IPV4 --ip-destination 192.168.103.0/24 -j mark --set-mark 103 --mark-target ACCEPT

#testing
$EBTABLES -A FORWARD -i ${IFIN} -p ipv4 --ip-source 192.168.0.0/24 -c 0 0 -j mark --set-mark 299 --mark-target ACCEPT
$EBTABLES -A FORWARD -i ${IFOUT} -p ipv4 --ip-destination 192.168.0.0/24 -c 0 0 -j mark --set-mark 199 --mark-target ACCEPT

echo "done"

