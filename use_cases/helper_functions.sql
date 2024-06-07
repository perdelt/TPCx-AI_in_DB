
create or replace language plpython3u;
-- save results at the end of an end to end run
CREATE OR REPLACE PROCEDURE save_results(
    prefix TEXT
)
AS $$
DECLARE
    timeit_table TEXT := prefix || '_timeit';
    properties_table TEXT := prefix || '_table_properties';
    results_table TEXT := prefix || '_score_results';
    runtime interval;
    total_size text;
BEGIN
    call populate_items_property();

    -- Drop the output tables if they exist
    EXECUTE format('DROP TABLE IF EXISTS %I', timeit_table);
    EXECUTE format('DROP TABLE IF EXISTS %I', properties_table);
    EXECUTE format('DROP TABLE IF EXISTS %I', results_table);

    -- Create the timeit table with the same structure and data as execution_times
    EXECUTE format('CREATE TABLE %I AS TABLE execution_times', timeit_table);
    -- Add the id column as the primary key to the timeit table
    EXECUTE format('ALTER TABLE %I ADD COLUMN id SERIAL PRIMARY KEY', timeit_table);

    -- Create the properties table with the same structure and data as items_property
    EXECUTE format('CREATE TABLE %I AS TABLE items_property', properties_table);
    EXECUTE format('ALTER TABLE %I ADD COLUMN id SERIAL PRIMARY KEY', properties_table);

    -- Create the results table with the same structure and data as evaluation_results
    EXECUTE format('CREATE TABLE %I AS TABLE evaluation_results', results_table);
    EXECUTE format('ALTER TABLE %I ADD COLUMN id SERIAL PRIMARY KEY', results_table);

    -- Raise a notice with the names of the created tables
    RAISE INFO 'Created tables: %, %, %', timeit_table, properties_table, results_table;

    EXECUTE format('SELECT sum(execution_time::interval) FROM %I', timeit_table) INTO runtime;
    RAISE INFO 'Total Runtime: %', to_char(runtime, 'HH24:MI:SS');
END;
$$ LANGUAGE plpgsql;

-- evaluation table for saving scoring results
CREATE OR REPLACE PROCEDURE create_evaluation_results_table()
AS $$
BEGIN
    Drop table if exists public.evaluation_results;
  CREATE TABLE if not exists public.evaluation_results (
    usecase INTEGER,
    date_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    evaluation_score NUMERIC
  );
END;
$$ LANGUAGE plpgsql;

-- MinMax Scaling Function, fit function
CREATE OR REPLACE FUNCTION minmax_scaling(
    input_table TEXT,
    feature_columns TEXT[],
    scaling_table TEXT DEFAULT 'minmax_scaling_table'
)
RETURNS void AS $$
DECLARE
    col TEXT;
BEGIN
    execute format('drop table if exists %I', scaling_table);
    -- Create the scaling table if it doesn't exist
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            column_name TEXT PRIMARY KEY,
            min_value NUMERIC,
            max_value NUMERIC
        )', scaling_table);

    -- Loop through each feature column to calculate and store scaling parameters
    FOREACH col IN ARRAY feature_columns LOOP
        EXECUTE format('
            WITH minmax AS (
                SELECT
                    MIN(%I) AS min_value,
                    MAX(%I) AS max_value
                FROM %I
            )
            INSERT INTO %I (column_name, min_value, max_value)
            SELECT %L, min_value, max_value
            FROM minmax
            ON CONFLICT (column_name) DO UPDATE SET
                min_value = EXCLUDED.min_value,
                max_value = EXCLUDED.max_value
        ', col, col, input_table, scaling_table, col);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Apply MinMax Scaling Function, transform function
CREATE OR REPLACE FUNCTION apply_minmax(
    input_table TEXT,
    feature_columns TEXT[],
    scaling_table TEXT
)
RETURNS void AS $$
DECLARE
    col TEXT;
BEGIN
    -- Loop through each feature column and apply MinMax scaling
    FOREACH col IN ARRAY feature_columns LOOP
        EXECUTE format('
            WITH scaling_params AS (
                SELECT min_value, max_value
                FROM %I
                WHERE column_name = %L
            )
            UPDATE %I
            SET %I = CASE
                WHEN scaling_params.max_value = scaling_params.min_value THEN 0
                ELSE (%I - scaling_params.min_value) / (scaling_params.max_value - scaling_params.min_value)
            END
            FROM scaling_params
        ', scaling_table, col, input_table, col, col);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- standardization
-- fit and transform
CREATE OR REPLACE FUNCTION standardize_features(input_table TEXT, feature_columns TEXT[], scaling_table TEXT DEFAULT 'standardization_scaling_table')
RETURNS void AS $$
DECLARE
    column_name TEXT;
    avg FLOAT;
    std FLOAT;
BEGIN
    -- Create the scaling table if it doesn't exist
    EXECUTE format('
        CREATE TABLE IF NOT EXISTS %I (
            column_name TEXT PRIMARY KEY,
            mean FLOAT,
            std FLOAT
        )', scaling_table);

    -- Loop through each feature column to standardize
    FOREACH column_name IN ARRAY feature_columns LOOP
        -- Calculate the mean and standard deviation and store them in variables
        EXECUTE format('
            SELECT
                AVG(%I) AS mean,
                STDDEV(%I) AS std
            FROM %I
        ', column_name, column_name, input_table) INTO avg, std;

        -- Insert or update the scaling parameters in the scaling table
        EXECUTE format('
            INSERT INTO %I (column_name, mean, std)
            VALUES (%L, %s, %s)
            ON CONFLICT (column_name) DO UPDATE SET
                mean = EXCLUDED.mean,
                std = EXCLUDED.std
        ', scaling_table, column_name, avg, std);

        -- Perform the standardization using the stored mean and standard deviation
        EXECUTE format('
            UPDATE %I SET %I = (%I - %s) / %s
        ', input_table, column_name, column_name, avg, std);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- transform function with given fitted values(scaling table)
CREATE OR REPLACE FUNCTION apply_standardization(
    input_table varchar(100),
    output_table varchar(100),
    feature_columns TEXT[],
    scaling_table TEXT
)
RETURNS void AS $$
DECLARE
    column_name TEXT;
BEGIN
    execute format('drop table if exists %I;', output_table);
    -- Create the output table as a copy of the input table
    EXECUTE format('CREATE TABLE %I AS TABLE %I;', output_table, input_table);

    -- Loop through each feature column to apply standardization
    FOREACH column_name IN ARRAY feature_columns LOOP
        EXECUTE format('
            UPDATE %I
            SET %I = (%I - scaling.mean) / scaling.std
            FROM (
                SELECT mean, std
                FROM %I
                WHERE column_name = %L
            ) AS scaling
        ', output_table, column_name, column_name, scaling_table, column_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- python imblearn adasyn oversampling (sythethic oversampling with focus on hard to differentiate samples
CREATE OR REPLACE FUNCTION imba_adasyn(input_table TEXT, output_table TEXT, feature_columns TEXT[], label_column TEXT)
RETURNS void AS $$
import pandas as pd
from imblearn.over_sampling import ADASYN

# Ensure the PL/Python environment correctly handles the string formatting:
try:
    # Create a new table based on the structure of the input table
    plpy.execute(f"CREATE TABLE IF NOT EXISTS {output_table} (LIKE {input_table} INCLUDING ALL)")
except Exception as e:
    plpy.error(f"Error creating table: {e}")

# Load data from the input table
df_query = f"SELECT * FROM {input_table}"
result = plpy.execute(df_query)
data = [dict(row) for row in result]
df = pd.DataFrame(data)

# Use the provided feature and label columns
features = df[list(feature_columns)]
labels = df[label_column]

# Apply ADASYN
adasyn = ADASYN(random_state=42)
features_resampled, labels_resampled = adasyn.fit_resample(features, labels)

# Create a new DataFrame from the resampled data
df_resampled = pd.DataFrame(features_resampled, columns=features.columns)
df_resampled[label_column] = labels_resampled

# Insert the resampled data back into the output table
for index, row in df_resampled.iterrows():
    columns = ', '.join(df_resampled.columns)
    values = ', '.join([f"'{val}'" if isinstance(val, str) else str(val) for val in row])
    query = f"INSERT INTO {output_table} ({columns}) VALUES ({values})"
    plpy.execute(query)

$$ LANGUAGE plpython3u;

-- Mean Absolute Error (MAE) function
CREATE OR REPLACE FUNCTION calculate_mae(
    input_table REGCLASS,
    prediction_column TEXT,
    label_column TEXT
)
RETURNS FLOAT AS $$
DECLARE
    mae FLOAT;
BEGIN
    EXECUTE format('
        SELECT AVG(ABS(%I - %I))
        FROM %s
    ', prediction_column, label_column, input_table)
    INTO mae;

    RETURN mae;
END;
$$ LANGUAGE plpgsql;

-- f1 score for classification problems
DROP FUNCTION IF EXISTS f1_score(text,text,text);
CREATE OR REPLACE FUNCTION f1_score(
  input_table TEXT,
  label TEXT,
  prediction TEXT
) RETURNS TABLE (
  "F1_Score" FLOAT
) AS $$
BEGIN
  RETURN QUERY EXECUTE format('
    WITH metrics AS (
      SELECT
        SUM(CASE WHEN t.label = 1 AND t.prediction = 1 THEN 1 ELSE 0 END)::FLOAT AS "TP",
        SUM(CASE WHEN t.label = 0 AND t.prediction = 1 THEN 1 ELSE 0 END)::FLOAT AS "FP",
        SUM(CASE WHEN t.label = 1 AND t.prediction = 0 THEN 1 ELSE 0 END)::FLOAT AS "FN"
      FROM (
        SELECT
          (CASE WHEN %I::INTEGER = 1 THEN 1 ELSE 0 END) AS label,
          (CASE WHEN %I::INTEGER = 1 THEN 1 ELSE 0 END) AS prediction
        FROM %I
      ) AS t
    )
    SELECT
      (2.0 * metrics."TP") / (2.0 * metrics."TP" + metrics."FP" + metrics."FN") AS "F1_Score"
    FROM metrics;
  ', label, prediction, input_table);
END;
$$ LANGUAGE plpgsql;


-- mathews correlation coefficient metric for classification problems
CREATE OR REPLACE FUNCTION calculate_mcc(input_table TEXT, predictions TEXT, true_value TEXT)
RETURNS FLOAT AS $$
DECLARE
    tp FLOAT;
    tn FLOAT;
    fp FLOAT;
    fn FLOAT;
    mcc FLOAT;
    query TEXT;
BEGIN
    -- Calculate True Positives
    EXECUTE 'SELECT COUNT(*) FROM ' || input_table || ' WHERE ' || predictions || ' = 1 AND ' || true_value || ' = 1' INTO tp;

    -- Calculate True Negatives
    EXECUTE 'SELECT COUNT(*) FROM ' || input_table || ' WHERE ' || predictions || ' = 0 AND ' || true_value || ' = 0' INTO tn;

    -- Calculate False Positives
    EXECUTE 'SELECT COUNT(*) FROM ' || input_table || ' WHERE ' || predictions || ' = 1 AND ' || true_value || ' = 0' INTO fp;

    -- Calculate False Negatives
    EXECUTE 'SELECT COUNT(*) FROM ' || input_table || ' WHERE ' || predictions || ' = 0 AND ' || true_value || ' = 1' INTO fn;

    -- Calculate MCC
    mcc := (tp * tn - fp * fn) / SQRT((tp + fp) * (tp + fn) * (tn + fp) * (tn + fn));

    -- Handle division by zero if any of the denominators are zero
    IF (tp + fp) = 0 OR (tp + fn) = 0 OR (tn + fp) = 0 OR (tn + fn) = 0 THEN
        RETURN 0; -- Or handle as appropriate for your application
    ELSE
        RETURN mcc;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- accuray metric for classification problems
CREATE OR REPLACE FUNCTION accuracy(
    input_table VARCHAR,
    prediction_column VARCHAR,
    true_value_column VARCHAR
)
RETURNS FLOAT AS $$
DECLARE
    accuracy FLOAT;
BEGIN
    EXECUTE format('
        SELECT (COUNT(*) FILTER (WHERE %I = %I)::FLOAT / COUNT(*))
        FROM %I',
        prediction_column, true_value_column, input_table
    ) INTO accuracy;

    RETURN accuracy;
END;
$$ LANGUAGE plpgsql;

-- mean squared log error (MSLE)
CREATE OR REPLACE FUNCTION public.calculate_msle(input_table TEXT, label TEXT, prediction TEXT)
RETURNS FLOAT
LANGUAGE plpgsql
AS $$
DECLARE
    msle FLOAT;
BEGIN
    EXECUTE format('
        SELECT
            AVG(POWER(LN(ABS(%I - %I) + 1), 2))
        FROM
            %I', label, prediction, input_table) INTO STRICT msle;
    RETURN msle;
END;
$$;

-- timer function
CREATE OR REPLACE FUNCTION record_execution_time(
    p_use_case VARCHAR(10),
    p_step VARCHAR(50),
    p_start_time TIMESTAMP
)
RETURNS VOID AS $$
DECLARE
    v_end_time TIMESTAMP := clock_timestamp();
    v_execution_time INTERVAL := v_end_time - p_start_time;
    v_formatted_execution_time VARCHAR(15);
BEGIN
    v_formatted_execution_time := to_char(v_execution_time, 'HH24:MI:SS.US');

    INSERT INTO execution_times (use_case, step, start_time, end_time, execution_time)
    VALUES (p_use_case, p_step, p_start_time, v_end_time, v_formatted_execution_time);
END;
$$ LANGUAGE plpgsql;

-- create table for timer function
create or replace procedure timeit() as $$
    begin
        drop table if exists execution_times;
        CREATE TABLE if not exists execution_times (
            use_case VARCHAR(10),
            step VARCHAR(50),
            start_time timestamp,
            end_time timestamp,
            execution_time varchar(100));
    end; $$ language plpgsql;




-- procedure to extract properties (column names, sizes) from various trained models, preprocessed tables etc
-- procedure to extract properties (column names, sizes) from various trained models, preprocessed tables etc
CREATE OR REPLACE PROCEDURE populate_items_property()
LANGUAGE plpgsql
AS $$
DECLARE
    v_model_table_name TEXT;
    v_total_size BIGINT := 0;
    v_model_size BIGINT;
    v_columns TEXT[];
    v_model_count INT := 0;
BEGIN
    DROP TABLE IF EXISTS items_property;
    CREATE TABLE items_property (
        item_name VARCHAR(100),
        columns TEXT[],
        size TEXT
    );

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc01_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc01_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc01_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc01_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc01_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc01_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc01_score_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc01_score_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc01_score_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc01_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc01_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc01_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc03_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc03_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc03_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc03_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc03_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc03_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc03_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc03_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc03_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc04_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc04_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc04_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc04_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc04_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc04_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc04_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc04_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc04_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc04_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc04_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc04_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc06_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc06_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc06_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc06_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc06_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc06_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc06_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc06_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc06_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc06_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc06_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc06_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT
      'uc07_train_preprocessed',
      string_to_array(string_agg(column_name, ','), ','),
      pg_size_pretty(pg_total_relation_size('train.productrating'))
    FROM information_schema.columns
    WHERE table_name = 'productrating' AND table_schema = 'train';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc07_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc07_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc07_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc07_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc07_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc07_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc07_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc07_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc07_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc08_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc08_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc08_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc08_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc08_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc08_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc08_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc08_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc08_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc08_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc08_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc08_serve_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc10_train_preprocessed', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc10_train_preprocessed'))
    FROM information_schema.columns
    WHERE table_name = 'uc10_train_preprocessed';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc10_model', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc10_model'))
    FROM information_schema.columns
    WHERE table_name = 'uc10_model';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc10_score_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc10_score_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc10_score_results';

    INSERT INTO items_property (item_name, columns, size)
    SELECT 'uc10_serve_results', array_agg(column_name), pg_size_pretty(pg_total_relation_size('uc10_serve_results'))
    FROM information_schema.columns
    WHERE table_name = 'uc10_serve_results';

    -- Aggregating uc03 model sizes
    FOR v_model_table_name IN
        SELECT table_name
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name LIKE 'arima_model_%'
        AND table_name NOT LIKE '%\_summary' ESCAPE '\'
        AND table_name NOT LIKE '%\_residual' ESCAPE '\'
    LOOP
        EXECUTE format('SELECT pg_total_relation_size(%L)', v_model_table_name) INTO v_model_size;
        v_total_size := v_total_size + v_model_size;
        v_model_count := v_model_count + 1;
        RAISE NOTICE 'Model: %, Size: %', v_model_table_name, pg_size_pretty(v_model_size);
    END LOOP;

    INSERT INTO items_property (item_name, columns, size)
    VALUES (format('uc03_models (%s models)', v_model_count), v_columns, pg_size_pretty(v_total_size));
END;
$$;

-- view drop_tables for all public dropable tables
-- Create a function to generate DROP TABLE commands for multiple schemas
CREATE OR REPLACE FUNCTION generate_drop_commands(schema_names text[]) RETURNS SETOF text AS $$
BEGIN
  RETURN QUERY
  SELECT 'DROP TABLE IF EXISTS "' || schemaname || '"."' || tablename || '" CASCADE;'
  FROM pg_tables
  WHERE schemaname = ANY(schema_names);
END;
$$ LANGUAGE plpgsql;

-- Create a function to execute DROP TABLE commands
CREATE OR REPLACE FUNCTION drop_all_tables(schema_names text[]) RETURNS void AS $$
DECLARE
  drop_command text;
BEGIN
  FOR drop_command IN (SELECT generate_drop_commands(schema_names)) LOOP
    EXECUTE drop_command;
  END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Usage:
-- select generate_drop_commands(ARRAY['train', 'serve', 'score']);
-- SELECT drop_all_tables(ARRAY['train', 'serve', 'score']); -- 'public'
-- -- -- check if tables are dropped or not:
-- SELECT * FROM information_schema.tables
-- WHERE table_schema = 'train';


-- find the python executable for current database (for installing python packages)
-- CREATE OR REPLACE FUNCTION get_python_env()
-- RETURNS text AS $$
-- import os
-- return str(os.environ)
-- $$ LANGUAGE plpython3u;

-- -- ---- dropping overloaded procedures ----
-- SELECT proname, pg_get_function_identity_arguments(p.oid) AS arguments
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.proname = 'uc06_preprocess';
-- -- drop procedure if exists public.uc08_score(IN prediction_table character varying);
--
-- -- find the code for a procedure --
-- SELECT pg_get_functiondef(p.oid)
-- FROM pg_proc p
-- JOIN pg_namespace n ON n.oid = p.pronamespace
-- WHERE n.nspname = 'public' AND p.proname = 'uc06_preprocess';

-- -- timeit wrapper for procedures
-- DROP FUNCTION IF EXISTS timeit_procedure(text,character varying,character varying);
-- CREATE OR REPLACE FUNCTION timeit_procedure(proc_name TEXT, input_schema VARCHAR, output_table VARCHAR) RETURNS TEXT AS $$
-- DECLARE
--   start_time TIMESTAMP;
--   end_time TIMESTAMP;
--   execution_time INTERVAL;
-- BEGIN
--   start_time := clock_timestamp();
--
--   -- Execute the procedure
--   EXECUTE format('CALL %I(%L, %L)', proc_name, input_schema, output_table);
--
--   end_time := clock_timestamp();
--   execution_time := end_time - start_time;
--
--    RETURN format('%02s:%02s:%02s.%03s',
--                 EXTRACT(HOUR FROM execution_time)::INTEGER,
--                 EXTRACT(MINUTE FROM execution_time)::INTEGER,
--                 FLOOR(EXTRACT(SECOND FROM execution_time))::INTEGER,
--                 FLOOR((EXTRACT(SECOND FROM execution_time) - FLOOR(EXTRACT(SECOND FROM execution_time))) * 1000)::INTEGER);
-- END;
-- $$ LANGUAGE plpgsql;
--
-- -- timeit for functions
-- DROP FUNCTION IF EXISTS timeit_function(text,text,text);
-- CREATE OR REPLACE FUNCTION timeit_function(func_name TEXT, input_table_name TEXT, model_table_name TEXT) RETURNS TEXT AS $$
-- DECLARE
--   start_time TIMESTAMP;
--   end_time TIMESTAMP;
--   execution_time INTERVAL;
--   result FLOAT;
-- BEGIN
--   start_time := clock_timestamp();
--
--   -- Execute the function and store the result
--   EXECUTE format('SELECT %I(%L, %L)', func_name, input_table_name, model_table_name) INTO result;
--
--   end_time := clock_timestamp();
--   execution_time := end_time - start_time;
--
--    RETURN format('%02s:%02s:%02s.%03s',
--                 EXTRACT(HOUR FROM execution_time)::INTEGER,
--                 EXTRACT(MINUTE FROM execution_time)::INTEGER,
--                 FLOOR(EXTRACT(SECOND FROM execution_time))::INTEGER,
--                 FLOOR((EXTRACT(SECOND FROM execution_time) - FLOOR(EXTRACT(SECOND FROM execution_time))) * 1000)::INTEGER);
-- END;
-- $$ LANGUAGE plpgsql;
