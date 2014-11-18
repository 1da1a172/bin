#!/usr/bin/zsh

show_help() {
	cat << EOL

usage: $scriptname [options] <local controller>

This script will poll the local controller for all APs terminated to it and
change the APs master discovery. Options:

	--master	GUI option: Master Controller IP Address/DNS name
			AP environment variable: master
			Default: (null)

	--servername	GUI option: Host Controller Name
			AP environment variable: server-name
			Default: 'aruba-master' or null if --serverip is used

	--serverip	GUI option: TFTP Server
			AP evnironment variable: server-ip
			Default: (null)
			Must be an IP address. (Not validated)

	--hostname	How the LMS identifies itself in the CLI. This is used
			to ensure the expect script is written correctly.
			Default: hostname (NOT FQDN) of LMS provided.
			Case sensitive!

Regarding AP options:
Set all values to null (use '') to use ADP.
Use defaults if you plan to use DHCP options 43 and 60.
Valid combinations:
	none
	master and serverip
	servername (default)
	servername and master

Down APs are listed in <local controller>$downapsuffix
EOL
}

check_args() {
	local valid=false
	if [ -z "$master$servername$serverip" ] ; then # All null values; use ADP
		valid=true
	elif [ -n "$master" -a -n "$serverip" -a -z "$servername"] ; then # GUI option 2
		[ -z "$servername" ] && valid=true
	elif [ -n "$servername" -a -z "$serverip" ] ; then # GUI option 3
		valid=true
	fi
	$valid || { echo "Bad AP options" ; show_help ; exit 1 }
}

poll_controller() { # TODO: make this work from any directory.
	local basedir="`pwd`"

	if [ -e ../airrecorder.sh ] ; then 
		[ -x ../airrecorder.sh ] && { local subdir="`basename $(pwd)`" ; cd .. } || err_nox ../airrecorder.sh
	elif [ -e ./airrecorder.sh ] ; then
		[ -x ./airrecorder.sh ] && local subdir="`dirname \"$scriptname`\"" || err_nox ./airrecorder.sh
	else
		echo "Unable to find airrecorder.sh"
		exit 1
	fi
	./airrecorder.sh -c $subdir/get-md.arc --log-file $subdir/$lms-aps $lms > /dev/null || { echo "Unable to connect to $lms" ; exit 1 }
	cd $basedir
}

err_nox() {
	echo $1" is not executable"
	exit 1
}

get_badap() {
	local apname # config from an individual AP
	local logfile=$lms-aps-00.log #AirRecorder output
	local i
	local -a ap #an array of all APs on the LMS

	for i in $apvar ; do
		[ -z "${(P)i}" ] && local ${i}str="N/A" || local ${i}str="${(P)i}"
	done

	ap=(`grep '///// Command: show ap provisioning ap-name' ${lms}-aps-00.log | cut -d\  -f 7`)
	for i in `seq ${#ap[@]}` ; do
		apmaster=`grep $ap[i] $logfile -A 2 | grep \^Master -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 2 | sed 's/\r//g'`
		[ -z "$apmaster" ] && { downap[i]=$ap[i] ; continue } # AirRecorder returns null values only if the AP is down
		apservername=`grep $ap[i] $logfile -A 3 | grep \^Server\ Name -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`
		apserverip=`grep $ap[i] $logfile -A 4 | grep \^Server\ IP -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`

		[ "$apmaster" != "$masterstr" -o "$apservername" != "$servernamestr" -o "$apserverip" != "$serveripstr" ] && badap[i]=$ap[i]
	done
	rm $logfile
}

write_expectscript() {
	local sendmaster="`[ -z "$master" ] && echo "no master" || echo "master $master"`"
	local sendservername="`[ -z "$servername" ] && echo "no server-name" || echo "server-name $servername"`"
	local sendserverip="`[ -z "$serverip" ] && echo "no server-ip" || echo "server-ip $serverip"`"
	local exp=$lms-fix-md.exp
	local i

	cat << EOL > $exp
#!`command -v expect`
set badap "`echo $badap[*] | sed 's/  / /g'`"

spawn `command -v ssh` $lms
expect "($hostname) #" { send "configure terminal\r" }
expect "($hostname) (config) #" { send "provision-ap\r" }

foreach ap \$badap {
	expect "($hostname) (AP provisioning) #" { send "read-bootinfo ap-name \$ap\r" }
	expect "($hostname) (AP provisioning) #" { send "$sendmaster\r" }
	expect "($hostname) (AP provisioning) #" { send "$sendservername\r" }
	expect "($hostname) (AP provisioning) #" { send "$sendserverip\r" }
	expect "($hostname) (AP provisioning) #" { send "reprovision ap-name \$ap\r" }
}

# Exit out
expect "($hostname) (AP provisioning) #" { send "exit\r" }
expect "($hostname) (config) #" { send "exit\r" }
expect "($hostname) #" { send "exit\r" }
EOL
	chmod +x $exp
}

# Default variable definitions
apvar=(master servername serverip) # provisioning options
scriptname=$0
downapsuffix='-down_aps.txt'
unset master
servername=aruba-master
unset serverip
unset lms
unset hostname
declare -a badap
declare -a downap

# set values based on arguments provided
while :
do
	case "$1" in
		-*)
			case "$1" in
				--master)
					master="$2"
					;;
				--servername)
					servername="$2"
					;;
				--serverip)
					serverip="$2"
					[ "$servername" = "aruba-master" ] && unset servername # Implicit default
					;;
				--hostname)
					hostname="$2"
					;;
				-h | --help)
					show_help
					exit 0
					;;
				*)
					echo "Unknown option $1"
					show_help
					exit 1
					;;
			esac
			shift
			;;
		*)
			if [ -z "$1" ] ; then
				if [ -z "$lms" ] ; then
					echo "Please provide an LMS"
					show_help
					exit 1
				fi
				break
			else
				[ -n "$lms" ] && { "\"$lms\" and \"$1\" given as an LMS. Please use only one."; show_help; exit 1 }
				lms="$1"
			fi
			;;
	esac
	shift
done
check_args
[ -z "$hostname" ] hostname=`echo $lms | cut -d\. -f 1`

poll_controller
get_badap
[ ${#badap[@]} -ne 0 ] && write_expectscript || echo "No misconfigured APs found."
[ -e $lms$downapsuffix ] && rm $lms$downapsuffix
if [ ${#downap[@]} -ne 0 ] ; then
	echo "The following APs are down:"
	for ap in $downap[*] ; do 
		echo $ap | tee -a $lms$downapsuffix
	done
else
	echo "No down APs."
fi
