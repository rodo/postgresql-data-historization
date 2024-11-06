# postgresql-data-historization
PLPGSQL Script to historize data in partitionned table


## Howto historize a table

Historizastion process needs 2 steps, a first one to initialize, this
step will create the necessary objects. The second step launch the
historization by setting up the triggers.


```sql

SELECT historize_table_init('public','alpha');

SELECT historize_table_start('public','alpha');
```


## Create the partitions

```sql

SELECT create_tab_part('alpha_log',0);

```