-- Function that will create a partition

CREATE OR REPLACE FUNCTION historize_check_partition(
  schema_dest varchar,
  table_source varchar,
  delta integer default 1)
RETURNS
  integer
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


CREATE OR REPLACE FUNCTION historize_create_partition(
schema_dest varchar,
table_source varchar, delta integer default 1) RETURNS integer
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
CREATE OR REPLACE FUNCTION historize_drop_partition(
  schema_dest varchar,
  table_source varchar,
  delta integer default 1)
RETURNS
  integer
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

    partition := schema_dest || table_log || '_' || dateStr::text;

    IF EXISTS (SELECT relname FROM pg_class WHERE relname=partition) THEN

      EXECUTE
          format('DROP TABLE %s', partition);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;


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
