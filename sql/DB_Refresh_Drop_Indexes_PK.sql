SELECT 
case
	when index_type = 'PK'
		then 'ALTER TABLE ' || quote_ident(schema_name) || '.' || quote_ident(table_name) ||  ' DROP CONSTRAINT ' || quote_ident(index_name) || ';'
	when index_type = 'INDEX'
		then 'DROP INDEX IF EXISTS ' || quote_ident(schema_name) || '.' || quote_ident(index_name) || ';' 
end as drop_cmd
from db_refresh.save_table_index
where index_type in ('PK','INDEX')
and dump_timestampkey = :v_dump_timestampkey
order by (case
	when index_type = 'PK'
		then 1
	when index_type = 'INDEX'
		then 2
end)
;