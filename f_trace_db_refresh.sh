#!/bin/bash
#---------------------------------------------------------------------#
# FONCTIONS:
#    - f_trace: Write a line in the trace file
#    - f_trace_error_only: Write a line in the trace file
#           only if the return code is different from 0
#---------------------------------------------------------------------#


function f_trace
{
	date_fin=`date +%Y-%m-%d" "%T"."%N`

	rc_cmd=$1
	str_Timestamp_Key_cmd=$2
	str_Step_cmd=$3
	date_deb=$4
	
	nanosec_deb=`date -d "${date_deb}" +%s%N`
	nanosec_fin=`date -d "${date_fin}" +%s%N`
	duration=`expr ${nanosec_fin:0:10} - ${nanosec_deb:0:10}`
	durationNano=`expr $nanosec_fin - $nanosec_deb`

	if [ ${rc_cmd} -eq 0 ]
	then
		echo "OK;"${str_Timestamp_Key_cmd}";"${str_Step_cmd}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
	else
		echo "ERROR;"${str_Timestamp_Key_cmd}";"${str_Step_cmd}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
		exit 1
	fi
}

function f_trace_error_exit
{
	date_fin=`date +%Y-%m-%d" "%T"."%N`

	rc_cmd=$1
	str_Timestamp_Key_cmd=$2
	str_Step_cmd=$3
	date_deb=$4
	
	nanosec_deb=`date -d "${date_deb}" +%s%N`
	nanosec_fin=`date -d "${date_fin}" +%s%N`
	duration=`expr ${nanosec_fin:0:10} - ${nanosec_deb:0:10}`
	durationNano=`expr $nanosec_fin - $nanosec_deb`

	if [ ${rc_cmd} -ne 0 ]
	then
		echo "ERROR;"${str_Timestamp_Key_cmd}";"${str_Step_cmd}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
		exit 1
	fi
}