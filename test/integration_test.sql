DEALLOCATE PREPARE ALL;


BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_foobar');

PREPARE start_histo AS
  SELECT historize_table_start('public','test_foobar');

PREPARE stop_histo AS
  SELECT historize_table_stop('public','test_foobar');


-- Define the number of tests to run
SELECT plan(15);

CREATE TABLE test_foobar (id int, fname text DEFAULT 'alpha') ;

-- initialize the historization
--

SELECT lives_ok('init_histo', 'init is successful');

SELECT has_table('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log exists');
SELECT is_partitioned('public'::name, 'test_foobar_log'::name, 'Table public.test_foobar_log is partitioned');

--
PREPARE call_func AS
SELECT historize_create_partition(
  'public',
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;

SELECT lives_ok('call_func');

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
          ],
    'All required partitions exists'
);

-- Drop a partition
SELECT historize_drop_partition('public',
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
    ],
    'Number of partitions are correct after dropping one'
);

-- create a partition to store data of today
SELECT historize_create_partition('test_foobar', 0);

--
-- the historization is not alreday started
--
INSERT INTO test_foobar (id) VALUES (1);
UPDATE test_foobar SET fname = 'beta' WHERE id = 1;

PREPARE count_log AS SELECT count(*)::int FROM test_foobar_log;
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[0],
       'The data is not historized');

-- start the historization
SELECT lives_ok('start_histo');

INSERT INTO test_foobar (id) VALUES (2),(3);
UPDATE test_foobar SET fname = 'beta' WHERE id = 2;
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[1],
       'The data is well historized');

SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=3',
    ARRAY[1],
    'The histo version is correct for row 3'
);

SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=2',
    ARRAY[2],
    'The histo version is correct for row 2'
);
--
-- Test that updating a row increase the version
--
UPDATE test_foobar SET fname = 'delta' WHERE id = 3;
SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=3',
    ARRAY[2],
    'The histo version is correct'
);
--
-- Test that updating a row without changing values do not change version
--
UPDATE test_foobar SET fname = 'echo' WHERE id = 3;
SELECT results_eq(
    'SELECT histo_version FROM test_foobar WHERE id=3',
    ARRAY[3]
);

-- stop the historization
SELECT lives_ok('stop_histo');

INSERT INTO test_foobar (id) VALUES (2);
SELECT results_eq(
       'EXECUTE count_log',
       ARRAY[3],
       'The data is no more historized');



SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
