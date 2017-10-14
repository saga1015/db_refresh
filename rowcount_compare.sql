CREATE TABLE db_refresh.row_count_src (tablename varchar(100),rowcount bigint) distributed by (tablename);
COPY db_refresh.row_count_src from '/home/gpadmin/migration/row_count/rowcount_src.out' with delimiter '|';

CREATE TABLE db_refresh.row_count_tgt (tablename varchar(100),rowcount bigint) distributed by (tablename);
COPY db_refresh.row_count_tgt from '/home/gpadmin/migration/row_count/rowcount_tgt.out' with delimiter '|';

select
   coalesce(src.tablename, tgt.tablename) as tablename,
   src.rowcount as src_rowcount,
   tgt.rowcount as tgt_rowcount,
   tgt.rowcount-src.rowcount as nb_rows_diff
from
   db_refresh.row_count_src src
   full outer join db_refresh.row_count_tgt tgt
      on src.tablename = tgt.tablename
   where
      tgt.rowcount-src.rowcount != 0
      or tgt.rowcount-src.rowcount is null
   order by 1
;
