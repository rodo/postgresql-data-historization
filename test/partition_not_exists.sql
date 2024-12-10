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

SELECT lives_ok('init_histo', 'call of historize_table_init do not throw an error');


-- drop the partition automatically created
SELECT historize_drop_partition('test_foobar', 0) ;

-- start the historization
SELECT throws_ok('start_histo', 'P0001', 'no available partition in log table');

-- create the partition
SELECT historize_create_partition('public', 'test_foobar', 0) ;

-- start the historization
SELECT lives_ok('start_histo', 'call of start_histo do not throw an error');

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
