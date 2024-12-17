--
--
CREATE OR REPLACE FUNCTION historize_cron_list(
  foreign_server varchar DEFAULT 'historize_foreign_cron'
)
RETURNS
  TABLE (jobid bigint, schedule text, command text, nodename text,
         nodeport integer, username text, active boolean, jobname text)
LANGUAGE plpgsql AS
$$
DECLARE
    qry text;
BEGIN

    qry := format('SELECT jobid, schedule, command, nodename, nodeport, database, username, active,jobname FROM cron.job' );

    RETURN QUERY
    SELECT t1.jobid, t1.schedule, t1.command, t1.nodename, t1.nodeport, t1.username, t1.active,
    t1.jobname
    FROM
        dblink('foreign_server', qry ) AS t1 (jobid bigint,schedule text,
                                          command text, nodename text,
                                          nodeport integer, database text,
                                          username text, active boolean,
                                          jobname text)
    WHERE
        t1.database = current_database();

END;
$$;

--
--
