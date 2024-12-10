BEGIN;

-- Define the number of tests to run
SELECT plan(2);

SELECT has_function('historize_get_logname'::name);

SELECT is(historize_get_logname('fi', 'foo'), 'fi.foo_log'::text, 'fi.foo_log' );

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
