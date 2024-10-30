-- Function that will create a partition


CREATE OR REPLACE FUNCTION create_tab_part(table_source varchar, delta integer default 1) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    dateStr varchar;
    dateUpStr varchar;
    partition varchar;

BEGIN
    IF NOT EXISTS (SELECT relname FROM pg_class WHERE relname=table_source) THEN
      RETURN 0;
    END IF;

    SELECT to_char(DATE 'today' + make_interval(days => delta), 'YYYYMMDD') INTO dateStr;
    SELECT to_char(DATE 'tomorrow' + make_interval(days => delta), 'YYYYMMDD') INTO dateUpStr;

    partition := table_source || '_' || dateStr::text;

    IF NOT EXISTS (SELECT relname FROM pg_class WHERE relname=partition) THEN

      EXECUTE
          format('CREATE TABLE %s (LIKE %s INCLUDING INDEXES)', partition, table_source);
      EXECUTE
          format('ALTER TABLE %s ATTACH PARTITION %s FOR VALUES FROM (%L) TO (%L)', table_source, partition, dateStr, dateUpStr);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;

-- Drop a partion
--
--
CREATE OR REPLACE FUNCTION drop_tab_part(table_source varchar, delta integer default 1) RETURNS integer
    LANGUAGE plpgsql AS
$$
DECLARE
    dateStr varchar;
    dateUpStr varchar;
    partition varchar;

BEGIN

    SELECT to_char(DATE 'today' + make_interval(days => delta), 'YYYYMMDD') INTO dateStr;
    SELECT to_char(DATE 'tomorrow' + make_interval(days => delta), 'YYYYMMDD') INTO dateUpStr;

    partition := table_source || '_' || dateStr::text;

    IF EXISTS (SELECT relname FROM pg_class WHERE relname=partition) THEN

      EXECUTE
          format('DROP TABLE %s', partition);
      RETURN 1;

    ELSE
      RETURN 0;
    END IF;

END;
$$;
