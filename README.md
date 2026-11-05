# crc_scripts

1. DICOM to BIDS
1. FreeSurfer
1. fMRIPrep



## DICOM to BIDS

## FreeSurfer

A FreeSurfer workflow is available for execution, coordinated by `cli_freesurfer.sh` and `resources/run_freesurfer.sh`. These scripts require `load_env.sh` to ensure proper environment building on scheduled nodes.

Basic workflow:

1. Find subjects in rawdata
2. Convert T1w to 001.mgz
3. Execute `recon-all`
4. Send output to derivatives

### User CLI

A user interface is available for running FreeSurfer at `cli_freesurfer.sh`. This script will check `rawdata` for subjects that:

- Have BIDS-organized T1w files, and
- Do not have FreeSurfer output in `derivatives`.

A FreeSurfer workflow will be submitted for each subject that meets these criteria. By default, the number of simultaneous jobs running will be limited to 15.

Input and final output data will be organized in the project directory specified (`-p`), and computing will occur in the working directory (`-w`). It is intended that the working directory to exist on a `scratch` partition, while the official project directory is stored somewhere more permanent. _Note:_ The subject working directory is deleted at the end of the worklfow.

Use `$ cli_freesurfer.sh` to print a help.

```{=bash}
$ ./cli_freesurfer.sh

Identify all subjects in proj_dir needing FreeSurfer, schedule FreeSurfer
job as QSUB array.

Wrapper of run_freesurfer.sh, logging files written to proj_dir/logs.
Generate intermediates in work_dir, then send final output files
to derivatives.

Required environment:
    - HOSTNAME = *crc.nd.edu, for computing on ND CRC.

Required arguments:
    -e <str>    BIDS session
    -p <str>    Location of BIDS-organized project directory
    -w <str>    Location of working directory

Optional arguments:
    -n <int>    Number of simultaneous array jobs (default=15).

Example Usage:
    ./cli_freesurfer.sh \
        -e ses-1 \
        -p /path/to/proj_dir \
        -w /path/to/work_dir

```

### Data Organization

- Input data: BIDS-organized rawdata `proj_dir/rawdata`.
- Output data:
  - FreeSurfer derivatives directory `proj_dir/derivatives/freesurfer`.
  - Pseudo-BIDS (subjects organized by session)
- Logging files: Written to `proj_dir/logs/preproc_freesurfer`.

```{=bash}
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
```

### Code Organization

```{=bash}
code_dir
├── resources
│   └── run_freesurfer.sh
├── load_env.sh
└── cli_freesurfer.sh
```

### Run script

The FreeSurfer workflow is organized by `resources/run_freesurfer.sh`.

```{=bash}
work_dir
└── freesurfer-8.2.0
    └── ses-1
        └── sub-A
            ├── label
            ├── mri
            ..
            └── touch

```

While generally wrapped by `cli_freesurfer.sh`, this script is executable independently and contains its own CLI. Use `$ run_freesurfer.sh` to print a help.

```{=bash}
$ ./run_freesurfer.sh

Run FreeSurfer for specified subjects and session as a QSUB array.

1. Read input data from: proj_dir/rawdata/sub-A/ses-1
2. Process intermediates in: work_dir/freesurfer/ses-1/sub-A
3. Write logs to: log_dir/sub-A_ses-1.{err,out}
4. Send final output to: proj_dir/derivatives/freesurfer-8.2.0/ses-1/sub-A
5. Clean work_dir

Required environment:
    - HOSTNAME = *crc.nd.edu, for computing on ND CRC.
    - SGE_TASK_ID = Set when submitted as array.

Notes:
    - Inverted subject, session in derivatives for FreeSurfer compatibility.

Required arguments:
    -e <str>    BIDS session
    -l <str>    Location of logging directory
    -p <str>    Location of BIDS-organize project directory
    -w <str>    Location of working directory
    -x <str>    Location of load_env.sh

Positional arguments:
    [<str>...]  BIDS subject IDs

Example Usage:
    qsub \
        -n fsarr \
        -t 1-3 \
        -tc 2 \
        -o out.log \
        run_freesurfer.sh \
        -e ses-1 \
        -l /path/to/logs \
        -p /path/to/proj_dir \
        -w /path/to/work_dir \
        -x /path/to/load_env.sh \
        sub-A sub-B sub-C

```