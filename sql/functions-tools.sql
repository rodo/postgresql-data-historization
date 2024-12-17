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
--
--
--
CREATE OR REPLACE FUNCTION historize_get_column_default_comment()
RETURNS
  text
LANGUAGE plpgsql AS
$$

BEGIN
    RETURN null;
END;
$$;
--
--
--
CREATE OR REPLACE FUNCTION historize_define_column_default_comment(def_com text)
RETURNS
  text
LANGUAGE plpgsql AS
$foo$

BEGIN
    EXECUTE format('CREATE OR REPLACE FUNCTION @extschema@.historize_get_column_default_comment()
RETURNS
  text
LANGUAGE plpgsql AS
$$

BEGIN
    RETURN ''%s'';
END;
$$;', def_com);
    RETURN format('Default comment for columns is : %s', def_com);
END;
$foo$;
--
--
--
CREATE OR REPLACE FUNCTION historize_reset_column_default_comment()
RETURNS
  text
LANGUAGE plpgsql AS
$foo$

BEGIN
    EXECUTE 'CREATE OR REPLACE FUNCTION @extschema@.historize_get_column_default_comment()
RETURNS
  text
LANGUAGE plpgsql AS
$$
BEGIN
    RETURN null;
END;
$$;';
    RETURN 'Default comment for columns is now null';
END;
$foo$;
