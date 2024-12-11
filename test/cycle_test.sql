DEALLOCATE PREPARE ALL;
SET client_min_messages TO WARNING;

BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','test_foobar');

PREPARE clean_histo AS
  SELECT historize_table_clean('public','test_foobar');

PREPARE reset_histo AS
  SELECT historize_table_reset('public','test_foobar');


-- Define the number of tests to run
SELECT plan(24);

CREATE TABLE test_foobar (id int, fname text DEFAULT 'alpha') ;

-- First full process
--
SELECT lives_ok('init_histo',  'init is successful');
SELECT lives_ok('start_histo', 'start is successful');
SELECT lives_ok('stop_histo',  'stop is successful');
SELECT lives_ok('reset_histo', 'reset is successful');
SELECT lives_ok('clean_histo', 'clean is successful');
--
-- Second full process
--
SELECT lives_ok('init_histo',  'init is successful');
SELECT lives_ok('start_histo', 'start is successful');
SELECT lives_ok('stop_histo',  'stop is successful');
SELECT lives_ok('reset_histo', 'reset is successful');
SELECT lives_ok('clean_histo', 'clean is successful');
--
-- Second full process, skipping steps
--
SELECT lives_ok('init_histo',  'init is successful');
SELECT lives_ok('start_histo', 'start is successful');
SELECT lives_ok('reset_histo', 'reset is successful');
SELECT lives_ok('clean_histo', 'clean is successful');
--
-- Second full process, skipping steps
--
SELECT lives_ok('init_histo',  'init is successful');
SELECT lives_ok('start_histo', 'start is successful');
SELECT lives_ok('stop_histo',  'stop is successful');
SELECT lives_ok('clean_histo', 'clean is successful');
SELECT lives_ok('reset_histo', 'reset is successful');

-- First full process
--
SELECT lives_ok('init_histo',  'init is successful');
SELECT lives_ok('start_histo', 'start is successful');
SELECT lives_ok('stop_histo',  'stop is successful');
SELECT lives_ok('reset_histo', 'reset is successful');
SELECT lives_ok('clean_histo', 'clean is successful');


SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
