BEGIN;

DEALLOCATE PREPARE ALL;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

-- Define the number of tests to run
SELECT plan(6);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
--

SELECT results_eq('init_histo',  ARRAY[0], 'init is successful and return 0');


-- Check we have all wanted objects created
--
--
SELECT has_column('public'::name, 'test_foobar'::name, 'histo_version',
'Table public.test_foobar has a column named histo_version');


SELECT has_table('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log exists');
SELECT is_partitioned('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log is partitioned');

SELECT columns_are('public'::name, 'test_foobar_log'::name, ARRAY['id','eventtime','txid','data']);

SELECT indexes_are('public'::name, 'test_foobar_log'::name, ARRAY['test_foobar_log_id_idx']);


SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;