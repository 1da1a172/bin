#!/usr/bin/zsh

VT-Wireless() {
	local -i i
	for i in {1..${#vlan}} ; do
		echo wlan virtual-ap VT-Wireless-VL$vlan[i]
		[[ $i -le $[ ${#vlan} / 2 ] ]] && echo \ aaa-profile VT-Wireless-aaa_prof || echo \ aaa-profile VT-Wireless-aaa-alt_prof
		echo \ ssid-profile VT-Wireless-ssid_prof
		echo \ vlan VL$vlan[i]
		echo \ band-steering
		echo \ broadcast-filter all
		echo \ no mobile-ip
		echo \!
	done
}
CONNECT() {
	local -i i
	for i in {1..${#vlan}} ; do
		echo wlan virtual-ap CONNECT-VL$vlan[i]
		echo \ aaa-profile CONNECT-aaa_prof
		echo \ ssid-profile CONNECT-ssid_prof
		echo \ vlan VL$vlan[i]
		echo \ band-steering
		echo \ broadcast-filter all
		echo \ no mobile-ip
		echo \!
	done
}
edit_ap-group() {
	local TLA
	local VTW_vlan
	local CON_vlan

	for TLA in ARA BBPF BFH BIO BUR BURCH CMMID COW CRA CRCIA CSB DAV DER DURHM FRALIN FST GBJ GLCDB GROVE HABBI HAHN HEND HUTCH ICTAS2 ILSB Inn KELLY LANE LATHAM LFSCI LIBR MAJ MALL2 MCB MCCOM MEDIA MIL PAT PLANTRD PRKSV PW3 R14 R15 SEB SEC SGC SHANK SPH SQUIR SSB STCTR SURGE TORG TVFLM VTTI WALA WMS; do
		case $TLA in
			CMMID|GLCDB|MALL2|PW3)
				VTW_vlan=10
				;;
			LFSCI|PLANTRD)
				VTW_vlan=11
				;;
			SPH)
				VTW_vlan=19
				;;
			COW|DER|HABBI)
				VTW_vlan=20
				;;
			SQUIR)
				VTW_vlan=21
				;;
			BIO|CSB|FRALIN|FST|GROVE|HUTCH|ICTAS2|LATHAM|MCCOM|SSB|WALA)
				VTW_vlan=30
				;;
			Inn)
				VTW_vlan=31
				;;
			BBPF|CRA|CRCIA|ILSB|KELLY|PRKSV|R15|SGC|STCTR|VTTI)
				VTW_vlan=40
				;;
			R14)
				VTW_vlan=41
				;;
			BFH|BUR|BURCH|GBJ|WMS)
				VTW_vlan=70
				;;
			MCB)
				VTW_vlan=80
				;;
			DURHM|PAT)
				VTW_vlan=81
				;;
			LIBR)
				VTW_vlan=90
				;;
			TORG)
				VTW_vlan=91
				;;
			DAV|HAHN|SURGE)
				VTW_vlan=92
				;;
			ARA|HEND|LANE|MAJ|MEDIA|MIL|SEC|SHANK|TVFLM)
				VTW_vlan=93
				;;
			*)
				VTW_vlan=""
				;;
		esac
		case $TLA in
			ARA|BBPF|BUR|CRA|CRCIA|HEND|ILSB|Inn|LANE|LIBR|MAJ|MEDIA|MIL|PRKSV|R15|SEC|SHANK|SGC|SQUIR|STCTR|SURGE|TORG|TVFLM|VTTI)
				CON_vlan=10
				;;
			SPH)
				CON_vlan=18
				;;
			BFH|BIO|BURCH|CMMID|CSB|DAV|DURHM|FRALIN|FST|GBJ|GROVE|HABBI|HAHN|HUTCH|ICTAS2|LATHAM|LFSCI|MALL2|MCB|MCCOM|PAT|PLANTRD|PW3|SSB|WALA|WMS)
				CON_vlan=20
				;;
			GLCDB)
				CON_vlan=31
				;;
			COW|DER)
				CON_vlan=70
				;;
			R14)
				CON_vlan=80
				;;
			KELLY)
				CON_vlan=91
				;;
			*)
				CON_vlan=""
				;;
		esac
		if [[ -n "$VTW_vlan" ]] || [[ -n "$CON_vlan" ]] ; then
			echo "ap-group $TLA-Basic"
			if [[ -n "$VTW_vlan" ]] ; then
				echo \ no virtual-ap $TLA-VT-Wireless-vap_prof
				echo \ virtual-ap VT-Wireless-VL$VTW_vlan
			fi
			if [[ -n "$CON_vlan" ]] ; then
				echo \ no virtual-ap $TLA-CONNECT-vap_prof
				echo \ virtual-ap CONNECT-VL$CON_vlan
			fi
			echo \!
		fi
	done
}

declare -a vlan; vlan=( {10..13} {18..21} 30 31 40 41 43 70 71 80 81 {90..93} )

#VT-Wireless
#CONNECT
edit_ap-group
