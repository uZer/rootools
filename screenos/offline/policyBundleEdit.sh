#!/bin/bash
# Build local inventories
set -euo pipefail
IFS=$'\n\t '
#
# Youenn Piolet
# <piolet.y@gmail.com>
#
# Version 0.2
# Sept. 27, 2012
#
# Policy List Changer for Juniper SSG

# You can add a custom change comment here.
# Don't forget to add a \n at the end of line as this script use a premade
# string and sed
CHANGE=""

# Output configuration
OUTPUTFILE="changeProcedure.txt"

# Temporary input file
# DO NOT EDIT THIS
TMPINPUTFILE=".___tmpinput"
INPUTFILE=$TMPINPUTFILE

display_help()
{
    cat <<EOF
Usage: ./PolicyListChanger OPTIONS

PolicyListChanger generates a file called "$OUTPUTFILE" in the current
directory, that contains a bunch of commands to type in a JUNIPER firewall in
order to edit a bundle of policies.

OPTIONS:
  -h                 Show this message

  -a <src>           Adding source address <src> in policies
  -b <dst>           Adding dest address <src> in policies
  -s "<old> <new>"   Replace src-address <old> by <new> (don't forget the quotes)
  -d "<old> <new>"   Replace dst-address <old> by <new> (don't forget the quotes)
  -l                 Enable Log
  -n <name>          Apply a new name <name> to the policy
  -p "<old> <new>"   Replace service <old> by <new> in policy

 REQUIRED
  -f <filename>      Take as input a file containing IDs of the policies to edit
     OR
  -i <list>          Take as input a list of policy IDs separated by spaces

EOF
    exit 0
}

COMMAND=$@

# No args
if [[ $# -eq 0 ]]; then display_help; fi

# getopts
while getopts ":hf:i:s:d:p:ln:a:b:" OPT; do
    case $OPT in
        h)  display_help ;;

        f)  INPUTFILE="$OPTARG";;
        i)
            for i in ${OPTARG}; do
                if [[ $i =~ ^[0-9]+$ ]]; then
                    echo $i >> $INPUTFILE
                else
                    echo "Your policy list must contain policy IDs"
                    echo "separated by spaces"
                    exit 99
                fi
            done
            ;;

        s)
            ((__count=1))
            for i in ${OPTARG}; do
                case $__count in
                    1) OLD="${i}";;
                    2) NEW="${i}";;
                    *)
                        echo "Invalid format for \"<old Source> <New Source>\""
                        exit 3
                        ;;
                esac
                ((__count=$__count+1))
            done
            CHANGE="${CHANGE}set src-address $NEW\nunset src-address $OLD\n"
            ;;

        d)
            ((__count=1))
            for i in ${OPTARG}; do
                case $__count in
                    1) OLD="${i}";;
                    2) NEW="${i}";;
                    *)
                        echo "Invalid format for \"<old Dest> <New Dest>\""
                        exit 3
                        ;;
                esac
                ((__count=$__count+1))
            done
            CHANGE="${CHANGE}set dst-address $NEW\nunset dst-address $OLD\n"
            ;;

        p)
            ((__count=1))
            for i in ${OPTARG}; do
                case $__count in
                    1) OLD="${i}";;
                    2) NEW="${i}";;
                    *)
                        echo "Invalid format for \"<old service> <New service>\""
                        exit 3
                        ;;
                esac
                ((__count=$__count+1))
            done
            CHANGE="${CHANGE}set service $NEW\nunset service $OLD\n"
            ;;

        l)  CHANGE="${CHANGE}set log\n"
            ;;

        a)
            CHANGE="${CHANGE}set src-address $OPTARG\n"
            ;;
        b)
            CHANGE="${CHANGE}set dst-address $OPTARG\n"
            ;;

        n)  CHANGE="${CHANGE}set name \"$OPTARG\"";;

        ?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 2
            ;;
    esac
done
shift `expr $OPTIND - 1`

[[ ! -e $INPUTFILE ]] && echo "You must specify an existing input" && exit 5

# Clear other opt
# (( $# )) && echo "Invalid arguments" && exit 55

if [ -e $OUTPUTFILE ]; then
    cat <<EOF
Output file "$OUTPUTFILE" already exists, do you want to:"
  (1)  Clear it
  (2)  Append the new results
EOF
    read
    [ "$REPLY" == "1" ] && echo "" > $OUTPUTFILE
fi

echo '
#################################################################################
##' `basename $0` $COMMAND '
## Date of generation:' `date`'
############################ THE BUNDLE STARTS HERE #############################
' >> $OUTPUTFILE

cat $INPUTFILE | sed '/^$/d' | sed s%^%"set policy id "%g | \
    sed s%$%"\n${CHANGE}exit\n"%g >> $OUTPUTFILE
echo '
############################  THE BUNDLE ENDS HERE  #############################
' >> $OUTPUTFILE
echo "" >> $OUTPUTFILE

cat $OUTPUTFILE
[[ -e $TMPINPUTFILE ]] && rm $TMPINPUTFILE

exit 0
