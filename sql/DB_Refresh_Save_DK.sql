delete from db_refresh.save_table_distrib_key
   where dump_timestampkey = :v_dump_timestampkey;

insert into db_refresh.save_table_distrib_key
select
   T.reloid
   ,split_part(tab.table_name,'.',1) as schema_name
   ,split_part(tab.table_name,'.',2) as table_name
   ,dk.distrib_column_list
   ,tab.dump_timestampkey
from db_refresh.v_list_dump_tables tab
   left outer join
      (select c.oid as reloid, n.nspname || '.' || c.relname as table_name, c.relkind,c.relstorage
            ,part.partitiontablename is not null as flag_partition
         from pg_catalog.pg_class c
            inner join pg_namespace n
               on c.relnamespace = n.oid
            left outer join pg_partitions part
               on n.nspname = part.partitionschemaname
                  and c.relname = part.partitiontablename
         where n.nspname !~~ 'pg_%'::text AND n.nspname <> 'gp_toolkit'::name AND n.nspname <> 'information_schema'::name
   ) T
      on T.table_name = tab.table_name
   left outer join db_refresh.V_LIST_TABLE_DISTRIB_key dk
      on dk.schema_name || '.' || dk.table_name = tab.table_name
   where 1=1
      and ((T.relkind = 'r' and T.relstorage not in ('x') and flag_partition = false) or T.reloid is null) 
      and tab.dump_timestampkey = :v_dump_timestampkey
;
