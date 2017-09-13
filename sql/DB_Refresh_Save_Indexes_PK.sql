
delete from db_refresh.save_table_index
where dump_timestampkey = :v_dump_timestampkey;

insert into db_refresh.save_table_index
 SELECT 
c.oid as reloid
,n.nspname as schema_name
,c.relname as table_name
,i.oid as index_oid
,i.relname as index_name
,'INDEX'::varchar as index_type
 ,pg_get_indexdef(i.oid) || ';' as index_ddl
  ,tab.dump_timestampkey
   FROM pg_index x
   inner JOIN pg_class i ON i.oid = x.indexrelid
   inner JOIN pg_class c ON c.oid = x.indrelid   
   inner JOIN pg_namespace n ON n.oid = i.relnamespace
   inner join db_refresh.v_list_dump_tables tab
        on quote_ident(n.nspname) || '.' || quote_ident(c.relname) = tab.table_name
where tab.dump_timestampkey = :v_dump_timestampkey
AND i.relkind = 'i'::"char"
    AND x.indisprimary = false
    AND n.nspname <> ALL (ARRAY['information_schema'::name, 'pg_catalog'::name, 'pg_toast'::name, 'gp_toolkit'::name
				,'pg_bitmapindex'::name,'pg_aoseg'::name])

union all

select 
c.oid as reloid
,n.nspname as schema_name
,c.relname as table_name
,cons.oid as pk_oid
,cons.conname as pk_name
,'PK'::varchar as pk_type
,'ALTER TABLE ' || quote_ident(n.nspname) || '.' || quote_ident(c.relname) 
||  ' ADD CONSTRAINT ' || quote_ident(cons.conname) || ' ' || pg_get_constraintdef(cons.oid) || ';'
    as PK_DDL
  ,tab.dump_timestampkey
 from pg_constraint cons
 inner join pg_class c
   on cons.conrelid = c.oid
   INNER JOIN pg_namespace n
      ON n.oid = c.relnamespace
   inner join db_refresh.v_list_dump_tables tab
        on quote_ident(n.nspname) || '.' || quote_ident(c.relname) = tab.table_name
where  (cons.contype = 'p' -- Primary Key
	or cons.contype = 'u') -- Unique Key
and tab.dump_timestampkey =  :v_dump_timestampkey
order by 1



				

