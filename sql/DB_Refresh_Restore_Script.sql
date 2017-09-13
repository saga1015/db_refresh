select 
--'gpssh -h ' || hostname || ' -v -e ''' 
--||
 case
	when substring(trim(file_name) from '...$') = '.gz'
		then 'zcat ' || file_name || ' | '
	else ''
end
|| 'PGOPTIONS="-c gp_session_role=utility" psql -1 -h '|| hostname || ' -p ' || port  || ' -d ' || :v_Target_DB || ' -U gpadmin -v ON_ERROR_STOP=1 ' ||
case
	when substring(trim(file_name) from '...$') = '.gz'
		then ''
	else ' -f ' || file_name 
end
|| E'&\n'--|| E'''&\n'
|| 'plist['|| id_file ||']=$!'
from (select row_number() over() as id_file,file_name
	from db_refresh.refresh_list_dump_file
	where dump_timestampkey = :v_dump_timestampkey) S1
inner join (select *, max(content) over () as max_content
			,row_number() over(order by port,hostname) as id_content_join 
			from gp_segment_configuration
			where role = 'p'
			and content >=0 ) T1
on mod(S1.id_file,T1.max_content + 1 ) + 1 = T1.id_content_join
order by id_file