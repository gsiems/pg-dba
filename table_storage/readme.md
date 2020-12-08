# Table Storage

How table columns are layed out can impact how much disk space they consume. For large database tables this can be significant.

References:
 * https://medium.com/braintree-product-technology/postgresql-at-scale-saving-space-basically-for-free-d94483d9ed9a
 * https://www.2ndquadrant.com/en/blog/on-rocks-and-sand/
 * https://stackoverflow.com/questions/2966524/calculating-and-saving-space-in-postgresql#7431468
 * https://www.enterprisedb.com/blog/column-storage-intervals
 * https://docs.gitlab.com/ee/development/ordering_table_columns.html

For ruby users, https://github.com/braintree/pg_column_byte_packer can be used to do this.

The [column_alignment_check](column_alignment_check.sql) view can be
used to check the current database tables to see which ones could
potentially benefit from re-ordering. Note that the attempt has been
made to make the output of the view match the results of using
pg_column_byte_packer.


## An example

First, identify a table to test. If this is a large table then it may be desirable to work with a subset of data from the table:

    CREATE TABLE test_base AS
        SELECT *
            FROM <schema_name>.<table_to_test>
            LIMIT !000 ;

Or:

    CREATE TABLE test_base AS
        SELECT *
            FROM <schema_name>.<table_to_test>
                ORDER BY random ()
            LIMIT !000 ;

Next, run the following to generate the statement to create a re-ordered copy of the test_base table:

    SELECT 'CREATE TABLE test_tab_one AS SELECT '
                || string_agg ( column_name, ', ' )
                || ' FROM ' || schema_name || '.' || table_name || '; '
        FROM column_alignment_check
        WHERE table_name = 'test_base'
        GROUP BY schema_name,
            table_name  ;

Finally, compare the two tables to see just how much of a difference re-ordering the columns makeș:

    WITH o AS (
        SELECT pg_relation_size ( 'test_base' ) AS sz
    ),
    n AS (
        SELECT pg_relation_size ( 'test_tab_one' ) AS sz
    )
    SELECT o.sz AS original_size,
            n.sz AS new_size,
            round ( ( 1 - n.sz::numeric / o.sz ) * 100, 2 ) AS percent_reduction
        FROM o
        CROSS JOIN n ;
