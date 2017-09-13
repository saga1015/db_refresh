set search_path=db_refresh;
set allow_system_table_mods="DML";

update gp_distribution_policy D
  SET attrnums = NULL
FROM save_table_distrib_key R
where D.localoid = R.reloid
and dump_timestampkey = :v_dump_timestampkey
and schema_name <> 'db_refresh'
and distrib_column_list <> 'RANDOMLY';
reset allow_system_table_mods;