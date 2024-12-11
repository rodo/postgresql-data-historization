SELECT pgtle.install_update_path
(
 'data_historization',
 '1.0.1',
 '1.0.2',
$_pg_tle_$
--
--

CREATE OR REPLACE FUNCTION historize_cron_define(
  schema_dest         NAME,
  table_source        NAME,
  days_in_advance     integer DEFAULT 4,
  days_to_keep        integer DEFAULT 7,
  schedule            text DEFAULT '00 08 * * *',
  foreign_server      varchar DEFAULT 'historize_foreign_cron'
)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    qry_c text;
    qry_d text;
    drop_start_from integer;
BEGIN
    -- check if the foreign_server exists
    PERFORM historize_check_foreign_server(foreign_server);

    qry_c := format('SELECT schedule_in_database(%L, %L,
  $eof$SELECT historize_create_partition(%L, %L, generate_series(1, %s) )$eof$,  %L) ',
    'histo_create_part_' || schema_dest || '_' || table_source,
    schedule,
    schema_dest,
    table_source,
    days_in_advance,
    current_database());

    -- Drop one week more to ensure that no partitions are missed
    drop_start_from := 0 - (7 + days_to_keep);

    qry_d := format('SELECT schedule_in_database(%L, %L,
  $eof$SELECT historize_drop_partition(%L, %L, generate_series(%s, -%s) )$eof$,  %L) ',
    'histo_drop_part_' || schema_dest || '_' || table_source,
    schedule,
    schema_dest,
    table_source,
    drop_start_from,
    days_to_keep,
    current_database());

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (schedule_in_database bigint)', foreign_server, qry_c);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (schedule_in_database bigint)', foreign_server, qry_d);

    RETURN 0;
END;
$$;

CREATE OR REPLACE FUNCTION historize_cron_remove(
  schema_dest    NAME,
  table_source   NAME,
  foreign_server varchar DEFAULT 'historize_foreign_cron'
)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    qry_c text;
    qry_d text;
BEGIN
    -- check if the foreign_server exists
    PERFORM historize_check_foreign_server(foreign_server);

    qry_c := format('SELECT unschedule(%L)',
    'histo_create_part_' || schema_dest || '_' || table_source);

    qry_d := format('SELECT unschedule(%L)',
    'histo_drop_part_' || schema_dest || '_' || table_source);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (result boolean)', foreign_server, qry_c);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (result boolean)', foreign_server, qry_d);

    RETURN 0;
END;
$$;

-- List all cron entries for the current database
--
--
--

CREATE OR REPLACE FUNCTION historize_cron_list(
  foreign_server varchar DEFAULT 'historize_foreign_cron'
)
RETURNS
  TABLE (jobid bigint, schedule text, command text, nodename text,
         nodeport integer, username text, active boolean, jobname text)
LANGUAGE plpgsql AS
$$
DECLARE
    qry text;
BEGIN
    -- check if the foreign_server exists
    PERFORM historize_check_foreign_server(foreign_server);

    qry := format('SELECT jobid, schedule, command, nodename, nodeport, database, username, active,jobname FROM job' );

    RETURN QUERY
    SELECT t1.jobid, t1.schedule, t1.command, t1.nodename, t1.nodeport, t1.username, t1.active, t1.jobname
    FROM
        dblink(foreign_server, qry ) AS t1 (jobid bigint,schedule text,
                                          command text, nodename text,
                                          nodeport integer, database text,
                                          username text, active boolean,
                                          jobname text)
    WHERE
        t1.database = current_database();

END;
$$;


CREATE OR REPLACE FUNCTION historize_check_foreign_server(
  foreign_server varchar
)
RETURNS
  void
LANGUAGE plpgsql AS
$$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_foreign_server WHERE srvname=foreign_server) THEN
      RAISE EXCEPTION 'foreign server "%" does not exists', foreign_server
      USING ERRCODE='42704',
      HINT='check the function parameter or set it if you use default value historize_foreign_cron';
    END IF;
END;
$$;

--
--


$_pg_tle_$
);
