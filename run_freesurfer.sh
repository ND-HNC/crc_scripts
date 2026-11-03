#!/bin/bash

#$ -pe smp 8
#$ -q long

function Usage {
    cat <<USAGE

    Run FreeSurfer for specified subjects and session as a QSUB array.

    1. Read input data from: proj_dir/rawdata/sub-A/ses-1
    2. Process intermediates in: work_dir/freesurfer/ses-1/sub-A
    3. Write logs to: log_dir/sub-A_ses-1.{err,out}
    4. Send final output to: proj_dir/derivatives/freesurfer-8.2.0/ses-1/sub-A
    5. Clean work_dir

    Required environment:
        - HOSTNAME = *crc.nd.edu, for computing on ND CRC.
        - SGE_TASK_ID = Set when submitted as array.
        - Module = freesurfer/$VER_FREESURFER
        - Data structure - BIDS organization (see below).

    Notes:
        - Inverted subject, session in derivatives for FreeSurfer compatibility.

    proj_dir
    ├── logs
    │   └── preproc_freesurfer
    │       ├── sub-A_ses-1.out
    │       └── sub-A_ses-1.err
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

    work_dir
    └── freesurfer-8.2.0
        └── ses-1
            └── sub-A
                ├── label
                ├── mri
                ..
                └── touch

    Required arguments:
        -e <str> = BIDS session
        -l <str> = Location of logging directory
        -p <str> = Location of BIDS-organize project directory
        -w <str> = Location of working directory
        -x <str> = Location of load_env.sh
        <subject array> = Positional args of BIDS subject IDs

    Example Usage:
        qsub \\
            -n fsarr \\
            -t 1-3 \\
            -tc 2 \\
            -o out.log \\
            run_freesurfer.sh \\
            -e ses-1 \\
            -l /path/to/logs \\
            -p /path/to/proj_dir \\
            -w /path/to/work_dir \\
            -x /path/to/load_env.sh \\
            sub-A sub-B sub-C

USAGE
}

# Capture arguments
while getopts ":e:l:p:w:x:h" OPT; do
    case $OPT in
    e)
        sess=${OPTARG}
        ;;
    l)
        log_dir=${OPTARG}
        if [ ! -d "$log_dir" ]; then
            echo -e "ERROR: $log_dir not found or is not a directory." >&2
            Usage
            exit 1
        fi
        ;;
    p)
        proj_dir=${OPTARG}
        ;;
    w)
        work_dir=${OPTARG}
        ;;
    x)
        env_script=${OPTARG}
        if [ ! -f "$env_script" ]; then
            echo -e "ERROR: $env_script not found." >&2
            Usage
            exit 1
        fi
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

# Capture subject list as array
shift 10
subj_list=( "$@" )

# Provide help for no options
if [ $OPTIND == 1 ]; then
    Usage
    exit 0
fi

# Check for required named parameters
case $1 in
    -e|-l|-p|-s|-w|-x)
        ;;
    -*)
        echo "ERROR: missing required parameter" >&2
        Usage
        exit 1
esac

# Verify CRC, array
if [[ $HOSTNAME != *"crc.nd.edu" ]]; then
    echo "ERROR: please execute on Notre Dame compute cluster." >&2
    Usage
    exit 1
fi

if [ -z "$SGE_TASK_ID" ]; then
    echo "ERROR: please submit $0 as qsub array" >&2
    Usage
    exit 1
fi

# Trigger project environment
# shellcheck disable=SC1090
. "$env_script"

# Verify project env
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

# Identify subject, specify STDOUT/ERR
subj=${subj_list[$SGE_TASK_ID-1]}
log_out=${log_dir}/${subj}_${sess}.out
log_err=${log_dir}/${subj}_${sess}.err

# shellcheck disable=SC2188
> "$log_out"
# shellcheck disable=SC2188
> "$log_err"

# Find rawdata, make work & derivatives
subj_raw=${proj_dir}/rawdata/${subj}/$sess
subj_deriv=${proj_dir}/derivatives/freesurfer-${VER_FREESURFER}/${sess}/$subj
subj_work=${work_dir}/freesurfer/${sess}/$subj
orig_dir=${subj_work}/mri/orig

[ -d "$subj_deriv" ] || mkdir -p "$subj_deriv"
[ -d "$orig_dir" ] || mkdir -p "$orig_dir"

# Verify no output
chk_fs=${subj_deriv}/mri/aparc.a2009s+aseg.mgz
if [ -f "$chk_fs" ]; then
    echo "FreeSurfer output detected: $chk_fs" >> "$log_out"
    exit 0
fi

# Verify input data
subj_anat=${subj_raw}/anat/${subj}_${sess}_T1w.nii.gz
if [ ! -f "$subj_anat" ]; then
    echo "ERROR: expected $subj_anat" >> "$log_err"
    exit 1
fi

# Start with 001.mgz
mri_convert "$subj_anat" "${orig_dir}/001.mgz" | tee -a "$log_out"
if [ ! -f "${orig_dir}/001.mgz" ]; then
    echo "ERROR: mri_convert failed" >> "$log_err"
    exit 1
fi

# Run FreeSurfer
recon-all \
    -subjid "$subj" \
    -all \
    -sd "$(dirname "$subj_work")" \
    -parallel \
    -openmp 6 \
    | tee -a "$log_out"
if [ ! -f "${subj_work}/mri/aparc.a2009s+aseg.mgz" ]; then
    echo "ERROR: recon-all failed" >> "$log_err"
    exit 1
fi

# Move and clean
sess_deriv="$(dirname "$subj_deriv")"
cp -r "$subj_work" "$sess_deriv"
if [ ! -f "$chk_fs" ]; then
    echo "ERROR: FreeSurfer copy failed" >> "$log_err"
    exit 1
fi
rm -r "$subj_work"
