#!/bin/bash

# FreeSurfer
echo "Loading FreeSurfer v8.2.0"
module load freesurfer/8.2.0
export SUBJECTS_DIR=""
FS_LICENSE=/users/$(whoami)/.ssh/FS_license.txt
if [ -f "$FS_LICENSE" ]; then
    export FS_LICENSE
else
    echo "ERROR: failed to find $FS_LICENSE"
    exit 1
fi

export LD_LIBRARY_PATH=/software/l/lapack/3.12.1/gcc/lib64:$LD_LIBRARY_PATH

# TemplateFlow
TEMPLATEFLOW_HOME=/leadfs/hnc/research_bin/templates/templateflow
export TEMPLATEFLOW_HOME
export TEMPLATE_DIR="$TEMPLATEFLOW_HOME/tpl-MNI152NLin2009cSym"

# fMRIPrep
echo "Loading fMRIPrep v25.2.7"
export SING_FMRIPREP=/leadfs/hnc/research_bin/sing_images/fmriprep-25.2.7.simg

# FSL
echo "Loading FSL v6.0"
module load fsl/6.0
