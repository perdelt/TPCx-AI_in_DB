--  == loading and preprocessing  == --
-- load and preprocess --

DROP PROCEDURE if exists uc01_preprocess(character varying, character varying);
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

CREATE TABLE IF NOT EXISTS uc01_train AS
SELECT returnratio, frequency FROM uc01_train_preprocessed;

SELECT * FROM pgml.train('uc01',
                         'clustering',
                         'uc01_train',  -- Specify schema explicitly
                         algorithm => 'kmeans',
                         hyperparams => '{"n_clusters": 4}');

-- scoring (silhouette score) is displayed right after training, no explicit scoring function available


-- preprocessing the serve dataset
call uc01_preprocess('serve', 'uc01_serve_preprocessed');
select * from uc01_serve_preprocessed;

-- serving
SELECT *,
    pgml.predict(
        'uc01',
        ARRAY[
            returnratio::double precision,
            frequency::double precision
        ]::double precision[]
    ) AS cluster
FROM uc01_serve_preprocessed;