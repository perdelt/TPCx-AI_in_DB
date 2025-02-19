#!/bin/bash
######################################################################################
# Bash script for TPCx-AI supplements - Data generator
######################################################################################
# Script Name:    generator.sh
# Description:    This script calls ./bin/tpcxai.sh of the TPCx-AI toolkit to generate data (training, serving, scoring) into /tpcx-ai/output/raw_data/
# Author:         Patrick K. Erdelt
# Email:          patrick.erdelt@bht-berlin.de
# Date:           2024-05-26
# Version:        1.0
# Important environment variables:
# TPCxAI_SCALE_FACTOR: Scaling factor, size of data approx. in GB (default 1)
# `TPCxAI_NODE_COUNT`: Total number of parallel containers for data generation (default 1) **currently not used**
# `TPCxAI_NODE_NUMBER`: Number of the current container in a set of parallel containers (default 1) **currently not used**
# `TPCxAI_SEED`: Random seed for data generation (default 1234 as set in the Python part of the toolkit) **currently not used**
# currently not implemented:
#In order to scale horizontally, generation can be split into `TPCxAI_NODE_COUNT` number of processes.
#The parameter `TPCxAI_NODE_NUMBER` sets which part of these parts the container should generate.
######################################################################################


######################## Start timing ########################
DATEANDTIME=$(date '+%d.%m.%Y %H:%M:%S');
echo "$DATEANDTIME"
SECONDS_START_SCRIPT=$SECONDS

######################## Show general parameters ########################
echo "TPCxAI_SCALE_FACTOR:$TPCxAI_SCALE_FACTOR"
echo "TPCxAI_NODE_COUNT:$TPCxAI_NODE_COUNT"
echo "TPCxAI_NODE_NUMBER:$TPCxAI_NODE_NUMBER"
echo "TPCxAI_SEED:$TPCxAI_SEED"

#TPCxAI_SEED_TRAIN=$((TPCxAI_SEED))
#TPCxAI_SEED_SERVE=$((TPCxAI_SEED+1))
#TPCxAI_SEED_SCORE=$((TPCxAI_SEED+2))
#echo "TPCxAI_SEED_TRAIN:$TPCxAI_SEED_TRAIN"
#echo "TPCxAI_SEED_SERVE:$TPCxAI_SEED_SERVE"
#echo "TPCxAI_SEED_SCORE:$TPCxAI_SEED_SCORE"

FINAL_PATH_DATA=/data/tpcxai/SF$TPCxAI_SCALE_FACTOR
# generating several parts independently is not supported (?)
#FINAL_PATH_DATA=/data/tpcxai/SF$TPCxAI_SCALE_FACTOR/$TPCxAI_NODE_COUNT/$TPCxAI_NODE_NUMBER
echo "FINAL_PATH_DATA:$FINAL_PATH_DATA"

######################## Execute workload ###################
echo IS_EULA_ACCEPTED=true >> /tpcx-ai/data-gen/Constants.properties
echo IS_EULA_ACCEPTED=true >> /tpcx-ai/lib/pdgf/Constants.properties
#cd /tpcx-ai/lib/pdgf/
cd /tpcx-ai/

# show help for options
# java -cp "/tpcx-ai/lib/pdgf/*" -Djava.awt.headless=true -jar pdgf.jar -help

export TPCx_AI_HOME_DIR=/tpcx-ai
# The absolute path to the configuration file used to run the validation test
export TPCxAI_VALIDATION_CONFIG_FILE_PATH=${TPCx_AI_HOME_DIR}/driver/config/default.yaml
# The absolute path to the configuration file used for the benchmark run
export TPCxAI_BENCHMARKRUN_CONFIG_FILE_PATH=${TPCx_AI_HOME_DIR}/driver/config/default.yaml
export TPCxAI_CONFIG_FILE_PATH=${TPCxAI_BENCHMARKRUN_CONFIG_FILE_PATH}
export MY_SEED=${TPCxAI_SEED}
MY_SEED=$TPCxAI_SEED

./bin/tpcxai.sh --phase {CLEAN,DATA_GENERATION,SCORING_DATAGEN} -sf ${TPCxAI_SCALE_FACTOR} -c ${TPCxAI_CONFIG_FILE_PATH} ${VFLAG}

# these give not the correct sizes as they are adjusted by the toolkit Python scrips
# training data
#time java -cp "/tpcx-ai/lib/pdgf/*" -Djava.awt.headless=true -jar pdgf.jar -l /tpcx-ai/data-gen/config/tpcxai-schema.xml -l /tpcx-ai/data-gen/config/tpcxai-generation.xml -output '"/tpcx-ai/lib/pdgf/output/SF'"$TPCxAI_SCALE_FACTOR"'/training/"' -sp includeLabels 1.0 -sp TTVF 1.0 -nn "$TPCxAI_NODE_NUMBER" -nc "$TPCxAI_NODE_COUNT" -ns -s -sf "$TPCxAI_SCALE_FACTOR" -sp MY_SEED "$TPCxAI_SEED_TRAIN"
# serving data
#time java -cp "/tpcx-ai/lib/pdgf/*" -Djava.awt.headless=true -jar pdgf.jar -l /tpcx-ai/data-gen/config/tpcxai-schema.xml -l /tpcx-ai/data-gen/config/tpcxai-generation.xml -output '"/tpcx-ai/lib/pdgf/output/SF'"$TPCxAI_SCALE_FACTOR"'/serving/"' -sp includeLabels 0.0 -sp TTVF 0.1 -nn "$TPCxAI_NODE_NUMBER" -nc "$TPCxAI_NODE_COUNT" -ns -s -sf "$TPCxAI_SCALE_FACTOR" -sp MY_SEED "$TPCxAI_SEED_SERVE"
# scoring data
#time java -cp "/tpcx-ai/lib/pdgf/*" -Djava.awt.headless=true -jar pdgf.jar -l /tpcx-ai/data-gen/config/tpcxai-schema.xml -l /tpcx-ai/data-gen/config/tpcxai-generation.xml -output '"/tpcx-ai/lib/pdgf/output/SF'"$TPCxAI_SCALE_FACTOR"'/scoring/"' -sp includeLabels 2.0 -sp TTVF 0.1 -nn "$TPCxAI_NODE_NUMBER" -nc "$TPCxAI_NODE_COUNT" -ns -s -sf "$TPCxAI_SCALE_FACTOR" -sp MY_SEED "$TPCxAI_SEED_SCORE"

######################## Move Files ###################
#mv -r /tpcx-ai/output/raw_data $FINAL_PATH_DATA
SRC=/tpcx-ai/output/raw_data
DEST=$FINAL_PATH_DATA

# Ensure source folder exists
if [ ! -d "$SRC" ]; then
    echo "Error: Source folder '$SRC' does not exist!"
    exit 1
fi

# Ensure destination folder exists, or create it
if [ ! -d "$DEST" ]; then
    echo "Creating destination folder '$DEST'..."
    mkdir -p "$DEST"
fi

# Move all files, including hidden ones
echo "Moving files from '$SRC' to '$DEST'..."
mv "$SRC"/* "$DEST" 2>/dev/null
# issues with moving . and ..
#mv "$SRC"/* "$SRC"/.* "$DEST" 2>/dev/null

# Check if the move was successful
if [ $? -eq 0 ]; then
    echo "Files moved successfully!"
else
    echo "Warning: Some files may not have been moved."
fi

echo "Done!"


######################## End time measurement ###################
SECONDS_END=$SECONDS
echo "End $SECONDS_END seconds"

DURATION=$((SECONDS_END-SECONDS_START))
echo "Duration $DURATION seconds"

######################## Show result files ###################
# ls -lhR /tpcx-ai/lib/pdgf/output

######################## Show timing information ###################
echo "Generating done"

DATEANDTIME=$(date '+%d.%m.%Y %H:%M:%S');
echo "$DATEANDTIME"

SECONDS_END_SCRIPT=$SECONDS
DURATION_SCRIPT=$((SECONDS_END_SCRIPT-SECONDS_START_SCRIPT))
echo "Duration $DURATION_SCRIPT seconds"

######################## Exit successfully ###################
exit 0
