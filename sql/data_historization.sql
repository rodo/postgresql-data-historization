-- Function that will create a partition

CREATE OR REPLACE FUNCTION historize_check_partition(schema_dest varchar, table_source varchar, delta integer default 1) RETURNS integer
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


CREATE OR REPLACE FUNCTION historize_create_partition(schema_dest varchar, table_source varchar, delta integer default 1) RETURNS integer
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

CREATE OR REPLACE FUNCTION historize_create_partition(table_source varchar, delta integer default 1) RETURNS integer
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
CREATE OR REPLACE FUNCTION historize_drop_partition(table_source varchar, delta integer default 1) RETURNS integer
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
          format('DROP TABLE %s', partition);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;
-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a new column on the table source

CREATE OR REPLACE FUNCTION historize_table_init(schema_dest varchar, table_source varchar) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    dateStr varchar;
    dateUpStr varchar;
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

    -- Create 7 first partition
    --
    EXECUTE format('
       SELECT historize_create_partition(''%s'', generate_series(0,6) )', table_source );

    RETURN 0;
END;
$$;

--
-- Implicit schema public
--

CREATE OR REPLACE FUNCTION historize_table_init(table_source varchar)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_init('public', table_source) INTO result;
    RETURN result;
END;
$$;
-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a new column on the table source

CREATE OR REPLACE FUNCTION historize_table_start(schema_dest varchar, table_source varchar)
RETURNS integer
    LANGUAGE plpgsql AS
$EOF$
DECLARE
    check_part boolean;
BEGIN
    SELECT historize_check_partition(schema_dest, table_source, 0) = 0 INTO check_part;
    IF NOT check_part THEN
      RETURN 1;
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

    RETURN 0;
END;
$EOF$;

--
-- Implicit schema public
--

CREATE OR REPLACE FUNCTION historize_table_start(table_source varchar)
    RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    result int;
BEGIN
    SELECT historize_table_start('public', table_source) INTO result;
    RETURN result;
END;
$$;
-- This function is used to stop the historization
--

CREATE OR REPLACE FUNCTION historize_table_stop(schema_dest varchar, table_source varchar) RETURNS integer
    LANGUAGE plpgsql AS
$EOF$

BEGIN
   EXECUTE format('DROP TRIGGER %s_historization_update_trg ON %s.%s',
    table_source, schema_dest, table_source);

   EXECUTE format('DROP TRIGGER %s_historization_insert_trg ON %s.%s',
    table_source, schema_dest, table_source);
   --
   -- Function that manage UPDATE statements
   --
   EXECUTE format('DROP FUNCTION %s_historization_update_trg()', table_source);
   --
   -- Function that manage INSERT statements
   --
   EXECUTE format('DROP FUNCTION %s_historization_insert_trg()', table_source);

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
