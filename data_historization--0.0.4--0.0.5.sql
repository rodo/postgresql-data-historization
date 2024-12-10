DROP FUNCTION historize_table_stop(varchar, varchar);
DROP FUNCTION historize_table_stop(varchar);

DROP FUNCTION historize_table_init(name, name);
DROP FUNCTION historize_table_init(name);

DROP FUNCTION historize_table_start(varchar, varchar);
DROP FUNCTION historize_table_start(varchar);

DROP FUNCTION historize_table_reset(name, name);
DROP FUNCTION historize_table_reset(name);


CREATE OR REPLACE FUNCTION historize_table_stop(
    schema_dest varchar,
    table_source varchar)
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



CREATE OR REPLACE FUNCTION historize_table_stop(table_source varchar)
    RETURNS void
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_stop('public', table_source) INTO result;
END;
$$;


CREATE OR REPLACE FUNCTION historize_table_start(schema_dest varchar, table_source varchar)
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

CREATE OR REPLACE FUNCTION historize_table_start(table_source varchar)
    RETURNS void
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_start('public', table_source) INTO result;
END;
$$;

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
    SELECT historize_table_init('public'::name, table_source);
END;
$$;


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
    SELECT historize_table_reset('public'::name, table_source);
END;
$$;
--
-- Part of parts
--

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
--
--
DROP FUNCTION historize_create_partition(varchar, varchar, integer);

CREATE OR REPLACE FUNCTION historize_create_partition(
schema_dest name,
table_source name,
delta integer default 1) RETURNS integer
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
--
--
DROP FUNCTION historize_create_partition(varchar, integer);

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
DROP FUNCTION historize_drop_partition(name, name, integer);

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

DROP FUNCTION historize_drop_partition(varchar, integer);

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
