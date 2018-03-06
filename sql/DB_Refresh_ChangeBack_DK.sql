select distinct
   'alter table ' || quote_ident(schema_name) || '.' || quote_ident(table_name) || ' set ' ||
      case when  distrib_column_list = 'RANDOMLY'::text
         then 'with (reorganize=true);' 
         else 'distributed by (' || distrib_column_list || ');'
      end
from
   pg_class c
   inner join pg_namespace n
      on c.relnamespace = n.oid
   inner join db_refresh.save_table_distrib_key tab
      on tab.schema_name = n.nspname
         and tab.table_name = c.relname
where
   dump_timestampkey = :v_dump_timestampkey
order by 1




