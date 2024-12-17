--
-- Test the auto add comment
--
SET client_min_messages TO WARNING;

DEALLOCATE PREPARE ALL;

BEGIN;

PREPARE init_histo AS
  SELECT historize_table_init('public','test_comment');

PREPARE reset_histo AS
  SELECT historize_table_reset('public','test_comment');

PREPARE clean_histo AS
  SELECT historize_table_clean('public','test_comment');


-- Define the number of tests to run
SELECT plan(12);

CREATE TABLE test_comment (id int, fname text DEFAULT 'alpha') ;

-- initialize the historization
--

SELECT results_eq(
    'SELECT historize_get_column_default_comment()',
    ARRAY[null],
    'The default comment is not set'
);

SELECT lives_ok('SELECT historize_define_column_default_comment(''toto'')', 'Define the default comment');

SELECT results_eq(
    'SELECT historize_get_column_default_comment()',
    ARRAY['toto'],
    'The default comment is now set to toto'
);

SELECT lives_ok('init_histo', 'historize_table_init() is successful');

--
-- check if the comment is well set on the new column histo_version
--
SELECT results_eq(
    'select pg_catalog.col_description(''test_comment''::regclass,3);',
    ARRAY['toto'],
    'The comment on column histo_version is ''toto'''
);

SELECT results_eq(
    'select pg_catalog.col_description(''test_comment''::regclass,4);',
    ARRAY['toto'],
    'The comment on column histo_sys_period is ''toto'''
);


SELECT lives_ok('reset_histo', 'historize_table_reset() is successful');
SELECT lives_ok('clean_histo', 'historize_table_clean() is successful');

SELECT lives_ok('SELECT historize_reset_column_default_comment()', 'Reset the default comment');

SELECT lives_ok('init_histo', 'historize_table_init() is successful');

SELECT results_eq(
    'select pg_catalog.col_description(''test_comment''::regclass,3);',
    ARRAY[null],
    'The comment on column histo_version is null'
);

SELECT results_eq(
    'select pg_catalog.col_description(''test_comment''::regclass,4);',
    ARRAY[null],
    'The comment on column histo_sys_period is null'
);



SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
