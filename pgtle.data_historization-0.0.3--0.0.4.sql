SELECT pgtle.install_update_path
(
 'data_historization',
 '0.0.3',
 '0.0.4',
$_pg_tle_$


CREATE OR REPLACE FUNCTION historize_drop_partition(table_source varchar, delta integer default 1) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
   result integer;
BEGIN
   SELECT historize_drop_partition('public', table_source, delta) INTO result;
   RETURN result;
END;
$$;


CREATE OR REPLACE FUNCTION historize_drop_partition(
  schema_dest varchar,
  table_source varchar,
  delta integer default 1)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    dateStr varchar;
    dateUpStr varchar;
    partition varchar;
    table_log varchar;
BEGIN
    table_log := table_source || '_log';

    SELECT to_char(DATE 'today' + make_interval(days => delta), 'YYYYMMDD') INTO dateStr;
    SELECT to_char(DATE 'tomorrow' + make_interval(days => delta), 'YYYYMMDD') INTO dateUpStr;

    partition := schema_dest || table_log || '_' || dateStr::text;

    IF EXISTS (SELECT relname FROM pg_class WHERE relname=partition) THEN

      EXECUTE
          format('DROP TABLE %s', partition);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;
--
--
--
DROP FUNCTION historize_table_init(varchar, varchar);
DROP FUNCTION historize_table_init(varchar);


CREATE OR REPLACE FUNCTION historize_table_init(
       schema_dest NAME,
       table_source NAME)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    partition varchar;
BEGIN
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %s
           ( id int,
             eventtime timestamp with time zone,
             txid bigint,
             sys_period tstzrange,
             data jsonb
           ) PARTITION BY RANGE (eventtime)', schema_dest || '.' || table_source || '_log');

    -- Create an index on the id the easily regroup all the tuple for the same initial one
    --
    EXECUTE format('
        CREATE INDEX %s_log_id_idx ON %s_log(id)', table_source, schema_dest || '.' || table_source);

    -- Add a new column on the source table to keep the version directly in the row
    --

    EXECUTE format('
       ALTER TABLE %s ADD COLUMN histo_version int default 0', table_source);

    EXECUTE format('
       ALTER TABLE %s ADD COLUMN histo_sys_period tstzrange NOT NULL DEFAULT tstzrange(current_timestamp, null)', table_source);

    -- Create 7 first partition from today
    --
    EXECUTE format('
       SELECT historize_create_partition(%L, generate_series(0,6) )', table_source );

    -- If a foreign server exists and named as default, define the cron entries
    --
    IF EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname='historize_foreign_cron') THEN

      EXECUTE format('
         SELECT historize_cron_define(%L, %L)', schema_dest, table_source );
    END IF;

    RETURN 0;
END;
$$;

--
-- Implicit schema public
--

CREATE OR REPLACE FUNCTION historize_table_init(table_source NAME)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_init('public'::name, table_source) INTO result;
    RETURN result;
END;
$$;
--
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
    current_database())   ;

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

CREATE OR REPLACE FUNCTION historize_table_reset(
       schema_source NAME,
       table_source NAME)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
    partition varchar;
BEGIN

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_source AND table_name=table_source) THEN
      RAISE EXCEPTION 'Table %.% does not exists', schema_source, table_source USING HINT = 'Check the table name and schema, fix the search_path is case of needed';
    END IF;

    -- Stop the historization to ensure there is no trigger left
    EXECUTE format('
       SELECT historize_table_stop(%L, %L)', schema_source, table_source );

    EXECUTE format('
       ALTER TABLE %s DROP COLUMN histo_version', table_source);

    EXECUTE format('
       ALTER TABLE %s DROP COLUMN histo_sys_period', table_source);

    -- If a foreign server exists and named as default, define the cron entries
    --
    IF EXISTS (SELECT 1 FROM pg_foreign_server WHERE srvname='historize_foreign_cron') THEN
      EXECUTE format('
         SELECT historize_cron_remove(%L, %L)', schema_source, table_source );
    END IF;

    RETURN 0;
END;
$$;

--
-- Implicit schema public
--

CREATE OR REPLACE FUNCTION historize_table_reset(table_source NAME)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_reset('public'::name, table_source) INTO result;
    RETURN result;
END;
$$;


CREATE OR REPLACE FUNCTION historize_table_stop(
    schema_dest varchar,
    table_source varchar)
RETURNS
    integer
LANGUAGE plpgsql AS
$EOF$

BEGIN

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=table_source) THEN
      RAISE EXCEPTION 'Table %.% does not exists', schema_dest, table_source USING HINT = 'Check the table name and schema, fix the search_path is case of needed';
    END IF;

   EXECUTE format('DROP TRIGGER IF EXISTS %s_historization_update_trg ON %s.%s',
    table_source, schema_dest, table_source);

   EXECUTE format('DROP TRIGGER IF EXISTS %s_historization_insert_trg ON %s.%s',
    table_source, schema_dest, table_source);
   --
   -- Function that manage UPDATE statements
   --
   EXECUTE format('DROP FUNCTION IF EXISTS %s_historization_update_trg()', table_source);
   --
   -- Function that manage INSERT statements
   --
   EXECUTE format('DROP FUNCTION IF EXISTS %s_historization_insert_trg()', table_source);

   RETURN 0;
END;
$EOF$;

CREATE OR REPLACE FUNCTION historize_table_stop(table_source varchar)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_stop('public', table_source) INTO result;
    RETURN result;
END;
$$;

$_pg_tle_$
);
