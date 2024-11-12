BEGIN;

DEALLOCATE PREPARE ALL;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

-- Define the number of tests to run
SELECT plan(3);

CREATE TABLE test_foobar (id int) ;


SELECT has_function('historize_cron_define'::name);
SELECT has_function('historize_cron_remove'::name);
SELECT has_function('historize_cron_list'::name);



SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
