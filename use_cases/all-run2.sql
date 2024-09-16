---------------- Main procedure to start the experiment -----------------------
-- adjust_params := False for faster run with MADlib's standard hyperparameters, still reaching threshhold
-- adjust_params := hyperparameters as in TPCx-AI, slower runtimes
DO $$
DECLARE
    v_start_time TIMESTAMP;
    adjust_params boolean := True;
BEGIN

call create_evaluation_results_table();
call timeit();

/*

 Use Case 01

 */
v_start_time := clock_timestamp();
CALL uc01_preprocess('train', 'uc01_train_preprocessed');
perform record_execution_time('uc01', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc01_train('uc01_train_preprocessed', 'uc01_model');
perform record_execution_time('uc01', 'train' , v_start_time);

v_start_time := clock_timestamp();
CALL uc01_preprocess('score', 'uc01_score_preprocessed');
perform record_execution_time('uc01', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc01_score('uc01_score_preprocessed', 'uc01_model');
perform record_execution_time('uc01', 'score' , v_start_time);

v_start_time := clock_timestamp();
CALL uc01_serve('uc01_model', 'uc01_serve_preprocessed', 'uc01_serve_results');
-- uc01_serve('uc01_model', 'uc01_serve_results');
perform record_execution_time('uc01', 'serve' , v_start_time);

/*

 Use Case 03

 */

-- preprocessing
v_start_time := clock_timestamp();
call uc03_preprocess('train', 'uc03_train_preprocessed');
perform record_execution_time('uc03', 'preprocess (train)' , v_start_time);

-- training
v_start_time := clock_timestamp();
call uc03_train('uc03_train_preprocessed');
perform record_execution_time('uc03', 'train' , v_start_time);

v_start_time := clock_timestamp();
call uc03_predict('uc03_score_predictions');
perform record_execution_time('uc03', 'predict' , v_start_time);

v_start_time := clock_timestamp();
call uc03_preprocess('score', 'uc03_score_preprocessed');
perform record_execution_time('uc03', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
call uc03_score('uc03_score_preprocessed', 'uc03_score_predictions', 'uc03_score_results');
perform record_execution_time('uc03', 'score' , v_start_time);

v_start_time := clock_timestamp();
CALL uc03_serve('uc03_serve_preprocessed', 'uc03_serve_results');
perform record_execution_time('uc03', 'serve' , v_start_time);
/*

 Use Case 04

 */
v_start_time := clock_timestamp();
call uc04_preprocess('train', 'uc04_train_preprocessed');
perform record_execution_time('uc04', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc04_train('uc04_train_preprocessed', 'uc04_model');
perform record_execution_time('uc04', 'train' , v_start_time);

v_start_time := clock_timestamp();
call uc04_preprocess('score', 'uc04_score_preprocessed');
perform record_execution_time('uc04', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc04_predict('uc04_score_preprocessed', 'uc04_model', 'uc04_score_predictions');
perform record_execution_time('uc04', 'predict' , v_start_time);

v_start_time := clock_timestamp();
call uc04_score('uc04_score_predictions', 'uc04_score_results');
perform record_execution_time('uc04', 'score' , v_start_time);

v_start_time := clock_timestamp();
call uc04_serve('uc04_serve_preprocessed', 'uc04_serve_results');
perform record_execution_time('uc04', 'serve', v_start_time);
/*

 Use Case 06

*/
v_start_time := clock_timestamp();
call uc06_preprocess('train', 'uc06_train_preprocessed');
perform record_execution_time('uc06', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc06_train('uc06_train_preprocessed', 'uc06_model', adjust_params); --true, false, adjust_params
perform record_execution_time('uc06', 'train' , v_start_time);

v_start_time := clock_timestamp();
call uc06_preprocess('score', 'uc06_score_preprocessed');
perform record_execution_time('uc06', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc06_predict('uc06_score_preprocessed','uc06_model', 'uc06_score_predictions');
perform record_execution_time('uc06', 'predict' , v_start_time);

v_start_time := clock_timestamp();
CALL uc06_score('uc06_score_predictions', 'uc06_score_results');
perform record_execution_time('uc06', 'score' , v_start_time);

v_start_time := clock_timestamp();
CALL uc06_serve('uc06_serve_preprocessed', 'uc06_serve_results');
perform record_execution_time('uc06', 'serve' , v_start_time);
/*

 Use Case 07

 */
v_start_time := clock_timestamp();
CALL uc07_preprocess('train', 'uc07_train_preprocessed');
perform record_execution_time('uc07', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
call uc07_train('uc07_train_preprocessed', 'uc07_model', adjust_params); -- true, false, adjust_params
perform record_execution_time('uc07', 'train' , v_start_time);

v_start_time := clock_timestamp();
CALL uc07_preprocess('score', 'uc07_score_preprocessed');
perform record_execution_time('uc07', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
call uc07_predict('uc07_score_preprocessed', 'uc07_model', 'uc07_score_predictions');
perform record_execution_time('uc07', 'predict' , v_start_time);

v_start_time := clock_timestamp();
call uc07_score('uc07_score_predictions', 'uc07_score_results');
perform record_execution_time('uc07', 'score' , v_start_time);

v_start_time := clock_timestamp();
call uc07_serve('uc07_serve_preprocessed', 'uc07_serve_results');
perform record_execution_time('uc07', 'serve' , v_start_time);
-- /*
--
--  Use Case 08
--
--  */
v_start_time := clock_timestamp();
call uc08_preprocess('train', 'uc08_train_preprocessed');
perform record_execution_time('uc08', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc08_train('uc08_train_preprocessed', 'uc08_model');
perform record_execution_time('uc08', 'train' , v_start_time);

v_start_time := clock_timestamp();
call uc08_preprocess('score', 'uc08_score_preprocessed');
perform record_execution_time('uc08', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc08_predict('uc08_score_preprocessed','uc08_model', 'uc08_score_predictions');
perform record_execution_time('uc08', 'predict' , v_start_time);

v_start_time := clock_timestamp();
call uc08_score('uc08_score_predictions', 'uc08_score_results');
perform record_execution_time('uc08', 'score' , v_start_time);

v_start_time := clock_timestamp();
call uc08_serve('uc08_serve_preprocessed','uc08_serve_results');
perform record_execution_time('uc08', 'serve' , v_start_time);
/*

 Use Case 10

 */
v_start_time := clock_timestamp();
CALL uc10_preprocess('train', 'uc10_train_preprocessed');
perform record_execution_time('uc10', 'preprocess (train)' , v_start_time);

v_start_time := clock_timestamp();
-- adjust_params default false, as cg is not comparable to LBFGS so we choose IRLS with significant better performance
CALL uc10_train('uc10_train_preprocessed', 'uc10_model', false);
perform record_execution_time('uc10', 'train' , v_start_time);

v_start_time := clock_timestamp();
CALL uc10_preprocess('score', 'uc10_score_preprocessed');
perform record_execution_time('uc10', 'preprocess (score)' , v_start_time);

v_start_time := clock_timestamp();
CALL uc10_predict('uc10_score_preprocessed', 'uc10_model', 'uc10_score_predictions');
perform record_execution_time('uc10', 'predict' , v_start_time);

v_start_time := clock_timestamp();
CALL uc10_score('uc10_score_predictions', 'uc10_score_results');
perform record_execution_time('uc10', 'score' , v_start_time);

v_start_time := clock_timestamp();
call uc10_serve('uc10_serve_preprocessed', 'uc10_serve_results');
perform record_execution_time('uc10', 'serve' , v_start_time);

end;
$$;


------------------ Save the results of your preview run -----------------------
-- change the 'prefix' argument to save the results of each experiment as
-- prefix_timeit, prefix_score_results, prefix_table_properties
-- suggestion: sf1, sf5, sf10, sf15 etc.
call save_results('sf10'); -- use the the argument as naming of output table for results


-- Show Results for each run, if named after sf1, sf5, sf10 or sf15
select * from sf1_timeit;
select * from sf1_score_results;
select * from sf1_table_properties;

select * from sf5_timeit;
select * from sf5_score_results;
select * from sf5_table_properties;

select * from sf10_timeit;
select * from sf10_score_results;
select * from sf10_table_properties;

select * from sf15_timeit;
select * from sf15_score_results;
select * from sf15_table_properties;

-- Show total runtime for each experiment (sf1, sf5, sf10, sf15)
select to_char(sum(sf1.execution_time::interval), 'HH24:MI:SS') from sf1_timeit sf1; -- 00:19:39
select to_char(sum(sf5.execution_time::interval), 'HH24:MI:SS') from sf5_fast_timeit sf5; -- 00:39:06 00:27:42
select to_char(sum(sf10.execution_time::interval), 'HH24:MI:SS') from sf10_timeit sf10; -- 01:11:09
select to_char(sum(sf15.execution_time::interval), 'HH24:MI:SS') from sf15_timeit sf15; -- 00:48:42


---------------- Save aggregated results of sf1 - sf15 runs ------------------
-- save runtimes
drop table if exists benchmark_running_time;
CREATE TABLE benchmark_running_time AS (
    SELECT
        sf1.use_case,
        sf1.step,
        to_char((sf1.execution_time::interval), 'HH24:MI:SS.MS') AS sf1_duration,
        to_char((sf5.execution_time::interval), 'HH24:MI:SS.MS') AS sf5_duration,
        to_char((sf10.execution_time::interval), 'HH24:MI:SS.MS') AS sf10_duration,
        to_char((sf15.execution_time::interval), 'HH24:MI:SS.MS') AS sf15_duration,
        (extract(epoch FROM sf5.execution_time::interval) / extract(epoch FROM sf1.execution_time::interval)) AS "sf5_sf1_ratio",
        (extract(epoch FROM sf10.execution_time::interval) / extract(epoch FROM sf1.execution_time::interval)) AS "sf10_sf1_ratio",
        (extract(epoch FROM sf15.execution_time::interval) / extract(epoch FROM sf1.execution_time::interval)) AS "sf15_sf1_ratio",
        ((extract(epoch FROM sf5.execution_time::interval) - extract(epoch FROM sf1.execution_time::interval)) / extract(epoch FROM sf1.execution_time::interval) * 100) AS "sf5_sf1_percentage_change",
        ((extract(epoch FROM sf10.execution_time::interval) - extract(epoch FROM sf1.execution_time::interval)) / extract(epoch FROM sf1.execution_time::interval) * 100) AS "sf10_sf1_percentage_change",
        ((extract(epoch FROM sf15.execution_time::interval) - extract(epoch FROM sf1.execution_time::interval)) / extract(epoch FROM sf1.execution_time::interval) * 100) AS "sf15_sf1_percentage_change"
    FROM
        sf1_timeit sf1
        JOIN sf5_timeit sf5 ON sf1.id = sf5.id
        JOIN sf10_timeit sf10 ON sf1.id = sf10.id
        JOIN sf15_timeit sf15 ON sf1.id = sf15.id
);
select * from benchmark_running_time;

-- save scoring values
drop table if exists benchmark_scoring;
CREATE TABLE benchmark_scoring AS (
    SELECT
        sf1.usecase,
        sf1.evaluation_score AS sf1_score,
        sf5.evaluation_score AS sf5_score,
        sf10.evaluation_score AS sf10_score,
        sf15.evaluation_score AS sf15_score,
        to_char(((sf5.evaluation_score - sf1.evaluation_score) / sf1.evaluation_score * 100), '999D99%') AS sf5_to_sf01_percentage,
        to_char(((sf10.evaluation_score - sf1.evaluation_score) / sf1.evaluation_score * 100), '999D99%') AS sf10_to_sf01_percentage,
        to_char(((sf15.evaluation_score - sf1.evaluation_score) / sf1.evaluation_score * 100), '999D99%') AS sf15_to_sf01_percentage
    FROM
        sf1_score_results sf1
        JOIN sf5_score_results sf5 ON sf1.id = sf5.id
        JOIN sf10_score_results sf10 ON sf1.id = sf10.id
        JOIN sf15_score_results sf15 ON sf1.id = sf15.id);
SELECT * FROM benchmark_scoring;

-- save output_table sizes
drop table if exists benchmark_table_sizes;
create table benchmark_table_sizes as(
select sf1.id, sf1.item_name, sf1.size as sf1_size, sf5.size as sf5_size, sf10.size as sf10_size, sf15.size as sf15_size,
       sf1.columns
    from sf1_table_properties sf1 join sf5_table_properties sf5 on sf1.id = sf5.id
        join sf10_table_properties sf10 on sf1.id = sf10.id
        join sf15_table_properties sf15 on sf1.id = sf15.id);
select * from benchmark_table_sizes;



-- select sum(size) from sf1_table_properties; -- 2.4796 GB
-- select sum(size) from sf5_table_properties; -- 3.9081 GB
-- select sum(size) from sf10_table_properties; -- 6.6950 GB
-- select sum(size) from sf15_table_properties; -- 8.5176 GB

-- sf1 stats:
select count(*) from uc01_train_preprocessed; -- 70710
select count(*) from train.lineitem; -- 23026666

-- SF5 stats:
select count(*) from uc01_train_preprocessed; --212132
select count(*) from train.lineitem; --69059995

-- sf10 stats:
select count(*) from uc01_train_preprocessed; --358817
select count(*) from train.lineitem; --175234694

-- sf15 stats:
select count(*) from uc01_train_preprocessed; -- 491172
select count(*) from train.lineitem; --239902958


-- select * from evaluation_results;
-- select * from items_property;
-- select * from execution_times;
-- select sum(size) from items_property;
-- select to_char(sum(et.execution_time::interval), 'HH24:MI:SS') from execution_times et; -- 1:45:58.52

-- sf1 completed in 19 m 41 s 968 ms
-- sf5 completed in  28 m 46 s 291 ms
-- sf10 completed in completed in 43 m 28 s 31 ms
-- sf15 completed in 56 m 48 s 819 ms
