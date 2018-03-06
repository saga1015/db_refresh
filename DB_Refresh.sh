#!/bin/bash

###################################################################################################
### Initialize the variables
###################################################################################################
source /usr/local/greenplum-db/greenplum_path.sh
str_script_dir="$( cd $( dirname "${BASH_SOURCE[0]}" ) && pwd )"

str_root_dir=${str_script_dir}
str_Trace=${str_root_dir}/trace/restore.trace
str_Dir_Sql=${str_root_dir}/sql
str_Dir_Log=${str_root_dir}/log
str_Dir_Temp=${str_root_dir}/temp
str_Dir_Cfg=${str_root_dir}
str_Dir_toolbox=${str_root_dir}

date_deb_global=`date +%Y-%m-%d" "%T"."%N`

unset str_Target_DB
unset flag_CONFIG_FILE
unset str_Timestamp_Key
unset str_Dir_Dump_Root
unset flag_DDL
unset flag_TRUNCATE
unset flag_DDBOOST
unset flag_INDEX
unset flag_RULE
flag_NOANALYZE=0
int_Nb_Thread=1
unset int_Nb_DB_Seg_Source
unset int_Nb_DB_Seg_Target

#internal variables
unset flag_COMPRESS
unset flag_OLDFILENAMES
unset str_Master_Dumpfile



###################################################################################################
### Help
###################################################################################################

usage() {
	echo "#############################################################################################"
	echo "      `basename $0`"
	echo
	echo "      Restore gpcrondump dumps whatever the number of source and target segments"
	echo
	echo "      Usage:"
	echo "      $0 [OPTIONS]"
	echo
	echo "      General options:"
	echo "        -?, display this help message & exit"
	echo "        -t, Timestamp Key of the dump"
	echo
	echo "      Optional options:"
	echo "        -d, Target Database"
	echo "        -u, Directory of the dump files "
	echo "        -c, Flag set if use of a configuration file "
	echo "             If use of config file, only parameters from config files are used: "
	echo "             the online parameter will be ignored (except the option -t) "
        echo "        -s, Flag set if must create schema from backup "
	echo "        --ddboost, Flag True if the backup was performed by DDBOOST"
	echo "        --truncate, Flag True if the target tables have to be truncated before the restore"
	echo "        --noanalyze, Flag True if the target tables have to be analyzed after the restore"
	echo "        --index, Flag True if the target indexes have to be dropped before the restore"
	echo "        --rule, Flag True if the target rules have to be dropped before the restore"
	echo "        --nbsource=<val>, Number of source DB segments in the dump"
	echo "        --nbtarget=<val>, Number of target DB segments"
	echo "        --nbthread=<val>, Number of threads for analyze, reorganize, ... (by default, 1)"
	echo
	echo "#############################################################################################"

	exit 1;
}

###################################################################################################
### Step 1: Check Parameters
###################################################################################################
str_Step=CHECK_PARAMETERS
date_deb=`date +%Y-%m-%d" "%T"."%N`

options="'?'hcst:u:d:-:"
while getopts $options opt; do
	case "${opt}" in
		'?'|h)
			usage
			;;
		c) flag_CONFIG_FILE=1;;
		s) flag_DDL=1 ;;
		d) str_Target_DB=$OPTARG;;
		t) str_Timestamp_Key=$OPTARG ;;
		u) str_Dir_Dump_Root=$OPTARG ;;
		-) # Long options ...
			case ${OPTARG} in
				truncate ) flag_TRUNCATE=1 ;;
				ddboost ) flag_DDBOOST=1 ;;
				noanalyze ) flag_NOANALYZE=1 ;;
				index ) flag_INDEX=1 ;;
				rule ) flag_RULE=1 ;;
				nbsource=*) int_Nb_DB_Seg_Source=${OPTARG#*=};;
				nbtarget=*) int_Nb_DB_Seg_Target=${OPTARG#*=};;
				nbthread=*) int_Nb_Thread=${OPTARG#*=};;
				* ) usage ;;
			esac
			;;
		\?)
			echo "Invalid option: -$OPTARG"
			exit 1
			;;
		:)
			echo "Option -$OPTARG requires an argument."
			exit 1
			;;
		* ) echo "Unrecognized option: $1"
		exit 1
		;;
	esac
done
shift $((OPTIND-1))

##Check the mandatory parameters

# If use of config file, only parameters from config files are used: the online parameter will be ignored (except the option -t)
if [ "$flag_CONFIG_FILE" == "1" ]; then
	unset str_Target_DB
	unset str_Dir_Dump_Root
	flag_DDL=0
	unset flag_TRUNCATE
	unset flag_DDBOOST
	unset flag_INDEX
	unset flag_RULE
	flag_NOANALYZE=0
	unset int_Nb_DB_Seg_Source
	unset int_Nb_DB_Seg_Target
	int_Nb_Thread=1
	. ${str_Dir_Cfg}/DB_Refresh.cfg
fi


###################################################################################################
### Included functions
###################################################################################################
export FPATH=${str_Dir_toolbox}
. $FPATH/f_trace_db_refresh.sh

echo "####################################################################################################"
echo "str_Timestamp_Key:"$str_Timestamp_Key"."
echo "str_Target_DB:"$str_Target_DB"."
echo "str_Dir_Dump_Root:"$str_Dir_Dump_Root"."
echo "int_Nb_DB_Seg_Source:"$int_Nb_DB_Seg_Source"."
echo "int_Nb_DB_Seg_Target:"$int_Nb_DB_Seg_Target"."
echo "int_Nb_Thread:"$int_Nb_Thread"."
echo "ddboost:"$flag_DDBOOST"."
echo "schema creation:"$flag_DDL"."
echo "noanalyze:"$flag_NOANALYZE"."
echo "truncate:"$flag_TRUNCATE"."
echo "flag_INDEX:"$flag_INDEX"."
echo "flag_RULE:"$flag_RULE"."
echo "####################################################################################################"
echo " "

if [ -z $str_Target_DB ];
then
	echo "ERROR: Target database not specified"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

if ! [[ $str_Timestamp_Key =~ ^[0-9]{14}$ ]];
then
	echo "ERROR: Incorrect value of the parameter Timestamp_Key ($str_Timestamp_Key): Should be 14 digits"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

if ! [[ $int_Nb_DB_Seg_Source =~ ^[0-9]+$ ]];
then
	echo "ERROR: Incorrect value for number of segments of source backup ($int_Nb_DB_Seg_Source)"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi
str_Dir_Dump=${str_Dir_Dump_Root}${str_Timestamp_Key:0:8}

###################################################################################################
### Step 1: Create db_refresh schema
###################################################################################################
str_Step=CREATE_TECH_SCHEMA
echo `date +%Y-%m-%d" "%T ` 'Start'
flag_DBREFRESH_SCHEMA_EXISTS=`psql -d ${str_Target_DB} -Atc "select count(*) from pg_namespace where nspname='db_refresh';"`
if [ $? -ne 0 ]
then
	echo "ERROR: problem with connection to database"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

if [ $flag_DBREFRESH_SCHEMA_EXISTS -eq 0 ]
then
	echo `date +%Y-%m-%d" "%T ` "Step  1: Create db_refresh schema"
	psql -d ${str_Target_DB} -f ${str_Dir_Sql}/DDL_db_refresh.sql >/dev/null
fi

###################################################################################################
### Step 2: Create the list of dump files
###################################################################################################
str_Step=LIST_DUMP_FILES
echo `date +%Y-%m-%d" "%T ` 'Step  2: Create the list of dump files'
str_Output2=${str_Dir_Temp}/list_dump_file_${str_Timestamp_Key}.out
date_deb=`date +%Y-%m-%d" "%T"."%N`

# Get backup directory contents
# Here gpddboost returns filenames only while ls returns full path.
# But finally we should have full path filenames in db_refresh.refresh_list_dump_file
if [ "${flag_DDBOOST}" == "1" ]
then
   gpddboost --listDirectory --dir=${str_Dir_Dump} |grep ${str_Timestamp_Key} > ${str_Output2}
else
   ls -1 ${str_Dir_Dump}/*${str_Timestamp_Key}* > ${str_Output2} 2>/dev/null
fi

# Find master backup file that contains database schema and
# determine filename convention of backup files:
#   new - gp_dump_<content>_<dbid>_<ts>  or
#   old - gp_dump_<0 or 1>_<content>_<ts>  - backup created by version below 4.3.12
str_Master_Dumpfile=`grep "gp_dump_-\?1_1_${str_Timestamp_Key}\(\.gz\)\?$" ${str_Output2}`
if [ -z ${str_Master_Dumpfile} ]
then
	echo "ERROR: Cannot find master backup file in ${str_Dir_Dump}"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

str_Master_Dumpfile=`basename ${str_Master_Dumpfile}`

if [[ "${str_Master_Dumpfile}" == *.gz ]];
then
   flag_COMPRESS=1
else
   flag_COMPRESS=0
fi

# Prepare list of dump files with data into delimeted file that will be loaded in db_refresh schema
str_Output=${str_Dir_Temp}/list_dump_file_${str_Timestamp_Key}.dat

if [[ "${str_Master_Dumpfile}" == gp_dump_1_1_* ]];
then
   flag_OLDFILENAMES=1
   grep "gp_dump_0_[0-9]\+_${str_Timestamp_Key}"       ${str_Output2} | sed -e "s/^/&${str_Timestamp_Key}|/g"|  nl -s "|" |sed 's/ //g'>${str_Output} 2>/dev/null
else
   flag_OLDFILENAMES=0
   grep "gp_dump_[0-9]\+_[0-9]\+_${str_Timestamp_Key}" ${str_Output2} | sed -e "s/^/&${str_Timestamp_Key}|/g"|  nl -s "|" |sed 's/ //g'>${str_Output} 2>/dev/null
fi

# Check the number of dump files
chmod 777 ${str_Output}
int_Nb_Files=`cat ${str_Output}|wc -l`

if [ ${int_Nb_Files} != ${int_Nb_DB_Seg_Source} ]
then
	echo "ERROR: Incorrect number of dump files: present ${int_Nb_Files}, expected ${int_Nb_DB_Seg_Source}"
	rc=1
	f_trace $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

# Load the list of files into the table db_refresh.refresh_list_dump_file
str_Qry="DELETE from db_refresh.refresh_list_dump_file where dump_timestampkey = ${str_Timestamp_Key}; "
str_Qry=${str_Qry}"COPY db_refresh.refresh_list_dump_file from '${str_Output}' WITH DELIMITER '|'; "
if [ "${flag_DDBOOST}" == "1" ]
then
	str_Qry=${str_Qry}"update db_refresh.refresh_list_dump_file set file_name='${str_Dir_Dump}/'||trim(file_name) where dump_timestampkey = ${str_Timestamp_Key};"
fi

psql -d ${str_Target_DB} -v ON_ERROR_STOP=1 -c "${str_Qry}" >/dev/null
rc_qry=$?

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"


###################################################################################################
### Step 3: Get the list of tables in the Dump File
###################################################################################################
str_Step=LIST_DUMP_TABLES
echo `date +%Y-%m-%d" "%T ` 'Step  3: Get the list of tables with gpdbrestore'
str_Output_Tmp=${str_Dir_Temp}/list_tables_${str_Timestamp_Key}.out
str_Output=${str_Dir_Temp}/list_tables_${str_Timestamp_Key}.dat
date_deb=`date +%Y-%m-%d" "%T"."%N`
if [ "$flag_DDBOOST" == "1" ]
then
	gpdbrestore -t ${str_Timestamp_Key} -L --ddboost --redirect ${str_Target_DB}                          > ${str_Output_Tmp}
else
	# remove db_dumps subfolder from root path
	gpdbrestore -t ${str_Timestamp_Key} -L -u ${str_Dir_Dump_Root/\/db_dumps*}  --redirect ${str_Target_DB} > ${str_Output_Tmp}
fi
rc_qry=$?
f_trace_error_exit $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"

chmod 777 ${str_Output_Tmp}
grep ":-Table " ${str_Output_Tmp} | sed -e "s/^/&${str_Timestamp_Key}|/g"	>	${str_Output}

rc_qry=$?
f_trace_error_exit $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"

chmod 777 ${str_Output}
int_Nb_Tables=`cat ${str_Output}|wc -l`

if [ ${int_Nb_Tables} -eq 0 ]
then
	echo "ERROR: No table to restore"
	rc=1
	f_trace_error_exit $rc ${str_Timestamp_Key} ${str_Step} "${date_deb}"
	exit 1
fi

# Load the list of tables into the table db_refresh.refresh_list_dump_table
str_Qry="DELETE from db_refresh.refresh_list_dump_table where dump_timestampkey = ${str_Timestamp_Key};"
str_Qry=${str_Qry}"COPY db_refresh.refresh_list_dump_table from '${str_Output}' WITH DELIMITER '|'"

psql -d ${str_Target_DB} -v ON_ERROR_STOP=1 -c "${str_Qry}"  >/dev/null
rc_qry=$?

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"

###################################################################################################
### Step 4: (optional) Restore schema
###################################################################################################
if [ "$flag_DDL" == "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step  4: Restore schema'
	str_Step=RESTORE_SCHEMA
	date_deb=`date +%Y-%m-%d" "%T"."%N`

	str_Output=${str_Dir_Log}/schema_restore_${str_Timestamp_Key}.log
	str_Err=${str_Dir_Log}/schema_restore_${str_Timestamp_Key}.err

	if [ "${flag_DDBOOST}" == "1" ]
	then
	   if [ "${flag_COMPRESS}" == "1" ]
	   then
	      gpddboost --readFile --from-file=${str_Dir_Dump}/${str_Master_Dumpfile}  | zcat | psql -d ${str_Target_DB} > ${str_Output} 2>${str_Err}
	   else
	      gpddboost --readFile --from-file=${str_Dir_Dump}/${str_Master_Dumpfile}  | psql -d ${str_Target_DB} > ${str_Output} 2>${str_Err}
	   fi
	else
	   if [ "${flag_COMPRESS}" == "1" ]
	   then
	      zcat ${str_Dir_Dump}/${str_Master_Dumpfile} | psql -d ${str_Target_DB} > ${str_Output} 2>${str_Err}
	   else
	      psql -d ${str_Target_DB} -f ${str_Dir_Dump}/${str_Master_Dumpfile} > ${str_Output} 2>${str_Err}
	   fi
	fi
	rc_qry=$?

	if [ -s ${str_Err} ]
	then
		echo "WARNING: Errors or warnings occured during schema restore. Review ${str_Err}"
	fi

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi


###################################################################################################
### Step 5: Save the DK
###################################################################################################
str_Step=SAVE_DK
echo `date +%Y-%m-%d" "%T ` 'Step  5: Save the DK'
str_Qry=${str_Dir_Sql}/DB_Refresh_Save_DK.sql
date_deb=`date +%Y-%m-%d" "%T"."%N`

# Save the Distribution Keys into the table db_refresh.save_table_distrib_key
psql -1 -d ${str_Target_DB}  -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -f ${str_Qry}  >/dev/null
rc_qry=$?

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"

###################################################################################################
### Step 6 (optional): Save the Indexes and PK
###################################################################################################
if [ "$flag_INDEX" == "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step  6: Save the Indexes and PK'
	str_Step=SAVE_INDEX_PK
	str_Qry=${str_Dir_Sql}/DB_Refresh_Save_Indexes_PK.sql
	date_deb=`date +%Y-%m-%d" "%T"."%N`

	psql -1 -d ${str_Target_DB}  -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -f ${str_Qry}  >/dev/null
	rc_qry=$?

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi

###################################################################################################
### Step 7 (optional): Drop the Indexes and PK
###################################################################################################
if [ "$flag_INDEX" == "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step  7: Drop the Indexes and PK'
	str_Step=DROP_INDEX_PK
	str_Qry=${str_Dir_Sql}/DB_Refresh_Drop_Indexes_PK.sql
	date_deb=`date +%Y-%m-%d" "%T"."%N`

	psql -1 -tXq -d ${str_Target_DB} -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -f ${str_Qry} | psql -1 -d ${str_Target_DB} -v ON_ERROR_STOP=1  >/dev/null
	rc_qry=$?

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi

###################################################################################################
### Step 8 (optional): Drop the rules
###################################################################################################
if [ "$flag_RULE" == "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step  8: Drop the rules'
	str_Step=DROP_RULES
	str_Qry=${str_Dir_Sql}/DB_Refresh_Drop_Rules.sql
	date_deb=`date +%Y-%m-%d" "%T"."%N`

	psql -1 -tXq -d ${str_Target_DB} -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -f ${str_Qry} | psql -1 -d ${str_Target_DB} -v ON_ERROR_STOP=1  >/dev/null
	rc_qry=$?

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi

###################################################################################################
### Step 9 (optional): Truncate the target tables
###################################################################################################
if [ "$flag_TRUNCATE" == "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step  9: Truncate the target tables'
	str_Step=TRUNCATE
	str_Qry=${str_Dir_Sql}/DB_Refresh_Truncate.sql
	date_deb=`date +%Y-%m-%d" "%T"."%N`

	psql -tX -f ${str_Qry} -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -d ${str_Target_DB} | xargs  -P ${int_Nb_Thread} -d"\n"  -n 1 -I{} psql -a -d ${str_Target_DB} -v ON_ERROR_STOP=1 -c {} >/dev/null
	rc_qry=$?

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi

###################################################################################################
### Step 10: Change the distribution of the restored tables from DK
###     to Randomly
###################################################################################################

str_Step=DK_to_RANDOMLY
echo `date +%Y-%m-%d" "%T ` 'Step 10: Change the distribution of the restored tables from DK to Random'
str_Qry=${str_Dir_Sql}/DB_Refresh_Change_DK_to_RANDOM.sql
date_deb=`date +%Y-%m-%d" "%T"."%N`

str_Output=${str_Dir_Log}/dktorandom_${str_Timestamp_Key}.log
str_Err=${str_Dir_Log}/dktorandom_${str_Timestamp_Key}.err

psql -1 -tXq -f ${str_Qry} -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -d ${str_Target_DB} | xargs  -P ${int_Nb_Thread} -d"\n"  -n 1 -I{} psql -a -d ${str_Target_DB} -c >${str_Output} 2>${str_Err} {}

rc_qry=$?

if [ -s ${str_Err} ]
then
	echo "WARNING: Errors or warnings occured during changing distribution to RANDOMLY. Review ${str_Err}"
fi

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"

###################################################################################################
### Step 11: Generate the loading script per db segment - Create a query file
###################################################################################################
str_Step=GENERATE_LOAD_SCRIPT
echo `date +%Y-%m-%d" "%T ` 'Step 11: Generate the loading script per db segment - Create a query file'
if [ "${flag_DDBOOST}" == "1" ]
then
	str_Qry=${str_Dir_Sql}/DB_Refresh_Restore_Script_Ddboost.sql
else
	str_Qry=${str_Dir_Sql}/DB_Refresh_Restore_Script.sql
fi
str_Output=${str_Dir_Temp}/DB_Refresh_Restore_Script_${str_Timestamp_Key}.sh
date_deb=`date +%Y-%m-%d" "%T"."%N`

>${str_Dir_Temp}/DB_Refresh_Restore_Script_${str_Timestamp_Key}.sh
psql -1 -t -d ${str_Target_DB} -v v_Target_DB="'${str_Target_DB}'" -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -f ${str_Qry} -o ${str_Output}  >/dev/null
rc_qry=$?

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
chmod 777 ${str_Dir_Temp}/DB_Refresh_Restore_Script_${str_Timestamp_Key}.sh


###################################################################################################
### Step 12: Execute the restore
###################################################################################################
str_Step=RUN_LOAD_SCRIPT
echo `date +%Y-%m-%d" "%T ` 'Step 12: Load data'
date_deb=`date +%Y-%m-%d" "%T"."%N`
. ${str_Dir_Temp}/DB_Refresh_Restore_Script_${str_Timestamp_Key}.sh  >/dev/null

failed=0
for i in $(seq ${int_Nb_DB_Seg_Source})
do
   wait ${plist[$i]}
   rv=$?
   echo " File $i: pid ${plist[$i]} returns $rv"
   if [[ $rv -ne 0 ]]
   then
     failed=1
   fi
done

wait

f_trace $failed ${str_Timestamp_Key} ${str_Step} "${date_deb}"

echo "End Load:" `date +%d/%m/%Y" "%T" "%N`

##################################################################################################
### Step 13: Reorganize + Change back the DK from RANDOMLY to Saved DK
###################################################################################################
str_Step=CHANGE_BACK_DK
echo `date +%Y-%m-%d" "%T ` 'Step 13: Reorganize + Change back the DK from RANDOMLY to Saved DK'
str_Qry=${str_Dir_Sql}/DB_Refresh_ChangeBack_DK.sql
date_deb=`date +%Y-%m-%d" "%T"."%N`

str_Output=${str_Dir_Log}/redistribute_${str_Timestamp_Key}.log
str_Err=${str_Dir_Log}/redistribute_${str_Timestamp_Key}.err

psql -1 -tXq -f ${str_Qry} -v v_dump_timestampkey=${str_Timestamp_Key} -v ON_ERROR_STOP=1 -d ${str_Target_DB} | xargs  -P ${int_Nb_Thread} -d"\n"  -n 1 -I{} psql -a -d ${str_Target_DB} -c >${str_Output} 2>${str_Err} {}

rc_qry=$?

if [ -s ${str_Err} ]
then
	echo "WARNING: Errors or warnings occured during redistribute. Review ${str_Err}"
fi

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"


###################################################################################################
### Step 14: Recreate the Indexes and PK from post_data script
###################################################################################################
str_Step=RECREATE_INDEX_PK
echo `date +%Y-%m-%d" "%T ` 'Step 14: Recreate the Indexes and PK from post_data script'
date_deb=`date +%Y-%m-%d" "%T"."%N`
if [ "${flag_OLDFILENAMES}" == "1" ]
then
	str_Prefix="gp_dump_1_1"
else
	str_Prefix="gp_dump_-1_1"
fi

str_Output=${str_Dir_Log}/postdata_restore_${str_Timestamp_Key}.log
str_Err=${str_Dir_Log}/postdata_restore_${str_Timestamp_Key}.err

if [ "${flag_DDBOOST}" == "1" ]
then
	if [ "${flag_COMPRESS}" == "1" ]
	then
	   gpddboost --readFile --from-file=${str_Dir_Dump}/${str_Prefix}_${str_Timestamp_Key}_post_data.gz | zcat | psql -d ${str_Target_DB} >${str_Output} 2>${str_Err}
	else
	   gpddboost --readFile --from-file=${str_Dir_Dump}/${str_Prefix}_${str_Timestamp_Key}_post_data           | psql -d ${str_Target_DB} >${str_Output} 2>${str_Err}
	fi
else
	if [ "${flag_COMPRESS}" == "1" ]
	then
	   zcat ${str_Dir_Dump}/${str_Prefix}_${str_Timestamp_Key}_post_data.gz | psql -d ${str_Target_DB} >${str_Output} 2>${str_Err}
	else
	   psql -d ${str_Target_DB} -f ${str_Dir_Dump}/${str_Prefix}_${str_Timestamp_Key}_post_data > ${str_Output} 2>${str_Err}
	fi
fi
rc_qry=$?

if [ -s ${str_Err} ]
then
	echo "WARNING: Errors or warnings occured during postdata restore. Review ${str_Err}"
fi

f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"


###################################################################################################
### Step 15 (Optional): Analyze the restored tables
###################################################################################################

if [ "$flag_NOANALYZE" != "1" ]
then
	echo `date +%Y-%m-%d" "%T ` 'Step 15: Analyze the restored tables'
	str_Step=ANALYZE
	date_deb=`date +%Y-%m-%d" "%T"."%N`
	str_Output=${str_Dir_Log}/analyze_${str_Timestamp_Key}.log

	analyzedb -a -d ${str_Target_DB} -p ${int_Nb_Thread}  > ${str_Output}
	rc_qry=$?

	f_trace $rc_qry ${str_Timestamp_Key} ${str_Step} "${date_deb}"
fi

###################################################################################################
### End trace
###################################################################################################
str_Step=END
echo `date +%Y-%m-%d" "%T ` 'Finished!'
f_trace 0 ${str_Timestamp_Key} ${str_Step} "${date_deb_global}"
