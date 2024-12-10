BEGIN;

DEALLOCATE PREPARE ALL;

PREPARE init_histo AS
  SELECT historize_table_init('public'::name, 'test_foobar'::name);

PREPARE start_histo AS
  SELECT historize_table_start('public', 'test_foobar');

PREPARE reset_histo AS
  SELECT historize_table_reset('public'::name, 'test_foobar'::name);

-- Define the number of tests to run
SELECT plan(6);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
--

SELECT lives_ok('init_histo');
SELECT lives_ok('start_histo');
SELECT lives_ok('reset_histo');

-- Check if all objects are removed
--
--
SELECT hasnt_column('public'::name, 'test_foobar'::name, 'histo_version',
'Table public.test_foobar has a column named histo_version');

SELECT hasnt_column('public'::name, 'test_foobar'::name, 'histo_sys_period',
'Table public.test_foobar has a column named histo_version');

SELECT has_table('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log does not exist');

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
