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
