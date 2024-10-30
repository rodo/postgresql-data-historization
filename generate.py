#!/usr/bin/env python

"""
Manage huge and sometimes complex data migration in 3 steps

- Edit the variable tables 10 lines below in this script
- Run the script
- Enjoy the SQL files generated

"""
import os
import argparse
from jinja2 import Environment, FileSystemLoader

environment = Environment(loader=FileSystemLoader("templates/"))

def generate_file(template_test, filename, database, tablename, timeout):
    """
    Load a jinja template and generate the associated file
    """
    with open(filename, mode="w", encoding="utf-8") as message:
        message.write(template_test.render(database=database,
                                           tablename=tablename,
                                           table_log=f'create2-partitions-{tablename}_log',
                                           timeout=timeout))
        print(f"... wrote {filename}")



def generate_global_file(path, database, tablename, timeout):
    """
    Generate files in the specified directory `path`
    """

    for filename in ['cron', 'cron-remove', 'table', 'table_test', 'trigger', 'trigger_test']:

        generate_file(
            environment.get_template(f'{filename}.sql'),
            os.path.join(path, f'{filename}.sql'),
            database,
            tablename,
            timeout
        )

def main(database, tablename, timeout):
    """
    Do the generation of files in the global directory and in a drectory per table
    """

    # generate the SQL command in global files
    generate_global_file("output", database, tablename, timeout)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--database", help="the database name", required=True)
    parser.add_argument("-t", "--table", help="the table name", required=True)
    parser.add_argument("--timeout", help="statement timeout in ms", type=int, default=50)
    args = parser.parse_args()
    main(args.database, args.table, args.timeout)
