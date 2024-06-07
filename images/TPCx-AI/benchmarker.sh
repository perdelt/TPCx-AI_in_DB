#!/bin/bash
######################################################################################
# Bash script for TPCx-AI supplements - Driver
######################################################################################
# Script Name:    generator.sh
# Description:    This script calls the tpcxai-driver of the TPCx-AI toolkit to execute phases of the workload.
# Author:         Patrick K. Erdelt
# Email:          patrick.erdelt@bht-berlin.de
# Date:           2024-05-26
# Version:        1.0
# Important environment variables:
# TPCxAI_SCALE_FACTOR: Scaling factor, size of data approx. in GB (default 1)
# TPCxAI_NODE_COUNT: Total number of parallel containers for data generation (default 1)
# TPCxAI_NODE_NUMBER: Number of the current container in a set of parallel containers (default 1)
# TPCxAI_SEED: Random seed for data generation (default 4234567890 like in the toolkit)
# TPCxAI_SEED: Random seed for data generation (default 4234567890 like in the toolkit)
# TPCxAI_UC: number of use case: 1 - 10 (default all), leave empty for all use cases
# TPCxAI_SCALE_FACTOR: scale factor (default 1)
######################################################################################


######################## Start timing ########################
DATEANDTIME=$(date '+%d.%m.%Y %H:%M:%S');
echo "$DATEANDTIME"
SECONDS_START_SCRIPT=$SECONDS

######################## Show general parameters ########################
echo "TPCxAI_SCALE_FACTOR:${TPCxAI_SCALE_FACTOR}"
echo "TPCxAI_NODE_COUNT:$TPCxAI_NODE_COUNT"
echo "TPCxAI_NODE_NUMBER:$TPCxAI_NODE_NUMBER"
echo "TPCxAI_SEED:$TPCxAI_SEED"
echo "TPCxAI_STAGE:$TPCxAI_STAGE"
echo "TPCxAI_UC:$TPCxAI_UC"
# make use case 2 digits fixed
printf -v TPCxAI_UC_STRING "%02d" $TPCxAI_UC
echo "TPCxAI_UC_STRING:$TPCxAI_UC_STRING"
# single use case?
if [ -z "$TPCxAI_UC" ]
then
	TPCxAI_UC_RESTRICT=""
else
	TPCxAI_UC_RESTRICT="-uc $TPCxAI_UC "
fi
echo "TPCxAI_UC_RESTRICT:$TPCxAI_UC_RESTRICT"

TEMP_SF=$TPCxAI_SCALE_FACTOR

######################## Execute workload ###################
# python workload/python/workload/UseCase01.py --workdir /tpcx-ai/ /tpcx-ai/lib/pdgf/output/SF1/training/order.csv /tpcx-ai/lib/pdgf/output/SF1/training/lineitem.csv /tpcx-ai/lib/pdgf/output/SF1/training/order_returns.csv  --stage training
# python workload/python/workload/UseCase01.py --workdir /tpcx-ai/ /tpcx-ai/lib/pdgf/output/SF1/serving/order.csv /tpcx-ai/lib/pdgf/output/SF1/serving/lineitem.csv /tpcx-ai/lib/pdgf/output/SF1/serving/order_returns.csv  --stage serving
# PATH_WORKLOAD=workload/python/workload
# PATH_DATA=/tpcx-ai/lib/pdgf/output
# PATH_BASE=/tpcx-ai/output
# PATH_OUTPUT="$PATH_BASE/SF$TPCxAI_SCALE_FACTOR/uc$TPCxAI_UC_STRING/"
# PATH_WORKDIR="$PATH_OUTPUT/"
# cd /tpcx-ai/

# case $TPCxAI_UC in
# 	1)
# 	/tpcx-ai/lib/python-venv-ks/bin/python $PATH_WORKLOAD/UseCase01.py \
# 		--workdir $PATH_WORKDIR \
# 		--output $PATH_OUTPUT \
# 		--stage $TPCxAI_STAGE \
# 		--num_clusters 4 \
# 		$PATH_DATA/SF$TPCxAI_SCALE_FACTOR/$TPCxAI_STAGE/order.csv \
# 		$PATH_DATA/SF$TPCxAI_SCALE_FACTOR/$TPCxAI_STAGE/lineitem.csv \
# 		$PATH_DATA/SF$TPCxAI_SCALE_FACTOR/$TPCxAI_STAGE/order_returns.csv 
# 	;;
# 	2)
# 	/tpcx-ai/lib/python-venv-ks/bin/python $PATH_WORKLOAD/UseCase02.py \
# 		--workdir $PATH_WORKDIR \
# 		--output $PATH_OUTPUT \
# 		--stage $TPCxAI_STAGE \
# 		--epochs 25 \
# 		--batch 32 \
# 		$PATH_DATA/SF$TPCxAI_SCALE_FACTOR/$TPCxAI_STAGE/CONVERSATION_AUDIO.csv \
# 	;;
# esac


####################
# from TPCx-AI_Benchmarkrun.sh
####################
. setenv.sh

TPCxAI_SCALE_FACTOR=$TEMP_SF

LOG_DEST="tpcxai_benchmark_run"
TPCxAI_CONFIG_FILE_PATH=${TPCxAI_BENCHMARKRUN_CONFIG_FILE_PATH}
#if [[ ${IS_VALIDATION_RUN} -eq "1" ]]; then
#   echo "Benchmark validation run. Setting scale factor value to 1..."
#   export TPCxAI_SCALE_FACTOR=1
#   TPCxAI_CONFIG_FILE_PATH=${TPCxAI_VALIDATION_CONFIG_FILE_PATH}
#   LOG_DEST="tpcxai_benchmark_validation"
#fi

if [[ ${TPCx_AI_VERBOSE} == "True" ]]; then
   VFLAG="-v"
fi

echo "TPCx-AI_HOME directory: ${TPCx_AI_HOME_DIR}";
echo "Using configuration file: ${TPCxAI_CONFIG_FILE_PATH} and Scale factor ${TPCxAI_SCALE_FACTOR}..."

echo "Starting Benchmark run..."

####################
# from bin/tpcxai.sh
####################
if [ -z "${TPCx_AI_HOME_DIR}" ]
   then echo "The Environment variable TPCx_AI_HOME_DIR is empty. Please edit and source the setenv.sh file before running the benchmark."
   exit 1
fi

TPCXAI_HOME=${TPCx_AI_HOME_DIR}
DRIVER_PATH="$TPCXAI_HOME/driver"

DEFAULT_CONFIG="$TPCXAI_HOME/driver/config/default.yaml"

PYTHON="$TPCXAI_HOME/lib/python-venv/bin/python"

if [[ $ARGS != *"-c"* && $ARGS != *"--config" ]]; then
  ARGS="-c $DEFAULT_CONFIG $ARGS"
fi

# TODO fix tpcxai_home in the driver itself
# change to different working directory
cd "$DRIVER_PATH"

echo IS_EULA_ACCEPTED=true >> /tpcx-ai/data-gen/Constants.properties
echo IS_EULA_ACCEPTED=true >> /tpcx-ai/lib/pdgf/Constants.properties

case $TPCxAI_STAGE in
	"training")
		CMD="$PYTHON -u -m tpcxai-driver $ARGS --phase LOADING -v -sf ${TPCxAI_SCALE_FACTOR}"
		$CMD
		CMD="$PYTHON -u -m tpcxai-driver $ARGS $TPCxAI_UC_RESTRICT--phase TRAINING -v -sf ${TPCxAI_SCALE_FACTOR}"
		$CMD
	;;
	"serving")
		CMD="$PYTHON -u -m tpcxai-driver $ARGS --phase LOADING -v -sf ${TPCxAI_SCALE_FACTOR}"
		$CMD
		CMD="$PYTHON -u -m tpcxai-driver $ARGS $TPCxAI_UC_RESTRICT--phase SERVING -v -sf ${TPCxAI_SCALE_FACTOR}"
		$CMD
	;;
	"scoring")
		CMD="$PYTHON -u -m tpcxai-driver $ARGS $TPCxAI_UC_RESTRICT--phase SCORING -v -sf ${TPCxAI_SCALE_FACTOR}"
		$CMD
	;;
esac


######################## End time measurement ###################
SECONDS_END=$SECONDS
echo "End $SECONDS_END seconds"

DURATION=$((SECONDS_END-SECONDS_START))
echo "Duration $DURATION seconds"

######################## Show result files ###################
ls -lhR /tpcx-ai/output/model
#ls -lhR $PATH_OUTPUT
#ls -lhR $PATH_WORKDIR

######################## Show timing information ###################
echo "Generating done"

DATEANDTIME=$(date '+%d.%m.%Y %H:%M:%S');
echo "$DATEANDTIME"

SECONDS_END_SCRIPT=$SECONDS
DURATION_SCRIPT=$((SECONDS_END_SCRIPT-SECONDS_START_SCRIPT))
echo "Duration $DURATION_SCRIPT seconds"

######################## Exit successfully ###################
exit 0
