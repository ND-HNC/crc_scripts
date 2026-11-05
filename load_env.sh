#!/bin/bash

# Local orienting vars
res_bin=/leadfs/hnc/research_bin
tpl_bin=${res_bin}/templateflow
sim_bin="$res_bin"/sing_images

# Heudiconv
export VER_HEUDICONV=1.5.1
echo "Loading HeuDiconv v$VER_HEUDICONV"
export SING_HEUDICONV="$sim_bin"/heudiconv-"$VER_HEUDICONV".simg

# FreeSurfer
export VER_FREESURFER=8.2.0
echo "Loading FreeSurfer v$VER_FREESURFER"
module load freesurfer/"$VER_FREESURFER"
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
TEMPLATEFLOW_HOME="$tpl_bin"
export TEMPLATEFLOW_HOME
export TEMPLATE_DIR="$TEMPLATEFLOW_HOME/tpl-MNI152NLin2009cSym"

# fMRIPrep
export VER_FMRIPREP=25.2.7
echo "Loading fMRIPrep v$VER_FMRIPREP"
export SING_FMRIPREP="$sim_bin"/fmriprep-"$VER_FMRIPREP".simg

# FSL
export VER_FSL=6.0
echo "Loading FSL v$VER_FSL"
module load fsl/"$VER_FSL"

# PATH
echo "Orienting to research binaries"
PATH="$PATH":\
"$res_bin":"$res_bin"/software:\
"$res_bin"/software/dcmtk-3.7.1-linux-x86_64/bin

export PATH