#!/bin/bash
#
# check_wmi_event - nagios plugin for agentless checking of Windows Event Log 
#
# Copyright (C) 2014 Kenneth Moller 
# kenneth.moller (at) gmail.com
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
#
#############################################################################
# TOOD
#
# Figure out to change timeout on WMIC!! Do you know please drop me a mail 
#
#############################################################################
#
# Version 1.1
#
# added extra argument -s , thats give you the possibility to match a 
# text string in message  
#
# -s "System.Net.WebException: The operation has timed out" 
#
# This will add to the WQL :
#
# 'and message like "%System.Net.WebException: The operation has timed out%"'
#
#############################################################################
#
# Version 1.2
#
# Bug fix - when using -C custom critical text 
#
#
#############################################################################
#
# Version 1.3
#
# added to the -t, -e, -s, -S and -l  argument , so that you can select multipel arguments.
# 
# fx. if you want to look for event type warning and error use:   -t 1,2
#
#############################################################################
#
# Version 1.4
#
# Bug fix .. error in script when -c or -w wasnt set
#
#############################################################################
#
# Version 1.5 by rojobull
#
# Bug fix - getops line Was missing a colon after the S optin which would ignor the source name provided.
# Bug fix - adjust WQL_Constructor function so that spaces are not used as a delimiter.
# Bug fix - changed $USER variable to $UNAME. $USER is a system variable and will always be set.
# Improvement. Changed the date option to convert time into UTC instead of specifying an offset
# Added option to use a credentials file instead of passing 
#
#############################################################################
VERSION=1.5

#echo $* >> /tmp/event

DEBUG=0
EXITCODE=0
EXITSTRING=""
LASTSTR=""
MARCOLIST="ITEMCOUNT,LASTSTR"
ERROR_EVENTTYPE=""

E_SUCCESS="0"
E_WARNING="1"
E_CRITICAL="2"
E_UNKNOWN="3"



## TMP directory where wmic outputs 

TMPDIR=/tmp

## WMIC binary

WMIC=/bin/wmic

## Custom exit test , can be set as an argumenten in command  line as  -O ,-W ,-C, -U 

CUSTOM_EXIT_STR[$E_SUCCESS]=""
CUSTOM_EXIT_STR[$E_WARNING]=""
CUSTOM_EXIT_STR[$E_CRITICAL]=""
CUSTOM_EXIT_STR[$E_UNKNOWN]=""


##


E_STR[0]="OK"
E_STR[1]="WARNING"
E_STR[2]="CRITICAL"
E_STR[3]="UNKNOWN"

ETYPE[1]="Error"
ETYPE[2]="Warning" 
ETYPE[3]="Information"
ETYPE[4]="Security Audit Success"
ETYPE[5]="Security Audit Failure"




usage()
{
cat << EOF
usage: $0 options

check_wmi_eventid is a script to check windows event log , for a certian eventid..

Simple example : check application log , for eventtype error(-t) and  eventid 9003(-e) with in the last 60 mins(-m60),
set warning (-w) if greater than 1 ,and set error(-c) if greater than 3

check_wmi_eventid  -H 172.10.10.10 -u domain/user -p password -l application -e 9003  -w 1 -c 3  -t1 -m60


Adv. example : same as above , but with arguments -O -W -C, these are custom plugin output for OK,Warning and Critical
Marco $MARCOLIST , can be used!!


check_wmi_eventid  -H 172.10.10.10 -u domain/user -p password -l application -e 9003  -w 1 -c 3  -t1 -m60 -O "Every thing is OK"
-W "Warning : something is not right" -C "It is totaly bad , found ITEMCOUNT events"

With Eventtype error, warning and Information

check_wmi_eventid  -H 172.10.10.10 -u domain/user -p password -l application -e 9003  -w 1 -c 3  -t1,2,3 -m60 -O "Every thing is OK"
-W "Warning : something is not right" -C "It is totaly bad , found ITEMCOUNT events"


Try it out :)

If you find any error , please let me know



 

OPTIONS:
   -h      Show this message
   -H	   Host/Ip
   -u      Domain/user
   -p      password
   -f      path to credentials file instead. user and password ignored if set. First line Domain\user, second line password
   -l      Name of the log eg "System" or "Application" or any other Event log as shown in the Windows "Event Viewer".
   -t      Eventtype: # 1=error , 2=warning , 3=Information,4=Security Audit Success,5=Security Audit Failure. Multiple Eventypes  possible with , separation
   -e 	   Eventid, Multiple Eventids possible with , separation
   -s      Sting search for string in message,Multiple strings possible with , separation
   -S	   SourceName ,Multiple SourceNames possible with , separation
   -m 	   Number of past min to check for events.	
   -w	   Warning 
   -W	   Custom waring string    - ITEMCOUNT,LASTSTR marco can be used  ex. -W "ITEMCOUNT Wanings  with in the LASTSTR"
   -c	   Critical
   -C      Custom critical string  - ITEMCOUNT,LASTSTR marco can be used  ex. -W "ITEMCOUNT Critical  with in the LASTSTR"
   -O	   Custom ok sting         - ITEMCOUNT,LASTSTR marco can be used  ex. -W "Everything ok with in the LASTSTR"
   -U	   CUstom unknown string   - ITEMCOUNT,LASTSTR marco can be used  ex. -W "ITEMCOUNT  Unknowns  with in the LASTSTR"
   -d	   Debug
   -v      Version
EOF
}


while getopts ":hH:u:p:f:l:t:e:s:S:m:w:c:dW:C:O:U:v" OPTION;
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         H)
             HOST=$OPTARG
             ;;
         u)
             UNAME=$OPTARG
             ;;
         p)
             PASSWD=$OPTARG
             ;;
         f)
             CREDS=$OPTARG
             ;;
         l)
             LOGFILE=$OPTARG
             ;;
	 t)
             EVENTTYPE=$OPTARG
             ;;
	 e)
             EVENTID=$OPTARG
             ;;
 	 s)
             STRING=$OPTARG
             ;;
	 S) 
	     SOURCENAME=$OPTARG
	     ;;
	 m)
             MIN=$OPTARG
             ;;
	 w)
             WARNING=$OPTARG
             ;;
  	 c)
             CRITICAL=$OPTARG
             ;;
	 d)
	     DEBUG=1
	     ;;
     	 W)
             ##custom Warning string
	     CUSTOM_EXIT_STR[$E_WARNING]=$OPTARG
             ;;
	 C)
	     ##custom critical string
             CUSTOM_EXIT_STR[$E_CRITICAL]=$OPTARG 
             ;;
	 O)
	     ##custom ok string
	     CUSTOM_EXIT_STR[$E_SUCCESS]=$OPTARG
             ;;
	 U)
	     ##custom unknown string
             CUSTOM_EXIT_STR[$E_UNKNOWN]=$OPTARG
             ;;
         v)
	     echo "Version : $VERSION"
	     exit
	     ;;
	 ?)
             usage
             exit
             ;;
     esac
done

## check arguments
if [[ -z $CREDS ]]
then
	if [[ -z $HOST ]] || [[ -z $UNAME ]] || [[ -z $PASSWD ]] || [[ -z $LOGFILE ]] || [[ -z $EVENTTYPE ]]
	then
     		usage
     		exit ${E_CRITICAL}
	fi
else
        if [[ -z $HOST ]] || [[ -z $LOGFILE ]] || [[ -z $EVENTTYPE ]]
        then
                usage
                exit ${E_CRITICAL}
        fi
        #using cred file so set UNAME and PASSWD
        if [[ -e $CREDS ]]
	then
		UNAME=`sed '1!d' $CREDS`
		PASSWD=`sed '2!d' $CREDS`
	else
		echo "Credentials file does not exist"
		exit ${E_CRITICAL}
	fi
fi


TMPFILE=$TMPDIR/$RANDOM$RANDOM".wmi"
NOW=`date -u --date="$MIN min ago" +%Y%m%d%H%M%S".000000-000"`

function WQL_Constructor 
{
  local WS=$1
  local WS_FIELD=$2
  local WS_TYPE=$3		
  if [ -n "$WS" ]
  then
  	local WS_WQL=" ( "
  	INDEX=0
	IFS=',' read -a WS_ARRAY <<< "$WS"

	for WS_ELEMENT in "${WS_ARRAY[@]}";
        	do
       	 		((INDEX++))
			if [[ $WS_TYPE == "like" ]]
			then
        			WS_WQL+=$WS_FIELD' like "%'$WS_ELEMENT'%"'
			else
				WS_WQL+=$WS_FIELD' = "'$WS_ELEMENT'"'
			fi 
        
			if [ $INDEX -lt "${#WS_ARRAY[@]}" ]
        		then
                		WS_WQL+=" or "
			else
   				WS_WQL+=" ) and "
        		fi


	done
  fi
echo $WS_WQL
}

EXTRA_WQL=" "$(WQL_Constructor "$LOGFILE"  "Logfile" "" )
EXTRA_WQL+=" "$(WQL_Constructor "$EVENTID" "eventcode" "")
EXTRA_WQL+=" "$(WQL_Constructor "$SOURCENAME" "SourceName" "like")
EXTRA_WQL+=" "$(WQL_Constructor "$STRING"  "Message" "like")
EXTRA_WQL+=" "$(WQL_Constructor "$EVENTTYPE"  "EventType" "" )
#echo $ERROR_EVENTTYPE
#echo $EXTRA_WQL



WQL='Select EventCode,EventIdentifier,EventType,SourceName from Win32_NTLogEvent where '$EXTRA_WQL' TimeGenerated > "'$NOW'"'
##WQL='Select EventCode,EventIdentifier,EventType from Win32_NTLogEvent where logfile="'$LOGFILE'" and eventcode='$EVENTID'  and TimeGenerated > "'$NOW'" '$EXTRA_WQL
echo $WQL
## debug

if [ $DEBUG -eq 1 ]; then


echo "$WMIC --namespace root/cimv2  -U $UNAME%$PASSWD --option='client ntlmv2 auth'=Yes //$HOST '--delimiter=\"|\"'  '"$WQL"'"

fi


ERROR=$($WMIC --namespace root/cimv2  -U $UNAME%$PASSWD --option='client ntlmv2 auth'=Yes //$HOST --delimiter="|"   "$WQL" 2>&1> $TMPFILE )

if [ $DEBUG -eq 1 ]; then

cat $TMPFILE  | sed 1,2d

fi


## WMIC error

if [ ${#ERROR} -gt 0 ]; then
	echo " WMIC ERROR : "$ERROR	
	exit ${E_UNKNOWN}
fi


## make min human-readable

ITEMCOUNT=`cat $TMPFILE | sed 1,2d | wc -l`
DAYS=$(($MIN / 1440))
HOURS=$((($MIN/60) - ($DAYS * 24)))
MINS=$(($MIN - ($DAYS * 1440)-($HOURS * 60)))
if [ $DAYS -gt 0 ] ;then LASTSTR="$DAYS Days,";fi
if [ $HOURS -gt 0 ] ;then LASTSTR="$LASTSTR $HOURS hour";fi
if [ $MINS -gt 0 ] ;then LASTSTR="$LASTSTR $MINS min";fi


## Check Thresholds

if [ -n "$WARNING" ];then
	if [ $ITEMCOUNT -ge $WARNING ]; then 
		EXITCODE=${E_WARNING}
	fi
fi

if [ -n "$CRITICAL" ];then
	if [ $ITEMCOUNT -ge  $CRITICAL ]; then
		EXITCODE=${E_CRITICAL}
	fi
fi

## replace marcos

EXITSTRING=${CUSTOM_EXIT_STR[$EXITCODE]}
EXITSTRING=${EXITSTRING//ITEMCOUNT/$ITEMCOUNT}
EXITSTRING=${EXITSTRING//LASTSTR/$LASTSTR}

IFS=', ' read -a EV_ARRAY <<< "$EVENTTYPE"
for EV_ELEMENT in ${EV_ARRAY[@]}    
	do
 		ERROR_EVENTTYPE+=${ETYPE[$EV_ELEMENT]}","
	done 

## if no custom output string , set it to default  

if [ ${#EXITSTRING} -eq 0 ]; then 

	EXITSTRING="${E_STR[$EXITCODE]} $ITEMCOUNT with Severity Level ${ERROR_EVENTTYPE%?}   in $LOGFILE with in  the last $LASTSTR"
fi


## perf data

 
EXITSTRING="$EXITSTRING|eventid$EVENTID=$ITEMCOUNT;$WARNING;$CRITICAL;;"

## housekeeping

rm -f $TMPFILE



echo $EXITSTRING
exit $EXITCODE




