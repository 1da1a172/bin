#!/usr/bin/zsh
#
# A library for scripting with network stuff
# This is an early version. function names are subject to change
#
# TODO: sensible function names; follow the lib::function naming convention

################################################################################
# prints ip address in binary to stdout
# arguments:
#  $1 = ipv4 or ipv6 address
# returns:
#  1: $1 is not a valid v4 or v6 address
################################################################################
function baddr() {
  typeset haddr="$1"
  typeset baddr
  typeset block

  if valid_ipv4_addr "${haddr}" ; then
    for block (${(ws|.|)haddr}) baddr+="${(l|8||0|)$(([#2]${block}))#'2#'}"
  elif valid_ipv6_addr "${haddr}" ; then
    haddr="$(long_ipv6_addr "${haddr}")" || return 1
    for block (${(ws|:|)haddr}) baddr+="${(l|16||0|)$(([#2]16#${block}))#'2#'}"
  else
    return 1
  fi
  echo "${baddr}"
}

################################################################################
# prints ip address in human readable format to stdout
# arguments:
#  $1 = 32 or 128 0's and 1's
# returns:
#  1: $1 is not a valid v4 or v6 address
################################################################################
function haddr() {
  typeset baddr="$1"
  typeset index
  typeset -a haddr

  if [[ "${baddr}" =~ "^[01]{32}$" ]]; then
    for index ({1..4}) haddr[index]=$((2#${baddr:(${index}-1)*8:8}))
    echo ${(j|.|)haddr}
  elif [[ "${baddr}" =~ "^[01]{128}$" ]]; then
    for index ({1..8}) haddr[index]="${$(([#16]2#${baddr:(${index}-1)*16:16}))}"
    short_ipv6_addr ${(Lj|:|)haddr#'16#'}
  else
    return 1
  fi
}

function valid_ipv4_addr() {
  typeset addr="$1"
  typeset octet

  [[ "${addr[1]}" != '.' ]] || return 1
  [[ "${addr[-1]}" != '.' ]] || return 1
  [[ ${(ws|.|)#addr} == 4 ]] || return 1
  [[ -z "${addr[(r)..]}" ]] || return 1

  for octet in ${(ws|.|)addr}; do
    [ ${octet} -le 255 ] &> /dev/null || return 1
    [[ ${octet} -ge 0 ]] || return 1
  done
}

function valid_ipv6_addr() {
  typeset addr="$1"
  typeset hextet

  [[ "${addr}" =~ '^::' ]] && addr="0${addr}"
  [[ "${addr[1]}" != ':' ]] || return 1
  [[ "${addr}" =~ '::$' ]] && addr+='0'
  [[ "${addr[-1]}" != ':' ]] || return 1
  [[ -z "${addr[(r):::]}" ]] || return 1
  case "${(ws|::|)#addr}" in
    (1) [[ ${(ws|:|)#addr} -eq 8 ]] || return 1 ;;
    (2) [[ ${(ws|:|)#addr} -le 7 ]] || return 1 ;;
    (*) return 1 ;;
  esac

  for hextet in ${(ws|:|)addr}; do
    [[ "${hextet}" =~ "^[[:xdigit:]]{1,4}$" ]] || return 1
  done
}

################################################################################
# fill in all the implicit zero's on an IPv6 address.
# Arguments:
#  $1 = IPv6 address
# Returns:
#  1 - $1 is not a valid IPv6 address
################################################################################
function long_ipv6_addr() {
  typeset pos
  typeset short_addr="$1"
  typeset -a long_addr
  valid_ipv6_addr "${short_addr}" || return 1

  long_addr=(0 0 0 0 0 0 0 0)
  if [[ -n "${short_addr%::*}" ]]; then
    for pos in {1.."${(ws|:|)#short_addr%::*}"}; do
      long_addr[pos]="${short_addr[(ws|:|)pos]}"
    done
  fi
  if [[ -n "${short_addr#*::}" ]]; then
    for pos in {-1..-"${(ws|:|)#short_addr#*::}"}; do
      long_addr[9+${pos}]="${short_addr[(ws|:|)pos]}"
    done
  fi

  echo ${(j|:|)${(l|4||0|)long_addr}}
}

################################################################################
# Apply all IPv6 address abbreviations
# TODO: regex instead of loops.
################################################################################
function short_ipv6_addr() {
  typeset long_addr
  typeset short_addr
  typeset zeros='0000:0000:0000:0000:0000:0000:0000'
  typeset hextet
  long_addr=$(long_ipv6_addr $1) || return 1
  short_addr="${long_addr}"

  while [[ ${#short_addr} -eq 39 ]] && [[ ${#zeros} -gt 4 ]]; do
    short_addr=${long_addr/$zeros/}
    zeros=${zeros:0:${#zeros}-5}
  done
  [[ "$short_addr[1]" == ':' ]] && short_addr=":${short_addr}"
  [[ "$short_addr[-1]" == ':' ]] && short_addr+=':'

  for index in {1..${(ws|:|)#short_addr}}; do
    hextet="${short_addr[(ws|:|)index]}"
    while [[ ${#hextet} -gt 1 ]] && [[ ${hextet[1]} == '0' ]]; do
      hextet=${hextet:1}
    done
    short_addr[(ws|:|)${index}]="${hextet}"
  done

  echo "${short_addr}"
}

################################################################################
# prints network address to stdout
# arguments:
#  $1=ip address and mask bits in cidr format (eg, 192.168.1.1/24)
# returns:
# 1: $1 is not a valid v4 or v6 address
################################################################################
function ntwk() {
  typeset addr="$1"
  typeset baddr

  [[ -n "${addr[(r)/]}" ]] || return 1

  baddr="$(baddr "${addr%/*}")"
  haddr "${(r|${#baddr}||0|)baddr:0:${addr#*/}}"
}
################################################################################
# prints broadcast address to stdout
# arguments:
#  $1=ip address and mask bits in cidr format (eg, 192.168.1.1/24)
# returns:
#  1: $1 is not a valid v4 or v6 address
################################################################################
function bcast() {
  typeset addr="$1"
  typeset baddr

  [[ -n "${addr[(r)/]}" ]] || return 1

  baddr="$(baddr "${addr%/*}")"
  haddr "${(r|${#baddr}||1|)baddr:0:${addr#*/}}"
}

function subnet() {
  case "$1" in
    ('255.255.255.255') echo 32 ;;
    ('255.255.255.254') echo 31 ;;
    ('255.255.255.252') echo 30 ;;
    ('255.255.255.248') echo 29 ;;
    ('255.255.255.240') echo 28 ;;
    ('255.255.255.224') echo 27 ;;
    ('255.255.255.192') echo 26 ;;
    ('255.255.255.128') echo 25 ;;
    ('255.255.255.0') echo 24 ;;
    ('255.255.254.0') echo 23 ;;
    ('255.255.252.0') echo 22 ;;
    ('255.255.248.0') echo 21 ;;
    ('255.255.240.0') echo 20 ;;
    ('255.255.224.0') echo 19 ;;
    ('255.255.192.0') echo 18 ;;
    ('255.255.128.0') echo 17 ;;
    ('255.255.0.0') echo 16 ;;
    ('255.254.0.0') echo 15 ;;
    ('255.252.0.0') echo 14 ;;
    ('255.248.0.0') echo 13 ;;
    ('255.240.0.0') echo 12 ;;
    ('255.224.0.0') echo 11 ;;
    ('255.192.0.0') echo 10 ;;
    ('255.128.0.0') echo 9 ;;
    ('255.0.0.0') echo 8 ;;
    ('254.0.0.0') echo 7 ;;
    ('252.0.0.0') echo 6 ;;
    ('248.0.0.0') echo 5 ;;
    ('240.0.0.0') echo 4 ;;
    ('224.0.0.0') echo 3 ;;
    ('192.0.0.0') echo 2 ;;
    ('128.0.0.0') echo 1 ;;
    ('0.0.0.0') echo 0 ;;
    (32) echo '255.255.255.255' ;;
    (31) echo '255.255.255.254' ;;
    (30) echo '255.255.255.252' ;;
    (29) echo '255.255.255.248' ;;
    (28) echo '255.255.255.240' ;;
    (27) echo '255.255.255.224' ;;
    (26) echo '255.255.255.192' ;;
    (25) echo '255.255.255.128' ;;
    (24) echo '255.255.255.0' ;;
    (23) echo '255.255.254.0' ;;
    (22) echo '255.255.252.0' ;;
    (21) echo '255.255.248.0' ;;
    (20) echo '255.255.240.0' ;;
    (19) echo '255.255.224.0' ;;
    (18) echo '255.255.192.0' ;;
    (17) echo '255.255.128.0' ;;
    (16) echo '255.255.0.0' ;;
    (15) echo '255.254.0.0' ;;
    (14) echo '255.252.0.0' ;;
    (13) echo '255.248.0.0' ;;
    (12) echo '255.240.0.0' ;;
    (11) echo '255.224.0.0' ;;
    (10) echo '255.192.0.0' ;;
    (9) echo '255.128.0.0' ;;
    (8) echo '255.0.0.0' ;;
    (7) echo '254.0.0.0' ;;
    (6) echo '252.0.0.0' ;;
    (5) echo '248.0.0.0' ;;
    (4) echo '240.0.0.0' ;;
    (3) echo '224.0.0.0' ;;
    (2) echo '192.0.0.0' ;;
    (1) echo '128.0.0.0' ;;
    (0) echo '0.0.0.0' ;;
    (*) return 1 ;;
  esac
}

################################################################################
# Returns the nth usable IP in a subnet. Takes v4 and v6 addresses. Will only 
# return usable IP's. if the nth IP is the network address (ie: n=0) or the
# broadcast address, function will quit with an error
# TODO: handle negative $n for nth ip from end
# Arguments:
#  $1=cidr formated address (ie, 192.168.1.3/24)
#  $2=n
# Returns:
#  1 - missing an argument
################################################################################
function nth_ip() {
  typeset network="${1%/*}"
  typeset network_bits
  typeset network_size="${1#*/}"
  typeset host_bits
  typeset host_size
  typeset n="$2"

  [[ "${network}" != "${network_size}" ]] || return 1
  [[ $(( $n )) == "$n" ]] || return 1

  network_bits="${$(baddr ${network}):0:${network_size}}"
  if valid_ipv4_addr ${network}; then
    host_size=$(( 32 - ${network_size} ))
  elif valid_ipv6_addr ${network}; then
    host_size=$(( 128 - ${network_size} ))
  else
    return 1
  fi
  host_bits=${$(([#2]$n))#'2#'}
  [[ ${host_bits} < ${(l|${host_size}||1|)} ]] || return 1
  host_bits=${(l|${host_size}||0|)host_bits}

  haddr "${network_bits}${host_bits}"
}
