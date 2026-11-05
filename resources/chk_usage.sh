#!/bin/bash

function Usage {
    cat <<USAGE

    Check usage of HNC storage.

    Checking scratch and active spawns subprocesses, cold runs
    on the current node.

    Required arguments:
        -c [cold,scratch,active]    Specify location to index

    Optional arguments:
        -o <str>                    Output location (default=$HOME/usage_logs)

    Example Usage:
        ./chk_usage.sh -c cold
        ./chk_usage.sh -c scratch
        ./chk_usage.sh -c active

USAGE
}

# Set defaults
out_dir=/users/$(whoami)/usage_logs

# Capture arguments
while getopts ":c:o:h" OPT; do
    case $OPT in
    c)
        chk_name=${OPTARG}
        ;;
    o)
        out_dir=${OPTARG}
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

# Check req args
case $1 in
    -c)
        ;;
    -*)
        Usage
        echo "ERROR: missing required parameter" >&2
        exit 1
esac

# Orient
[ -d "$out_dir" ] || mkdir -p "$out_dir"
today=$(date +%F)

# Lazy control
if [ "$chk_name" == scratch ]; then
    out_scratch="$out_dir"/scratch_leadfs_hnc_"$today".log
    > "$out_scratch"
    qsub \
        -b y \
        -N chkScratch \
        -pe smp 1 \
        -q long \
        -o "$out_scratch" \
        -e "$out_scratch" \
        "du -sh /leadfs/hnc/*"
fi

if [ "$chk_name" == active ]; then
    out_active="$out_dir"/active_groups_hnc_"$today".log
    > "$out_active"
    qsub \
        -b y \
        -N chkActive \
        -pe smp 1 \
        -q long \
        -o "$out_active" \
        -e "$out_active" \
        "du -sh /groups/hnc/*"
fi

if [ "$chk_name" == cold ]; then
    out_cold="$out_dir"/cold_goldfs_hnc_"$today".log
    > "$out_cold"
    du -sh /goldfs/hnc/* > "$out_cold"
fi
