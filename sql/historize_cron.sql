-- This function is used to define conr entries in another database
--
-- schema_dest :
-- table_source :
-- nb_partition : the number of partition to create in advance
-- foreign_server : the name of the ofreign server defined with CREATE SERVER statement
-- cron_foreign_schema : the name of the scheme where the pg_cron extesion is installed

CREATE OR REPLACE FUNCTION historize_cron_define(
  schema_dest    varchar,
  table_source   varchar,
  nb_partition   integer DEFAULT 4,
  schedule       text DEFAULT '00 08 * * *',
  foreign_server varchar DEFAULT 'historize_foreign_cron',
  cron_foreign_schema varchar DEFAULT 'cron')
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    qry_c text;
    qry_d text;
BEGIN

    qry_c := format('SELECT %s.schedule_in_database(%L, %L,
  $eof$SELECT historize_create_partition(%L, %L, generate_series(1, %s) )$eof$,  %L) ',
    cron_foreign_schema,
    'histo_create_part_' || schema_dest || '_' || table_source,
    schedule,
    schema_dest,
    table_source,
    nb_partition,
    current_database());

    qry_d := format('SELECT %s.schedule_in_database(%L, %L,
  $eof$SELECT historize_drop_partition(%L, %L, generate_series(-14, -%s) )$eof$,  %L) ',
    cron_foreign_schema,
    'histo_drop_part_' || schema_dest || '_' || table_source,
    schedule,
    schema_dest,
    table_source,
    nb_partition,
    current_database())   ;

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (schedule_in_database bigint)', foreign_server, qry_c);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (schedule_in_database bigint)', foreign_server, qry_d);

    RETURN 0;
END;
$$;

CREATE OR REPLACE FUNCTION historize_cron_remove(
  schema_dest    varchar,
  table_source   varchar,
  foreign_server varchar DEFAULT 'historize_foreign_cron',
  cron_foreign_schema varchar DEFAULT 'cron')
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    qry_c text;
    qry_d text;
BEGIN

    qry_c := format('SELECT %s.unschedule(%L)',
    cron_foreign_schema,
    'histo_create_part_' || schema_dest || '_' || table_source);

    qry_d := format('SELECT %s.unschedule(%L)',
    cron_foreign_schema,
    'histo_drop_part_' || schema_dest || '_' || table_source);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (result boolean)', foreign_server, qry_c);

    EXECUTE format('
     SELECT * FROM dblink(%L, %L ) AS t1 (result boolean)', foreign_server, qry_d);

    RETURN 0;
END;
$$;


drop FUNCTION historize_cron_list ( character varying, text) ;

CREATE OR REPLACE FUNCTION historize_cron_list(
  foreign_server varchar DEFAULT 'historize_foreign_cron',
  cron_foreign_schema text DEFAULT 'cron')
RETURNS
  TABLE (jobid bigint, schedule text, command text, nodename text,
         nodeport integer, username text, active boolean, jobname text)
LANGUAGE plpgsql AS
$$
DECLARE
    qry text;
BEGIN

    qry := format('SELECT jobid, schedule, command, nodename, nodeport, database, username, active,jobname FROM %s.job', cron_foreign_schema);

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
