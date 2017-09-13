select 'truncate ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || ';' 
from pg_class c
inner join pg_namespace n 
	on c.relnamespace=n.oid
inner join db_refresh.save_table_distrib_key list_tables
	on quote_ident(n.nspname) = quote_ident(list_tables.schema_name)
	and quote_ident(c.relname) = quote_ident(list_tables.table_name)
left outer join pg_partitions part
	on quote_ident(n.nspname) = quote_ident(part.partitionschemaname)
	and quote_ident(c.relname) = quote_ident(part.partitiontablename)
where c.relkind='r'
and c.relstorage not in ('x')
and list_tables.dump_timestampkey = :v_dump_timestampkey
-- Partioned tables and their partitions are excluded
  and part.partitiontablename is null
group by 1
order by 1;