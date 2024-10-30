BEGIN;

-- six tests will be run
SELECT plan(3);


CREATE TABLE test_foobar (id int) PARTITION BY RANGE(id);


PREPARE call_func AS
SELECT create_tab_part(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-01')::int
) ;

SELECT results_eq(
       'call_func',
       ARRAY[1]
);

SELECT create_tab_part(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
) ;

SELECT partitions_are(
    'public', 'test_foobar',
    ARRAY[ 'test_foobar_20240102', 'test_foobar_20240103' ]
);

SELECT drop_tab_part(
  'test_foobar',
  1 - EXTRACT(DAY FROM now() - '2024-01-02')::int
) ;

SELECT partitions_are(
    'public', 'test_foobar',
    ARRAY[ 'test_foobar_20240102' ]
);

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
