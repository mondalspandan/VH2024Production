#!/usr/bin/env bash
set -euo pipefail

cluster=${1:?missing cluster}
process=${2:?missing process}
bb_mass=${3:?missing BB mass}
cc_mass=${4:?missing CC mass}
events=${5:?missing events}
output_base=${6:?missing output base}

payload_dir=$PWD
scratch=$(mktemp -d "${TMPDIR:-/tmp}/vh2024.${cluster}.${process}.XXXXXX")
trap 'rm -rf "$scratch"' EXIT

source /cvmfs/cms.cern.ch/cmsset_default.sh
export X509_USER_PROXY="$scratch/x509up_user.pem"
cp x509up_user.pem "$X509_USER_PROXY"
chmod 600 "$X509_USER_PROXY"
voms-proxy-info -timeleft

export VH_PAYLOAD_DIR="$payload_dir"
export VH_GRIDPACK_DIR="$scratch"
export NCPU=1

eos_host=eoscms.cern.ch:1094
output_path=${output_base#root://$eos_host/}
if [ "$output_path" = "$output_base" ]; then
    echo "Unexpected EOS output URL: $output_base" >&2
    exit 1
fi

remote_exists() {
    xrdfs "$eos_host" stat "$1" >/dev/null 2>&1
}

valid_root() {
    root -b -q -l -e "TFile f(\"$1\"); if (f.IsZombie()) gSystem->Exit(1);" >/dev/null 2>&1
}

copy_with_retry() {
    local source=$1 destination=$2
    local destination_path=${destination#root://$eos_host/}
    local temporary_path="${destination_path}.part.${cluster}.${process}"
    local temporary_url="${destination}.part.${cluster}.${process}"
    xrdfs "$eos_host" mkdir -p "$(dirname "$destination_path")"
    for attempt in 1 2 3; do
        if xrdcp -f "$source" "$temporary_url" && \
           xrdfs "$eos_host" mv "$temporary_path" "$destination_path"; then
            return 0
        fi
        xrdfs "$eos_host" rm "$temporary_path" >/dev/null 2>&1 || true
        [ "$attempt" -lt 3 ] && sleep 30
    done
    return 1
}

run_flavour() {
    local name=$1 flavour=$2 mass=$3
    local workdir="$scratch/$name"
    local filename="${name}_$(id -un)_${cluster}_${process}_MH${mass}.root"
    local nano_path="$output_path/${name}_Nano/$filename"
    local pfnano_path="$output_path/${name}_PFNanoLatent/$filename"
    local nano_url="$output_base/${name}_Nano/$filename"
    local pfnano_url="$output_base/${name}_PFNanoLatent/$filename"

    if remote_exists "$nano_path" && remote_exists "$pfnano_path"; then
        return
    fi

    mkdir -p "$workdir"
    local gridpack="HZJ_el8_amd64_gcc12_CMSSW_14_0_21_HZJ_${mass}.tgz"
    cp "$payload_dir/$gridpack" "$scratch/$gridpack"
    export VH_WORKDIR="$workdir"
    export VH_CMSSW14="$scratch/CMSSW_14_0_21/src"
    export VH_CMSSW15="$scratch/CMSSW_15_0_6/src"

    if [ ! -d "$VH_CMSSW14" ]; then
        (cd "$scratch" && scram project CMSSW CMSSW_14_0_21)
    fi

    if [ ! -d "$VH_CMSSW15" ]; then
        (cd "$scratch" && scram project CMSSW CMSSW_15_0_6)
        (
            cd "$VH_CMSSW15"
            git cms-init
            git remote remove spandan 2>/dev/null || true
            git remote add spandan https://github.com/mondalspandan/cmssw.git
            git fetch --depth=1 spandan latent-features-cmssw-15-0-6
            git checkout -B latent-features-cmssw-15-0-6 FETCH_HEAD
            scram b -j 1
        )
    fi

    bash "$payload_dir/cmsDrive_commands_2024.sh" \
        "$cluster" "$process" "$mass" "$events" "$flavour"

    valid_root "$workdir/Nano.root"
    valid_root "$workdir/PFNanoLatent.root"
    copy_with_retry "$workdir/Nano.root" "$nano_url"
    copy_with_retry "$workdir/PFNanoLatent.root" "$pfnano_url"
}

run_flavour ZHbb 5 "$bb_mass"
run_flavour ZHcc 4 "$cc_mass"
