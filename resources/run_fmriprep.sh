#!/bin/bash

#$ -pe smp 10
#$ -q long

function Usage {
    cat <<USAGE

    Run fMRIPrep for specified subjects and sessions as a QSUB array.

    1. Read input data from: proj_dir/rawdata/sub-A/ses-1
    2. Check for FreeSurfer output in proj_dir/derivatives/freesurfer/ses-1/sub-A
    3. Process intermediates in: work_dir/fmriprep/sub-A/ses-1
    3. Write logs to: log_dir/sub-A_ses-1.{err,out}
    4. Send final output to: proj_dir/derivatives/fmriprep/sub-A/ses-1
    5. Clean work_dir

    Required environment:
        - HOSTNAME = *crc.nd.edu, for computing on ND CRC.
        - SGE_TASK_ID = Set when submitted as array.
        - apptainer executable in env.
        - Data structure - BIDS organization (see below).

    Required named arguments:
        -e <str>    BIDS session
        -l <str>    Location of logging directory
        -p <str>    Location of BIDS-organize project directory
        -w <str>    Location of working directory
        -x <str>    Location of load_env.sh

    Optional arguments:
        -d <float>  Framewise displacement threshold (default=0.5)
        -f <str>    TemplateFlow template name (default=MNI152NLin6Asym)
        -n <int>    Number of dummy volumes to skip (default=0)
        -r <float>  Output func resolution (default=2.0)
        -t <str>    BIDS task name (default=task-rest)

    Positional arguments:
        [<str>...]     BIDS subject IDs

    Example Usage:
        qsub \\
            -n fparr \\
            -t 1-3 \\
            -tc 2 \\
            -o out.log \\
            run_fmriprep.sh \\
            -e ses-1 \\
            -l /path/to/logs \\
            -p /path/to/proj_dir \\
            -w /path/to/work_dir \\
            -x /path/to/load_env.sh \\
            sub-A sub-B sub-C

USAGE
}
if [[ $# -eq 0 ]]; then
    Usage
    exit 0
fi

# Prep for req validation
unset cnt_reqs
declare -i cnt_reqs=0

# Set defaults
fd_thresh=0.5
out_res=2.0
tpl_name=MNI152NLin6Asym
num_dummy=0
task=task-rest

# Catch positionals
subj_list=()

# Capture arguments
while [[ $# -gt 0 ]]; do
    case "$1" in

        # Required args
        -e)
            # if [[ -z "${2:-}" ]]; then
            #     Usage
            #     echo "ERROR: $1 requires a non-empty argument." >&2
            #     exit 1
            # fi
            sess="$2"
            ((cnt_reqs++))
            shift 2
            ;;
        -l)
            log_dir="$2"
            if [ ! -d "$log_dir" ]; then
                Usage
                echo -e "ERROR: $log_dir not found or is not a directory." >&2
                exit 1
            fi
            ((cnt_reqs++))
            shift 2
            ;;
        -p)
            proj_dir="$2"
            if [ ! -d "$proj_dir" ]; then
                Usage
                echo -e "ERROR: $proj_dir not found or is not a directory." >&2
                exit 1
            fi
            cnt_reqs+=1
            shift 2
            ;;
        -w)
            work_dir="$2"
            ((cnt_reqs++))
            shift 2
            ;;
        -x)
            env_script="$2"
            if [ ! -f "$env_script" ]; then
                Usage
                echo -e "ERROR: $env_script not found." >&2
                exit 1
            fi
            ((cnt_reqs++))
            shift 2
            ;;

        # Optional args
        -d)
            fd_thresh="$2"
            shift 2
            ;;
        -f)
            tpl_name="$2"
            shift 2
            ;;
        -n)
            num_dummy="$2"
            shift 2
            ;;
        -r)
            out_res="$2"
            shift 2
            ;;
        -t)
            task="$2"
            shift 2
            ;;
        -h)
            Usage
            exit 0
            ;;

        # Positional
        *)
            subj_list+=($1)
            shift 1
            ;;

        # Control
        --)
            shift
            break
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
if [[ $# -gt 0 ]]; then
    subj_list+=("$@")
fi

# Check for required named parameters
if [ "$cnt_reqs" != 5 ]; then
    Usage
    echo "ERROR: missing required arguments" >&2
    exit 1
fi
if [ "${#subj_list[@]}" -eq 0 ]; then
    Usage
    echo "ERROR: missing positional subject IDs" >&2
    exit 1
fi

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
if [ -z "$SING_FMRIPREP" ]; then
    echo "ERROR: missing global SING_FMRIPREP" >&2
    Usage
    exit 1
fi

if [ ! -f "$SING_FMRIPREP" ]; then
    echo "ERROR: expected $SING_FMRIPREP" >&2
    Usage
    exit 1
fi

if ! command -v apptainer >/dev/null 2>&1; then
    echo "ERROR: missing apptainer in environment" >&2
    Usage
    exit 1
fi

if [ -z "$FS_LICENSE" ]; then
    echo "ERROR: missing global FS_LICENSE" >&2
    Usage
    exit 1
fi

# Communicate
cat <<EOF

Session     $sess
Logging     $log_dir
Project     $proj_dir
Work        $work_dir
FD          $fd_thresh
TPL         $tpl_name
Dummy       $num_dummy
Res         $out_res
Task        $task
Subjs       "${subj_list[@]}"

EOF

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
subj_deriv=${proj_dir}/derivatives/fmriprep-"$VER_FMRIPREP"/$subj
subj_work=${work_dir}/fmriprep-"$VER_FMRIPREP"/$subj

[ -d "$subj_deriv" ] || mkdir -p "$subj_deriv"
[ -d "$subj_work" ] || mkdir -p "$subj_work"

# Check for untransferred work, organize
chk_file=${subj}/${sess}/anat/${subj}_${sess}_desc-preproc_T1w.nii.gz
chk_work_html=${work_dir}/${subj}.html
chk_work_anat=${work_dir}/$chk_file

if [ -f "$chk_work_html" ] && [ -f "$chk_work_anat" ]; then
    mv ${work_dir}/${subj}/$sess "$subj_deriv"
    mv ${work_dir}/${subj}/figures "$subj_deriv"
    mv ${work_dir}/${subj}.html ${proj_dir}/derivatives/fmriprep-"$VER_FMRIPREP"/${subj}_${sess}.html
fi

# Check for existing output
chk_deriv_html=${proj_dir}/derivatives/fmriprep-"$VER_FMRIPREP"/${subj}_${sess}.html
chk_deriv_anat=${proj_dir}/derivatives/fmriprep-"$VER_FMRIPREP"/$chk_file

if [ -f "$chk_deriv_html" ] && [ -f "$chk_deriv_anat" ]; then
    [ -d "$subj_work" ] && rm -r "$subj_work"
    echo "fMRIPrep output exists for $subj, $sess."
    exit 0
fi

# Find input
subj_anat=${subj_raw}/anat/${subj}_${sess}_T1w.nii.gz
if [ ! -f "$subj_anat" ]; then
    echo "ERROR: expected $subj_anat" >> "$log_err"
    exit 1
fi
cnt_func=0
subj_func=${subj_raw}/func/${subj}_${sess}_${task}*.nii.gz
cnt_func=$(ls $subj_func | wc -l)
if [ "$cnt_func" -eq 0 ]; then
    echo "ERROR: expected $subj_func" >> "$log_err"
    exit 1
fi

# Check for FreeSurfer output
has_fs=""
fs_deriv=${proj_dir}/derivatives/freesurfer-${VER_FREESURFER}/$sess
[ -f "$fs_deriv"/"$subj"/mri/aparc.a2009s+aseg.mgz ] && has_fs=1

# Apptainer options
bind_opts=(
    --bind "$proj_dir":"$proj_dir"
    --bind "$work_dir":"$work_dir"
    --bind "$proj_dir"/rawdata:/data
    --bind "$work_dir":/out
)

# fMRIPrep options
# --ignore fieldmaps
# --use-aroma
fmriprep_opts=(
    --work-dir "$subj_work"/tmp_work/$subj
    --participant-label ${subj#*-}
    --skull-strip-template "$tpl_name"
    --output-spaces "$tpl_name":res-"$out_res" anat
    --fs-license "$FS_LICENSE"
    --fd-spike-threshold "$fd_thresh"
    --skip-bids-validation
    --bids-database-dir "$subj_work"/tmp_work/"$subj"/bids_layout
    --nprocs 10
    --omp-nthreads 8
    --stop-on-first-crash
    --debug all
    --notrack
)

# Manage options
if [ ! -z "$has_fs" ]; then
    fmriprep_opts+=(--fs-subjects-dir "$fs_deriv")
fi

if [ "$num_dummy" -gt 0 ]; then
    fmriprep_opts+=(--dummy-scans "$num_dummy")
fi

cat <<EOF

Executing: apptainer run --cleanenv \\
    ${bind_opts[@]} \\
    $SING_FMRIPREP /data /out participant \\
    ${fmriprep_opts[@]}

EOF

# Run fMRIPrep
apptainer run --cleanenv \
    "${bind_opts[@]}" \
    "$SING_FMRIPREP" /data /out participant \
    "${fmriprep_opts[@]}"


# Send work to derivatives
if [ -f "$chk_work_html" ] && [ -f "$chk_work_anat" ]; then
    mv ${work_dir}/${subj}/$sess "$subj_deriv"
    mv ${work_dir}/${subj}/figures "$subj_deriv"
    mv ${work_dir}/${subj}.html ${proj_dir}/derivatives/fmriprep-"$VER_FMRIPREP"/${subj}_${sess}.html
fi

# Verify output
if [ -f "$chk_deriv_html" ] && [ -f "$chk_deriv_anat" ]; then
    [ -d "$subj_work" ] && rm -r "$subj_work"
    echo "Success! fMRIPrep output exists for $subj, $sess."
else
    echo "ERROR: expected $chk_deriv_anat"
    exit 1
fi