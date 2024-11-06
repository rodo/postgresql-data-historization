BEGIN;

DEALLOCATE PREPARE ALL;

-- six tests will be run
SELECT plan(3);


CREATE TABLE test_foobar_log (id int) PARTITION BY RANGE(id);


PREPARE call_func AS
SELECT historize_create_partition(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;

SELECT results_eq(
       'call_func',
       ARRAY[0]
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
