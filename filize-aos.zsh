#!/usr/bin/zsh

function write_profiles() {
    local integer i
    local definition # keyword string to declare the profile in AOS e.g. "rf arm-profile" (no quotes)
    local folder     # basedir of $file, based on $definition
    local file       # where we are actually going to write the profile config. Instance in this function does not include path
    local -a defline # array of the line numbers in $CONFIG starting the definition of the profiles
    local -a defstr  # string that declares that particular profile, e.g. 'rf arm-profile "some name"' (no single-quotes)
                     # Making this an array makes is easy to pull off a quoted profile name with a space

    definition=$1
    folder="$PREFIX"/$( echo "$definition" | sed 's: :/:g' ) # note that sed is deliminated with : not / for readability
    defline=( $( sed -n "/^$definition/=" $CONFIG ) )

    [[ -d $folder ]] && rm -r $folder
    [[ ${#defline} -eq 0 ]] && { echo "No \"$definition\" defined" >&2 ; return }
    mkdir -p $folder

    for i in {1..${#defline}} ; do
        # name the output file after the profile name
        defstr=( $(sed -n $defline[i]p $CONFIG) )
        file=$folder/$( echo $defstr[${#defstr}] | sed s/\"//g )

        # Parse for raw config of ith profile and write to $file
        sed -n "$defline[i],/^!$/p" $CONFIG | sed 1d | sed '$d' | sed 's/^ *//' > $file
    done
}

function write_unnamed_profile() {
    local integer i
    local definition      # keyword string to declare the profile in AOS
    local file            # where on the disk we are going to write the file. Instance in this function includes path

    definition=$1
    file="$PREFIX"/$( echo "$definition" | sed 's: :/:g' ) # note that sed is deliminated with : not / for readability

    mkdir -p $( dirname $file )

    sed -n "/^$definition/,/^!$/p" $CONFIG | sed 1d | sed '$d' | sed 's/^ *//' > $file
}

function write_option_group() {
    local definition
    local file

    definition=$1
    file="$PREFIX"/$( echo "$definition" | sed 's: :/:g' ) # note that sed is deliminated with : not / for readability
    grep "^$definition" $CONFIG | cut -d ' ' -f $[ $( echo $definition | wc -w ) + 1 ]- > $file # grep config for any line that starts with the definition, then write only the part of the line after the definition to the file.

}

CONFIG=$1
declare PREFIX="." # base output directory

## rf ##
for type in am-scan arm arm-rf-domain dot11{a,g}-radio event-thresholds ht-radio optimization spectrum
    write_profiles "rf $type-profile"

## wlan ##
write_profiles "wlan virtual-ap"
for type in bcn-rpt-req client-wlan dot11{k,r} handover-trigger {ht-,}ssid rrm-ie {wmm-,}traffic-management tsm-req voip-cac
    write_profiles "wlan $type-profile"
for type in ap station
    write_profiles "wlan edca-parameters-profile $type"
## wlan hotspot ##
for type in advertisement hs2
    write_profiles "wlan hotspot $type"
for type in 3gpp-nwk domain-name ip-addr-avail nai-realm nwk-auth roam-cons venue-name 
    write_profiles "wlan hotspot anqp-$type-profile"
for type in conn-capability op-cl operator-friendly-name wan-metrics
    write_profiles "wlan hotspot h2qp-$type-profile"

## aaa ###
# TODO dns-query-interval log "radius-attributes add" "tacacs-accounting server-group" "user {fast-age,stats-poll}" "xml-api server"
for type in alias-group bandwidth-contract profile rfc-3576-server server-group "derivation-rules user"
    write_profiles "aaa $type"
write_unnamed_profile "aaa password-policy mgmt"
for type in captive-portal dot1x mac mgmt stateful-{kerberos,ntlm} vpn wispr
    write_profiles "aaa authentication $type"
for type in stateful-dot1x wired
    write_unnamed_profile "aaa authentication $type"
for type in ldap radius tacacs windows # TODO "internal use-local-switch"
    write_profiles "aaa authentication-server $type"
write_option_group "aaa timers"

## ap-group ##
for type in ap-group ap-name
    write_profiles $type

## END OF FILE #################################################################
# vim:filetype=zsh foldmethod=marker autoindent expandtab shiftwidth=4 tabstop=4
# Local variables: i definition folder file defline PREFIX
# mode: sh
# End:
#
