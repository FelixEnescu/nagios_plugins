#!/bin/bash

#
# Send email for service notification
#

#
# Args: command_line    /usr/bin/printf "%b" "***** Icinga *****\n\nNotification Type: $NOTIFICATIONTYPE$\n\nService: $SERVICEDESC$\nHost: $HOSTALIAS$\nAddress: $HOSTADDRESS$\nState: $SERVICESTATE$\n\nDate/Time: $LONGDATETIME$\n\nAdditional Info:\n\n$SERVICEOUTPUT$\n\nService Perfdata: http://monitor.qsol.ro/pnp4nagios/index.php/graph?host=$HOSTNAME$&srv=$SERVICEDESC$\nHost Information: http://monitor.qsol.ro/icinga/cgi-bin/extinfo.cgi?type=1&host=$HOSTNAME$\nCurrent Network Status: http://monitor.qsol.ro/icinga/cgi-bin/status.cgi?host=$HOSTNAME$&nostatusheader\n" | /usr/bin/mail -s "** $NOTIFICATIONTYPE$ Service Alert: $HOSTALIAS$/$SERVICEDESC$ is $SERVICESTATE$ **" $CONTACTEMAIL$
#
#NOTIFICATIONTYPE 1
#SERVICEDESC 2
#HOSTNAME 3
#HOSTALIAS 4
#HOSTADDRESS 5
#SERVICESTATE 6
#LONGDATETIME 7
#SERVICEOUTPUT 8
#CONTACTEMAIL 9
#
#

if [ -z "$1" ]; then
	echo "NOTIFICATIONTYPE is not defined"
	exit 127;
else
	NOTIFICATIONTYPE="$1"
fi

if [ -z "$2" ]; then
	echo "SERVICEDESC is not defined"
	exit 128;
else
	SERVICEDESC="$2"
fi

if [ -z "$3" ];then
	echo "HOSTNAME is not defined"
	exit 129;
else
	HOSTNAME="$3"
fi

if [ -z "$4" ];then
	echo "HOSTALIAS is not defined"
	exit 130;
else
	HOSTALIAS="$4"
fi

if [ -z "$5" ];then
	echo "HOSTADDRESS is not defined"
	exit 131;
else
	HOSTADDRESS="$5"
fi

if [ -z "$6" ]; then
	echo "SERVICESTATE is not defined"
	exit 132;
else
	SERVICESTATE="$6"
fi

if [ -z "$7" ];then
	echo "LONGDATETIME is not defined"
	exit 133;
else
	LONGDATETIME="$7"
fi

if [ -z "$8" ]; then
	echo "SERVICEOUTPUT is not defined"
	exit 134;
else
	SERVICEOUTPUT="$8"
fi

if [ -z "$9" ]; then
	echo "CONTACTEMAIL is not defined"
	exit 135;
else
	CONTACTEMAIL="$9"
fi

SERVICEDESC_CLEAN=`echo "$SERVICEDESC" | tr ' ' '_'`

#/usr/bin/printf "%b" "Notification Type: $NOTIFICATIONTYPE\n\nService: $SERVICEDESC_CLEAN\nHost: $HOSTNAME\nHost alias: $HOSTALIAS\nAddress: $HOSTADDRESS\nState: $SERVICESTATE\nDate/Time: $LONGDATETIME\n\nAdditional Info:$SERVICEOUTPUT\n\nService Perfdata: http://monitor.qsol.ro/pnp4nagios/index.php/graph?host=$HOSTNAME&srv=$SERVICEDESC_CLEAN\nHost Information: http://monitor.qsol.ro/icinga/cgi-bin/extinfo.cgi?type=1&host=$HOSTNAME\nHost Service Detail: http://monitor.qsol.ro/icinga/cgi-bin/status.cgi?host=$HOSTNAME&nostatusheader\n" | /bin/mail -s "** $NOTIFICATIONTYPE: $HOSTALIAS/$SERVICEDESC is $SERVICESTATE **" $CONTACTEMAIL

/usr/bin/printf "%b" "Notification Type: $NOTIFICATIONTYPE\n\nService: $SERVICEDESC_CLEAN\nHost: $HOSTNAME\nHost alias: $HOSTALIAS\nAddress: $HOSTADDRESS\nState: $SERVICESTATE\nDate/Time: $LONGDATETIME\n\nAdditional Info:$SERVICEOUTPUT\n\nService Perfdata: http://monitor.qsol.ro/pnp4nagios/index.php/graph?host=$HOSTNAME&srv=$SERVICEDESC_CLEAN\nHost Information: http://monitor.qsol.ro/icinga/cgi-bin/extinfo.cgi?type=1&host=$HOSTNAME\nHost Service Detail: http://monitor.qsol.ro/icinga/cgi-bin/status.cgi?host=$HOSTNAME&nostatusheader\n" | /bin/mail -s "** $NOTIFICATIONTYPE: $HOSTALIAS/$SERVICEDESC is $SERVICESTATE **" $CONTACTEMAIL
