--
-- This file test the case when the historization is started without
-- having a compatible partition
--
DEALLOCATE PREPARE ALL;


BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','test_foobar');


-- Define the number of tests to run
SELECT plan(3);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
--

SELECT results_eq('init_histo',  ARRAY[0], 'init is successful and return 0');


-- start the historization
SELECT results_eq('start_histo',  ARRAY[1], 'start is not successful and return 1');

-- create the partition
SELECT historize_create_partition('public', 'test_foobar', 0) ;

-- start the historization
SELECT results_eq('start_histo',  ARRAY[0], 'start is successful and return 0');



SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
