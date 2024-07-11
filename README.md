# TPCx-AI in PostgreSQL
Supplement material for implementations of the TPCx-AI benchmark in PostgreSQL.

This includes
* How to turn the data generator into a Docker image and how to use it
* How to turn the Python toolkit into a Docker image and how to use it
* How to build a PostgreSQL/MADLib Docker image including all extensions needed and how to start it
* How to build a Docker image of a loader that ingests generated data into PostgreSQL and how to use it
* How to run the benchmark

The workflow is basically
* Generate the data (once per SF)
* Start an instance of PostgreSQL/MADLib
* Run schema scripts `use-cases/helper_functions.sql` and `use-cases/all-schema.sql`
* Run an instance of the loader
* Run the benchmark
* Drop the instance of PostgreSQL/MADLib when done




## Docker image for TPCx-AI Toolkit

### Data Generator

1. Copy the toolkit into `./images/TPCx-AI/tpcx-ai-v1.0.3.1` (for matching version only)

2. Build the image inside `./images/TPCx-AI` with
```
docker build -t tpcx-ai-datagenerator:v1.0.3.1 -f Dockerfile_generator .
```

3. Run the image with
```
docker run --rm tpcx-ai-datagenerator:v1.0.3.1
```
Data will be generated into subfolders of `/tpcx-ai/output/raw_data`.
The subfolders are `scoring`,  `serving` and  `training`.

You can set some parameters as environment variables
* `TPCxAI_SCALE_FACTOR`: Scaling factor, size of data approx. in GB (default 1)
* `TPCxAI_NODE_COUNT`: Total number of parallel containers for data generation (default 1)
* `TPCxAI_NODE_NUMBER`: Number of the current container in a set of parallel containers (default 1)
* `TPCxAI_SEED`: Random seed for data generation (default 4234567890 like in the toolkit)

Example:
```
docker run --rm \
	-e TPCxAI_SCALE_FACTOR=10 \
	tpcx-ai-datagenerator:v1.0.3.1
```

Data generation automatically scales (vertically) to the number of available threads.
In order to scale horizontally, generation can be split into `TPCxAI_NODE_COUNT` number of processes.
The parameter `TPCxAI_NODE_NUMBER` sets which part of these parts the container should generate.

You can mount the output folders like
```
docker run --rm \
	-v ~/tpcxai-data/SF1:/tpcx-ai/output/raw_data/ \
	-e TPCxAI_SCALE_FACTOR=1 \
	tpcx-ai-datagenerator:v1.0.3.1
```




### Benchmarking Toolkit

1. Copy the toolkit into `./images/TPCx-AI/tpcx-ai-v1.0.3.1` (for matching version only)

2. Build the image inside `./images/TPCx-AI` with
```
docker build -t tpcx-ai-benchmarker:v1.0.3.1 -f Dockerfile_benchmarker .
```

3. Run the image with
```
docker run --rm \
	-v ~/tpcxai-data/SF1:/tpcx-ai/output/raw_data/ \
	-v ~/tpcxai-data/SF1/model:/tpcx-ai/output/model/ \
	-v ~/tpcxai-data/SF1/output:/tpcx-ai/output/output/ \
	-e TPCxAI_SCALE_FACTOR=1 \
	tpcx-ai-benchmarker:v1.0.3.1
```

The container
* copies data from `/tpcx-ai/output/raw_data/` to `/tpcx-ai/output/data/`. Subfolder structure is expected to be like in the data generation containers (`training/` etc).
* builds and expects models in `/tpcx-ai/output/model/`
* writes labeled data in `/tpcx-ai/output/output/`

You can set some parameters as environment variables
* `TPCxAI_STAGE`: stage of the benchmark: training, serving or scoring (default training)
* `TPCxAI_UC`: number of use case: 1 - 10 (default all), leave empty for all use cases
* `TPCxAI_SCALE_FACTOR`: scale factor (default 1)

Example:
```
docker run --rm \
	-v ~/tpcxai-data/SF1:/tpcx-ai/output/raw_data/ \
	-v ~/tpcxai-data/SF1/model:/tpcx-ai/output/model/ \
	-v ~/tpcxai-data/SF1/output:/tpcx-ai/output/output/ \
	-e TPCxAI_STAGE=serving \
	-e TPCxAI_UC=1 \
	-e TPCxAI_SCALE_FACTOR=1 \
	tpcx-ai-benchmarker:v1.0.3.1
```

Note that training must happen before serving.

#### Interactive Mode

To start in an interactive mode (for example for debugging), use
```
docker run -it --name tpcxai -v ~/tpcxai-data:/tpcx-ai/output/raw_data/ --entrypoint /bin/bash tpcx-ai-benchmarker:v1.0.3.1
```
Inside interactive mode, you might for example want to run and inspect use case 2:
```
TPCxAI_UC=2
./benchmarker.sh
```




## Docker image for MADLib

1. Build the image inside `./images/MADLib` with
```
docker build . -t madlib_postgresql:15.x_3.10_2.1
```

2. Run the image with
```
docker run -d --name madlib -p 5432:5432 madlib_postgresql:15.x_3.10_2.1
```
This will start a PostgreSQL server with MADLib and PLPython3 active.

There are some fixed settings:
* Ubuntu 22.04
* PostgreSQL 15.x
* PostgreSQL user/password: postgres/postgres
* Database directory: `/var/lib/postgresql/15/main`
* Python 3.10
* MADLib 2.1

There are two test scripts
* `tests/madlib-test.sql`: MADLib logregr_train
* `tests/plpython3-test.sql`: Python PL extension

### Interactive Mode

Inside a container, you can activate the Python environment used by PL/Python with `source madlib/bin/activate`.

### Optional Modules

The Dockerfile contains sections to (optionally) also install

* PostGIS
* PL/R
* TimescaleDB
* pg_vector
* Citus

These are not needed, so you can comment them out, but you may want to have them to have a more complete data science system.




## Data Loader

Loads Data into PostgreSQL / MADLib

2. Build the image inside `./images/loader_postgresql` with
```
docker build -t tpcx-ai-loader:v1.0.3.1 -f Dockerfile_loader .
```

2. Run the image with
```
docker run --name loader -v ~/tpcxai:/data --rm --net=host -e TPCxAI_SCALE_FACTOR=1  tpcx-ai-loader:v1.0.3.1
```

The container expects the data to be in `/data` and PostgreSQL to listen at `localhost:5432`.

You can set some parameters as environment variables
* `TPCxAI_SCALE_FACTOR`: Scaling factor, size of data approx. in GB (default 1)
* `BEXHOMA_HOST`: Host of PostgreSQL (default localhost)
* `BEXHOMA_PORT`: Port of PostgreSQL (default 5432)
* `DATABASE`: Database in PostgreSQL (default postgres)
* `USER`: User for PostgreSQL (default postgres)
* `PASSWORD`: Password for PostgreSQL (default postgres)




## DBMSBenchmarker

You can run the benchmark using https://github.com/Beuth-Erdelt/DBMS-Benchmarker with the configuration folder `tpcx-ai` provided by this repository.

You may want to run the phases of the benchmark separately:

### Training Power

`dbmsbenchmarker -f tpcx-ai -b -e yes -wli "SF=1 training" -qf queries-training.config run`

yields

```
Q1: UC01 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 17647.81 |    0.00 |   0.00 |     0.00 |  0.00 | 17647.81 | 17647.81 | 17647.81 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q2: UC03 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 41895.03 |    0.00 |   0.00 |     0.00 |  0.00 | 41895.03 | 41895.03 | 41895.03 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q3: UC04 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 15667.39 |    0.00 |   0.00 |     0.00 |  0.00 | 15667.39 | 15667.39 | 15667.39 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q4: UC06 - Training - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 2051.05 |    0.00 |   0.00 |     0.00 |  0.00 |  2051.05 | 2051.05 | 2051.05 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q5: UC07 - Training - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 7816.17 |    0.00 |   0.00 |     0.00 |  0.00 |  7816.17 | 7816.17 | 7816.17 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q6: UC08 - Training - timerExecution
+-------------+------+------------+---------+--------+----------+-------+------------+------------+------------+
| DBMS [ms]   |    n |       mean |   stdev |   cv % |   qcod % |   iqr |     median |        min |        max |
+=============+======+============+=========+========+==========+=======+============+============+============+
| MADLib      | 1.00 | 1047846.40 |    0.00 |   0.00 |     0.00 |  0.00 | 1047846.40 | 1047846.40 | 1047846.40 |
+-------------+------+------------+---------+--------+----------+-------+------------+------------+------------+
Q7: UC10 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 66720.08 |    0.00 |   0.00 |     0.00 |  0.00 | 66720.08 | 66720.08 | 66720.08 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+

TPCx-AI : SF=1 training
First successful query: Q1
Limited to: ['MADLib']
Number of successful queries: 7
Number of runs per query: 1
Number of max. parallel clients per stream: 1
Number of parallel independent streams: 1

### Errors (failed queries)
No errors

### Warnings (result mismatch)
No warnings

### Geometric Mean of Medians of Run Times (only successful) [s]
        average run time [s]
DBMS                        
MADLib                 27.85
### Sum of Maximum Run Times per Query (only successful) [s]
        sum of max run times [s]
DBMS                            
MADLib                   1199.64
### Queries per Hour (only successful) [QpH] - 1*7*3600/(sum of max run times)
        queries per hour [Qph]
DBMS                          
MADLib                   21.01
### Queries per Hour (only successful) [QpH] - Sum per DBMS
        queries per hour [Qph]
DBMS                          
MADLib                   21.01
### Queries per Hour (only successful) [QpH] - (max end - min start)
        queries per hour [Qph]          formula
DBMS                                           
MADLib                    21.0  1*1*7*3600/1200
Experiment 1721057427 has been finished
```

Alternatively, this configuration shows the runtimes of preparation and training separately:

`dbmsbenchmarker -f tpcx-ai -b -e yes -wli "SF=1 training" -qf queries-preparing-and-training.config run`

yields

```
Q1: UC01 - Training Preprocess - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 11777.19 |    0.00 |   0.00 |     0.00 |  0.00 | 11777.19 | 11777.19 | 11777.19 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q2: UC01 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 12832.12 |    0.00 |   0.00 |     0.00 |  0.00 | 12832.12 | 12832.12 | 12832.12 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q3: UC03 - Training Preprocess - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 8948.90 |    0.00 |   0.00 |     0.00 |  0.00 |  8948.90 | 8948.90 | 8948.90 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q4: UC03 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 34297.94 |    0.00 |   0.00 |     0.00 |  0.00 | 34297.94 | 34297.94 | 34297.94 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q5: UC04 - Training Preprocessing - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 10033.25 |    0.00 |   0.00 |     0.00 |  0.00 | 10033.25 | 10033.25 | 10033.25 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q6: UC04 - Training - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 4970.85 |    0.00 |   0.00 |     0.00 |  0.00 |  4970.85 | 4970.85 | 4970.85 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q7: UC06 - Training Preprocess - timerExecution
+-------------+------+--------+---------+--------+----------+-------+----------+-------+-------+
| DBMS [ms]   |    n |   mean |   stdev |   cv % |   qcod % |   iqr |   median |   min |   max |
+=============+======+========+=========+========+==========+=======+==========+=======+=======+
| MADLib      | 1.00 |  16.31 |    0.00 |   0.00 |     0.00 |  0.00 |    16.31 | 16.31 | 16.31 |
+-------------+------+--------+---------+--------+----------+-------+----------+-------+-------+
Q8: UC06 - Training - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 1832.49 |    0.00 |   0.00 |     0.00 |  0.00 |  1832.49 | 1832.49 | 1832.49 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q9: UC07 - Training Preprocess - timerExecution
+-------------+------+--------+---------+--------+----------+-------+----------+-------+-------+
| DBMS [ms]   |    n |   mean |   stdev |   cv % |   qcod % |   iqr |   median |   min |   max |
+=============+======+========+=========+========+==========+=======+==========+=======+=======+
| MADLib      | 1.00 |   2.91 |    0.00 |   0.00 |     0.00 |  0.00 |     2.91 |  2.91 |  2.91 |
+-------------+------+--------+---------+--------+----------+-------+----------+-------+-------+
Q10: UC07 - Training - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 7781.10 |    0.00 |   0.00 |     0.00 |  0.00 |  7781.10 | 7781.10 | 7781.10 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
Q11: UC08 - Training Preprocessing - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 65613.18 |    0.00 |   0.00 |     0.00 |  0.00 | 65613.18 | 65613.18 | 65613.18 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q12: UC08 - Training - timerExecution
+-------------+------+------------+---------+--------+----------+-------+------------+------------+------------+
| DBMS [ms]   |    n |       mean |   stdev |   cv % |   qcod % |   iqr |     median |        min |        max |
+=============+======+============+=========+========+==========+=======+============+============+============+
| MADLib      | 1.00 | 1047946.15 |    0.00 |   0.00 |     0.00 |  0.00 | 1047946.15 | 1047946.15 | 1047946.15 |
+-------------+------+------------+---------+--------+----------+-------+------------+------------+------------+
Q13: UC10 - Training Preprocess - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 19505.58 |    0.00 |   0.00 |     0.00 |  0.00 | 19505.58 | 19505.58 | 19505.58 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
Q14: UC10 - Training - timerExecution
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+
| DBMS [ms]   |    n |     mean |   stdev |   cv % |   qcod % |   iqr |   median |      min |      max |
+=============+======+==========+=========+========+==========+=======+==========+==========+==========+
| MADLib      | 1.00 | 40926.29 |    0.00 |   0.00 |     0.00 |  0.00 | 40926.29 | 40926.29 | 40926.29 |
+-------------+------+----------+---------+--------+----------+-------+----------+----------+----------+

TPCx-AI : SF=1 training
First successful query: Q1
Limited to: ['MADLib']
Number of successful queries: 14
Number of runs per query: 1
Number of max. parallel clients per stream: 1
Number of parallel independent streams: 1

### Errors (failed queries)
No errors

### Warnings (result mismatch)
No warnings

### Geometric Mean of Medians of Run Times (only successful) [s]
        average run time [s]
DBMS                        
MADLib                  6.04
### Sum of Maximum Run Times per Query (only successful) [s]
        sum of max run times [s]
DBMS                            
MADLib                   1266.48
### Queries per Hour (only successful) [QpH] - 1*14*3600/(sum of max run times)
        queries per hour [Qph]
DBMS                          
MADLib                    39.8
### Queries per Hour (only successful) [QpH] - Sum per DBMS
        queries per hour [Qph]
DBMS                          
MADLib                    39.8
### Queries per Hour (only successful) [QpH] - (max end - min start)
        queries per hour [Qph]           formula
DBMS                                            
MADLib                   39.78  1*1*14*3600/1267
Experiment 1721058985 has been finished
```


### Scoring

`dbmsbenchmarker -f tpcx-ai -b -e yes -wli "SF=1 scoring" -qf queries-scoring.config -vr run`

yields

```
USECASE DATE_TIME                       EVALUATION_SCORE 
1       2024-07-16 10:22:46.467797      0.636758798113665
3       2024-07-16 10:22:47.646807      70.5438095547646 
4       2024-07-16 10:22:49.490151      0.695845697329377
6       2024-07-16 10:22:49.705600      0.371279252963552
7       2024-07-16 10:22:49.781929      1.55371900826446 
8       2024-07-16 10:23:43.961350      0.639219230769231
10      2024-07-16 10:23:46.554992      0.816385576923077

TABLE_SCHEMA    TABLE_FULL_NAME                                 TOTAL_SIZE
public          uc01_minmax_scaling_table                       32 kB     
public          uc01_model                                      16 kB     
public          uc01_score_preprocessed                         1648 kB   
public          uc01_serve_preprocessed                         1184 kB   
public          uc01_serve_results                              576 kB    
public          uc01_train_preprocessed                         11 MB     
public          uc03_score_predictions                          1616 kB   
public          uc03_score_preprocessed                         2528 kB   
public          uc03_score_results                              1928 kB   
public          uc03_serve_results                              1616 kB   
public          uc03_train_preprocessed                         3440 kB   
public          uc04_model                                      992 kB    
public          uc04_score_predictions                          1184 kB   
public          uc04_score_preprocessed                         20 MB     
public          uc04_serve_preprocessed                         13 MB     
public          uc04_serve_results                              824 kB    
public          uc04_tokens                                     626 MB    
public          uc04_train_preprocessed                         133 MB    
public          uc06_model                                      16 kB     
public          uc06_model_random                               32 kB     
public          uc06_model_summary                              16 kB     
public          uc06_score_predictions                          424 kB    
public          uc06_score_results                              424 kB    
public          uc06_serve_results                              248 kB    
public          uc06_standardization_scaling_table              32 kB     
public          uc06_standardized                               9296 kB   
public          uc06_train_preprocessed                         1296 kB   
public          uc06_train_preprocessed_upsampled_standardized  5552 kB   
public          uc07_model                                      11 MB     
public          uc07_score_predictions                          1688 kB   
public          uc07_score_results                              16 kB     
public          uc07_serve_results                              984 kB    
public          uc08_model                                      2328 kB   
public          uc08_model_summary                              3936 kB   
public          uc08_score_predictions                          185 MB    
public          uc08_score_predictions_metrics                  16 kB     
public          uc08_score_preprocessed                         140 MB    
public          uc08_score_results                              21 MB     
public          uc08_train_preprocessed                         859 MB    
public          uc08_train_preprocessed_preprocessed            1026 MB   
public          uc10_loaded_temp                                113 MB    
public          uc10_model                                      16 kB     
public          uc10_model_summary                              16 kB     
public          uc10_score_predictions                          44 MB     
public          uc10_score_preprocessed                         59 MB     
public          uc10_score_results                              44 MB     
public          uc10_serve_preprocessed                         42 MB     
public          uc10_serve_results                              31 MB     
public          uc10_train_preprocessed                         479 MB    
```

and some timing information.

### Serve Power

`dbmsbenchmarker -f tpcx-ai -b -e yes -wli "SF=1 serving power" -qf queries-serving.config run`

yields

```
Q1: UC01 - Serve - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib      | 1.00 | 1387.79 |    0.00 |   0.00 |     0.00 |  0.00 |  1387.79 | 1387.79 | 1387.79 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+

TPCx-AI : SF=1 serving power
First successful query: Q1
Limited to: ['MADLib']
Number of successful queries: 1
Number of runs per query: 1
Number of max. parallel clients per stream: 1
Number of parallel independent streams: 1

### Errors (failed queries)
No errors

### Warnings (result mismatch)
No warnings

### Geometric Mean of Medians of Run Times (only successful) [s]
        average run time [s]
DBMS                        
MADLib                  1.39
### Sum of Maximum Run Times per Query (only successful) [s]
        sum of max run times [s]
DBMS                            
MADLib                      1.39
### Queries per Hour (only successful) [QpH] - 1*1*3600/(sum of max run times)
        queries per hour [Qph]
DBMS                          
MADLib                 2594.05
### Queries per Hour (only successful) [QpH] - Sum per DBMS
        queries per hour [Qph]
DBMS                          
MADLib                 2594.05
### Queries per Hour (only successful) [QpH] - (max end - min start)
        queries per hour [Qph]       formula
DBMS                                        
MADLib                  3600.0  1*1*1*3600/1
Experiment 1721118367 has been finished
```

Show results again: `dbmsbenchmarker -r ./1720708938 read -e yes`


### Serve Throughput

To run 2 streams, you can use

`dbmsbenchmarker -f tpcx-ai -b -e yes -wli "SF=1 serving throughput 2 streams" -qf queries-serving.config -p 2 -pp run`

This yields

```
Q1: UC01 - Serve - timerExecution
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| DBMS [ms]   |    n |    mean |   stdev |   cv % |   qcod % |   iqr |   median |     min |     max |
+=============+======+=========+=========+========+==========+=======+==========+=========+=========+
| MADLib-1    | 1.00 | 1286.90 |    0.00 |   0.00 |     0.00 |  0.00 |  1286.90 | 1286.90 | 1286.90 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+
| MADLib-2    | 1.00 | 1298.30 |    0.00 |   0.00 |     0.00 |  0.00 |  1298.30 | 1298.30 | 1298.30 |
+-------------+------+---------+---------+--------+----------+-------+----------+---------+---------+

TPCx-AI : SF=1 serving throughput 2 streams
First successful query: Q1
Limited to: ['MADLib-1', 'MADLib-2']
Number of successful queries: 1
Number of runs per query: 1
Number of max. parallel clients per stream: 1
Number of parallel independent streams: 2

### Errors (failed queries)
No errors

### Warnings (result mismatch)
No warnings

### Geometric Mean of Medians of Run Times (only successful) [s]
          average run time [s]
DBMS                          
MADLib-1                  1.29
MADLib-2                  1.30
### Sum of Maximum Run Times per Query (only successful) [s]
          sum of max run times [s]
DBMS                              
MADLib-1                      1.29
MADLib-2                      1.30
### Queries per Hour (only successful) [QpH] - 1*1*3600/(sum of max run times)
          queries per hour [Qph]
DBMS                            
MADLib-1                 2797.43
MADLib-2                 2772.86
### Queries per Hour (only successful) [QpH] - Sum per DBMS
        queries per hour [Qph]
DBMS                          
MADLib                 5570.29
### Queries per Hour (only successful) [QpH] - (max end - min start)
        queries per hour [Qph]       formula
DBMS                                        
MADLib                  7200.0  1*2*1*3600/1
Experiment 1721118433 has been finished

```

### Show Results Again

Show results again: `dbmsbenchmarker -r ./1721118433 read -e yes`

### Prerequisites

1. Install DBMSBenchmarker by `pip install dbmsbenchmarker`
1. Download PostgreSQL JDBC driver: https://jdbc.postgresql.org/download/
1. Download or clone the config folder `tpcx-ai` from this repository
1. Adjust connection infos to your MADLib installation in `tpcx-ai/connections.config`

### Background

This automatically runs a sequence of SQL queries.
It follows the default ordering preprocessing, training, scoring and serving use-case after use-case.
At the end it reads and shows the content of the evaluation store and sizes of the artefacts.
Arguments mean
* `-f tpcx-ai`: Folder containing the parameter files `queries.config` and `connections.config`
* `-b`: Batch mode (reduced output)
* `-vr`: Verbose result sets
* `-e yes`: Build evaluation cube
* `-wli "SF=1 first test"`: Workload info text to be included in results for convinience
* `-p 2`: 2 Streams
* `-pp`: Streams in parallel (independent) processes
* `-r`: Folder for storing results
* `-vr`: Verbose result sets of queries

After the benchmark has finished you will see some results and something like
```
Experiment 1715943567 has been finished
```
The results are stored in an evaluation folder named by a code, `1715943567` here.

### Evaluation

You can evaluate the result using the Python interface of dbmsbenchmarker.
We have included an example, that can be run by (inspect latest result)
```
python evaluate.py
```
or by (inspect result code `1715943567`)
```
python evaluate.py -c 1721118433
```
