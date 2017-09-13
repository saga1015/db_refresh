select
'select ''' ||  now() || '''::timestamp,''' || quote_ident(schema_name) || ''',''' || quote_ident(table_name) 
|| ''', (select count(*) as nb_rows from ' || quote_ident(schema_name) || '.' || quote_ident(table_name) || ');'
from
(
 SELECT n.nspname AS schema_name
 , c.relname AS table_name
 , pg_get_userbyid(c.relowner) AS table_owner
 , c.relhasindex AS has_indexes
 , c.relhasrules AS has_rules
 , c.relkind
 , c.relstorage = 'x' as flag_external_tab
 , c.reloptions as storage_policy
 , case c.relstorage
      when 'a' then 'row compressed'
      when 'c' then 'column compressed'
      when 'h' then 'heap'
      else 'unknown'
   end as storage_type
 , c.relhassubclass as flag_is_partitionned
 , part.tablename is not null as flag_partition
 ,part.parentpartitiontablename as partition_parent
 ,part.tablename as partition_master
   FROM pg_class c
   INNER JOIN pg_namespace n
      ON n.oid = c.relnamespace
   LEFT OUTER JOIN pg_partitions part
      ON n.nspname = part.partitionschemaname
      and c.relname = part.partitiontablename
   WHERE c.relkind = 'r'
) T
where T.schema_name = :v_schema
  and T.flag_external_tab = false
and flag_is_partitionned = false
;
