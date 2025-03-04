
-- do not drop elements of crosstab
/*
drop function if exists public.normal_rand(integer, double precision, double precision) cascade;

drop function if exists public.crosstab(text) cascade;

drop function if exists public.crosstab2(text) cascade;

drop function if exists public.crosstab3(text) cascade;

drop function if exists public.crosstab4(text) cascade;

drop function if exists public.crosstab(text, integer) cascade;

drop function if exists public.crosstab(text, text) cascade;

drop function if exists public.connectby(text, text, text, text, integer, text) cascade;

drop function if exists public.connectby(text, text, text, text, integer) cascade;

drop function if exists public.connectby(text, text, text, text, text, integer, text) cascade;

drop function if exists public.connectby(text, text, text, text, text, integer) cascade;

*/

drop function if exists public.fit_minmax_scaler(varchar, character varying[]) cascade;

drop function if exists public.transform_minmax_scaler(varchar, character varying[]) cascade;

drop function if exists public.minmax_scale(numeric, numeric, numeric) cascade;

drop procedure if exists public.uc1_preprocess_score() cascade;

drop procedure if exists public.uc1_preprocess_scoring_data() cascade;

drop function if exists public.fit_minmax_scaler(varchar, character varying[], varchar) cascade;

drop function if exists public.transform_minmax_scaler(varchar, varchar, varchar) cascade;

drop procedure if exists public.uc1_preprocess_1(varchar) cascade;

drop function if exists public.transform_minmax_scaler(varchar, varchar) cascade;

drop function if exists public.uc01_silhouette_scoring(varchar, varchar, varchar) cascade;

drop function if exists public.uc01_silhouette_scoring(varchar, varchar) cascade;

drop function if exists public.uc01_point_cluster_mapping(varchar, varchar) cascade;

drop procedure if exists public.train_model() cascade;

drop function if exists public.preprocess_data(text, text) cascade;

drop function if exists public.preprocess_data(text, text, text) cascade;

drop function if exists public.preprocess_and_train(text, text, text, text) cascade;

drop procedure if exists public.predict(text, text) cascade;

drop procedure if exists public.predict(text, text, text) cascade;

drop function if exists public.preprocess_score_data(text, text, text, text) cascade;

drop function if exists public.preprocess_serve_data(text, text, text, text) cascade;

drop procedure if exists public.predict(text, text, text, text) cascade;

drop procedure if exists public.predict_serve(text, text, text, text) cascade;

drop procedure if exists public.uc03_training(text) cascade;

drop procedure if exists public.uc3_preprocess(text, text) cascade;

drop procedure if exists public.forecast_arima_models(text) cascade;

drop procedure if exists public.train_arima_model(text) cascade;

drop procedure if exists public.evaluation(integer) cascade;

drop procedure if exists public.create_temp_failures(text) cascade;

drop procedure if exists public.process_failures(text, text, text) cascade;

drop procedure if exists public.uc06_load(text) cascade;

drop procedure if exists public.uc06_preprocess(text, text, text) cascade;

drop procedure if exists public.uc06_train_svm_model(text, text) cascade;

drop procedure if exists public.preprocess_data(varchar, varchar) cascade;

drop procedure if exists public.load_data(varchar, varchar) cascade;

drop procedure if exists public.uc10_preprocess_data(varchar, varchar) cascade;

drop procedure if exists public.uc10_load_data(varchar, varchar) cascade;

drop function if exists public.uc10_scoring(varchar, varchar) cascade;

drop function if exists public.evaluate_fraud_prediction(text, text) cascade;

drop function if exists public.uc10_scoring(text, text) cascade;

drop function if exists public.timeit(text, text[], boolean) cascade;

drop function if exists public.timeit(text, text, text[]) cascade;

drop function if exists public.timeit_python(text, text, text[]) cascade;

drop function if exists public.timeit2(text, text, text[]) cascade;

drop procedure if exists public.create_usecase08_view(varchar) cascade;

drop procedure if exists public.uc08_loading(varchar) cascade;

drop procedure if exists public.uc08_preprocessing(varchar) cascade;

drop procedure if exists public.uc08_preprocessing(varchar, varchar) cascade;

drop procedure if exists public.uc08_loading(varchar, varchar) cascade;

drop procedure if exists public.uc08_preprocessing(varchar, varchar, varchar) cascade;

drop procedure if exists public.uc08_scoring_preprocessing(varchar, varchar, varchar) cascade;

drop function if exists public.accuracy(varchar, varchar, varchar) cascade;

drop function if exists public.uc08_evaluate_model() cascade;

drop function if exists public.uc08_evaluate_model(varchar, varchar, varchar) cascade;

drop function if exists public.calculate_mcc() cascade;

drop function if exists public.calculate_mcc(text, text, text) cascade;

drop function if exists public.apply_adasyn(text, text) cascade;

drop function if exists public.get_python_path() cascade;

drop function if exists public.get_python_env() cascade;

drop function if exists public.standardize_features(text, text, text[]) cascade;

drop function if exists public.apply_adasyn(text, text, text[], text) cascade;

drop procedure if exists public.uc06_preprocess(text) cascade;

drop procedure if exists public.uc06_load(text, text) cascade;

drop procedure if exists public.uc06_upsampling_standardization(text, text, text[], text, text) cascade;

drop function if exists public.imba_adasyn(text, text, text[], text) cascade;

drop procedure if exists public.uc06_predict_and_evaluate(text) cascade;

drop function if exists public.calculate_mae(regclass, text, text) cascade;

drop function if exists public.uc04_preprocess_and_train(text, text, text, text) cascade;

drop function if exists public.standardize_features2(text, text[]) cascade;

drop function if exists public.apply_standardization(text, text[], text) cascade;

drop procedure if exists public.uc06_upsampling_standardization(text, text, text[], text, text, text) cascade;

drop function if exists public.standardize_features(text, text[], text) cascade;

drop procedure if exists public.uc06_predict_and_evaluate(text, text) cascade;

drop function if exists public.minmax_scaling(text, text[], text) cascade;

drop function if exists public.apply_minmax(text, text[], text) cascade;

drop procedure if exists public.create_uc07_results() cascade;

drop function if exists public.calculate_msle(text, text, text) cascade;

drop procedure if exists public.uc03_results(integer) cascade;

drop procedure if exists public.calculate_msle() cascade;

drop procedure if exists public.uc03_results_no_labels() cascade;

drop procedure if exists public.uc03_score_labels() cascade;

drop procedure if exists public.uc03_preprocess_score(text, text) cascade;

drop function if exists public.uc04_preprocess_and_train(text, text, text) cascade;

drop procedure if exists public.uc03_load(text) cascade;

drop procedure if exists public.uc03_load(text, text) cascade;

drop procedure if exists public.uc04_load(text, text) cascade;

drop procedure if exists public.uc04_train_preprocessing(text, text) cascade;

drop procedure if exists public.uc04_evaluate(text, text, text, text, inout text) cascade;

drop procedure if exists public.usecase10_training(text, text, integer, text, double precision) cascade;

drop procedure if exists public.uc01_training_train() cascade;

drop function if exists public.evaluate_model() cascade;

drop procedure if exists public.uc10_loading(varchar, varchar) cascade;

drop procedure if exists public.create_evaluation_results_table() cascade;

drop function if exists public.generate_drop_commands(text[]) cascade;

drop function if exists public.drop_all_tables(text[]) cascade;

drop function if exists public.f1_score(text, text, text) cascade;

drop function if exists public.timeit_procedure(text, varchar, varchar) cascade;

drop function if exists public.timeit_function(text, text, text) cascade;

drop procedure if exists public.uc01_training_preprocess() cascade;

drop function if exists public.uc01_training_evaluate() cascade;

drop procedure if exists public.uc01_scoring_apply() cascade;

drop procedure if exists public.uc01_scoring_preprocess() cascade;

drop function if exists public.uc01_scoring_evaluate() cascade;

drop procedure if exists public.uc10_preprocessing(varchar, varchar) cascade;

drop procedure if exists public.stratified_sampling(text, text) cascade;

drop procedure if exists public.xgboost_training(text) cascade;

drop procedure if exists public.uc08_training(text) cascade;

drop procedure if exists public.uc08_stratified_sampling(text, text) cascade;

drop procedure if exists public.uc1_preprocess(varchar, varchar) cascade;

drop function if exists public.uc01_scoring(varchar, varchar) cascade;

drop procedure if exists public.uc03_train(text) cascade;

drop procedure if exists public.uc01_train(varchar, varchar) cascade;

drop procedure if exists public.uc04_preprocess(text, text) cascade;

drop procedure if exists public.uc04_train(text, text) cascade;

drop procedure if exists public.train(text) cascade;

drop procedure if exists public.uc06_preprocess(text, text) cascade;

drop procedure if exists public.uc06_train(text, text) cascade;

drop procedure if exists public.uc06_predict_and_score(text, text) cascade;

drop procedure if exists public.uc06_predict(text, text, text) cascade;

drop procedure if exists public.uc06_score(text) cascade;

drop procedure if exists public.uc07_preprocess() cascade;

drop procedure if exists public.uc07_predict() cascade;

drop procedure if exists public.uc07_score() cascade;

drop procedure if exists public.uc10_train(text, text, integer, text, double precision) cascade;

drop procedure if exists public.uc10_predict(text, text, text) cascade;

drop procedure if exists public.uc10_score(text) cascade;

drop procedure if exists public.uc08_load_preprocess(varchar, varchar) cascade;

drop procedure if exists public.uc08_preprocess(varchar, varchar) cascade;

drop procedure if exists public.uc08_train(text) cascade;

drop procedure if exists public.uc08_predict(varchar, varchar, varchar) cascade;

drop procedure if exists public.uc08_score(varchar) cascade;

drop procedure if exists public.uc08_train(text, text) cascade;

drop procedure if exists public.uc07_training() cascade;

drop procedure if exists public.uc01_score(varchar, varchar) cascade;

drop procedure if exists public.uc03_predict(text) cascade;

drop procedure if exists public.uc07_train() cascade;

drop procedure if exists public.uc08_stratified_sampling2(text, text) cascade;

drop procedure if exists public.uc08_preprocess2(varchar, varchar) cascade;

drop procedure if exists public.uc01_preprocess(varchar, varchar) cascade;

drop procedure if exists public.uc03_preprocess(text, text) cascade;

drop procedure if exists public.uc03_score(text) cascade;

drop procedure if exists public.uc04_predict(text, text, text) cascade;

drop procedure if exists public.uc04_score(text, text, text, text) cascade;

drop procedure if exists public.uc10_preprocess(varchar, varchar) cascade;

