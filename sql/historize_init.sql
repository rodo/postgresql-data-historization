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

    IF historize_get_column_default_comment() IS NOT NULL THEN
       EXECUTE format('
         COMMENT ON COLUMN %s.histo_version IS ''%s'' ', table_source, historize_get_column_default_comment() );
       EXECUTE format('
         COMMENT ON COLUMN %s.histo_sys_period IS ''%s'' ', table_source, historize_get_column_default_comment() );
    END IF;

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
