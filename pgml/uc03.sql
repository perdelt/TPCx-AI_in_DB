CREATE OR REPLACE PROCEDURE public.uc03_preprocess(schema TEXT, output_table TEXT)
LANGUAGE plpgsql
AS $procedure$
BEGIN
    IF schema = 'train' THEN
        EXECUTE format('DROP TABLE IF EXISTS %I', output_table);
        EXECUTE format('
            CREATE TABLE %I AS
            WITH combined_data AS (
                SELECT o.store                AS store_id,
                       regexp_replace(lower(p.department), ''[^a-z0-9_]+'', ''_'', ''g'') as department_id,
                       o.date                 AS order_date,
                       li.quantity * li.price AS row_price
                FROM %I."order" o
                         JOIN %I.lineitem li ON o.o_order_id = li.li_order_id
                         JOIN %I.product p ON li.li_product_id = p.p_product_id
            ),
            grouped_sales AS (
                SELECT
                    store_id,
                    department_id,
                    CASE
                        WHEN EXTRACT(''week'' FROM order_date) > 51 AND EXTRACT(''month'' FROM order_date) = 1
                            THEN EXTRACT(''year'' FROM order_date) - 1
                        ELSE EXTRACT(''year'' FROM order_date)
                    END AS year,
                    EXTRACT(''week'' FROM order_date) AS week,
                    SUM(row_price)             AS total_sales
                FROM combined_data
                GROUP BY
                    store_id,
                    department_id,
                    year,
                    week
            )
            SELECT
                ROW_NUMBER() OVER (PARTITION BY store_id, department_id ORDER BY year, week) AS week_index,
                store_id,
                department_id,
                cast(total_sales as float)
            FROM grouped_sales;
        ', output_table, schema, schema, schema);

    ELSIF schema = 'score' THEN
        EXECUTE format('DROP TABLE IF EXISTS %I', output_table);
        EXECUTE format('CREATE TABLE %I AS (
            SELECT
                CAST(s.store AS TEXT) AS store_id,
                REGEXP_REPLACE(LOWER(s.department), ''[^a-z0-9_]+'', ''_'', ''g'') AS department_id,
                s.weekly_sales AS sales,
                EXTRACT(''week'' FROM s.date) AS week_index
            FROM %I.store_dept_labels s
        )', output_table, schema);

    ELSIF schema = 'serve' THEN
        EXECUTE format('DROP VIEW IF EXISTS %I', output_table);
        EXECUTE format('CREATE OR REPLACE VIEW %I AS
                        SELECT *
                        FROM %I.store_dept', output_table, schema);
    END IF;
END;
$procedure$;
CREATE OR REPLACE PROCEDURE public.uc03_train(input_table_name TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record RECORD;
    v_temp_table_name TEXT;
    v_model_table_name TEXT;
BEGIN
     -- Drop all existing ARIMA model tables
    FOR v_model_table_name IN SELECT table_name
                              FROM information_schema.tables
                              WHERE table_schema = 'public'
                              AND table_name LIKE 'arima_model_%'
    LOOP
        EXECUTE format('DROP TABLE IF EXISTS %I', v_model_table_name);
    END LOOP;

    -- loop through distinct store_id and department_id combination
    FOR v_record IN EXECUTE format('SELECT DISTINCT store_id, department_id FROM %I', input_table_name)
    LOOP
        -- Simplify table names by avoiding special characters and preserving case sensitivity
        v_temp_table_name := 'temp_arima_data_' || v_record.store_id || '_' || v_record.department_id;
        v_model_table_name := 'arima_model_' || v_record.store_id || '_' || v_record.department_id;

        -- Drop the temporary table if it exists
        EXECUTE format('DROP TABLE IF EXISTS %I', v_temp_table_name);

        -- Create the temporary table,
        -- use week_index for full training over the period of two years (104 entries for each combination)
        -- use week for training over only 1 year period (52 weeks)
        EXECUTE format('CREATE TABLE %I AS SELECT week_index, total_sales FROM %I WHERE store_id = %L AND department_id = %L',
--         EXECUTE format('CREATE TABLE %I AS SELECT week, total_sales FROM %I WHERE store_id = %L AND department_id = %L',
                       v_temp_table_name, input_table_name, v_record.store_id, v_record.department_id);

        -- train each distinct store_id, department_id temp table
        EXECUTE format('SELECT madlib.arima_train(%L, %L, %L, %L, NULL, FALSE, ARRAY[1, 1, 1])',
                       v_temp_table_name,
--                            v_model_table_name, 'week', 'total_sales');
                       v_model_table_name, 'week_index', 'total_sales');

    END LOOP;
END;
$$;

call uc03_preprocess('train', 'uc03_train_preprocessed');
select * from uc03_train_preprocessed;

CREATE TABLE uc03_lags AS
SELECT
    week_index,
    store_id,
    department_id,
    total_sales,
    -- Lag features (previous total_sales values)
    LAG(total_sales, 1) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_1,
    LAG(total_sales, 2) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_2,
    LAG(total_sales, 3) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_3,
    LAG(total_sales, 4) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_4,
    LAG(total_sales, 5) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_5,
    LAG(total_sales, 6) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_6,
    LAG(total_sales, 7) OVER (PARTITION BY store_id, department_id ORDER BY week_index) AS total_sales_lag_7,
    -- Rolling averages (for smoothing)
    AVG(total_sales) OVER (PARTITION BY store_id, department_id ORDER BY week_index ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS total_sales_avg_3,
    AVG(total_sales) OVER (PARTITION BY store_id, department_id ORDER BY week_index ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS total_sales_avg_7
FROM uc03_train_preprocessed;
select * from uc03_lags;

-- testing with 1 store_id and 1 department_id combination
drop table if exists uc03_test;
CREATE TABLE IF NOT EXISTS uc03_test AS
select * from uc03_train_preprocessed where store_id = 1 and department_id = 'automotive';
select * from uc03_test;
-- train with xgboost
SELECT * FROM pgml.train(
    'uc03_test',  -- Model name
    'regression',               -- Regression task (not clustering/classification)
    'uc03_test',   -- Training table
    'total_sales',
    algorithm => 'xgboost',     -- Algorithm choice
    search => 'grid',
    search_params => '{
       "max_depth": [3, 5, 7],
       "n_estimators": [100, 500, 1000],
       "eta": [0.1, 0.01, 0.001]}'::JSONB
); -- r2 = -10
-- train with adaboost
SELECT * FROM pgml.train(
    'uc03_test',  -- Model name
    'regression',               -- Regression task (not clustering/classification)
    'uc03_test',   -- Training table
    'total_sales',
    algorithm => 'ada_boost'
);

-- train with lags
drop table if exists uc03_test_lags;
CREATE TABLE IF NOT EXISTS uc03_test_lags AS
select * from uc03_lags where store_id = 1 and department_id = 'automotive';
select * from uc03_test_lags;
-- train with xgboost;
SELECT * FROM pgml.train(
    'uc03_test_lags',  -- Model name
    'regression',               -- Regression task (not clustering/classification)
    'uc03_test_lags',   -- Training table
    'total_sales',
    algorithm => 'xgboost',     -- Algorithm choice
    hyperparams => '{
        "n_estimators": 100,
        "learning_rate": 0.1,
        "max_depth": 6
    }',
    preprocess => '{
        "total_sales_lag_1": {"impute": "mean"},
        "total_sales_lag_2": {"impute": "mean"},
        "total_sales_lag_3": {"impute": "mean"},
        "total_sales_lag_4": {"impute": "mean"},
        "total_sales_lag_5": {"impute": "mean"},
        "total_sales_lag_6": {"impute": "mean"},
        "total_sales_lag_7": {"impute": "mean"}
    }'
);
--train with adaboost
SELECT * FROM pgml.train(
    'test',  -- Model name
    'regression',               -- Regression task (not clustering/classification)
    'test',   -- Training table
    'total_sales',
    algorithm => 'ada_boost',     -- Algorithm choice
--     search => 'grid',
--     search_params => '{
--        "max_depth": [3, 5, 7],
--        "n_estimators": [100, 500, 1000],
--        "eta": [0.1, 0.01, 0.001]}'::JSONB,
    preprocess => '{
        "sales_lag_1": {"impute": "mean"},
        "sales_lag_2": {"impute": "mean"},
        "sales_lag_3": {"impute": "mean"},
        "sales_lag_4": {"impute": "mean"},
        "sales_lag_5": {"impute": "mean"},
        "sales_lag_6": {"impute": "mean"},
        "sales_lag_7": {"impute": "mean"}
    }'
);

select * from uc03_train_preprocessed;
-- scoring with one department_id and one store_id for testing purpose
call uc03_preprocess('score', 'uc03_score_preprocessed');
select * from uc03_score_preprocessed;
drop table if exists uc03_scoring_test;
create table uc03_scoring_test as select * from uc03_score_preprocessed
where store_id = '1';
select * from uc03_scoring_test;

-- compare results with python training,
-- .csv file with the same training data
-- as in python xgboost training procedure
drop table if exists sales_data;
CREATE TABLE sales_data (
    week_index numeric,
    store_id numeric,
    department_id numeric,
    total_sales NUMERIC,
    total_sales_lag_1 NUMERIC,
    total_sales_lag_2 NUMERIC,
    total_sales_lag_3 NUMERIC,
    total_sales_lag_4 NUMERIC,
    total_sales_lag_5 NUMERIC,
    total_sales_lag_6 NUMERIC,
    total_sales_lag_7 NUMERIC,
    total_sales_avg_3 NUMERIC,
    total_sales_avg_7 NUMERIC,
    moving_avg NUMERIC
);
-- \COPY sales_data from '/home/ll/inDB_ML_survey/temp_data/uc03_test_sales.csv' with csv header;
select * from sales_data;

-- remove week_index, store_id, department_id
drop table if exists sales_data2;
create table sales_data2 as
    select week_index, total_sales, total_sales_lag_1, total_sales_lag_2,
           total_sales_lag_3, total_sales_lag_4, total_sales_lag_5,
           total_sales_lag_6, total_sales_lag_7, total_sales_avg_3,
           total_sales_avg_7, moving_avg from sales_data;

SELECT * FROM pgml.train(
    'sales_model',  -- Model name
    'regression',               -- Regression task (not clustering/classification)
    'sales_data2',   -- Training table
    'total_sales',
    algorithm => 'xgboost',     -- Algorithm choice
    hyperparams => '{
    "eval_metric": "mae",
    "max_depth": 6,
    "eta": 0.1,
    "subsample": 0.8,
    "colsample_bytree": 0.8,
    "min_child_weight": 1}'
    );

-- maybe scaling?
drop table if exists scaled_sales_data;
CREATE table scaled_sales_data AS
SELECT
    *,
    (total_sales - avg(total_sales) OVER()) / NULLIF(stddev(total_sales) OVER(), 0) as scaled_total_sales,
    (total_sales_lag_1 - avg(total_sales_lag_1) OVER()) / NULLIF(stddev(total_sales_lag_1) OVER(), 0) as scaled_lag_1
    -- Add other columns similarly
FROM sales_data;
select * from scaled_sales_data;

-- Then train on the scaled data
SELECT pgml.train(
    'sales_prediction_model',
    'regression',
    'scaled_sales_data',
    'total_sales',
    'xgboost',
    '{"max_depth": 6, "eta": 0.1, "subsample": 0.8}'
);
-- with the hyperparams as in python xgboost
SELECT pgml.train(
    'sales_prediction_model',
    'regression',
    'scaled_sales_data',
    'total_sales',
    'xgboost',
    hyperparams => '{
        "max_depth": 6,
        "eta": 0.1,
        "subsample": 0.8,
        "colsample_bytree": 0.8,
        "min_child_weight": 1,
        "n_estimators": 100
    }',
    test_size => 0.2,
    test_sampling => 'last'  -- This ensures we use the last 20% as test data, similar to time series validation
);

-- ## training not working -> while xgboost in python is able to do rather accurate prediction,
-- ## training not working in pgml for unknown reasons. Steps


