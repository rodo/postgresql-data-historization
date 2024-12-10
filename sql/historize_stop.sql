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
