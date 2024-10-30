SELECT cron.unschedule('create-partitions-{{tablename}}_log_1');
SELECT cron.unschedule('create-partitions-{{tablename}}_log_2');
SELECT cron.unschedule('drop-partitions-{{tablename}}_log_1');
SELECT cron.unschedule('drop-partitions-{{tablename}}_log_2');
