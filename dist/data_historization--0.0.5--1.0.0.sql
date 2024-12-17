-- Function that will create a partition
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

CREATE OR REPLACE FUNCTION historize_table_start(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_start('public'::name, table_source);
END;
$$;

CREATE OR REPLACE FUNCTION historize_table_stop(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_stop('public'::name, table_source);
END;
$$;

CREATE OR REPLACE FUNCTION historize_table_reset(table_source NAME)
    RETURNS void
    LANGUAGE plpgsql AS
$$
BEGIN
    PERFORM historize_table_reset('public'::name, table_source);
END;
$$;
