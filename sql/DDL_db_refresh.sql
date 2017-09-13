--
-- Greenplum Database database dump
--

-- Dumped from database version 8.2.15
-- Started on 2015-09-24 12:36:03 CEST

SET statement_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET default_with_oids = false;

--
-- TOC entry 8 (class 2615 OID 22731)
-- Name: db_refresh; Type: SCHEMA; Schema: -; Owner: gpadmin
--

CREATE SCHEMA db_refresh;


ALTER SCHEMA db_refresh OWNER TO gpadmin;

SET search_path = db_refresh, pg_catalog;

SET default_tablespace = '';

--
-- TOC entry 3827 (class 1259 OID 104289)
-- Dependencies: 8
-- Name: refresh_list_dump_file; Type: TABLE; Schema: db_refresh; Owner: gpadmin; Tablespace: 
--

CREATE TABLE refresh_list_dump_file (
    id_file integer,
    dump_timestampkey bigint,
    file_name text
) DISTRIBUTED RANDOMLY;


ALTER TABLE db_refresh.refresh_list_dump_file OWNER TO gpadmin;

--
-- TOC entry 3789 (class 1259 OID 46735)
-- Dependencies: 8
-- Name: refresh_list_dump_table; Type: TABLE; Schema: db_refresh; Owner: gpadmin; Tablespace: 
--

CREATE TABLE refresh_list_dump_table (
    dump_timestampkey bigint,
    dump_line text
) DISTRIBUTED RANDOMLY;


ALTER TABLE db_refresh.refresh_list_dump_table OWNER TO gpadmin;

--
-- TOC entry 3788 (class 1259 OID 46654)
-- Dependencies: 8
-- Name: save_table_distrib_key; Type: TABLE; Schema: db_refresh; Owner: gpadmin; Tablespace: 
--

CREATE TABLE save_table_distrib_key (
    reloid oid NOT NULL,
    schema_name name NOT NULL,
    table_name name NOT NULL,
    distrib_column_list text,
    dump_timestampkey bigint
) DISTRIBUTED RANDOMLY;


ALTER TABLE db_refresh.save_table_distrib_key OWNER TO gpadmin;

--
-- TOC entry 3790 (class 1259 OID 46752)
-- Dependencies: 4730 8
-- Name: v_list_dump_tables; Type: VIEW; Schema: db_refresh; Owner: gpadmin
--

CREATE VIEW v_list_dump_tables AS
    SELECT refresh_list_dump_table.dump_timestampkey, split_part(refresh_list_dump_table.dump_line, ' '::text, 3) AS table_name 
	FROM refresh_list_dump_table 
	WHERE refresh_list_dump_table.dump_line like '%-[INFO]:-Table %';


ALTER TABLE db_refresh.v_list_dump_tables OWNER TO gpadmin;

--
-- TOC entry 3829 (class 1259 OID 129283)
-- Dependencies: 4732 8
-- Name: v_list_table_distrib_key; Type: VIEW; Schema: db_refresh; Owner: gpadmin
--

CREATE VIEW v_list_table_distrib_key AS
    SELECT t.reloid, t.schema_name, t.table_name, t.distrib_column_list 
	FROM (SELECT d.localoid AS reloid, n.nspname AS schema_name, c.relname AS table_name, string_agg(quote_ident((a.attname)::text), ', '::text ORDER BY d.colorder) AS distrib_column_list 
		FROM (((((SELECT gp_distribution_policy.localoid, unnest(gp_distribution_policy.attrnums) AS colnum, generate_series(1, array_upper(gp_distribution_policy.attrnums, 1)) AS colorder 
				FROM gp_distribution_policy 
				WHERE (gp_distribution_policy.attrnums IS NOT NULL)) d 
				JOIN pg_attribute a 
					ON (((d.localoid = a.attrelid) AND (d.colnum = a.attnum)))) 
				JOIN pg_class c 
					ON ((d.localoid = c.oid))) 
				JOIN pg_namespace n 
					ON ((c.relnamespace = n.oid))) 
				LEFT JOIN pg_partitions part 
					ON (((n.nspname = part.partitionschemaname) AND (c.relname = part.partitiontablename)))) 
				WHERE (part.partitiontablename IS NULL) GROUP BY d.localoid, n.nspname, c.relname 
				
			UNION ALL 
					
				SELECT d.localoid AS reloid, n.nspname AS schema_name, c.relname AS table_name, 'RANDOMLY' AS distrib_column_list 
				FROM (((gp_distribution_policy d 
				JOIN pg_class c 
					ON ((d.localoid = c.oid))) 
				JOIN pg_namespace n 
					ON ((c.relnamespace = n.oid))) 
				LEFT JOIN pg_partitions part 
					ON (((n.nspname = part.partitionschemaname) AND (c.relname = part.partitiontablename)))) 
				WHERE (((part.partitiontablename IS NULL) AND (d.attrnums IS NULL)) AND (c.relstorage <> 'x'::"char"))
		) t;


ALTER TABLE db_refresh.v_list_table_distrib_key OWNER TO gpadmin;


CREATE TABLE save_table_index (
    reloid oid,
    schema_name name,
    table_name name,
	index_oid oid,
	index_name name,
	index_type varchar,
    index_DDL text,
    dump_timestampkey bigint
) DISTRIBUTED RANDOMLY;


ALTER TABLE db_refresh.save_table_index OWNER TO gpadmin;



CREATE TABLE db_refresh.count_nb_rows_source
(
  timestamp_count timestamp without time zone,
  schema_name text,
  table_name text,
  nb_rows bigint
)
WITH (
  OIDS=FALSE
)
DISTRIBUTED RANDOMLY;
ALTER TABLE db_refresh.count_nb_rows_source OWNER TO gpadmin;

CREATE TABLE db_refresh.count_nb_rows_target
(
  timestamp_count timestamp without time zone,
  schema_name text,
  table_name text,
  nb_rows bigint
)
WITH (
  OIDS=FALSE
)
DISTRIBUTED RANDOMLY;
ALTER TABLE db_refresh.count_nb_rows_target OWNER TO gpadmin;

-- Completed on 2015-09-24 12:36:04 CEST

--
-- Greenplum Database database dump complete
--

