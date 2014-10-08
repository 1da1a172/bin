#============The AP group would be that of a classroom deployment or other large client capacity venue=====#
#============This script should not be execute across groups having more than 20 APs provisioned===========#
#================Logging Levels for Client Match===============#
#=== MUST TURN ON DEBUG PRIOR TO SCRIPT EXECUTION ===========#
#set following logging levels for Client Match Debugging===============#
#config t logging level debugging arm subcat client-match
#==============================================================#
#================Controller Config===============#
0,show clock
0,show running-config
#================Client State================================================================================#
#================!!!!Modify <replace with prefix of AP-names in APgroup> to reflect APgroup for AP's that you are searching in=======================#
5m,show ap arm client-match history | include <prefix-apname>
#==========================================================================================================#
2m,show ap remote debug mgmt-frames ap-name #{show ap database group <apgroup>,,Name}
2m,show ap remote debug association ap-name #{show ap database group <apgroup>,,Name}
2m,show ap association ap-group #{show ap database group <apgroup>,,Name}
2m,show ap bss-table ap-name #{show ap database group <apgroup>,,Name}
2m,show ap active ap-name #{show ap database group <apgroup>,,Name}
2m,show ap debug client-table ap-name #{show ap database group <apgroup>,,Name} | include Client,Mac,Retries,Idle,---,UAP,HT,Delay,Stat
2m,show ap debug client-table ap-name #{show ap database group <apgroup>,,Name}
2m,show ap debug gre-tun-stats ap-name #{show ap database group <apgroup>,,Name}
#=============RF ARM==============
10m,show ap arm state ap-name #{show ap database group <apgroup>,,Name}
10m,show ap arm rf-summary ap-name #{show ap database group <apgroup>,,Name}
10m,show ap arm history ap-name #{show ap database group <apgroup>,,Name}
#=============client Match=========
5m,show ap arm virtual-beacon-report ap-name #{show ap database group <apgroup>,,Name}
5m,show ap virtual-beacon-report ap-name #{show ap database group <apgroup>,,Name}
5m,show ap arm client-match probe-report ap-name #{show ap database group <apgroup>,,Name}
5m,show ap arm client-match restriction-table ap-name #{show ap database group <apgroup>,,Name}
10m,show ap arm client-match neighbors ap-name #{show ap database group <apgroup>,,Name}
10m,show ap arm client-match unsupported
10m,show ap client trail-info
10m,show ap arm client-match summary advanced
#===============AP stats===========
10m,show ap debug system-status ap-name #{show ap database group <apgroup>,,Name}
10m,show ap debug crash-info ap-name #{show ap database group <apgroup>,,Name}
10m,show ap debug driver-log ap-name #{show ap database group <apgroup>,,Name}
10m,show ap debug radio-stats ap-name #{show ap database group <apgroup>,,Name} radio 0 advanced
10m,show ap debug radio-stats ap-name #{show ap database group <apgroup>,,Name} radio 1 advanced
10m,show ap debug log ap-name #{show ap database group <apgroup>,,Name}
#====================================================================#
#===RadioBusy =======================================================#
5m,show ap radio-summary ap-name #{show ap database group <apgroup>,,Name}
6m,show ap radio-summary ap-name #{show ap database group <apgroup>,,Name}
#====================================================================#
#================Displaying Log and Capturing Output====#
11m,show log arm all
#=======================================================#
####To check and see if all cmds executed with the correct snytax 
####search for "Invalid input detected" in the output logfile
