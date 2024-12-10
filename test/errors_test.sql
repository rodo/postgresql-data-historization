DEALLOCATE PREPARE ALL;


BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','does_not_exists');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','no_table');

PREPARE reset_histo AS
  SELECT historize_table_reset('public','no_table');


PREPARE init_histo1 AS
  SELECT historize_table_init('does_not_exists');

PREPARE start_histo1 AS
  SELECT historize_table_start('test_foobar');

PREPARE stop_histo1 AS
  SELECT historize_table_stop('no_table');

PREPARE reset_histo1 AS
  SELECT historize_table_reset('no_table');


-- Define the number of tests to run
SELECT plan(8);

CREATE TABLE test_foobar (id int, fname text DEFAULT 'alpha') ;

-- initialize the historization
--

SELECT throws_ok('init_histo', '42P01', 'table public.does_not_exists does not exists');

SELECT throws_ok('stop_histo', '42P01', 'table public.no_table does not exists');

SELECT throws_ok('start_histo', 'P0001', 'no available partition in log table');

SELECT throws_ok('reset_histo', '42P01', 'table public.no_table does not exists');

SELECT throws_ok('init_histo1', '42P01', 'table public.does_not_exists does not exists');

SELECT throws_ok('stop_histo1', '42P01', 'table public.no_table does not exists');

SELECT throws_ok('start_histo1', 'P0001', 'no available partition in log table');

SELECT throws_ok('reset_histo1', '42P01', 'table public.no_table does not exists');


SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
