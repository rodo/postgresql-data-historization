BEGIN;

DEALLOCATE PREPARE ALL;

-- Define the number of tests to run
SELECT plan(4);

SELECT has_function('historize_cron_define'::name);
SELECT has_function('historize_cron_remove'::name);
SELECT has_function('historize_cron_list'::name);
SELECT has_function('historize_check_foreign_server'::name);

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
