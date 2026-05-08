#!/bin/bash

# FreeSurfer
echo "Loading FreeSurfer v8.2.0"
module load freesurfer/8.2.0
export SUBJECTS_DIR=""
FS_LICENSE=/users/$(whoami)/.ssh/FS_license.txt
export FS_LICENSE

export LD_LIBRARY_PATH=/software/l/lapack/3.12.1/gcc/lib64:$LD_LIBRARY_PATH

# TemplateFlow
TEMPLATEFLOW_HOME=/scratch365/$(whoami)/research_bin/templates/templateflow
export TEMPLATEFLOW_HOME
export TEMPLATE_DIR="$TEMPLATEFLOW_HOME/tpl-MNI152NLin2009cSym"

# FSL
echo "Loading FSL v6.0"
module load fsl/6.0

# Load conda