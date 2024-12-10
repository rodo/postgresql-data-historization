BEGIN;

DEALLOCATE PREPARE ALL;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

-- Define the number of tests to run
SELECT plan(8);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
--

SELECT lives_ok('init_histo');

-- Check we have all wanted objects created
--
--
SELECT has_column('public'::name, 'test_foobar'::name, 'histo_version',
'Table public.test_foobar has a column named histo_version');

SELECT has_column('public'::name, 'test_foobar'::name, 'histo_sys_period',
'Table public.test_foobar has a column named histo_version');


SELECT has_table('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log exists');
SELECT is_partitioned('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log is partitioned');

SELECT partitions_are(
    'public', 'test_foobar_log',
    ARRAY['test_foobar_log_' || TO_CHAR(NOW()::date, 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '1 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '2 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '3 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '4 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '5 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '6 day', 'yyyymmdd')
          ]
);

SELECT columns_are('public'::name, 'test_foobar_log'::name, ARRAY['id','eventtime','txid','data','sys_period']);

SELECT indexes_are('public'::name, 'test_foobar_log'::name, ARRAY['test_foobar_log_id_idx']);


SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
