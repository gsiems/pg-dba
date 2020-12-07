
CREATE VIEW column_alignment_check AS
WITH o AS (
    SELECT schm.nspname AS schema_name,
            tabs.relname AS table_name,
            cols.attname AS column_name,
            typs.typname AS type_name,
            CASE cols.attalign
                WHEN 'c' THEN 0
                ELSE cols.attlen
                END AS alignment_datum_ref,
            cols.attalign,
            cols.attlen,
            cols.attnum AS current_position,
            cols.attnotnull AS not_null,
            cols.attbyval,
            cols.atttypmod,
            cols.atthasdef AS has_default,
            EXISTS (
                SELECT 1
                    FROM pg_index idx
                    WHERE idx.indisprimary
                      AND cols.attnum = ANY ( idx.indkey )
                      AND idx.indrelid = cols.attrelid
                ) AS is_pk_col
        FROM pg_catalog.pg_class tabs
        JOIN pg_catalog.pg_attribute cols
        ON ( cols.attrelid = tabs.oid )
        JOIN pg_catalog.pg_type typs
            ON ( typs.oid = cols.atttypid )
        JOIN pg_catalog.pg_namespace schm
            ON ( schm.oid = tabs.relnamespace )
        WHERE cols.attnum >= 0
            AND NOT cols.attisdropped
            AND schm.nspname <> 'information_schema'
            AND substr ( schm.nspname, 1, 3 ) <> 'pg_'
            AND tabs.relkind = 'r'
),
n AS (
    SELECT schema_name,
            table_name,
            column_name,
            type_name,
            alignment_datum_ref,
            not_null,
            has_default,
            is_pk_col,
            current_position,
            row_number () OVER (
                PARTITION BY schema_name, table_name
                ORDER BY alignment_datum_ref desc, is_pk_col desc, not_null desc, has_default desc, column_name
                ) AS new_position
        FROM o
),
diff AS (
    SELECT DISTINCT schema_name,
            table_name
        FROM n x
        WHERE EXISTS (
            SELECT 1
                FROM n x2
                WHERE x2.schema_name = x.schema_name
                    AND x2.table_name = x.table_name
                    AND x2.column_name = x.column_name
                    AND x2.current_position <> x.new_position
            )
)
SELECT n.schema_name,
        n.table_name,
        n.column_name,
        n.type_name,
        n.alignment_datum_ref,
        n.is_pk_col,
        n.not_null,
        n.has_default,
        n.current_position,
        n.new_position
    FROM n
    JOIN diff
        ON ( n.schema_name = diff.schema_name
            AND n.table_name = diff.table_name )
    ORDER BY n.schema_name,
        n.table_name,
        n.new_position ;

COMMENT ON VIEW column_alignment_check IS 'View that compares the current column ordering of tables with a calculated "optimal" ordering to determine which tables could be re-organized to save disk space.' ;
