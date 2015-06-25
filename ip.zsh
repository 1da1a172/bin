#!/usr/bin/zsh
#
# A library for scripting with network stuff

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
    for block in ${(ws|.|)haddr}; do
      # next line converts ${block} to base2, strips the leading '2#' base
      # indicator, then pads the string to 8 characters with leading 0's
      # and appends the result to the ${baddr} parameter.
      baddr+=${(l|8||0|):-${${:-$(( [#2] ${block} ))}#'2#'}}
    done
  elif valid_ipv6_addr "${haddr}" ; then
    haddr="$(long_ipv6_addr "${haddr}")" || return 1
    for block in ${(ws|:|)haddr}; do
      # next line converts ${block} from base 16 to base 2, strips the leading
      # '2#' base indicator, then pads the string to 16 characters with leading
      # 0's and appends the result to the ${baddr} parameter.
      baddr+=${(l|16||0|):-${${:-$(( [#2] 16#${block} ))}#'2#'}}
    done
  else
    return 1
  fi
  echo "${baddr}"
}

################################################################################
# prints ip address in human readable format to stdout
# arguments:
#  $1 = 32 or 128 0's and 1's
################################################################################
function haddr() {
  typeset baddr="$1"
  typeset index
  typeset block
  typeset -a haddr

  if [[ ${#baddr} == 32 ]]; then # IPv4 address
    for index in {1..4}; do
      block=${baddr:($index - 1) * 8:8}
      haddr[index]=$(( 2#${block} ))
    done
    echo ${(j|.|)haddr}
  elif [[ ${#baddr} == 128 ]]; then # IPv6 address
    for index in {1..8}; do
      block=${baddr:($index - 1) * 16:16}
      haddr[index]=${${:-$(( [#16] 2#${block} ))}#'16#'}
    done
    short_ipv6_addr ${(Lj|:|)haddr}
  else
    return 1
  fi
}

function valid_ipv4_addr() {
  typeset addr="$1"
  typeset octet

  [[ ${(ws|.|)#addr} == 4 ]] || return 1
  for octet in ${(ws|.|)addr}; do
    [ ${octet} -eq ${octet} ] &> /dev/null || return 1
    [[ ${octet} -le 255 ]] || return 1
    [[ ${octet} -ge 0 ]] || return 1
  done
}

# TODO: validation for weird junk (eg, ':::', leading and trailing ':')
function valid_ipv6_addr() {
  typeset addr="$1"
  typeset hextet
  typeset digit

  case "${(ws|::|)#addr}" in
    (1) [[ ${(ws|:|)#addr} -eq 8 ]] || return 1 ;;
    (2) [[ ${(ws|:|)#addr} -le 7 ]] || return 1 ;;
    (*) return 1 ;;
  esac

  for hextet in ${(ws|:|)addr}; do
    [[ ${#hextet} -le 4 ]] && [[ ${#hextet} -ge 1 ]] || return 1
    #TODO regex next line instead of checking each character individually
    for digit (${(s||)hextet}) [[ "${digit}" == [[:xdigit:]] ]] || return 1
  done
}

################################################################################
# fill in all the implicit zero's on an IPv6 address.
################################################################################
function long_ipv6_addr() {
  typeset index
  typeset addr="$1"
  typeset filler

  valid_ipv6_addr "${addr}" || return 1
  for index in {1..${(ws|:|)#addr}}; do
    addr[(ws|:|)index]="${(Ll|4||0|):-${addr[(ws|:|)index]:-0}}"
  done

  # TODO regex could probably do this better
  while [[ $(( ${(ws|:|)#addr} + ${(ws|:|)#filler} )) -lt 8 ]]; do
    filler+=':0000'
  done

  echo "${addr/"::"/"${filler}:"}"
}

################################################################################
# Apply all IPv6 address abbreviations
# TODO: fix trailing ::
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

  for index in {1..${(ws|:|)#short_addr}}; do
    hextet="${short_addr[(ws|:|)index]}"
    while [[ ${#hextet} -gt 1 ]] && [[ ${hextet[1]} == '0' ]]; do
      hextet=${hextet:1:${#hextet}-1}
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
#  1: $1 is not a valid v4 or v6 address
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

function mask_to_cidr() {
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
    (*) return 1 ;;
  esac
}

function cidr_to_mask() {
  case "$1" in
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
# TODO: cleanup. parameter names are confusing. logic can probably be refined
# Arguments:
#  $1=cidr formated address (ie, 192.168.1.3/24)
#  $2=n
# Returns:
#  1 - missing an argument
################################################################################
function nth_ip() {
  typeset n="$2"
  typeset addr="${1%/*}"
  typeset baddr
  typeset cidr="${1#*/}"
  typeset host

  [[ -n "$2" ]] && [[ "$2" -gt 0 ]] || return 1
  [[ -n "${1[(r)/]}" ]] || return 1
  if valid_ipv4_addr "${addr}"; then
    host=$(( 32 - ${cidr} ))
  elif valid_ipv6_addr "${addr}"; then
    host=$(( 128 - ${cidr} ))
  else
    return 1
  fi
  [[ ${n} -lt $(( 2#${(l|${host}||1|):-} )) ]] || return 1 # getting message 'number truncated after 63 digits' on v6 addresses

  baddr="$(baddr ${addr})"
  haddr "${baddr:0:${cidr}}${(l|${host}||0|):-${${:-$(( [#2] ${n} ))}#'2#'}}"
}
