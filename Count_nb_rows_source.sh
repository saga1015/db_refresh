#!/bin/bash
source /usr/local/greenplum-db/greenplum_path.sh

int_Nb_Thread=4

str_host=mdw
str_database=reporting
str_user=gpadmin

str_host_target=10.10.171.14
str_database_target=reporting
str_user_target=gpadmin
#str_password_target=changeme

str_Connection_String="dbname=${str_database} user=${str_user}"
str_Connection_String_Target="dbname=${str_database_target} user=${str_user_target}"

echo  ${str_Connection_String}
echo  ${str_Connection_String_Target}

str_Schema="'"$1"'"
str_Schema_without_quote=$1


str_script_dir="$( cd "$( echo "${BASH_SOURCE[0]%/*}" )"; pwd )"

str_root_dir=${str_script_dir}
str_Log=${str_root_dir}/log/Count_nb_rows_source_`date +%Y%m%d`.log
str_Trace=${str_root_dir}/trace/Count_nb_rows_source.trace
str_Output=${str_root_dir}/output/Count_nb_rows_source_`date +%Y%m%d`.out
str_Dir_Sql=${str_root_dir}/sql
>${str_Output}
chmod 777 ${str_Output}
###################################################################################################
### Count nb rows per table in the source environment
###################################################################################################
str_Step="Count NB rows Source"
str_Qry=${str_Dir_Sql}/count_nb_rows.sql

date_deb=`date +%d/%m/%Y" "%T" "%N`
sec_deb_global=`date +%s`
sec_deb=`date +%s`
nanosec_deb=`date +%s%N`

psql -tXA -f ${str_Qry} -h ${str_host} -d "${str_Connection_String}" -v v_schema=${str_Schema} | xargs -d '\n'  -P ${int_Nb_Thread} -n 1 -I{} psql -tXA -h ${str_host} -d "${str_Connection_String}" -v ON_ERROR_STOP=1 -c {} >> ${str_Output} 2>${str_Log}

rc_qry=$?
date_fin=`date +%d/%m/%Y" "%T" "%N`
sec_fin=`date +%s`

duration=`expr $sec_fin - $sec_deb`
nanosec_fin=`date +%s%N`
durationNano=`expr $nanosec_fin - $nanosec_deb`
durationGlobale=`expr $sec_fin - $sec_deb_global`

if [ ${rc_qry} -ne 0 ]
then
        echo ${str_database}";ERROR;"${str_Step}";"${str_Schema_without_quote}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
fi

###################################################################################################
### Load in the table db_refresh.count_nb_rows_source
###################################################################################################
str_Qry="COPY db_refresh.count_nb_rows_source from stdin with delimiter '|'"
cat ${str_Output} | psql -p 15432 -h ${str_host_target} -d "${str_Connection_String_Target}" -v ON_ERROR_STOP=1 -c "${str_Qry}"

rc_qry=$?
date_fin=`date +%d/%m/%Y" "%T" "%N`
sec_fin=`date +%s`

duration=`expr $sec_fin - $sec_deb`
nanosec_fin=`date +%s%N`
durationNano=`expr $nanosec_fin - $nanosec_deb`
durationGlobale=`expr $sec_fin - $sec_deb_global`

if [ ${rc_qry} = 0 ]
then
        echo ${str_database}";OK;"${str_Step}";"${str_Schema_without_quote}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
else
        echo ${str_database}";ERROR;"${str_Step}";"${str_Schema_without_quote}";"$date_deb";"$date_fin";"$duration";"$durationNano >>${str_Trace}
fi


