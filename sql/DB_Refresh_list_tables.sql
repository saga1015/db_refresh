select quote_ident(n.nspname) || '.' || quote_ident(c.relname)
from pg_class c 
inner join pg_namespace n on c.relnamespace = n.oid
left outer join pg_partitions part ON n.nspname = part.partitionschemaname AND c.relname = part.partitiontablename  
where relkind = 'r' and relstorage not in ('x') 
and n.nspname not in ('gp_toolkit','pg_catalog','information_schema','db_refresh')
and part.partitiontablename IS NULL;