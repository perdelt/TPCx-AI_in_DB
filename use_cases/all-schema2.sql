-----------------------------------------------------------------------------------------------------------------------
---------------------------------- All Procedures for running the experiment ------------------------------------------
-- This file contains all procedures for running the experiment,
-- select all by ctrl+a and execute
--
-----------------------------------------------------------------------------------------------------------------------
-- ucXX = uc01, uc03 ... uc10
--
-- majority of all procedures have the following architecture:
--
-- Preprocessing:
-- ucXX_preprocess(schema_name, output_table)
-- joins and preprocesses use case specific tables;
-- preprocessed data are used in training or prediction procedures;
-- always specify the proper schema by naming 'train', 'score',
--  or 'test' as schema_name to load the respective data for later stages;
-- outputs the preprocessed file as output_table;
--
-- Training:
-- ucXX_train(input_table, model_table, adjust_params[optional])
-- takes the preprocessed file (should be from 'train' schema) through input_table;
-- outputs a model in table format as model_table;
-- if adjust_params argument is available, then the training incorperates
--  two set of hyperparameters:
--   adjust_params = True, hyperparameters are exactly the same as or close to the TPCx-AI Python implementation
--   adjust_params = False, hyperparamters are set to MADlib's default, much faster runtime with small metric differences
--
-- Prediction:
-- ucXX_predict(input_table, model, output_table)
-- takes the preprocessed file (should be from 'score' schema) through input_table;
-- takes the pretrained model through model parameter;
-- executes inference and outputs the results as output_table
--
-- Scoring:
-- ucXX_score(prediction_table, output_table)
-- takes the prediction results (output from Prediction procedure) through prediction_table;
-- joins the prediction table with a true label table from the 'score' schema to create
--  an output_table at least three columns (id, predicted_results, true_label);
-- inputs the output_table into a scoring function to calculate a quality metric;
-- saves the quality metric into evaluation_results table;



/*

 Use Case 01: KMeans++ clustering

 */
-- includes preprocessing with minmax scaling
-- minmax_scaling() fitting function is called if input schema = 'train',
-- otherwise minmax transformation with prefitted scaling table
CREATE OR REPLACE PROCEDURE public.uc01_preprocess(schema_name VARCHAR(10), output_table VARCHAR(50))
LANGUAGE plpgsql
AS $$
BEGIN
  EXECUTE format('
    DROP TABLE IF EXISTS %I cascade;
    CREATE TABLE %I AS
    WITH table_groups AS (
        SELECT
           MIN(EXTRACT(YEAR FROM CAST(date AS DATE))) AS invoice_year,
           SUM(quantity * price) AS row_price,
           SUM(COALESCE(or_return_quantity, 0) * price) AS return_row_price,
           o_customer_sk,
           o_order_id
        FROM %I.lineitem li
        LEFT JOIN %I.order_returns oret ON li.li_order_id = oret.or_order_id AND li.li_product_id = oret.or_product_id
        JOIN %I."order" ord ON li.li_order_id = ord.o_order_id
        GROUP BY o_customer_sk, o_order_id
    )
    , table_ratios AS (
        SELECT AVG(return_row_price/row_price) AS ratio, o_customer_sk FROM table_groups GROUP BY o_customer_sk
    )
    , table_frequency_groups AS (
        SELECT COUNT(DISTINCT o_order_id) AS o_order_id, o_customer_sk, invoice_year FROM table_groups GROUP BY o_customer_sk, invoice_year
    )
    , table_frequency AS (
        SELECT AVG(o_order_id) AS frequency, o_customer_sk FROM table_frequency_groups GROUP BY o_customer_sk
    )
    , table_pre AS (
        SELECT o_customer_sk AS CustomerID, ratio AS ReturnRatio, table_frequency.frequency AS Frequency
        FROM table_ratios NATURAL JOIN table_frequency
    )
    SELECT table_pre.* FROM table_pre;
  ', output_table, output_table, schema_name, schema_name, schema_name);

  IF schema_name = 'train' THEN
    PERFORM minmax_scaling(output_table, ARRAY['returnratio', 'frequency'], 'uc01_minmax_scaling_table');
    PERFORM apply_minmax(output_table, ARRAY['returnratio', 'frequency'], 'uc01_minmax_scaling_table');
  ELSE
    PERFORM apply_minmax(output_table, ARRAY['returnratio', 'frequency'], 'uc01_minmax_scaling_table');
  END IF;
END;
$$;

-- training
drop procedure if exists public.uc01_train(varchar,varchar);
CREATE OR REPLACE PROCEDURE public.uc01_train(input_table VARCHAR, model_table VARCHAR)
    LANGUAGE plpgsql
AS $$
BEGIN
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS
        SELECT * FROM madlib.kmeanspp(
            %L,                             -- Table of source data
            ''ARRAY[frequency, returnratio]'',   -- Column containing point co-ordinates
            4,                              -- k, Number of centroids to calculate
            ''madlib.squared_dist_norm2'',       -- Distance function
            ''madlib.avg'',                      -- Aggregate function
            300                             -- Max number of iterations
            --0.001                         -- Fraction of centroids reassigned to keep iterating
        );
    ', model_table, model_table, input_table);
END;
$$;

-- scoring
CREATE OR REPLACE PROCEDURE public.uc01_score(
    input_table varchar(100),
    model varchar(100)
)
LANGUAGE plpgsql
AS $$
DECLARE
    score double precision;
BEGIN
    EXECUTE format(
        'SELECT * FROM madlib.simple_silhouette( %L,                    -- Input points table
                                                 ''ARRAY[frequency, returnratio]'',          -- Column containing coordinates
                                                 (SELECT centroids FROM %I),  -- Centroids
                                                 ''madlib.squared_dist_norm2''  -- Distance function
                                               )',
        input_table, model
    ) INTO score;

    -- Insert the scoring value and usecase into the evaluation_results table
    INSERT INTO public.evaluation_results (usecase, evaluation_score)
    VALUES (01, score);
END
$$;


-- serving
CREATE OR REPLACE procedure uc01_serve(
    model varchar,
    preprocessed varchar,
    output_table varchar
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- call uc01_preprocess('serve', 'uc01_serve_preprocessed');
    EXECUTE foall-schema.sqlrmat('call uc01_preprocess(''%I'', ''%I'')', 'serve', preprocessed);
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

    EXECUTE format('
        CREATE TABLE %I AS
        SELECT data.*, (madlib.closest_column(centroids, ARRAY[frequency, returnratio], ''madlib.squared_dist_norm2'')).*
        FROM %I AS data, %I;
        ALTER TABLE %I RENAME column_id TO cluster_id;
    ', output_table, preprocessed, model, output_table); -- uc01_serve_preprocessed

END;
$$;

/*

 Use Case 03

 */

-- preprocess
DROP PROCEDURE IF EXISTS public.uc03_preprocess(schema_name TEXT, output_table_name TEXT);
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

CREATE OR REPLACE PROCEDURE public.uc03_predict(output_table TEXT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record RECORD;
    v_model_table_name TEXT;
    v_forecast_table_name TEXT;
    v_store_id TEXT;
    v_department_id TEXT;
BEGIN
    -- create empty output table to be filled later
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table); -- drop the output table if exists
    EXECUTE format('
        CREATE TABLE %I (
            store_id TEXT,
            department_id TEXT,
            week_index INT,
            forecast FLOAT
        )', output_table);

    -- loop through the distinct models for each store_id and department_id combination
    FOR v_record IN SELECT table_name
                    FROM information_schema.tables
                    WHERE table_schema = 'public'
                    AND table_name LIKE 'arima_model_%'
                    AND table_name NOT LIKE '%\_summary' ESCAPE '\'
                    AND table_name NOT LIKE '%\_residual' ESCAPE '\'
    LOOP
        -- select the model and create a name for forecasts for the selected model
        v_model_table_name := v_record.table_name;
        v_forecast_table_name := 'forecast_' || regexp_replace(lower(v_model_table_name), '^arima_model_', ''); -- drop arima_model_, leaves only store_id, department_id
        RAISE NOTICE 'Using model table name: %, forecast table name: %', v_model_table_name, v_forecast_table_name;

        -- Call arima_forecast for the current model, 52 periods into future
        EXECUTE format('DROP TABLE IF EXISTS %I', v_forecast_table_name);
        EXECUTE format('SELECT madlib.arima_forecast(%L, %L, 52)', v_model_table_name, v_forecast_table_name);

        -- Insert the forecast results into the output table
        -- Extract store_id (assuming it's always the third part)
        v_store_id := split_part(v_model_table_name, '_', 3);
        -- Extract department_id (assuming it starts from the fourth part to the end of the string)
        v_department_id := regexp_replace(v_model_table_name, 'arima_model_[0-9]+_', '');

        -- insert forecasting results into output_table
        EXECUTE format('INSERT INTO %I (store_id, department_id, week_index, forecast)
                        SELECT %L, %L, steps_ahead, forecast_value FROM %I
                        ORDER BY steps_ahead', output_table, v_store_id, v_department_id, v_forecast_table_name);
    END LOOP;
END;
$$;

CREATE OR REPLACE PROCEDURE uc03_score(input_table text, prediction_table TEXT, output_table text)
LANGUAGE plpgsql
AS $$
DECLARE
    score FLOAT;
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

    EXECUTE format('
        CREATE TABLE %I AS
        SELECT
            s.store_id,
            s.department_id,
            s.sales,
            f.forecast,
            s.week_index
        FROM
            %I s
            JOIN %I f
                ON s.store_id = f.store_id
                AND s.department_id = f.department_id
                AND s.week_index = f.week_index;
    ', output_table, input_table, prediction_table);

    EXECUTE format('SELECT calculate_msle(''%I'', ''forecast'', ''sales'')', output_table) INTO score;
    INSERT INTO public.evaluation_results (usecase, evaluation_score)
    VALUES (3, score);
END;
$$;

CREATE OR REPLACE PROCEDURE public.uc03_serve(
    preprocessed TEXT,
    output_table TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_record RECORD;
    v_model_table_name TEXT;
    v_forecast_table_name TEXT;
    v_store_id TEXT;
    v_department_id TEXT;
    p_record RECORD;
    p_store_id TEXT;
    p_department TEXT;
    p_periods INT;
    model_found BOOLEAN;
BEGIN
    -- Drop the output table if it exists
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

    -- Create the output table with the desired schema
    EXECUTE format('
        CREATE TABLE %I (
            store_id TEXT,
            department_id TEXT,
            week_index INT,
            forecast FLOAT
        )', output_table);

    -- Call the preprocessing procedure with the dynamic preprocessed table name
    EXECUTE format('CALL uc03_preprocess(%L, %L)', 'serve', preprocessed);

    -- Loop through each store-department combination in the preprocessed data
    FOR p_record IN EXECUTE format('SELECT * FROM %I', preprocessed)
    LOOP
        p_store_id := p_record.store;
        p_department := REGEXP_REPLACE(LOWER(p_record.department), '[^a-z0-9_]+', '_', 'g');
        p_periods := p_record.periods;
        model_found := FALSE;

        -- Loop through the model tables to find a matching model
        FOR v_record IN
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name LIKE 'arima_model_%'
              AND table_name NOT LIKE '%\_summary' ESCAPE '\'
              AND table_name NOT LIKE '%\_residual' ESCAPE '\'
        LOOP
            v_model_table_name := v_record.table_name;
            v_store_id := split_part(v_model_table_name, '_', 3);
            v_department_id := regexp_replace(v_model_table_name, 'arima_model_[0-9]+_', '');

            IF v_department_id = p_department AND v_store_id = p_store_id THEN
                model_found := TRUE;
                v_forecast_table_name := 'forecast_' || regexp_replace(lower(v_model_table_name), '^arima_model_', ''); -- e.g., drop 'arima_model_' prefix

                -- **Raise a notice that the model has been found**
                RAISE NOTICE 'Model found for store: %, department: %', p_store_id, p_department;

                -- Drop the forecast table if it exists
                EXECUTE format('DROP TABLE IF EXISTS %I', v_forecast_table_name);

                -- Generate forecasts using the ARIMA model
                EXECUTE format('SELECT madlib.arima_forecast(%L, %L, %L)', v_model_table_name, v_forecast_table_name, p_periods);

                -- Insert the forecast results into the output table
                EXECUTE format('
                    INSERT INTO %I (store_id, department_id, week_index, forecast)
                    SELECT %L, %L, steps_ahead, forecast_value FROM %I
                    ORDER BY steps_ahead
                ', output_table, p_store_id, p_department, v_forecast_table_name);

                EXIT; -- Exit the inner loop once the match is found and forecast is generated
            END IF;
        END LOOP;

        -- Raise a notice if no matching model is found
        IF NOT model_found THEN
            RAISE NOTICE 'Model not found for store: %, department: %', p_store_id, p_department;
        END IF;
    END LOOP;
END;
$$;
/*

 Use Case 04

 */

CREATE OR REPLACE PROCEDURE uc04_preprocess(schema TEXT, output_table TEXT)
AS $$
BEGIN
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS
        SELECT id,
               %s
               (SELECT array_agg(madlib.stem_token(token))
                FROM unnest(string_to_array(lower(regexp_replace(text, ''[^a-zA-Z0-9\s]'', '''', ''g'')), '' '')) AS token
                WHERE token !~ ''^\\d+$'' AND token <> ''''
               ) AS text
        FROM %I.review;
    ', output_table, output_table, CASE WHEN schema = 'train' THEN 'spam,' ELSE '' END, schema);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE uc04_train(
    input_table TEXT,
    output_table TEXT
)
AS $$
BEGIN
    -- Unnest the loaded uc04_train_preprocessed table to get the full token table
    DROP TABLE IF EXISTS uc04_tokens;
    EXECUTE format('
        CREATE TABLE uc04_tokens AS
        SELECT unnest(text) AS token, spam
        FROM %I', input_table);

    -- Token counts
    DROP TABLE IF EXISTS token_counts;
    CREATE TEMP TABLE token_counts AS
    SELECT
        token,
        COUNT(*) FILTER (WHERE spam = 1) AS spam_count,
        COUNT(*) FILTER (WHERE spam = 0) AS non_spam_count
    FROM uc04_tokens
    GROUP BY token;

    -- Adjusted counts and probabilities (Laplace smoothing)
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS
        SELECT
            token,
            (spam_count + 1)::float / (SUM(spam_count) OVER () + COUNT(*) OVER ()) AS spam_prob,
            (non_spam_count + 1)::float / (SUM(non_spam_count) OVER () + COUNT(*) OVER ()) AS non_spam_prob
        FROM token_counts;
    ', output_table, output_table);
END;
$$ LANGUAGE plpgsql;

DROP PROCEDURE if exists uc04_predict(text,text,text);
CREATE OR REPLACE PROCEDURE uc04_predict(
    input_table TEXT,
    model TEXT,
    output_table TEXT
) AS $$
BEGIN
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS (
            WITH base_probs AS (
                SELECT
                    ln((SELECT count(*) FROM uc04_train_preprocessed WHERE spam = 1) * 1.0 / (SELECT count(*) FROM uc04_train_preprocessed)) AS log_spam_ratio,
                    ln((SELECT count(*) FROM uc04_train_preprocessed WHERE spam = 0) * 1.0 / (SELECT count(*) FROM uc04_train_preprocessed)) AS log_non_spam_ratio
            ),
            document_tokens AS (
                SELECT id, unnest(text) AS token
                FROM %I
            ),
            document_probs AS (
                SELECT
                    dt.id,
                    SUM(CASE WHEN tp.spam_prob IS NULL THEN 0 ELSE ln(tp.spam_prob) END) AS log_spam_score,
                    SUM(CASE WHEN tp.non_spam_prob IS NULL THEN 0 ELSE ln(tp.non_spam_prob) END) AS log_non_spam_score
                FROM document_tokens dt
                LEFT JOIN %I tp ON dt.token = tp.token
                GROUP BY dt.id
            )
            SELECT
                dp.id,
                dp.log_spam_score + (SELECT log_spam_ratio FROM base_probs) AS log_spam_score,
                dp.log_non_spam_score + (SELECT log_non_spam_ratio FROM base_probs) AS log_non_spam_score,
                CASE WHEN dp.log_spam_score + (SELECT log_spam_ratio FROM base_probs) > dp.log_non_spam_score + (SELECT log_non_spam_ratio FROM base_probs) THEN 1 ELSE 0 END AS predicted_spam
            FROM document_probs dp
            ORDER BY dp.id
        );
    ', output_table, output_table, input_table, model);
END;
$$ LANGUAGE plpgsql;

DROP PROCEDURE if exists uc04_score(prediction_table TEXT, output_table TEXT);
CREATE OR REPLACE PROCEDURE uc04_score(
  prediction_table TEXT,
  output_table TEXT
) AS $$
DECLARE
  result numeric;
BEGIN
  -- Create the temporary table joining predictions and labels
  EXECUTE format('
    DROP TABLE IF EXISTS %I;
    CREATE TEMP TABLE %I AS
    SELECT p.*, l.spam
    FROM %I p
    JOIN score.review_labels l ON p.id = l.id;
  ', output_table, output_table, prediction_table);

  -- Calculate the F1 score and store the result in the variable
  EXECUTE format('
    SELECT "F1_Score"
    FROM f1_score(''%I'', ''spam'', ''predicted_spam'')
  ', output_table) INTO result;

  -- Insert the evaluation results into the evaluation_results table
  INSERT INTO public.evaluation_results (usecase, evaluation_score)
  VALUES ('04', result);

END;
$$ LANGUAGE plpgsql;

create or replace procedure uc04_serve(preprocessed varchar, output_table varchar)
    language plpgsql
    as $$
    begin
        execute format('call uc04_preprocess(''%I'', ''%I'')', 'serve', preprocessed);
        execute format('call uc04_predict(''%I'', ''uc04_model'', ''%I'');', preprocessed, output_table);
    end;
    $$;


/*

 Use Case 06

 */

CREATE OR REPLACE PROCEDURE public.uc06_preprocess(schema_name text, output_table text)
LANGUAGE plpgsql
AS $procedure$
BEGIN
  IF schema_name = 'train' THEN
    -- Drop the output table if it exists
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

    -- Create the output table with the loaded data
    EXECUTE format('
      CREATE TABLE %I AS
      SELECT *
      FROM %I.failures
      WHERE (serial_number, model) IN (
        SELECT serial_number, model
        FROM %I.failures
        WHERE failure = 1
        GROUP BY serial_number, model
      )', output_table, schema_name, schema_name);

    -- Add a new column 'ttf_int' for time to fail
    EXECUTE format('ALTER TABLE %I ADD COLUMN ttf_int INTEGER', output_table);

    -- Update the 'ttf_int' column with the time to failure
    EXECUTE format('
      UPDATE %I tf
      SET ttf_int = sub.last_failure_date - tf.date
      FROM (
        SELECT serial_number, model, MAX(date) AS last_failure_date
        FROM %I
        WHERE failure = 1
        GROUP BY serial_number, model
      ) AS sub
      WHERE tf.serial_number = sub.serial_number AND tf.model = sub.model', output_table, output_table);

    -- Update the label column 'failure' for 1 day before failure
    EXECUTE format('
      UPDATE %I tf
      SET failure = 1
      WHERE tf.ttf_int = 1', output_table);

  ELSIF schema_name = 'serve' OR schema_name = 'score' THEN
    -- Drop the output view if it exists
    EXECUTE format('DROP VIEW IF EXISTS %I', output_table);

    -- Create a view of the serve.failures or score.failures table
    EXECUTE format('
      CREATE VIEW %I AS
      SELECT *
      FROM %I.failures', output_table, schema_name);

  ELSE
    RAISE EXCEPTION 'Invalid schema_name. Expected ''train'', ''serve'', or ''score''.';
  END IF;
END;
$procedure$;

CREATE OR REPLACE PROCEDURE uc06_upsampling_standardization(
    input_table text,
    output_table text,
    features text[],
    dependent_variable text,
    sample_method text,
    scaling_table text DEFAULT 'standardization_scaling_table'
)
AS $$
DECLARE
    column_exists boolean;
BEGIN
    -- Check if all the specified columns exist in the input table
    SELECT bool_and(EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = input_table AND column_name = ANY(features || array[dependent_variable])
    )) INTO column_exists;

    IF NOT column_exists THEN
        RAISE EXCEPTION 'One or more specified columns do not exist in the input table.';
    END IF;

    -- Drop the output table if it exists
    EXECUTE 'DROP TABLE IF EXISTS ' || output_table;

    -- Perform upsampling based on the chosen sample method
    IF sample_method = 'madlib.balance_sample' THEN
        EXECUTE format('SELECT madlib.balance_sample(''%s'', ''%s'', ''%s'')',
                       input_table, output_table, dependent_variable);
    ELSIF sample_method = 'imba_adasyn' THEN
        EXECUTE format('SELECT apply_adasyn(''%s'', ''%s'', ''%s'', ''%s'')',
                       input_table, output_table, features, dependent_variable);
    ELSE
        RAISE EXCEPTION 'Invalid sample method. Choose either "madlib.balance_sample" or "imba_adasyn".';
    END IF;

    -- Standardize the features
    EXECUTE format('SELECT standardize_features(''%s''::text, ''%s''::text[], ''%s''::text)',
                   output_table, features, scaling_table);
END;
$$ LANGUAGE plpgsql;

drop procedure if exists uc06_train_svm_model(input_table TEXT, model_table TEXT);
CREATE OR REPLACE PROCEDURE uc06_train_svm_model(
  input_table TEXT,
  model_table TEXT,
  adjust_params boolean DEFAULT True
)
LANGUAGE plpgsql
AS $$
BEGIN

  EXECUTE format('
    DROP TABLE IF EXISTS %I_random, %I, %I_summary;
  ', model_table, model_table, model_table);
  if adjust_params Then
  EXECUTE format('
    SELECT madlib.svm_classification(
      ''%I'',
      ''%I'',
      ''failure'',
      ''ARRAY[smart_5_raw, smart_10_raw, smart_184_raw, smart_187_raw, smart_188_raw,
             smart_197_raw, smart_198_raw]'',
      ''ga'',
      '''',
      '''',
      ''max_iter=100000, tolerance = 0.001, lambda=1.0, class_weight=balanced''
    );
  ', input_table, model_table);
  else
  EXECUTE format('
    SELECT madlib.svm_classification(
      ''%I'',
      ''%I'',
      ''failure'',
      ''ARRAY[smart_5_raw, smart_10_raw, smart_184_raw, smart_187_raw, smart_188_raw,
             smart_197_raw, smart_198_raw]'',
      ''ga''
    );
  ', input_table, model_table);
  end if;
END;
$$;

CREATE OR REPLACE PROCEDURE uc06_train(
    input_table text,
    model_table text,
    adjust_params boolean default true
)
AS $$
DECLARE
    upsampled_standardized_table text := input_table || '_upsampled_standardized';
    features text[] := ARRAY['smart_5_raw', 'smart_10_raw', 'smart_184_raw', 'smart_187_raw', 'smart_188_raw', 'smart_197_raw', 'smart_198_raw'];
    dependent_variable text := 'failure';
    sample_method text := 'madlib.balance_sample';
    scaling_table text := 'uc06_standardization_scaling_table';
BEGIN
    -- Call the uc06_upsampling_standardization procedure
    CALL uc06_upsampling_standardization(
        input_table,
        upsampled_standardized_table,
        features,
        dependent_variable,
        sample_method,
        scaling_table
    );

    -- Call the uc06_train_svm_model procedure
    CALL uc06_train_svm_model(
        upsampled_standardized_table,
        model_table,
         adjust_params
    );
END;
$$ LANGUAGE plpgsql;

drop procedure if exists uc06_predict(model text, input_table text, output_table text);
CREATE OR REPLACE PROCEDURE uc06_predict(
    input_table text,
    model text,
    output_table text
)
AS $$
BEGIN
    -- Standardize the features in the input_table
    EXECUTE format('
        SELECT apply_standardization(''%I'', ''uc06_standardized'',
                                     ARRAY[''smart_5_raw'', ''smart_10_raw'', ''smart_184_raw'', ''smart_187_raw'', ''smart_188_raw'', ''smart_197_raw'', ''smart_198_raw''],
                                     ''uc06_standardization_scaling_table'');
    ', input_table);
    -- Perform the SVM prediction
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        SELECT madlib.svm_predict(''%s'', ''uc06_standardized'', ''id'', ''%I'');
    ', output_table, model, output_table);
END;
$$ LANGUAGE plpgsql;

DROP PROCEDURE if exists uc06_score(text,text);
CREATE OR REPLACE PROCEDURE uc06_score(
    prediction_table TEXT,
    output_table TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    mcc_result FLOAT;
BEGIN
    -- Create the uc06_results table
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);
    EXECUTE format('
        CREATE TABLE %I AS
        SELECT p.id, p.prediction, fl.failure
        FROM %I p
        JOIN score.failures_labels fl ON p.id = fl.id
    ', output_table, prediction_table);

    -- Calculate the MCC (Matthews Correlation Coefficient)
    EXECUTE format('SELECT calculate_mcc(''%I'', ''prediction'', ''failure'')', output_table)
    INTO mcc_result;

    -- Insert the MCC result into the evaluation_results table
    INSERT INTO public.evaluation_results (usecase, evaluation_score)
    VALUES ('06', mcc_result);
END;
$$;


create or replace procedure uc06_serve(preprocessed text, output_table text)
    language plpgsql
    as $$
    begin
        execute format('call uc06_preprocess(''%I'', ''%I'')', 'serve', preprocessed);
        execute format('CALL uc06_predict(''%I'', ''uc06_model'', ''%I'');', preprocessed, output_table);
    end;
    $$;

/*

 Use Case 07

 */

-- loading
CREATE OR REPLACE PROCEDURE uc07_preprocess(schema VARCHAR(100), output_table VARCHAR(200))
LANGUAGE plpgsql
AS $$
declare
    has_rating_column boolean;
BEGIN

    EXECUTE format('
    SELECT EXISTS (
           SELECT 1
           FROM information_schema.columns
           WHERE table_name = ''productrating''
           AND table_schema = ''%I''
           AND column_name = ''rating''
           )', schema)
    INTO has_rating_column;

    EXECUTE FORMAT('DROP VIEW IF EXISTS %I', output_table);

    IF has_rating_column THEN
        EXECUTE FORMAT('CREATE OR REPLACE VIEW %I AS
                        SELECT userid + 1 AS userid,
                               productid,
                               CAST(rating AS FLOAT) AS rating
                        FROM %I.productrating', output_table, schema);
    ELSE
        EXECUTE FORMAT('CREATE OR REPLACE VIEW %I AS
                        SELECT userid + 1 AS userid,
                               productid
                        FROM %I.productrating', output_table, schema);
    END IF;
END;
$$;



drop procedure if exists uc07_train(adjust_params boolean);
CREATE OR REPLACE PROCEDURE uc07_train(input_table text, model text, adjust_params boolean DEFAULT true)
AS $$
DECLARE
    numRows INTEGER;
    numCols INTEGER;
BEGIN
    execute format('Drop table if exists %I', model);
    -- Get the number of rows
    EXECUTE format('SELECT matrix_ndims[1] FROM (SELECT madlib.matrix_ndims(''%I'', ''row=userid, col=productid, val=rating'')) AS foo', input_table) INTO numRows;

    -- Get the number of columns
    EXECUTE format('SELECT matrix_ndims[2] FROM (SELECT madlib.matrix_ndims(''%I'', ''row=userid, col=productid, val=rating'')) AS foo', input_table) INTO numCols;

    -- Execute lmf with adjusted parameters if adjust_params is true
    IF adjust_params THEN
        EXECUTE format('SELECT madlib.lmf_igd_run(%L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L, %L)',
                       model, -- output
                       input_table, -- input
                       'userid', -- rows
                       'productid', -- cols
                       'rating', -- values
                       numRows, -- row dim
                       numCols, -- col dim
                       100, -- max rank (number of latent factors)
                       0.005, -- step size (learning rate)
                       0.1, -- scale_factor (initialization)
                       20, -- num_iterations
                       1e-4); -- tolerance
    ELSE
        EXECUTE format('SELECT madlib.lmf_igd_run(%L, %L, %L, %L, %L, %s, %s, %s)',
                       model, -- output
                       input_table, -- input
                       'userid', -- rows
                       'productid', -- cols
                       'rating', -- values
                       numRows, -- row dim
                       numCols,
                        20); -- col dim
    END IF;
END;
$$ LANGUAGE plpgsql;

drop procedure if exists uc07_predict(input_table varchar, output_table varchar, model varchar);
CREATE OR REPLACE PROCEDURE uc07_predict(
  input_table varchar,
  model VARCHAR,
  output_table VARCHAR
)
AS $$
DECLARE
  avg NUMERIC;
  max_userid int;
  max_productid int;
  matrix_u DOUBLE PRECISION[];
  matrix_v DOUBLE PRECISION[];
BEGIN
  -- Drop the output table if it exists
  EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

  -- Create the output table
  EXECUTE format('
    CREATE TABLE %I (
      userid INTEGER,
      productid INTEGER,
      prediction DOUBLE PRECISION
    )',
    output_table);

  -- Retrieve the avg in case of missing productid / userid
  SELECT avg(rating) FROM train.productrating INTO avg;
  SELECT max(userid) FROM train.productrating INTO max_userid;
  SELECT max(productid) FROM train.productrating INTO max_productid;

-- Fetch the matrix_u and matrix_v from the model table
  EXECUTE format('
    SELECT matrix_u
    FROM %I
    WHERE id = 1
  ', model)
  INTO matrix_u;

  EXECUTE format('
    SELECT matrix_v
    FROM %I
    WHERE id = 1
  ', model)
  INTO matrix_v;

  -- Calculate the dot product for all rows in the productrating table
  EXECUTE format('
    INSERT INTO %I (userid, productid, prediction)
    SELECT
      pr.userid,
      pr.productid,
      CASE
        WHEN pr.userid > %L OR pr.productid > %L THEN %L
        ELSE COALESCE(
          madlib.array_dot($1[pr.userid:pr.userid][1:100], $2[pr.productid:pr.productid][1:100]),
          %L
        )
      END AS prediction
    FROM %I pr',
    output_table, max_userid, max_productid, avg, avg, input_table)
  USING matrix_u, matrix_v;

  -- Adjust the prediction values based on the conditions
  EXECUTE format('
    UPDATE %I
    SET prediction = CASE
      WHEN prediction > 5 THEN 5
      WHEN prediction < 1 THEN 1
      ELSE ROUND(prediction)
    END',
    output_table);
END;
$$ LANGUAGE plpgsql;

create or replace procedure uc07_score(
    prediction_table varchar,
    output_table varchar)
as $$
declare
    mae_result float;
begin
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);
    execute format('
            create table %I as (
            select l.userid, l.productid, l.rating as true_rating, p.prediction
                from score.productrating_labels l join
                     %I p on l.userid = p.userid and l.productid = p.productid);
            ', output_table, prediction_table);

    EXECUTE format('SELECT calculate_mae(%L, %L, %L)', output_table, 'true_rating', 'prediction') INTO mae_result;

    INSERT INTO public.evaluation_results (usecase, evaluation_score)
    VALUES ('07', mae_result);
end;
$$ language plpgsql;

create or replace procedure uc07_serve(preprocessed varchar, output_table varchar)
language plpgsql
as $$
begin
    execute format('call uc07_preprocess(''%I'', ''%I'')', 'serve', preprocessed);
    execute format('call uc07_predict(''%I'', ''uc07_model'', ''%I'');', preprocessed, output_table);
end;
$$;

CREATE OR REPLACE PROCEDURE public.uc07_predict_numpy(model text, predictions text)
 LANGUAGE plpython3u
AS $procedure$
  import numpy as np
  import gc
  
  # Execute the query and fetch the results
  result = plpy.execute("SELECT matrix_u, matrix_v FROM {model}".format(model=model))
  #plpy.notice(result[0]['matrix_u'])
  mat_u = np.array(result[0]['matrix_u'])
  mat_v = np.array(result[0]['matrix_v'])
  #plpy.notice((mat_u.shape))
  #plpy.notice((mat_v.shape))
  mat_prod = np.matmul(mat_u, mat_v.T)
  plpy.notice((mat_prod.shape))
  del mat_u
  del mat_v
  gc.collect()							# gc of matrices U and V
  mat_prod = np.round(mat_prod)			# round
  mat_prod = np.clip(mat_prod, 1, 5)	# clip to 1-5
  gc.collect()							# gc of temp intermediate matrices

  query = "DROP TABLE IF EXISTS public.{predictions}".format(predictions=predictions) #uc07_predictions_numpy
  result = plpy.execute(query)
  query = """CREATE TABLE public.{predictions} (
  unnest_row_id int4 NULL,
  unnest_result _float8 NULL)""".format(predictions=predictions)
  result = plpy.execute(query)
  query = "INSERT INTO public.{predictions} (unnest_row_id, unnest_result) VALUES ($1, $2)".format(predictions=predictions)
  plan = plpy.prepare(query, ["integer", "float8[]"])
  for i, row in enumerate(mat_prod):
    plpy.execute(plan, [i+1, mat_prod[i]])
  $procedure$;

CREATE OR REPLACE PROCEDURE uc07_predict_with_matrix_mult(model text, predictions text)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Sanity check for dimensions
        -- SELECT array_dims(matrix_u) AS u_dims, array_dims(matrix_v) AS v_dims
        -- FROM lora
        -- WHERE id = 1;
        -- select * from productrating_final;

        -- select madlib.matrix_ndims('productrating_final', 'row=userid, col=productid, val=rating');

        -- with userid as
        --     (select distinct userid from productrating_final)
        --     select count(userid) from userid;
        -- with productid as
        --     (select distinct productid from productrating_final)
        --     select max(productid) from productid;
        --
        -- select matrix_u[31623:31624][:20] from lora;

    -- Use CTEs to avoid creating intermediate tables
    drop table if exists lora_u;
    drop table if exists lora_v;
    EXECUTE format('Drop table if exists %I', predictions);
    EXECUTE format('
        create table lora_u AS (
            SELECT (madlib.array_unnest_2d_to_1d(matrix_u)).*
            FROM %I
            WHERE id = 1
        );
        create table lora_v AS (
            SELECT (madlib.array_unnest_2d_to_1d(matrix_v)).*
            FROM %I
            WHERE id = 1
        );
        SELECT madlib.matrix_mult(
            ''lora_u'', ''row=unnest_row_id, val=unnest_result'',
            ''lora_v'', ''row=unnest_row_id, val=unnest_result, trans=true'',
            %L
        )', model, model, predictions);
END;
$$;
/*

 Use Case 08

 */
--        maximum input table size can't exceed 1 GB.

CREATE OR REPLACE PROCEDURE uc08_preprocess(schema_name VARCHAR, output_table VARCHAR)
AS $$
DECLARE
    trip_type_exists BOOLEAN;
    preprocessed_table VARCHAR := output_table || '_preprocessed';
    table_size_bytes BIGINT;
    table_size_gb NUMERIC;
BEGIN
    -- Check if the trip_type column exists in the order table of the specified schema
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = schema_name AND table_name = 'order' AND column_name = 'trip_type'
    ) INTO trip_type_exists;

    -- Preprocessing steps (same as before)
       EXECUTE format('
    DROP TABLE IF EXISTS %I;
    drop table if exists preprocessed_table;
    CREATE TABLE %I AS
    WITH order_data AS (
        SELECT o.o_order_id, o.date' || CASE WHEN trip_type_exists THEN ', o.trip_type' ELSE '' END || '
        FROM %I."order" o
    ),
    lineitem_data AS (
        SELECT li.li_order_id, li.li_product_id, li.quantity
        FROM %I.lineitem li
    ),
    product_data AS (
        SELECT p.p_product_id, p.department
        FROM %I.product p
    ),
    order_lineitem AS (
        SELECT o.o_order_id, o.date' || CASE WHEN trip_type_exists THEN ', o.trip_type' ELSE '' END || ', li.li_product_id, li.quantity
        FROM order_data o
        JOIN lineitem_data li ON o.o_order_id = li.li_order_id
    ),
    order_lineitem_product AS (
        SELECT ol.o_order_id, ol.date' || CASE WHEN trip_type_exists THEN ', ol.trip_type' ELSE '' END || ', p.department, ol.quantity
        FROM order_lineitem ol
        JOIN product_data p ON ol.li_product_id = p.p_product_id
    ),
    preprocessed_week AS (
        SELECT DISTINCT
            o_order_id,
            CASE
                WHEN EXTRACT(DOW FROM date) = 0 THEN 7
                ELSE EXTRACT(DOW FROM date)
            END AS weekday_number
        FROM order_lineitem_product
    ),
    departments_index_table AS (
        SELECT
            department,
            ROW_NUMBER() OVER (ORDER BY department) AS dept_id
        FROM
            (SELECT DISTINCT department FROM %I.store_dept) AS unique_departments
    ),
    preprocessed_departments AS (
        SELECT
            olp.o_order_id, d.dept_id, olp.quantity
        FROM
            order_lineitem_product olp
        JOIN
            departments_index_table d ON olp.department = d.department
    ),
    preprocessed_departments_total_quantity AS (
        SELECT
            o_order_id, dept_id, SUM(quantity) AS total_quantity
        FROM
            preprocessed_departments
        GROUP BY
            o_order_id, dept_id
    ),
    usecase08_departments_dense_col AS (
        SELECT
            o_order_id,
            SUM(CASE WHEN dept_id = 1 THEN total_quantity ELSE 0 END) AS dept_1,
            SUM(CASE WHEN dept_id = 2 THEN total_quantity ELSE 0 END) AS dept_2,
            SUM(CASE WHEN dept_id = 3 THEN total_quantity ELSE 0 END) AS dept_3,
            SUM(CASE WHEN dept_id = 4 THEN total_quantity ELSE 0 END) AS dept_4,
            SUM(CASE WHEN dept_id = 5 THEN total_quantity ELSE 0 END) AS dept_5,
            SUM(CASE WHEN dept_id = 6 THEN total_quantity ELSE 0 END) AS dept_6,
            SUM(CASE WHEN dept_id = 7 THEN total_quantity ELSE 0 END) AS dept_7,
            SUM(CASE WHEN dept_id = 8 THEN total_quantity ELSE 0 END) AS dept_8,
            SUM(CASE WHEN dept_id = 9 THEN total_quantity ELSE 0 END) AS dept_9,
            SUM(CASE WHEN dept_id = 10 THEN total_quantity ELSE 0 END) AS dept_10,
            SUM(CASE WHEN dept_id = 11 THEN total_quantity ELSE 0 END) AS dept_11,
            SUM(CASE WHEN dept_id = 12 THEN total_quantity ELSE 0 END) AS dept_12,
            SUM(CASE WHEN dept_id = 13 THEN total_quantity ELSE 0 END) AS dept_13,
            SUM(CASE WHEN dept_id = 14 THEN total_quantity ELSE 0 END) AS dept_14,
            SUM(CASE WHEN dept_id = 15 THEN total_quantity ELSE 0 END) AS dept_15,
            SUM(CASE WHEN dept_id = 16 THEN total_quantity ELSE 0 END) AS dept_16,
            SUM(CASE WHEN dept_id = 17 THEN total_quantity ELSE 0 END) AS dept_17,
            SUM(CASE WHEN dept_id = 18 THEN total_quantity ELSE 0 END) AS dept_18,
            SUM(CASE WHEN dept_id = 19 THEN total_quantity ELSE 0 END) AS dept_19,
            SUM(CASE WHEN dept_id = 20 THEN total_quantity ELSE 0 END) AS dept_20,
            SUM(CASE WHEN dept_id = 21 THEN total_quantity ELSE 0 END) AS dept_21,
            SUM(CASE WHEN dept_id = 22 THEN total_quantity ELSE 0 END) AS dept_22,
            SUM(CASE WHEN dept_id = 23 THEN total_quantity ELSE 0 END) AS dept_23,
            SUM(CASE WHEN dept_id = 24 THEN total_quantity ELSE 0 END) AS dept_24,
            SUM(CASE WHEN dept_id = 25 THEN total_quantity ELSE 0 END) AS dept_25,
            SUM(CASE WHEN dept_id = 26 THEN total_quantity ELSE 0 END) AS dept_26,
            SUM(CASE WHEN dept_id = 27 THEN total_quantity ELSE 0 END) AS dept_27,
            SUM(CASE WHEN dept_id = 28 THEN total_quantity ELSE 0 END) AS dept_28,
            SUM(CASE WHEN dept_id = 29 THEN total_quantity ELSE 0 END) AS dept_29,
            SUM(CASE WHEN dept_id = 30 THEN total_quantity ELSE 0 END) AS dept_30,
            SUM(CASE WHEN dept_id = 31 THEN total_quantity ELSE 0 END) AS dept_31,
            SUM(CASE WHEN dept_id = 32 THEN total_quantity ELSE 0 END) AS dept_32,
            SUM(CASE WHEN dept_id = 33 THEN total_quantity ELSE 0 END) AS dept_33,
            SUM(CASE WHEN dept_id = 34 THEN total_quantity ELSE 0 END) AS dept_34,
            SUM(CASE WHEN dept_id = 35 THEN total_quantity ELSE 0 END) AS dept_35,
            SUM(CASE WHEN dept_id = 36 THEN total_quantity ELSE 0 END) AS dept_36,
            SUM(CASE WHEN dept_id = 37 THEN total_quantity ELSE 0 END) AS dept_37,
            SUM(CASE WHEN dept_id = 38 THEN total_quantity ELSE 0 END) AS dept_38,
            SUM(CASE WHEN dept_id = 39 THEN total_quantity ELSE 0 END) AS dept_39,
            SUM(CASE WHEN dept_id = 40 THEN total_quantity ELSE 0 END) AS dept_40,
            SUM(CASE WHEN dept_id = 41 THEN total_quantity ELSE 0 END) AS dept_41,
            SUM(CASE WHEN dept_id = 42 THEN total_quantity ELSE 0 END) AS dept_42,
            SUM(CASE WHEN dept_id = 43 THEN total_quantity ELSE 0 END) AS dept_43,
            SUM(CASE WHEN dept_id = 44 THEN total_quantity ELSE 0 END) AS dept_44,
            SUM(CASE WHEN dept_id = 45 THEN total_quantity ELSE 0 END) AS dept_45,
            SUM(CASE WHEN dept_id = 46 THEN total_quantity ELSE 0 END) AS dept_46,
            SUM(CASE WHEN dept_id = 47 THEN total_quantity ELSE 0 END) AS dept_47,
            SUM(CASE WHEN dept_id = 48 THEN total_quantity ELSE 0 END) AS dept_48,
            SUM(CASE WHEN dept_id = 49 THEN total_quantity ELSE 0 END) AS dept_49,
            SUM(CASE WHEN dept_id = 50 THEN total_quantity ELSE 0 END) AS dept_50,
            SUM(CASE WHEN dept_id = 51 THEN total_quantity ELSE 0 END) AS dept_51,
            SUM(CASE WHEN dept_id = 52 THEN total_quantity ELSE 0 END) AS dept_52,
            SUM(CASE WHEN dept_id = 53 THEN total_quantity ELSE 0 END) AS dept_53,
            SUM(CASE WHEN dept_id = 54 THEN total_quantity ELSE 0 END) AS dept_54,
            SUM(CASE WHEN dept_id = 55 THEN total_quantity ELSE 0 END) AS dept_55,
            SUM(CASE WHEN dept_id = 56 THEN total_quantity ELSE 0 END) AS dept_56,
            SUM(CASE WHEN dept_id = 57 THEN total_quantity ELSE 0 END) AS dept_57,
            SUM(CASE WHEN dept_id = 58 THEN total_quantity ELSE 0 END) AS dept_58,
            SUM(CASE WHEN dept_id = 59 THEN total_quantity ELSE 0 END) AS dept_59,
            SUM(CASE WHEN dept_id = 60 THEN total_quantity ELSE 0 END) AS dept_60,
            SUM(CASE WHEN dept_id = 61 THEN total_quantity ELSE 0 END) AS dept_61,
            SUM(CASE WHEN dept_id = 62 THEN total_quantity ELSE 0 END) AS dept_62,
            SUM(CASE WHEN dept_id = 63 THEN total_quantity ELSE 0 END) AS dept_63,
            SUM(CASE WHEN dept_id = 64 THEN total_quantity ELSE 0 END) AS dept_64,
            SUM(CASE WHEN dept_id = 65 THEN total_quantity ELSE 0 END) AS dept_65,
            SUM(CASE WHEN dept_id = 66 THEN total_quantity ELSE 0 END) AS dept_66,
            SUM(CASE WHEN dept_id = 67 THEN total_quantity ELSE 0 END) AS dept_67,
            SUM(CASE WHEN dept_id = 68 THEN total_quantity ELSE 0 END) AS dept_68
        FROM
            preprocessed_departments_total_quantity
        GROUP BY
            o_order_id
    ),
    usecase08_aggregated_data AS (
        SELECT
            o_order_id,
            SUM(ABS(quantity)) AS scan_count_abs_sum' || CASE WHEN trip_type_exists THEN ',
            MIN(trip_type) AS trip_type' ELSE '' END || '
        FROM
            order_lineitem_product
        GROUP BY
            o_order_id
    ),
    usecase08_weekday_dense_col AS (
        SELECT
            o_order_id,
            CASE WHEN weekday_number = 1 THEN 1 ELSE 0 END AS monday,
            CASE WHEN weekday_number = 2 THEN 1 ELSE 0 END AS tuesday,
            CASE WHEN weekday_number = 3 THEN 1 ELSE 0 END AS wednesday,
            CASE WHEN weekday_number = 4 THEN 1 ELSE 0 END AS thursday,
            CASE WHEN weekday_number = 5 THEN 1 ELSE 0 END AS friday,
            CASE WHEN weekday_number = 6 THEN 1 ELSE 0 END AS saturday,
            CASE WHEN weekday_number = 7 THEN 1 ELSE 0 END AS sunday
        FROM
            preprocessed_week
    )
    SELECT
        uag.scan_count_abs_sum' || CASE WHEN trip_type_exists THEN ', uag.trip_type' ELSE '' END || ',
        wdc.monday, wdc.tuesday, wdc.wednesday, wdc.thursday, wdc.friday, wdc.saturday, wdc.sunday,
        ddc.*
    FROM
        usecase08_aggregated_data uag
    JOIN
        usecase08_weekday_dense_col wdc ON uag.o_order_id = wdc.o_order_id
    JOIN
        usecase08_departments_dense_col ddc ON uag.o_order_id = ddc.o_order_id;
    ', preprocessed_table, preprocessed_table, schema_name, schema_name, schema_name, schema_name);
    -- show the size of the table
    RAISE NOTICE 'Output table: %. ', preprocessed_table;

    EXECUTE format('SELECT pg_total_relation_size(''%I'')', preprocessed_table) INTO table_size_bytes;
    RAISE NOTICE 'Preprocessing completed. Output table: %. Size: % bytes', preprocessed_table, table_size_bytes;

    -- Call the uc08_stratified_sampling procedure
    IF schema_name = 'train' and table_size_bytes >= 1000000000.0 THEN
        CALL uc08_stratified_sampling(preprocessed_table, output_table);
    elsif schema_name in ('serve', 'score') and table_size_bytes >= 300000000.0 then
        call uc08_stratified_sampling(preprocessed_table, output_table, 300);
    ELSE
        -- For schemas other than 'train', just rename the preprocessed table to the output table
        EXECUTE format('DROP TABLE IF EXISTS %I;
                ALTER TABLE %I RENAME TO %I', output_table, preprocessed_table, output_table);
        RAISE NOTICE 'table name change from %I to %I. ', preprocessed_table, output_table;

    END IF;

    RAISE NOTICE 'Preprocessing and stratified sampling completed. Output table: %.', output_table;
END;
$$ LANGUAGE plpgsql;
drop procedure if exists uc08_stratified_sampling(input_table TEXT, output_table TEXT);
drop procedure if exists uc08_stratified_sampling(input_table TEXT, output_table TEXT, max_size_mb float);
CREATE OR REPLACE PROCEDURE uc08_stratified_sampling(
    input_table TEXT,
    output_table TEXT,
    max_size_mb float default null
)
AS $$
DECLARE
    input_size BIGINT;
    stratified_proportion FLOAT;
    has_trip_type boolean;
BEGIN
    -- Get the size of the input table
    EXECUTE 'SELECT pg_total_relation_size($1)' INTO input_size USING input_table;
    RAISE NOTICE 'table size in bytes: %.', input_size;

    -- Calculate the stratified proportion based on the input table size and max_size_mb
    IF max_size_mb IS NULL THEN
        IF input_size < 1000000000 THEN -- 1 GB in bytes
            stratified_proportion := 1.0;
        ELSE
            stratified_proportion := 1000000000.0 / input_size * 0.9;
        END IF;
    ELSE
        IF input_size < max_size_mb * 1000000 THEN -- max_size_mb in bytes
            stratified_proportion := 1.0;
        ELSE
            stratified_proportion := (max_size_mb * 1000000) / input_size;
        END IF;
    END IF;
    RAISE NOTICE 'proportion: %.', stratified_proportion;


    -- Check if the input_table has the column trip_type
    EXECUTE format('SELECT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = %L AND column_name = ''trip_type''
    )', input_table) INTO has_trip_type;

    -- Perform stratified sampling
    IF has_trip_type THEN
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            SELECT madlib.stratified_sample(
                %L,  -- source_table
                %L,  -- output_table
                %L,  -- proportion
                ''trip_type'',  -- grouping_cols
                NULL,  -- target_cols
                FALSE  -- with_replacement
            );
        ', output_table, input_table, output_table, stratified_proportion);
    ELSE
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            SELECT madlib.stratified_sample(
                %L,  -- source_table
                %L,  -- output_table
                %L,  -- proportion
                NULL,  -- grouping_cols
                NULL,  -- target_cols
                FALSE  -- with_replacement
            );
        ', output_table, input_table, output_table, stratified_proportion);
    END IF;

    RAISE NOTICE 'Stratified sampling completed. Sampled table: %. Proportion: %', output_table, stratified_proportion;
END;
$$ LANGUAGE plpgsql;

drop procedure if exists uc08_train(sampled_table TEXT, model_name TEXT);
CREATE OR REPLACE PROCEDURE uc08_train(
    sampled_table TEXT,
    model_name TEXT
)
AS $$
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %I, %I_summary', model_name, model_name);
    PERFORM madlib.xgboost(
        sampled_table,  -- Training table TEXT
        model_name,          -- output table TEXT
        'o_order_id',   -- Id column TEXT
        'trip_type',    -- dependent variable TEXT
        '*',             -- Independent variables TEXT
        NULL,                           -- Columns to exclude from features
        $py$
        {
            'learning_rate': [0.3], #Regularization on weights (eta). For smaller values, increase n_estimators
            'max_depth': [6],#Larger values could lead to overfitting
            'subsample': [1],#introduce randomness in samples picked to prevent overfitting
            'colsample_bytree': [1],#introduce randomness in features picked to prevent overfitting
            'min_child_weight': [1],#larger values will prevent over-fitting
            'n_estimators':[100], #More estimators, lesser variance (better fit on test set)
            'objective': ['multisoft.prob'],
            'tree_method': ['hist']
        }
        $py$
    --              -- XGBoost grid search parameters
    --     '',         -- Class weights
    --     0.8,        -- Training set size ratio
    --     NULL        -- Variable used to do the test/train split.
    );
END;
$$ LANGUAGE plpgsql;
drop procedure if exists uc08_predict(input_table varchar, output_table varchar, model varchar);
CREATE OR REPLACE PROCEDURE uc08_predict(
    input_table VARCHAR,
    model VARCHAR,
    output_table VARCHAR
)
AS $$
BEGIN
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);
    EXECUTE format('DROP TABLE IF EXISTS %I_metrics', output_table);
    PERFORM madlib.xgboost_predict(
        input_table,
        model,
        output_table,
        'o_order_id'
    );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE uc08_score(
    prediction_table text,
    output_table text
)
AS $$
DECLARE
    accuracy FLOAT;
BEGIN
    -- Create the uc08 prediction table
    EXECUTE format(' Drop table if exists %I;
        CREATE TABLE %I AS
        SELECT
            out.o_order_id,
            out.class_label_predicted,
            CAST(ol.trip_type AS TEXT) AS true_label
        FROM
            %I out
        JOIN
            score.order_labels ol ON out.o_order_id = ol.o_order_id
    ', output_table, output_table, prediction_table);

    -- Calculate the accuracy using the accuracy function
    EXECUTE format('select accuracy(''%I'', ''class_label_predicted'', ''true_label'')', output_table) INTO accuracy;

    -- Insert the accuracy into the evaluation_results table
    INSERT INTO public.evaluation_results (usecase, evaluation_score)
    VALUES ('08', accuracy);

    RAISE NOTICE 'Accuracy: %', accuracy;
END;
$$ LANGUAGE plpgsql;

-- serve
create or replace procedure uc08_serve(preprocessed text, output_table text)
    language plpgsql
    as $$
    begin
        execute format('call uc08_preprocess(''%I'', ''%I'')', 'serve', preprocessed);
        execute format('call uc08_predict(''%I'', ''uc08_model'', ''%I'');', preprocessed, output_table);
end;
$$;

/*

 Use Case 10

 */

DROP PROCEDURE IF EXISTS uc10_preprocess(VARCHAR, VARCHAR);
CREATE OR REPLACE PROCEDURE uc10_preprocess(
    input_schema VARCHAR,
    output_table VARCHAR
)
LANGUAGE plpgsql
AS $$
DECLARE
    loaded_table VARCHAR := 'uc10_loaded_temp';
    has_isfraud_column BOOLEAN;
BEGIN
    -- Loading step
    EXECUTE format('
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS
        SELECT ft.*, fa.*
        FROM %I.financial_transactions ft
        JOIN %I.financial_account fa ON ft.senderid = fa.fa_customer_sk
        ORDER BY senderid;
    ', loaded_table, loaded_table, input_schema, input_schema);

    -- Check if the loaded_table has the isfraud column
    SELECT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = loaded_table AND column_name = 'isfraud'
    ) INTO has_isfraud_column;

    -- Preprocessing step
    -- Create the preprocessed table with conditional selection of isfraud column
    IF has_isfraud_column THEN
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            CREATE TABLE %I AS
            SELECT
                transactionid,
                EXTRACT(HOUR FROM time) / 23 AS business_hour_norm,
                amount / transaction_limit AS amount_norm,
                cast(isfraud as integer) as isfraud
            FROM %I;
        ', output_table, output_table, loaded_table);
    ELSE
        EXECUTE format('
            DROP TABLE IF EXISTS %I;
            CREATE TABLE %I AS
            SELECT
                transactionid,
                EXTRACT(HOUR FROM time) / 23 AS business_hour_norm,
                amount / transaction_limit AS amount_norm
            FROM %I;
        ', output_table, output_table, loaded_table);
    END IF;
END;
$$;

-- training
drop procedure if exists uc10_train(source_table TEXT, out_table TEXT, max_iterations INTEGER, optimizer TEXT, tolerance FLOAT);
drop procedure if exists uc10_train(source_table text, out_table text);
CREATE OR REPLACE PROCEDURE uc10_train(
    source_table TEXT,
    out_table TEXT,
    adjust_params boolean DEFAULT True
)
AS $$
BEGIN

    EXECUTE format('
        DROP TABLE IF EXISTS %I, %I_summary;', out_table, out_table);
    if adjust_params then
        execute format('
              SELECT madlib.logregr_train(
            %L,                     -- source_table
            %L,                     -- out_table
            ''isfraud'',            -- dependent_varname
            ''ARRAY[1, business_hour_norm, amount_norm]'',  -- independent_varname
            NULL,                   -- grouping_cols
            ''100'',                     -- max_iter
            ''cg''                     -- optimizer
        );', source_table, out_table);
        else
            execute format('
                SELECT madlib.logregr_train(
                    %L,                     -- source_table
                    %L,                     -- out_table
                    ''isfraud'',            -- dependent_varname
                    ''ARRAY[1, business_hour_norm, amount_norm]'',  -- independent_varname
                    NULL,                   -- grouping_cols
                    ''100'',                     -- max_iter
                    ''irls''                     -- optimizer
        );', source_table, out_table);
    end if;
END;
$$ LANGUAGE plpgsql;

-- prediction
drop procedure if exists uc10_predict(input_table_name text, model_table_name text, output_table_name text);
CREATE OR REPLACE PROCEDURE uc10_predict(
    input_table TEXT,
    model TEXT,
    output_table TEXT
) AS $$
BEGIN
    -- Drop the prediction results table if it exists
    EXECUTE format('DROP TABLE IF EXISTS %I', output_table);

    -- Create a table to store the prediction results
    EXECUTE format($fmt$
        CREATE TABLE %I AS
        SELECT p.transactionid,
               madlib.logregr_predict(coef, ARRAY[1, business_hour_norm, amount_norm]) AS prediction
        FROM %I p, %I o
        ORDER BY p.transactionid
    $fmt$, output_table, input_table, model);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE uc10_score(
    prediction_table TEXT,
    output_table text
) AS $$
DECLARE
    accuracy_value FLOAT;
BEGIN
    -- Aggregate the prediction results with the true labels
    EXECUTE format($fmt$
        DROP TABLE IF EXISTS %I;
        CREATE TABLE %I AS
        SELECT p.transactionid, p.prediction, l.isfraud AS true_value
        FROM %I p
        LEFT JOIN score.financial_transactions_labels l ON p.transactionid = l.transactionid
    $fmt$, output_table, output_table, prediction_table);

    -- Calculate the accuracy of the predictions using the accuracy function
    EXECUTE format('SELECT accuracy(''%I'', ''prediction'', ''true_value'')', output_table) INTO accuracy_value;

    -- Insert the accuracy result into the evaluation_results table
    INSERT INTO evaluation_results (usecase, evaluation_score)
    VALUES ('10', accuracy_value);
END;
$$ LANGUAGE plpgsql;

-- serve
create or replace procedure uc10_serve(preprocessed text, output_table text)
    language plpgsql
    as $$
    begin
        execute format('call uc10_preprocess(''%I'', ''%I'')', 'serve', preprocessed);

        execute format('call uc10_predict(''%I'', ''uc10_model'', ''%I'');', preprocessed, output_table);
end;
$$;