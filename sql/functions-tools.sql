-- This function is used to initialize the data historization
--
CREATE OR REPLACE FUNCTION historize_get_logname(
       schema_source NAME,
       table_source NAME)
RETURNS
  text
LANGUAGE plpgsql AS
$$

BEGIN
    RETURN schema_source || '.' || table_source || '_log';
END;
$$;
