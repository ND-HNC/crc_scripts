#!/bin/bash

function Usage {
    cat <<USAGE

    Identify all subjects in proj_dir needing fMRIPrep, schedule fMRIPrep
    job as QSUB array.

    Wrapper of run_fmriprep.sh, logging files written to proj_dir/logs.
    Generate intermediates in work_dir, then send final output files
    to derivatives.

    Required environment:
        - HOSTNAME = *crc.nd.edu, for computing on ND CRC.
        - load_env.sh in same directory as this file:
            crc_scripts
            ├── load_env.sh
            ├── run_fmriprep.sh
            └── wrap_fmriprep.sh

    Required arguments:
        -e <str>    BIDS session
        -f <str>    Location of FreeSurfer derivatives
        -p <str>    Location of BIDS-organized project directory
        -w <str>    Location of working directory

    Optional arguments:
        -n <int>    Number of simultaneous array jobs (default=10).

    Example Usage:
        ./wrap_fmriprep.sh \\
            -e ses-1 \\
            -p /path/to/proj_dir \\
            -w /path/to/work_dir

USAGE
}

# Default args
num_simul=10

# Capture arguments
while getopts ":e:n:p:w:h" OPT; do
    case $OPT in
    e)
        sess=${OPTARG}
        ;;
    n)
        num_simul=${OPTARG}
        ;;
    p)
        proj_dir=${OPTARG}
        ;;
    w)
        work_dir=${OPTARG}
        ;;
    h)
        Usage
        exit 0
        ;;
    :)
        echo -e "ERROR: option '$OPTARG' missing argument." >&2
        Usage
        exit 1
        ;;
    \?)
        echo -e "ERROR: invalid option '$OPTARG'." >&2
        Usage
        exit 1
        ;;
    esac
done

# Provide help for no options
if [ $OPTIND == 1 ]; then
    Usage
    exit 0
fi

# Check for required named parameters
case $1 in
    -e|-f|-p|-w)
        ;;
    -*)
        echo "ERROR: missing required parameter" >&2
        Usage
        exit 1
esac

# Verify cluster environment
if [[ $HOSTNAME != *"crc.nd.edu" ]]; then
    echo "ERROR: please execute on Notre Dame compute cluster." >&2
    Usage
    exit 1
fi

# Identify environment load script
code_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )"
env_script="$code_dir"/load_env.sh
if [ ! -f "$env_script" ]; then
    echo "ERROR: failed to detect environment script." >&2
    Usage
    exit 1
fi

# Check for BIDS
bids_raw="$proj_dir"/rawdata
if [ ! -d "$bids_raw" ]; then
    echo "ERROR: failed to detect BIDS rawdata. $bids_raw" >&2
    Usage
    exit 1
fi

# Make logging location
job_name=fmriprep
log_dir=${proj_dir}/logs/preproc_$job_name
[ ! -d "$log_dir" ] && mkdir -p "$log_dir"
log_out=${log_dir}/wrap_${job_name}.log

# shellcheck disable=SC2188
> "$log_out"

# # Identify subjects needing fMRIPrep
subj_list=(sub-38285)
# subj_list=()
# cd "${proj_dir}/rawdata" || exit 2
# for subj in sub-*; do
#     fp_in=${proj_dir}/rawdata/${subj}/${sess}/func/${subj}_${sess}_T1w.nii.gz
#     # fp_out=${proj_dir}/derivatives/fmriprep-25.2.7/${subj}/${sess}/
#     if [ -f "$fp_in" ] && [ ! -f "$fp_out" ]; then
#         subj_list+=("$subj")
#     fi
# done
# cd "$code_dir" || exit 2

if [ ${#subj_list[@]} == 0 ]; then
    echo "No subjects detected needing fMRIPrep output, exiting ..."  >> "$log_out"
    exit 0
fi

# Submit array of jobs
echo "Found ${#subj_list[@]} subjects: ${subj_list[*]}" >> "$log_out"
qsub \
    -V \
    -N "$job_name" \
    -t 1-${#subj_list[@]} \
    -tc "$num_simul" \
    -o "${log_out}" \
    run_fmriprep.sh \
    -e "$sess" \
    -l "$log_dir" \
    -p "$proj_dir" \
    -w "$work_dir" \
    -x "$env_script" \
    "${subj_list[@]}"