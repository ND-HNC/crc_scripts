#!/bin/bash

#!/bin/bash

#$ -pe smp 8
#$ -q long

function Usage {
    cat <<USAGE


    Required environment:

    Notes:


    Required arguments:

        -e <str> = BIDS session
        -l <str> = Location of logging directory
        -p <str> = Location of BIDS-organize project directory
        -x <str> = Location of load_env.sh
        <subject array> = Positional args of BIDS subject IDs

    Example Usage:
        qsub \\
            -n sheu \\
            -o out.log \\
            run_dcmbids.sh \\
            -s srcID \\
            -b sub-A \\
            -e ses-1 \\
            -l /path/to/logs \\
            -p /path/to/proj_dir \\
            -x /path/to/load_env.sh

USAGE
}

# Capture arguments
while getopts ":b:e:l:p:x:h" OPT; do
    case $OPT in
    b)
        subj=${OPTARG}
        ;;
    e)
        sess=${OPTARG}
        ;;
    l)
        log_dir=${OPTARG}
        if [ ! -d "$log_dir" ]; then
            Usage
            echo -e "ERROR: $log_dir not found or is not a directory." >&2
            exit 1
        fi
        ;;
    p)
        proj_dir=${OPTARG}
        ;;
    s)
        src_name=${OPTARG}
        ;;
    x)
        env_script=${OPTARG}
        if [ ! -f "$env_script" ]; then
            Usage
            echo -e "ERROR: $env_script not found." >&2
            exit 1
        fi
        ;;
    h)
        Usage
        exit 0
        ;;
    :)
        Usage
        echo -e "ERROR: option '$OPTARG' missing argument." >&2
        exit 1
        ;;
    \?)
        Usage
        echo -e "ERROR: invalid option '$OPTARG'." >&2
        exit 1
        ;;
    esac
done

# Capture subject list as array
shift 12
subj_list=( "$@" )

# Provide help for no options
if [ $OPTIND == 1 ]; then
    Usage
    exit 0
fi

# Check for required named parameters
case $1 in
    -b|-e|-l|-p|-s|-x)
        ;;
    -*)
        Usage
        echo "ERROR: missing required parameter" >&2
        exit 1
esac

# Verify CRC, array
if [[ $HOSTNAME != *"crc.nd.edu" ]]; then
    Usage
    echo "ERROR: please execute on Notre Dame compute cluster." >&2
    exit 1
fi

if [ -z "$SGE_TASK_ID" ]; then
    Usage
    echo "ERROR: please submit $0 as qsub array" >&2
    exit 1
fi

# Trigger project environment
# shellcheck disable=SC1090
. "$env_script"

# Verify project env
if [ -z "$SING_HEUDICONV" ]; then
    Usage
    echo "ERROR: missing global SING_HEUDICONV" >&2
    exit 1
fi

if [ ! -f "$SING_HEUDICONV" ]; then
    Usage
    echo "ERROR: expected $SING_HEUDICONV" >&2
    exit 1
fi

if ! command -v apptainer >/dev/null 2>&1; then
    Usage
    echo "ERROR: missing apptainer in environment" >&2
    exit 1
fi

# Communicate
cat <<EOF

SRC Name    $src_name
BIDS Name   $subj
BIDS Sess   $sess
BIDS Dir    $proj_dir
Logging     $log_dir

EOF


# Identify subject, specify STDOUT/ERR
subj=${subj_list[$SGE_TASK_ID-1]}
log_out=${log_dir}/${subj}_${sess}.out
log_err=${log_dir}/${subj}_${sess}.err

# shellcheck disable=SC2188
> "$log_out"
# shellcheck disable=SC2188
> "$log_err"

# Find srcdata and start rawdata
subj_src="$proj_dir"/srcdata/"$src_name"
raw_dir="$proj_dir"/rawdata
[ -d "$raw_dir" ] || mkdir -p "$raw_dir"

# Verify no output


# Verify input data
subj_anat=${subj_raw}/anat/${subj}_${sess}_T1w.nii.gz
if [ ! -f "$subj_anat" ]; then
    echo "ERROR: expected $subj_anat" >> "$log_err"
    exit 1
fi

# # Generate skeleton
# apptainer run --cleanenv \
#     --bind /leadfs/hnc/nmuncy/crc_test:/leadfs/hnc/nmuncy/crc_test \
#     "$SING_HEUDICONV" \
#     --files /leadfs/hnc/nmuncy/heud_test/srcdata/TESTJW/*/*.dcm \
#     -o /leadfs/hnc/nmuncy/heud_test/rawdata \
#     -f convertall \
#     -s 1234 \
#     -ss A \
#     -c none


