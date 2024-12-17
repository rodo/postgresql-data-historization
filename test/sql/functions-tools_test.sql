BEGIN;

-- Define the number of tests to run
SELECT plan(12);

SELECT has_function('historize_get_logname'::name, ARRAY['name','name']);
SELECT function_returns('historize_get_logname'::name, ARRAY['name','name'], 'text');
SELECT isnt_definer('historize_get_logname'::name, ARRAY['name','name']);
SELECT is_normal_function('historize_get_logname'::name, ARRAY['name','name']);

SELECT is(historize_get_logname('fi', 'foo'), 'fi.foo_log'::text, 'fi.foo_log');
--
--
--
SELECT has_function('historize_get_column_default_comment'::name);
SELECT function_returns('historize_get_column_default_comment'::name, 'text');
SELECT isnt_definer('historize_get_column_default_comment'::name);
--
--
SELECT has_function('historize_define_column_default_comment'::name, ARRAY['text']);
SELECT function_returns('historize_define_column_default_comment'::name, ARRAY['text'],'text');
--
--
SELECT has_function('historize_reset_column_default_comment'::name);
SELECT function_returns('historize_reset_column_default_comment'::name,'text');

SELECT * FROM finish();
-- Always end unittest with a rollback
ROLLBACK;
