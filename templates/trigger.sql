--
-- Triggers and function on {{tablename}}
--
BEGIN;
--
-- Function that manager INSERT statement
--
CREATE OR REPLACE FUNCTION {{tablename}}_historization_update_trg()
        RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.histo_version = OLD.histo_version + 1;

    INSERT INTO public.{{tablename}}_log (id, txid, eventtime, data)
    VALUES (NEW.id, txid_current(), now(), to_jsonb(NEW));


    RETURN NEW;
    END;
$$;

--
-- Function that manage INSERT statement
--
CREATE OR REPLACE FUNCTION {{tablename}}_historization_insert_trg()
        RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    NEW.histo_version = 1;

    INSERT INTO public.{{tablename}}_log (id, txid, eventtime, data)
    VALUES (NEW.id, txid_current(), now(), to_jsonb(NEW));


    RETURN NEW;
    END;
$$;


CREATE TRIGGER {{tablename}}_historization_update_trg
    BEFORE UPDATE ON {{tablename}}
    FOR EACH ROW
    WHEN (NEW <> OLD)
    EXECUTE PROCEDURE {{tablename}}_historization_update_trg();

CREATE TRIGGER articles_article_historization_insert_trg
    BEFORE INSERT ON {{tablename}}
    FOR EACH ROW
    EXECUTE PROCEDURE {{tablename}}_historization_insert_trg();


COMMIT;
