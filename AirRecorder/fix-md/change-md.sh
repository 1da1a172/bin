#!/usr/bin/zsh

show_help() {
	cat << EOL

usage: $scriptname [options] <local controller>

poll the local controller for all APs terminated to it and change the 
APs' master discovery. AP environment variables are settable via the options:

	--master	defaults to null
	--servername	defaults to 'aruba-master'
	--serverip	defaults to null

Down APs are listed in <local controller>${downapsuffix}

Note that if you provide a bad LMS, AirRecorder will fail with its normal output.
If you see AirRecorder fail, check your LMS and credintial files.

EOL
}

poll_controller() {
	# TODO: check to make sure we really are executing from the subdir
	local subdir=`basename $(pwd)`
	cd ..
	./airrecorder.sh -c $subdir/get-md.arc --log-file $subdir/$lms-aps $lms > /dev/null
	cd $subdir
}

get_badap() { # TODO: define the variables from the to be created apvar array and a loop
	local apname # config from an individual AP
	local apmaster
	local apservername
	local apserverip
	local masterstr #string version of these vars b/c AirRecorder returns N/A for a null value.
	local severnamestr
	local serveripsrt
	local logfile=$lms-aps-00.log #AirRecorder output
	local i
	local -a ap #an array of all APs on the LMS

	for i in master servername serverip ; do
		[ -z "${(P)i}" ] && eval ${i}str="N/A" || eval ${i}str="${(P)i}"
	done

	ap=(`grep '///// Command: show ap provisioning ap-name' ${lms}-aps-00.log | cut -d\  -f 7`)
	for i in `seq ${#ap[@]}` ; do
		apmaster=`grep $ap[i] $logfile -A 2 | grep \^Master -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 2 | sed 's/\r//g'`
		apservername=`grep $ap[i] $logfile -A 3 | grep \^Server\ Name -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`
		apserverip=`grep $ap[i] $logfile -A 4 | grep \^Server\ IP -m 1 | sed 's/\ \ */\ /g' | cut -d\  -f 3 | sed 's/\r//g'`

		if [ -z "$apmaster" ] ; then # AirRecorder returns null values only if the AP is down.
			downap[i]=$ap[i]
		elif [ "$apmaster" != "$masterstr" -o "$apservername" != "$servernamestr" -o "$apserverip" != "$serveripstr" ] ; then
			badap[i]=$ap[i]
		fi
	done
	rm $logfile
}

write_expectscript() {
	local hostname=`echo $lms | cut -d\. -f 1`
	local exp=$lms-fix-md.exp
	# TODO: get this with pointers and a loop
	local sendmaster="`[ -z "$master" ] && echo "no master" || echo "master $master"`"
	local sendservername="`[ -z "$servername" ] && echo "no server-name" || echo "server-name $servername"`"
	local sendserverip="`[ -z "$serverip" ] && echo "no server-ip" || echo "server-ip $serverip"`"
	cat << EOL > $exp
#!`command -v expect`
set badap "$badap[*]"

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
# TODO: create an apvar array
scriptname=$0
downapsuffix='-down_aps.txt'
unset master
servername=aruba-master
unset serverip
unset lms
declare -a badap
declare -a downap

# get input from cli options
while :
do
	case $1 in
		--master)
			master=$2
			shift
			;;
		--servername)
			servername=$2
			shift
			;;
		--serverip)
			serverip=$2
			shift
			;;
		-h | --help)
			show_help
			exit 0
			;;
		*)
			if [[ -z $1 ]] ; then
				echo "Please provide an LMS"
				show_help
				exit 1
			else
				lms=$1
			fi
			break
			;;
	esac
	shift
done

poll_controller
get_badap
write_expectscript
echo "The following APs are down:"
for ap in $downap[*] ; do 
	echo $ap | tee -a $lms$downapsuffix
done
