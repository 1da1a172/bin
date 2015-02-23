#!/usr/bin/zsh

show_help() {
cat << EOL

usage: wastedonlol -r <region> -s <summoner name> [{-a | -o} <file>]
Get total time <summoner name> has been logged into League of Legends

options -r and -s are required. All output is in csv format.

    -a    Append to or create <file>
    -h    Show this help
    -n    Also output with libnotify
    -o    Overwrite or create <file>
    -r    Select a region. Valid options for <region> are:
            $VALID_REGIONS
    -s    Name of the summoner to lookup
                        
EOL
}

get_hours() {
    local URL="https://wastedonlol.com/$REGION-$SUMMONER/"     # It wont work without the trailing '/' !
    local PREHOURS='spent about <span style="color:#78c9fd;">' # Note that this is used with a '-' deliminated sed
    local POSTHOURS='</span> hours'                            # Note that this is used with a '-' deliminated sed
    local MATCH='class="result_pseudo"'

    HOURS=$( curl $URL 2> /dev/null | sed -n "/$MATCH/ s-^.*$PREHOURS\(.*\)$POSTHOURS.*\$-\1-p" ) # deliminated with '-'
}

gen_line() {
        local TIMESTAMP="$( date +%Y-%b-%d\ %H:%M:%S\ %Z )"
    LINE=$TIMESTAMP,$HOURS
}

validate_args() {
    local i
    local invalid_region=true

    [[ -z $REGION ]] || [[ -z $SUMMONER ]] && { show_help ; exit 1 }

    REGION=$( echo $REGION | tr '[:upper:]' '[:lower:]') #convert region to lowercase
    for i in $VALID_REGIONS
        [[ $REGION == $i ]] && { invalid_region=false ; break }

    $invalid_region && { show_help ; exit 1 }

    SUMMONER=$( echo $SUMMONER | sed s/\ //g | tr '[:upper:]' '[:lower:]' ) #Convert the name to lowercase and strip spaces

    if ! which notify-send 1>/dev/null ; then
        echo 'notify-send not found' 1>&2
        NOTIFY=false
    fi
}

unset FILE
unset REGION
unset SUMMONER
unset OVERWRITE
unset HOURS
unset LINE
NOTIFY=false
VALID_REGIONS=( euw na eune br lan las oce kr tr ru )

while :
do
    case $1 in
        -h)
            show_help
            exit 0
            break
            ;;
        -a)
            FILE=$2
            OVERWRITE=false
            shift 2
            ;;
        -o)
            FILE=$2
            OVERWRITE=true
            shift 2
            ;;
        -r)
            REGION=$2
            shift 2
            ;;
        -s)
            SUMMONER=$2
            shift 2
            ;;
        -n)
            NOTIFY=true
            shift
            ;;
        --) # End of all options (?)
            shift
            break
            ;;
        *) # no more options. Stop while loop
            break
            ;;
    esac
done

validate_args
get_hours
gen_line

$NOTIFY && notify-send "$LINE"
if [[ -z $FILE ]]; then
    echo $LINE
else
    $OVERWRITE && echo $LINE > $FILE || echo $LINE >> $FILE
fi
