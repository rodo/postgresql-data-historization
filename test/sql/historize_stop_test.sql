BEGIN;

DEALLOCATE PREPARE ALL;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','test_foobar');

-- Define the number of tests to run
SELECT plan(7);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
-- start the historization
-- stop the historization

SELECT results_eq('init_histo', ARRAY[0], 'init is successful and return 0');
SELECT results_eq('start_histo', ARRAY[0], 'start is successful and return 0');
SELECT results_eq('stop_histo', ARRAY[0], 'stop is successful and return 0');

-- Check we have all wanted objects created
--
--
SELECT hasnt_function('test_foobar_historization_update_trg');
SELECT hasnt_function('test_foobar_historization_insert_trg');

SELECT hasnt_trigger('public'::name, 'test_foobar'::name, 'test_foobar_historization_insert_trg'::name);
SELECT hasnt_trigger('public'::name, 'test_foobar'::name, 'test_foobar_historization_update_trg'::name);


SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
