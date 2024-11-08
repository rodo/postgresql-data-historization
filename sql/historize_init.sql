-- This function is used to initialize the data historization
--
-- It creates multiple objects
-- - a table with the name of the table to historize adding a suffix _log
-- - an index
-- - a new column on the table source

CREATE OR REPLACE FUNCTION historize_table_init(
       schema_dest varchar,
       table_source varchar) RETURNS integer
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

    -- Create 7 first partition from today
    --
    EXECUTE format('
       SELECT historize_create_partition(%L, generate_series(0,6) )', table_source );

    EXECUTE format('
       SELECT historize_cron_define(%L, %L)', schema_dest, table_source );

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
