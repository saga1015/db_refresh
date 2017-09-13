select
	'DROP RULE ' || rulename || ' on ' || quote_ident(schemaname) || '.' || quote_ident(tablename) || ';' as RULE_DROP_command
from pg_rules r
inner join db_refresh.v_list_dump_tables tab
	on quote_ident(r.schemaname) || '.' || quote_ident(r.tablename) = tab.table_name
where tab.dump_timestampkey = :v_dump_timestampkey
;