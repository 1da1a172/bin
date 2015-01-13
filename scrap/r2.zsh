#!/usr/bin/zsh

build_addresses() {
	local BUR=60
	local CAS=40
	local HIL=80
	local ISB=20
	local OWE=a0
	local REMOTE=ef
	local SHA=c0
	local -i i
	local wx; local yz
	local network

	for i in {0..$[ ${#vlan} - 1 ]}; do # Start with 172.30.0.0, not 172.30.8.0
		network="172.30."$[ $i * 8 ]
		ROUTER_IPv4_ADD+=( $network".1" )
		WLC_IPv4_ADD+=( $network".2" )
	done

	for wx in $HIL $BUR $OWE $CAS ; do
		for yz in {00..07} ; do
			network="2607:b400:24:$wx$yz:" 
			ROUTER_IPv6_ADD+=( $network":1" )
			WLC_IPv6_ADD+=( $network":2" )
		done
	done
}

build_subnets() {
	local -i i
	local BUR=60
	local CAS=40
        local HIL=80
        local ISB=20
        local OWE=a0
        local REMOTE=ef
        local SHA=c0
	local wx; local yz

	# Assign VLAN names
	for wx in {01..$[ ${#vlan} / 2 ]} {01..$[ ${#vlan} / 2 ]}; do
		VLAN_NAME+="WVL$wx"
	done

	# Assign v4 networks
	for i in {1..${#vlan}}; do
		IPv4_NETWORK+=( "172.30."$[ ( $i - 1 ) * 8 ]"." )
	done

	# Assign v6 networks
	for wx in $HIL $BUR $OWE $CAS; do
		for yz in {00..07}; do
			IPv6_NETWORK+="2607:b400:24:$wx$yz::"
		done
	done
}

write_wlc() {
	local -i i
	local -i seqstart=$1
	local -i seqend=$2
	local out=$3
	local -i wlc_id=`echo $out | cut -d- -f3`
	local -i netadd_suffix
	[[ $wlc_id -le 2 ]] && netadd_suffix=$[ $wlc_id + 1] || netadd_suffix=$[ $wlc_id - 1 ]

	rm_out $out
	for i in {$seqstart..$seqend} ; do
		cat << EOF >> $out
vlan $vlan[i]
vlan $VLAN_NAME[i] $vlan[i]
interface vlan $vlan[i]
 ip address $IPv4_NETWORK[i]$netadd_suffix 255.255.248.0
 ipv6 address $IPv6_NETWORK[i]$netadd_suffix/64
 ip helper-address 198.82.247.66
 ip helper-address 198.82.247.98
 ip igmp snooping
 ipv6 mld snooping
 !
EOF
		(( j++ ))
	done
}

write_router() {
	local -i i
	local seqstart=$1
	local seqend=$2
	local out=$3

	rm_out $out
	for i in {$seqstart..$seqend} ; do
		cat << EOF >> $out
vlan $vlan[i]
 name WLAN-$vlan[i]
interface Vlan$vlan[i]
 ip vrf forwarding wl
 ip address $IPv4_NETWORK[i]1 255.255.248.0
 no ip redirects
 no ip unreachables
 no ip proxy-arp
 ip pim sparse-mode
 ipv6 address $IPv6_NETWORK[i]1/64
 ipv6 nd reachable-time 600000
 ipv6 nd other-config-flag
 ipv6 nd router-preference High
 ipv6 nd ra interval 30
 no ipv6 redirects
 ipv6 verify unicast reverse-path
 ipv6 dhcp server wl
 ipv6 ospf 1 area 11
 no shutdown
exit
!
EOF
	done
}

write_aruba-master() {
	local -i i
	local aaa_prof
	local out=$1

	rm_out $out

	aaa_prof="eduroam-aaa_prof"
	for i in {1..$[ ${#vlan} / 2 ]} ; do
		cat << EOF >> $out
wlan virtual-ap eduroam-$VLAN_NAME[i]
 aaa-profile $aaa_prof
 ssid-profile eduroam-ssid_prof
 vlan $VLAN_NAME[i]
 band-steering
 broadcast-filter arp
 broadcast-filter all
 no mobile-ip
!
EOF
		[[ $i -eq $[ ${#vlan} / 2 ] ]] && aaa_prof="eduroam-alt-aaa_prof"
	done
}

write_docs() {
	local -i i
	local out=vlans.csv

	rm_out $out

	for i in {1..${#vlan}} ; do
		echo "$vlan[i],$IPv4_NETWORK[i]0,21,wlan,$IPv6_NETWORK[i]0/64" >> $out
	done
}

rm_out() {
	local out=$1

	[[ -f $out ]] && rm $out || { [[ -e $out ]] && { echo "$out exists and is not a normal file" ; exit 127 } }
}

vlan=( {2901..2932} )
declare -a IPv4_NETWORK
declare -a IPv6_NETWORK
declare -a VLAN_NAME
unset i lower upper

build_subnets

#write_router 1 16 cas-6509-2-vlans.txt
#write_router 17 32 cas-6509-3-vlans.txt

lower=1
upper=16
for i in {1..5} ; do
	if [[ $i -eq 3 ]] ; then
		lower=17
		upper=32
	fi
	#write_wlc $lower $upper cas-wlc-$i-vlans.txt
done

write_aruba-master aruba-master.txt

write_docs
