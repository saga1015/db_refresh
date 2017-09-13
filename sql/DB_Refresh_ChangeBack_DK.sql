select distinct
	'alter table ' || quote_ident(schema_name) || '.' || quote_ident(table_name) || ' set ' ||
	case when  distrib_column_list = 'RANDOMLY'::text
		then 'with (reorganize=true);' 
		else 'distributed by (' || distrib_column_list || ');'
	end
from  pg_class c
inner join pg_namespace n
on c.relnamespace = n.oid
inner join db_refresh.save_table_distrib_key tab
on quote_ident(tab.schema_name) = n.nspname
and quote_ident(tab.table_name) = c.relname
left outer join (select distinct schemaname,tablename from pg_partitions) part
on n.nspname = part.schemaname
and c.relname = part.tablename
where  dump_timestampkey = :v_dump_timestampkey
order by 1




