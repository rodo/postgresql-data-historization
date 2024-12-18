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
