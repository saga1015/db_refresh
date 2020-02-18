select 'truncate ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) || ';' 
from pg_class c
inner join pg_namespace n 
	on c.relnamespace=n.oid
inner join db_refresh.save_table_distrib_key list_tables
	on quote_ident(n.nspname) = quote_ident(list_tables.schema_name)
	and quote_ident(c.relname) = quote_ident(list_tables.table_name)
where c.relkind='r'
and c.relstorage in ('a','c','h')
and list_tables.dump_timestampkey = :v_dump_timestampkey
order by 1;

