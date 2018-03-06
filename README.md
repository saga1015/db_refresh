# db_refresh

This script performs restore from backup when number of segments in source and target systems are different.
If you restoring data to Greenplum with same number of segments - use `gpdbrestore` and not this script


Usage: unpack archive on master, change to script directory and run

```shell
./DB_Refresh.sh -t 20171019072646 -c

-t timestamp of your backup
-c option tells script to take parameters from DB_Refresh.cfg file (always specify it)
```
Logs for certain operations are collected in `log` directory. Timings collected in `trace` directory. Good practice to check all log for errors and warnings during restore.

All parameters except timestamp are set in DB_Refresh.cfg file. Explaining parameters below

```shell
export str_Target_DB=dwhtest       # target database name. Database should exist; script doesn't run CREATE DATABASE operation
export int_Nb_DB_Seg_Source=128    # number of segments in source system on which backup was done
export int_Nb_DB_Seg_Target=96     # number of segments in target system
export str_Dir_Dump_Root="/backup/db_dumps/"        # path to dump directory without subdirectory specifying date
export int_Nb_Thread=6             # number of threads for running redistribute and analyze operations in parallel
export flag_DDBOOST=0              # set 1 if backup was made to Data Domain with --ddboost option
export flag_DDL=1                  # set 1 to restore both schema and data (0 - only data will be restored, tables should exist)
export flag_INDEX=1                # set 1 to drop indexes before data load and recreate after
export flag_RULE=1                 # set 1 to drop rules before data load and recreate after
export flag_TRUNCATE=0             # set 1 to truncate target tables before data load
export flag_NOANALYZE=0            # set 1 to skip full database analyze in the end of migration process
```
