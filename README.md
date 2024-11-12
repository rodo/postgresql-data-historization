# postgresql-data-historization
PLPGSQL Script to historize data in partitionned table


## How to historize a table

Data historization process needs 2 steps, a first one to initialize, this
step will create the necessary objects. The second step launch the
historization by setting up the triggers.

### Initialize the historization

The following function will set up all necessary object to historize
data on a table, no data will be stored after this step

```sql
SELECT historize_table_init('public','alpha');
```

### Start the historization

The function will set up trigger on the source table, once the `start` step is done data will be collected in the table suffix with `_log`

```sql
SELECT historize_table_start('public','alpha');
```

### Stop the historization

The function will remove trigger dans function and stop to store changes in log table

```sql
SELECT historize_table_stop('public','alpha');
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

If you want to automatically create partition with [pg_cron](https://github.com/citusdata/pg_cron) you can add
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

## Create foreign server

In case of the extension pg_cron is installed in another database you
can automaticcaly create the entries through foreign data wrapper.

Be aware of adding the right `search_path` option if the pg_cron extension is not set in public schema. By default pg_cron is installed in the schema named `cron`

```sql
CREATE EXTENSION dblink;
CREATE EXTENSION postgres_fdw;

CREATE SERVER historize_foreign_cron
        FOREIGN DATA WRAPPER dblink_fdw
        OPTIONS (host 'localhost', port '5432', dbname 'postgres', options '-csearch_path=cron');

CREATE USER MAPPING FOR local_user
        SERVER historize_foreign_cron
        OPTIONS (user 'foreign_user', password 'password');
```