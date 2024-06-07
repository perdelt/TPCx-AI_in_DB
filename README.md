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

You can run the benchmark using https://github.com/Beuth-Erdelt/DBMS-Benchmarker via

`dbmsbenchmarker -f tpcx-ai -b -w connection -vr -e yes -pn 1 -wli "SF=1 first test" run`

with the configuration folder `tpcx-ai` provided by this repository.

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
* `-w connection`: Run sequence as a stream without reconnection
* `-vr`: Verbose result sets
* `-e yes`: Build evaluation cube
* `-pn 1`: Each query is executed once
* `-wli "SF=1 first test"`: Workload info text to be included in results for convinience

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
python evaluate.py -c 1715943567
```
