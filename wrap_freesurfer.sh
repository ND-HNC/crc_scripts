#!/bin/bash

function Usage {
    cat <<USAGE

    Run FreeSurfer for subjects found in rawdata T1w anat files and not
    freesurfer output.

    Wrapper of run_freesurfer.sh, logging files written to proj_dir/logs.
    Generate intermediates in work_dir, then send final output files
    to derivatives.

    Required environment:
        - HOSTNAME = *crc.nd.edu, for computing on ND CRC.

    proj_dir
    ├── logs
    │   └── preproc_freesurfer
    │       └── wrap_freesurfer.log
    ├── rawdata
    │   └── sub-A
    │       └── ses-1
    │           └── anat
    │               ├── sub-A_ses-1_T1w.nii.gz
    │               └── sub-A_ses-1_T1w.json
    └── derivatives
        └── freesurfer-8.2.0
            └── ses-1
                └── sub-A
                    ├── label
                    ├── mri
                    ..
                    └── touch

    Required arguments:
        -e <str> = BIDS session
        -p <str> = Location of BIDS-organized project directory
        -w <str> = Location of working directory

    Example Usage:
        ./wrap_freesurfer.sh \\
            -e ses-1 \\
            -p /path/to/proj_dir \\
            -w /path/to/work_dir

USAGE
}

# Default args
code_dir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit ; pwd -P )"

# Capture arguments
while getopts ":e:p:w:h" OPT; do
    case $OPT in
    e)
        sess=${OPTARG}
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

if [ -z "$FS_LICENSE" ]; then
    echo "ERROR: missing global FS_LICENSE" >&2
    Usage
    exit 1
fi

if ! command -v mri_convert >/dev/null 2>&1; then
    echo "ERROR: missing FreeSurfer in environment" >&2
    Usage
    exit 1
fi

# Check for BIDS
bids_raw="${proj_dir}/rawdata"
if [ ! -d "$bids_raw" ]; then
    echo "ERROR: failed to detect BIDS rawdata." >&2
    Usage
    exit 1
fi

# Make logging location
job_name=freesurfer
log_dir=${proj_dir}/logs/preproc_$job_name
[ ! -d "$log_dir" ] && mkdir -p "$log_dir"
log_out=${log_dir}/wrap_${job_name}.log

# shellcheck disable=SC2188
> "$log_out"

# Identify subjects needing FreeSurfer
subj_list=()
cd "${proj_dir}/rawdata" || exit 2
for subj in sub-*; do
    fs_in=${proj_dir}/rawdata/${subj}/${sess}/anat/${subj}_${sess}_T1w.nii.gz
    fs_out=${proj_dir}/derivatives/freesurfer-8.2.0/${sess}/${subj}/mri/aparc.a2009s+aseg.mgz
    if [ -f "$fs_in" ] && [ ! -f "$fs_out" ]; then
        subj_list+=("$subj")
    fi
done
cd "$code_dir" || exit 2

if [ ${#subj_list[@]} == 0 ]; then
    echo "No subjects detected needing FreeSurfer output, exiting ..."  >> "$log_out"
    exit 0
fi

# Submit array of jobs
echo "Found ${#subj_list[@]} subjects: ${subj_list[*]}" >> "$log_out"
qsub \
    -V \
    -N "$job_name" \
    -t 1-${#subj_list[@]} \
    -tc 15 \
    -o "${log_out}" \
    run_freesurfer.sh \
    -e "$sess" \
    -l "$log_dir" \
    -p "$proj_dir" \
    -w "$work_dir" \
    "${subj_list[@]}"