DEALLOCATE PREPARE ALL;


BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','test_foobar');


-- Define the number of tests to run
SELECT plan(14);

CREATE TABLE test_foobar (id int) ;

-- initialize the historization
--

SELECT results_eq('init_histo',  ARRAY[0], 'init is successful and return 1');

SELECT has_table('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log exists');
SELECT is_partitioned('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log is partitioned');

--
PREPARE call_func AS
SELECT historize_create_partition(
  'public',
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;

SELECT results_eq('call_func', ARRAY[0], 'The new partition is well created');

--
SELECT historize_create_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
);

SELECT partitions_are(
    'public', 'test_foobar_log',
    ARRAY['test_foobar_log_20240102',
          'test_foobar_log_20240103',
          'test_foobar_log_' || TO_CHAR(NOW()::date, 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '1 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '2 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '3 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '4 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '5 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '6 day', 'yyyymmdd')
          ]
);

-- Drop a partition
SELECT historize_drop_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
) ;

SELECT partitions_are(
    'public', 'test_foobar_log',
    ARRAY['test_foobar_log_20240102',
          'test_foobar_log_' || TO_CHAR(NOW()::date, 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '1 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '2 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '3 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '4 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '5 day', 'yyyymmdd'),
          'test_foobar_log_' || TO_CHAR(NOW()::date + INTERVAL '6 day', 'yyyymmdd')
    ]
);

-- create a partition to store data of today
SELECT historize_create_partition('test_foobar', 0);

--
-- the historization is not alreday started
--
INSERT INTO test_foobar (id) VALUES (1);

PREPARE count_log AS SELECT count(*)::int FROM test_foobar_log;
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[0],
       'The data is not historized');

-- start the historization
SELECT results_eq('start_histo',  ARRAY[0], 'start is successful and return 0');

INSERT INTO test_foobar (id) VALUES (2);
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[1],
       'The data is well historized');

SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=2',
    ARRAY[1],
    'active_users() should return active users'
);
--
-- Test that updating a row increase the version
--
UPDATE test_foobar SET id = 3 WHERE id = 2;
SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=3',
    ARRAY[2],
    'active_users() should return active users'
);
--
-- Test that updating a row without changing values do not change version
--
UPDATE test_foobar SET id = 3 WHERE id = 3;
SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=3',
    ARRAY[2],
    'active_users() should return active users'
);

-- stop the historization
SELECT results_eq('stop_histo',  ARRAY[0], 'stop is successful and return 0');

INSERT INTO test_foobar (id) VALUES (2);
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[2],
       'The data is no more historized');



SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
