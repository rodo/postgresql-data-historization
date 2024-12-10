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
    IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema=schema_source AND table_name=table_source) THEN
      RAISE EXCEPTION 'table %.% does not exists', schema_source, table_source USING HINT = 'Check the table name and schema, fix the search_path is case of needed', ERRCODE = '42P01';
    END IF;

    -- Reset the historization to ensure we can drop the table at no risk
    EXECUTE format('
       SELECT historize_table_reset(%L, %L)', schema_source, table_source );

    EXECUTE format('DROP TABLE %',  historize_get_logname(schema_dest, table_source));

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
    PERFORM historize_table_reset('public'::name, table_source);
END;
$$;
