#!/bin/bash

src_dir=/leadfs/hnc/nmuncy/heud_test/srcdata
sub_name=Bidstest
subj=sub-A
sess=ses-1

subj_raw=/leadfs/hnc/nmuncy/heud_test/${subj}/$sess
# [ -d "$subj_raw" ] || mkdir -p "$subj_raw"

# Extract series description as string
get_series_desc() {
  local file="$1"
  local series_desc
  series_desc=$(
    dcmdump +P "0008,103e" "$file" 2>/dev/null | \
    sed -n 's/.*\[\(.*\)\].*/\1/p' | \
    head -n 1
  )

  if [[ -z "$series_desc" ]]; then
    echo "Unknown_Series"
  else
    echo "$series_desc"
  fi
}
export -f get_series_desc

# Extract image type echo ORIGINAL or DERIVED
get_orig_deriv() {
  local file="$1"
  local orig_deriv
  orig_deriv=$(
    dcmdump +P "0008,008" "$file" 2>/dev/null | \
    sed -n 's/.*\[\(.*\)\].*/\1/p' | \
    head -n 1 | \
    sed 's/\\/_/g'
  )

  if [[ -z "$orig_deriv" ]]; then
    echo "Unknown_Type"
  else
    echo "${orig_deriv%%_*}"
  fi
}
export -f get_orig_deriv

# Find first dcm in each dir
cd ${src_dir}/$sub_name
mapfile -t dcm_files < <(
  find . -type d -exec bash -c '
    for dir in "$@"; do
      first=$(find "$dir" -maxdepth 1 -type f -name "*.dcm" ! -name "._*" | head -n 1)
      [ -n "$first" ] && echo "$first"
    done
  ' bash {} +
)
# echo "${dcm_files[@]}"

# Identify original image type dirs
orig_data=()
for dcm_path in "${dcm_files[@]}"; do
    is_orig=$(get_orig_deriv $dcm_path)
    [ "$is_orig" == "ORIGINAL" ] && orig_data+=($(dirname "$dcm_path"))
done

# Only support anat, fmap, func, dwi
supp_type=(anat fmap func dwi)

# Convert original data
for orig_dir in "${orig_data[@]}"; do

    # ID data type
    first_dcm=$(find "$orig_dir" -maxdepth 1 -type f -name "*.dcm" ! -name "._*" | head -n 1)
    series_name=$(get_series_desc $first_dcm)
    series_type=${series_name%%_*}

    # Determine if data type is supported
    conv_data=0
    for chk_type in "${supp_type[@]}"; do
        if [[ "$chk_type" == "$series_type" ]]; then
            conv_data=1
            break
        fi
    done

    #
    [ "$conv_data" == 0 ] && continue
    # echo -e "$orig_dir \t $series_type \t $conv_data"

    # Split series name into useful fields
    IFS='_' read -r -a bids_info <<< "$series_name"
    # echo "${bids_info[0]} ${bids_info[1]} ${bids_info[2]} ${bids_info[3]}"

    # Make bids dir
    bids_dir=${subj_raw}/"${bids_info[0]}"
    # [ -d "$bids_dir" ] || mkdir -p "$bids_dir"

    # TODO: fix multiple T1w anats
    # TODO: fix func fmap


    #
    if [ "${bids_info[0]}" == "anat" ]; then
        bids_name=${subj}_${sess}_${bids_info[1]}
    elif [ "${bids_info[0]}" == "fmap" ]; then
        bids_name=${subj}_${sess}_${bids_info[2]}_${bids_info[1]}
    elif [ "${bids_info[0]}" == "func" ]; then
        bids_name=${subj}_${sess}_${bids_info[2]}_${bids_info[3]}_${bids_info[1]}
    elif [ "${bids_info[0]}" == "dwi" ]; then
        bids_name=${subj}_${sess}_${bids_info[1]}_${bids_info[0]}
    else
        echo "ERROR: unexpected data type"
        continue
    fi

    #
    echo "$series_name" "$bids_dir" "$bids_name"
    continue
    dcm2niix \
        -a y \
        -b y \
        -ba y \
        -i y \
        -f "$bids_name" \
        -o "$bids_dir" \
        -z y
done