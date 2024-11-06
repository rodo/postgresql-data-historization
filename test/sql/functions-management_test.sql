BEGIN;

DEALLOCATE PREPARE ALL;

-- six tests will be run
SELECT plan(6);


CREATE TABLE test_foobar_log (id int) PARTITION BY RANGE(id);


PREPARE create_partition AS
SELECT historize_create_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;

PREPARE check_partition AS
SELECT historize_check_partition(
  'public',
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;


--
--
SELECT results_eq(
       'check_partition',
       ARRAY[2],
       'The partition does not exists, return 2'
);
--
SELECT results_eq(
       'create_partition',
       ARRAY[0],
       'The partition is created, return 0'
);

SELECT results_eq(
       'create_partition',
       ARRAY[2],
       'The partition already exists, return 2'
);


SELECT results_eq(
       'check_partition',
       ARRAY[0],
       'The partition exists, return 0'
);

SELECT historize_create_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
) ;

SELECT partitions_are(
    'public', 'test_foobar_log',
    ARRAY[ 'test_foobar_log_20240102', 'test_foobar_log_20240103' ]
);

SELECT historize_drop_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
) ;

SELECT partitions_are(
    'public', 'test_foobar_log',
    ARRAY[ 'test_foobar_log_20240102' ]
);






SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
