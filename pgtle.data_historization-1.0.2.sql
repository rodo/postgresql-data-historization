SELECT pgtle.install_extension
(
 'data_historization',
 '1.0.2',
 'Keep a copy of each tuples in a dedicated table',
$_pg_tle_$
-- Function that will create a partition

CREATE OR REPLACE FUNCTION historize_check_partition(
  schema_dest name,
  table_source name,
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

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=table_log) THEN
      RETURN 1;
    END IF;

    SELECT to_char(DATE 'today' + make_interval(days => delta), 'YYYYMMDD') INTO dateStr;
    SELECT to_char(DATE 'tomorrow' + make_interval(days => delta), 'YYYYMMDD') INTO dateUpStr;

    partition := table_log || '_' || dateStr::text;

    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=partition) THEN
      RETURN 0;
    ELSE
      RETURN 2;
    END IF;

END;
$$;


CREATE OR REPLACE FUNCTION historize_create_partition(
schema_dest name,
table_source name, delta integer default 1) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    dateStr varchar;
    dateUpStr varchar;
    partition varchar;
    table_log varchar;
BEGIN
    table_log := table_source || '_log';

    IF NOT EXISTS (SELECT 1  FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=table_log) THEN
      RETURN 1;
    END IF;

    SELECT to_char(DATE 'today' + make_interval(days => delta), 'YYYYMMDD') INTO dateStr;
    SELECT to_char(DATE 'tomorrow' + make_interval(days => delta), 'YYYYMMDD') INTO dateUpStr;

    partition := table_log || '_' || dateStr::text;

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=partition) THEN

      EXECUTE
          format('CREATE TABLE %s (LIKE %s INCLUDING INDEXES)', partition, table_log);
      EXECUTE
          format('ALTER TABLE %s ATTACH PARTITION %s FOR VALUES FROM (%L) TO (%L)', table_log, partition, dateStr, dateUpStr);
      RETURN 0;

    ELSE
      RETURN 2;
    END IF;

END;
$$;

CREATE OR REPLACE FUNCTION historize_create_partition(table_source name, delta integer default 1) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
   result integer;
BEGIN
   SELECT historize_create_partition('public', table_source, delta) INTO result;
   RETURN result;
END;
$$;



-- Drop a partion
--
--
CREATE OR REPLACE FUNCTION historize_drop_partition(
  schema_dest name,
  table_source name,
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

    partition := table_log || '_' || dateStr::text;

    IF EXISTS (SELECT relname FROM pg_class WHERE relname=partition) THEN

      EXECUTE
          format('DROP TABLE %s.%s', schema_dest, partition);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;

CREATE OR REPLACE FUNCTION historize_drop_partition(table_source name, delta integer default 1)
RETURNS
  integer
LANGUAGE plpgsql AS
$$
DECLARE
   result integer;
BEGIN
   SELECT historize_drop_partition('public', table_source, delta) INTO result;
   RETURN result;
END;
$$;
-- This function is used to initialize the data historization
--
CREATE OR REPLACE FUNCTION historize_get_logname(
       schema_source NAME,
       table_source NAME)
RETURNS
  text
LANGUAGE plpgsql AS
$$

BEGIN
    RETURN schema_source || '.' || table_source || '_log';
END;
$$;
-- This function is used to initialize the data historization
--
-- Drop the partitionned tables

CREATE OR REPLACE FUNCTION historize_table_clean(
       schema_source NAME,
       table_source NAME)
RETURNS
  void
LANGUAGE plpgsql AS
$$
DECLARE
    partition varchar;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables
                   WHERE table_schema=schema_source
                   AND table_name=table_source)
    THEN
      RAISE EXCEPTION 'table %.% does not exists', schema_source, table_source
        USING HINT = 'Check the table name and schema, fix the search_path is case of needed',
        ERRCODE = '42P01';
    END IF;

    -- Stop the historization to ensure to not block users doing an error
    PERFORM historize_table_stop(schema_source, table_source);

    EXECUTE format('DROP TABLE %s ',  historize_get_logname(schema_source, table_source ));

END;
$$;

--
-- Implicit schema public
--
CREATE OR REPLACE FUNCTION historize_table_clean(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_clean('public'::name, table_source);
END;
$$;
-- This function is used to define conr entries in another database
--
-- schema_dest :
-- table_source :
-- days_in_advance : the number of partition to create in advance
-- days_to_keep :
-- foreign_server : the name of the ofreign server defined with CREATE SERVER statement
--
-- No need to specify the schema, it's define in foreign server search_path option
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
--
--
--
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
-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a column histo_version on the table source
-- - a column histo_sys_period on the table source

CREATE OR REPLACE FUNCTION historize_table_init(
       schema_dest NAME,
       table_source NAME)
RETURNS
  void
LANGUAGE plpgsql AS
$$
DECLARE
    partition varchar;

BEGIN
    -- check if the table source exists
    IF NOT EXISTS (SELECT true FROM information_schema.tables WHERE table_schema = schema_dest AND table_name = table_source) THEN
      RAISE EXCEPTION 'table %.% does not exists', schema_dest, table_source USING ERRCODE = '42P01';
    END IF;

    -- check if the columns does not already exists

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
END;
$$;

--
-- Implicit schema public
--
CREATE OR REPLACE FUNCTION historize_table_init(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_init('public'::name, table_source);
END;
$$;
-- This function is used to initialize the data historization
--
-- Reset the related objects likned to the historization
--
-- - stop the historization
-- - drop columns created on source table
-- - remove the cron commands

CREATE OR REPLACE FUNCTION historize_table_reset(
       schema_source NAME,
       table_source NAME)
RETURNS
  void
LANGUAGE plpgsql AS
$$
DECLARE
    partition varchar;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_source AND table_name=table_source) THEN
      RAISE EXCEPTION 'table %.% does not exists', schema_source, table_source USING HINT = 'Check the table name and schema, fix the search_path is case of needed', ERRCODE = '42P01';
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
END;
$$;

--
-- Implicit schema public
--
CREATE OR REPLACE FUNCTION historize_table_reset(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_reset('public'::name, table_source);
END;
$$;
-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a new column on the table source

CREATE OR REPLACE FUNCTION historize_table_start(schema_dest NAME, table_source NAME)
RETURNS void
    LANGUAGE plpgsql AS
$EOF$
DECLARE
    check_part boolean;
BEGIN
    SELECT historize_check_partition(schema_dest, table_source, 0) = 0 INTO check_part;
    IF NOT check_part THEN
      RAISE EXCEPTION 'no available partition in log table' USING HINT = 'check if you init the historization with historize_table_init function';
    END IF;
   --
   -- Function to manage UPDATE statements
   --
   EXECUTE format('CREATE OR REPLACE FUNCTION %s_historization_update_trg()
        RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      NEW.histo_version = OLD.histo_version + 1;
      NEW.histo_sys_period = tstzrange(CURRENT_TIMESTAMP,null);

      INSERT INTO %s.%s_log (id, txid, eventtime, sys_period, data)
      VALUES (OLD.id, txid_current(), now(),
              tstzrange(lower(OLD.histo_sys_period), CURRENT_TIMESTAMP), to_jsonb(OLD) - ''histo_sys_period'');

    RETURN NEW;
    END;
$$', table_source, schema_dest, table_source);

   --
   -- Function to manage INSERT statements
   --

   EXECUTE format('CREATE OR REPLACE FUNCTION %s_historization_insert_trg()
        RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.histo_version = 1;
    NEW.histo_sys_period = tstzrange(CURRENT_TIMESTAMP,null);
    RETURN NEW;
    END;
$$', table_source, schema_dest, table_source);

   --
   -- Create two triggers, one for UPDATE and one for INSERT
   --

   EXECUTE format('
     CREATE TRIGGER %s_historization_update_trg
       BEFORE UPDATE ON %s.%s
       FOR EACH ROW
       WHEN (NEW <> OLD)
       EXECUTE PROCEDURE %s_historization_update_trg()',
     table_source, schema_dest, table_source, table_source);

   EXECUTE format('
     CREATE TRIGGER %s_historization_insert_trg
       BEFORE INSERT ON %s.%s
       FOR EACH ROW
       EXECUTE PROCEDURE %s_historization_insert_trg()',
    table_source, schema_dest, table_source, table_source);

END;
$EOF$;

--
-- Implicit schema public
--

CREATE OR REPLACE FUNCTION historize_table_start(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_start('public'::name, table_source);
END;
$$;
-- This function is used to stop the historization
--

CREATE OR REPLACE FUNCTION historize_table_stop(
    schema_dest NAME,
    table_source NAME)
RETURNS
    void
LANGUAGE plpgsql AS
$EOF$

BEGIN

    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_dest AND table_name=table_source) THEN
      RAISE EXCEPTION 'table %.% does not exists', schema_dest, table_source USING HINT = 'Check the table name and schema, fix the search_path in case of needed', ERRCODE = '42P01';
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
END;
$EOF$;



CREATE OR REPLACE FUNCTION historize_table_stop(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_stop('public'::name, table_source);
END;
$$;
$_pg_tle_$
);
