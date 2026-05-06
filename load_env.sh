#!/bin/bash

# FreeSurfer
echo "Loading FreeSurfer v8.2.0"
module load freesurfer/8.2.0
export FS_LICENSE=""

# TemplateFlow
export TEMPLATEFLOW_HOME=""
export TEMPLATE_DIR="$TEMPLATEFLOW_HOME/FOO"

# FSL
echo "Loading FSL v6.0"
module load fsl/6.0

# Load conda