--
-- Historization table for {{tablename}}
--
-- Columns
-- id : the unique id of the row in the source table
-- eventtime : timestamp when the event occurs (INSERT or UPDATE)
-- txid : the postgresql transaction identifier in which the event occurs
-- data : the full row contains the new data in json format

BEGIN;

CREATE TABLE IF NOT EXISTS {{tablename}}_log

( id int,
  eventtime timestamp with time zone,
  txid bigint,
  data jsonb

) PARTITION BY RANGE (eventtime)
;

CREATE INDEX {{tablename}}_log_id_idx ON {{tablename}}_log(id);

-- Add a new column to keep the version of the row directly in the row
--
ALTER TABLE {{tablename}} ADD COLUMN histo_version int default 0;


COMMIT;
