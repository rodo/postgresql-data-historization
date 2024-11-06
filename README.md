# postgresql-data-historization
PLPGSQL Script to historize data in partitionned table


## How to historize a table

Data historization process needs 2 steps, a first one to initialize, this
step will create the necessary objects. The second step launch the
historization by setting up the triggers.

```sql
SELECT historize_table_init('public','alpha');

SELECT historize_table_start('public','alpha');
```

The data are stored in a partitioned table to ease the removal of old
data, be sure to create enough partition.

## Creating the partitions

```sql
SELECT historize_create_partition('public', 'alpha_log', 0);
```

## Dropping the partitions

```sql
SELECT historize_drop_partition('public', 'alpha_log', 0);
```

## Create partition with pg_cron

If you want to automatically create partition with (pg_cron)[https://github.com/citusdata/pg_cron] you can add
the following commands


```sql
SELECT cron.schedule_in_database(
  'create-part_1', '00 08 * * *',
  $$SELECT historize_create_partition('my_table', generate_series(1, 4) )$$,
  'my_database');

SELECT cron.schedule_in_database(
  'create-part_1', '00 08 * * *',
  $$SELECT historize_drop_partition('my_table', generate_series(-8, -4) )$$,
  'my_database');
```
