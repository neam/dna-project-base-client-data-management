SET @database_name = DATABASE();
SET SESSION group_concat_max_len = 10240;

SET @arguments = NULL;
SELECT
    IFNULL(GROUP_CONCAT('--ignore-table ', table_schema, '.', table_name SEPARATOR ' '),'')
INTO @arguments
FROM
    information_schema.views
WHERE
    table_schema = @database_name;

SELECT @arguments;