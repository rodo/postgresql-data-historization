-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a new column on the table source

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
BEGIN
    SELECT historize_table_start('public', table_source);
END;
$$;
