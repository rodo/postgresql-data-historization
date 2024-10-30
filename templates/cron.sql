--
-- create partitions for the next 4 days twice a day
--
SELECT cron.schedule_in_database('create-partitions-{{tablename}}_log_1', '00 08 * * *',$$SELECT create_tab_part('{{tablename}}_log', generate_series(1, 4, 1) )$$, '{{database}}');
SELECT cron.schedule_in_database('create-partitions-{{tablename}}_log_2', '10 13 * * *',$$SELECT create_tab_part('{{tablename}}_log', generate_series(1, 4, 1) )$$, '{{database}}');

--
-- drop partitions, keep one week
--
SELECT cron.schedule_in_database('drop-partitions-{{tablename}}_log_1', '00 08 * * *',$$SELECT drop_tab_part('{{tablename}}_log',generate_series(-10, -8, 1) )$$,'external_is_service');
SELECT cron.schedule_in_database('drop-partitions-{{tablename}}_log_2', '10 13 * * *',$$SELECT drop_tab_part('{{tablename}}_log',generate_series(-10, -8, 1) )$$,'external_is_service');
