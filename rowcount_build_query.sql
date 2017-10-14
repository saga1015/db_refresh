select 'select '''||nspname||'.'||relname||'|'''||'||count(*) from "'||nspname||'"."'||relname||'";'
   from
      pg_class c join pg_namespace n on c.relnamespace=n.oid
   where
      relkind='r'
      and relstorage in ('a','c','h')
      and nspname not in ('gp_toolkit','information_schema') and nspname not like 'pg_%'
      and not relhassubclass
   order by 1
;

--1. Create query file
-- psql _dbname_ -Atf rowcount_build_query.sql > rowcount.sql

--2. Run query file on source and target systems
-- nohup psql _dbname_ -Atf rowcount.sql > rowcount.out &

--3. Compare
-- rowcount_compare.sql
