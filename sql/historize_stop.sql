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
   -- Function that manager UPDATE statements
   --
   EXECUTE format('DROP FUNCTION %s_historization_update_trg()', table_source);
   --
   -- Function that manage INSERT statements
   --
   EXECUTE format('DROP FUNCTION %s_historization_insert_trg()', table_source);

   RETURN 1;
END;
$EOF$



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
