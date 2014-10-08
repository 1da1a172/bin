#=================================================================#
##search and replace <cmac> with lower case client mac address##
##search and replace <CMAC> with upper case client mac address
#================================================================#
#================Logging Levels for Client Match===============#
#=== Do this stuff manually ahead of time ===========#
#set following logging levels for Client Match Debugging===============#
#config t logging level debugging arm subcat client-match
#config t logging level debugging arm-user-debug <client-mac>
#==============================================================#
#================Logging Levels for Client Debugging===============#
#=== Do this stuff manually ahead of time===============#
#config t logging level debug user-debug <cmac>
#set packet capture wifi datapath as needed for a specific client
#==============================================================#
#================Controller Config===============#
0,show running-config
#==============================================================#
#================Client State=====================================================================================================#
1m,show ap remote debug mgmt-frames ap-name #{show ap association client-mac <cmac>,,Name,30} | include Traced,Timestamp,---,<cmac>
1m,show ap association client-mac <cmac>
1m,show auth-trace mac <cmac>
1m,show aaa state station <cmac>
3m,show user-table verbose | include User,IP,Profile,---,Curr,<cmac>     
3m,show datapath station table | include Datapath,----,Flags,AMSDU,MAC,<CMAC>
3m,show datapath user table | include Datapath,----,Flags,VPN,Src,IP,<CMAC>
3m,show ap debug client-stats <cmac>
1m,show ap debug client-table ap-name #{show ap association client-mac <cmac>,,Name,30} | include Client,Mac,Retries,Idle,---,<cmac>,UAP,HT,Delay,Stat

#================AP-debug cmac and Health of AP client is associated to.===============================================================================#
5m,show ap debug gre-tun-stats ap-name #{show ap association client-mac <cmac>,,Name,30} | include HBT,Controller,GRE,MAC,---,<CMAC>
5m,show ap debug radio-stats ap-name #{show ap association client-mac <cmac>,,Name,30} radio 0 advanced 
5m,show ap debug radio-stats ap-name #{show ap association client-mac <cmac>,,Name,30} radio 1 advanced 
5m,show ap debug system-status ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap debug ipc forwarding-statistics ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap bss-table ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap remote debug client-mgmt-counters ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap radio-summary ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap blacklist-clients | include <cmac>
10m,show ap debug crash-info ap-name #{show ap association client-mac <cmac>,,Name,30}
10m,show ap debug counters ap-name #{show ap association client-mac <cmac>,,Name,30}
10m,show ap debug driver-log ap-name #{show ap association client-mac <cmac>,,Name,30}
0,show ap debug lldp counter ap-name #{show ap association client-mac <cmac>,,Name,30}
0,show ap debug lldp neighbors ap-name #{show ap association client-mac <cmac>,,Name,30}
0,show ap debug port status ap-name #{show ap association client-mac <cmac>,,Name,30}
0,show ap debug lacp ap-name #{show ap association client-mac <cmac>,,Name,30}
0,show ap debug lldp state ap-name #{show ap association client-mac <cmac>,,Name,30}
#================ARM Data=================================================================================================================#
10m,show ap arm state ap-name #{show ap association client-mac <cmac>,,Name,30}
10m,show ap arm rf-summary ap-name #{show ap association client-mac <cmac>,,Name,30}
10m,show ap arm history ap-name #{show ap association client-mac <cmac>,,Name,30}
#=========================================================================================================================================================#
#================Client Match Data-client specific==========================================================#
5m,show ap client trail-info <cmac>
5m,show ap virtual-beacon-report client-mac <cmac> 
5m,show ap virtual-beacon-report ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap arm client-match history client-mac <cmac>
5m,show ap arm client-match neighbors ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap arm client-match probe-report ap-name #{show ap association client-mac <cmac>,,Name,30}
5m,show ap arm client-match restriction-table ap-name #{show ap association client-mac <cmac>,,Name,30} | include <cmac>
5m,show ap arm client-match unsupported | include <cmac>,MAC,---
5m,show ap arm client-match summary client-mac <cmac> | include MAC,:  
#============================================================================================================#
#================AP Dot11r of AP client is associated to.==============================#
0,show ap debug dot11r efficiency <cmac>
0,show ap debug dot11r state ap-name #{show ap association client-mac <cmac>,,Name,30}
#======================================================================================#
#================airplay===============#
10m,show airgroup vlan
10m,show airgroup servers verbose
10m,show airgroup users verbose
#===============================#
#================Displaying Log and Capturing Output====#
10m,show log user-debug all | include <cmac>
10m,show log arm all | in <cmac>
11m,show log arm-user-debug all
#=======================================================#
####To check and see if all cmds executed with the correct snytax 
####search for "Invalid input detected" in the output logfile