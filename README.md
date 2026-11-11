# crc_scripts

A common MRI workflow involves pre-processing anatomic and functional MRI data with standardized packages. These scripts are written for use on the Notre Dame compute cluster and provide a basic pipeline for use or reference.

1. [FreeSurfer](#freesurfer)
1. [fMRIPrep](#fmriprep)
1. AFNI- additional pre-processing

## FreeSurfer

A FreeSurfer workflow is available for execution, coordinated by `cli_freesurfer.sh` and `resources/run_freesurfer.sh`. These scripts require `load_env.sh` to ensure proper environment building on scheduled nodes.

Basic workflow:

1. Find subjects in rawdata
2. Convert T1w to 001.mgz
3. Execute `recon-all`
4. Send output to derivatives

Set [FS_LICENSE](https://surfer.nmr.mgh.harvard.edu/fswiki/License) in `load_env.sh`.

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

## fMRIPrep

An fMRIPrep workflow is available for execution, coordinated by `cli_fmriprep.sh` and `resources/run_fmriprep.sh`. These scripts require `load_env.sh` to ensure proper environment building on scheduled nodes.

Basic workflow:

1. Find subjects in rawdata
2. Check for pre-run FreeSurfer derivatives
3. Build and run fMRIPrep call
4. Send output to derivatives

fMRIPrep is executed via apptainer. This workflow references:

- singularity images at: `/leadfs/hnc/research_bin/sing_images`
- [templateflow](https://www.templateflow.org/) at: `/leadfs/hnc/research_bin/templateflow`

### User CLI

A user interface is available for running FreeSurfer at `cli_fmriprep.sh`. This script will check `rawdata` for subjects that:

- Have BIDS-organized anat and func files, and
- Do not have fMRIPrep output in `derivatives`.

An fMRIPrep workflow will be submitted for each subject that meets these criteria. By default, the number of simultaneous jobs running will be limited to 10.

Input and final output data will be organized in the project directory specified (`-p`), and computing will occur in the working directory (`-w`). It is intended that the working directory to exist on a `scratch` partition, while the official project directory is stored somewhere more permanent. _Note:_ The subject working directory is deleted at the end of the worklfow.

Use `$ cli_fmriprep.sh` to print a help.

```{=bash}
$ ./cli_fmriprep.sh

Identify all subjects in proj_dir needing fMRIPrep, schedule fMRIPrep
job as QSUB array.

Wrapper of run_fmriprep.sh, logging files written to proj_dir/logs.
Generate intermediates in work_dir, then send final output files
to derivatives.

Required environment:
    - HOSTNAME = *crc.nd.edu, for computing on ND CRC.

Required arguments:
    -e <str>    BIDS session
    -p <str>    Location of BIDS-organized project directory
    -w <str>    Location of working directory

Optional arguments:
    -n <int>    Number of simultaneous array jobs (default=10).

Example Usage:
    ./cli_fmriprep.sh \
        -e ses-1 \
        -p /leadfs/hnc/nmuncy/crc_test \
        -w /leadfs/hnc/nmuncy/crc_test/work_dir
```

### Data Organization

- Input data: BIDS-organized rawdata `proj_dir/rawdata`.
- Output data: Derivatives directory `proj_dir/derivatives/fmriprep`.
- Logging files: Written to `proj_dir/logs/preproc_fmriprep`.

```{=bash}
proj_dir
├── logs
│   └── preproc_fmriprep
│       └── wrap_fmriprep.log
├── rawdata
│   └── sub-A
│       ├── ses-1
│       │   ├── sub-A_ses-1_T1w.json
│       │   └── sub-A_ses-1_T1w.nii.gz
│       └── func
│           ├── sub-A_ses-1_task-rest_run-01_bold.json
│           └── sub-A_ses-1_task-rest_run-01_bold.nii.gz
└── derivatives
    ├── freesurfer-8.2.0
    └── fmriprep-25.2.7
        ├── sub-A_ses-1.html
        └── sub-A
           ├── figures
           └── ses-1
               ├── anat
               ├── func
               └── log
```

### Code Organization

```{=bash}
code_dir
├── resources
│   └── run_fmriprep.sh
├── load_env.sh
└── cli_fmriprep.sh
```

### Run script

The fMRIPrep workflow is organized by `resources/run_fmriprep.sh`.

```{=bash}
work_dir
├── sub-A.html
├── sub-A
│   ├── figures
│   └── ses-1
│       ├── anat
│       ├── func
│       └── log
└── fmriprep-25.2.7
    └── sub-A
       └── tmp_work
```

While generally wrapped by `cli_fmriprep.sh`, this script is executable independently and contains its own CLI. Use `$ run_fmriprep.sh` to print a help.

```{=bash}
$ ./run_fmriprep.sh

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
    qsub \
        -n fparr \
        -t 1-3 \
        -tc 2 \
        -o out.log \
        run_fmriprep.sh \
        -e ses-1 \
        -l /path/to/logs \
        -p /path/to/proj_dir \
        -w /path/to/work_dir \
        -x /path/to/load_env.sh \
        sub-A sub-B sub-C
```