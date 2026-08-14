#!/usr/bin/env bash
set -euo pipefail

cluster=${1:?missing cluster}
process=${2:?missing process}
mass=${3:?missing mass}
events=${4:?missing events}
hadron_flavour=${5:?missing hadron flavour}

: "${VH_WORKDIR:?VH_WORKDIR is required}"
: "${VH_PAYLOAD_DIR:?VH_PAYLOAD_DIR is required}"
: "${VH_GRIDPACK_DIR:?VH_GRIDPACK_DIR is required}"
: "${VH_CMSSW14:?VH_CMSSW14 is required}"
: "${VH_CMSSW15:?VH_CMSSW15 is required}"

export SCRAM_ARCH=el8_amd64_gcc12
export VH_MASS="$mass"
export VH_HADFLAV="$hadron_flavour"
export PYTHONPATH="$VH_PAYLOAD_DIR${PYTHONPATH:+:$PYTHONPATH}"

is_valid_root() {
    [ -s "$1" ]
}

source /cvmfs/cms.cern.ch/cmsset_default.sh

mkdir -p "$VH_WORKDIR"
mkdir -p "$VH_CMSSW14/Configuration/GenProduction/python"
cp "$VH_PAYLOAD_DIR/ZHjj.py" "$VH_CMSSW14/Configuration/GenProduction/python/ZHjj.py"

cd "$VH_CMSSW14"
eval "$(scram runtime -sh)"
cd "$VH_WORKDIR"

if ! is_valid_root RAWSIM.root; then
    cmsDriver.py Configuration/GenProduction/python/ZHjj.py \
        --python_filename makeRAWSIM.py \
        --eventcontent RAWSIM,LHE \
        --customise Configuration/DataProcessing/Utils.addMonitoring \
        --customise_commands "process.RandomNumberGeneratorService.externalLHEProducer.initialSeed=$((cluster + process + 1))\\nprocess.source.numberEventsInLuminosityBlock=cms.untracked.uint32(250)" \
        --datatier GEN-SIM,LHE \
        --conditions 140X_mcRun3_2024_realistic_v26 \
        --beamspot DBrealistic \
        --step LHE,GEN,SIM \
        --geometry DB:Extended \
        --era Run3_2024 \
        --fileout file:RAWSIM.root \
        --number "$events" \
        --number_out "$events" \
        --no_exec \
        --mc
    cmsRun makeRAWSIM.py
fi

cd "$VH_CMSSW14"
eval "$(scram runtime -sh)"
cd "$VH_WORKDIR"

if ! is_valid_root RAW.root; then
    cmsDriver.py \
        --eventcontent PREMIXRAW \
        --customise Configuration/DataProcessing/Utils.addMonitoring \
        --datatier GEN-SIM-RAW \
        --conditions 140X_mcRun3_2024_realistic_v26 \
        --step DIGI,DATAMIX,L1,DIGI2RAW,HLT:2024v14 \
        --procModifiers premix_stage2 \
        --geometry DB:Extended \
        --datamix PreMix \
        --era Run3_2024 \
        --python_filename makeRAW.py \
        --fileout file:RAW.root \
        --filein file:RAWSIM.root \
        -n -1 \
        --pileup_input "dbs:/Neutrino_E-10_gun/RunIIISummer24PrePremix-Premixlib2024_140X_mcRun3_2024_realistic_v26-v1/PREMIX" \
        --no_exec \
        --mc
    cmsRun makeRAW.py
fi

if ! is_valid_root AOD.root; then
    cmsDriver.py \
        --eventcontent AODSIM \
        --customise Configuration/DataProcessing/Utils.addMonitoring \
        --datatier AODSIM \
        --conditions 140X_mcRun3_2024_realistic_v26 \
        --step RAW2DIGI,L1Reco,RECO,RECOSIM \
        --geometry DB:Extended \
        --era Run3_2024 \
        --python_filename makeAOD.py \
        --fileout file:AOD.root \
        --filein file:RAW.root \
        -n -1 \
        --no_exec \
        --mc
    cmsRun makeAOD.py
fi

cd "$VH_CMSSW15"
eval "$(scram runtime -sh)"
cd "$VH_WORKDIR"

if ! is_valid_root Mini.root; then
    cmsDriver.py \
        --eventcontent MINIAODSIM \
        --customise Configuration/DataProcessing/Utils.addMonitoring \
        --datatier MINIAODSIM \
        --conditions 150X_mcRun3_2024_realistic_v2 \
        --step PAT \
        --geometry DB:Extended \
        --era Run3_2024 \
        --python_filename makeMini.py \
        --fileout file:Mini.root \
        --filein file:AOD.root \
        -n -1 \
        --no_exec \
        --mc
    cmsRun makeMini.py
fi

if ! is_valid_root PFNanoLatent.root; then
    cmsDriver.py \
        --scenario pp \
        --era Run3_2024 \
        --step NANO \
        --conditions 150X_mcRun3_2024_realistic_v2 \
        --datatier NANOAODSIM \
        --eventcontent NANOAODSIM \
        --python_filename makePFNanoLatent.py \
        --fileout file:PFNanoLatent.root \
        --filein file:Mini.root \
        -n -1 \
        --no_exec \
        --mc \
        --customise custom_btv_overlay.PrepBTVCustomNanoAOD_MC_LatentFeatures
    cmsRun makePFNanoLatent.py
fi

if ! is_valid_root Nano.root; then
    cmsDriver.py \
        --scenario pp \
        --era Run3_2024 \
        --step NANO \
        --conditions 150X_mcRun3_2024_realistic_v2 \
        --datatier NANOAODSIM \
        --eventcontent NANOAODSIM \
        --python_filename makeNano.py \
        --fileout file:Nano.root \
        --filein file:Mini.root \
        -n -1 \
        --no_exec \
        --mc
    cmsRun makeNano.py
fi

is_valid_root PFNanoLatent.root
is_valid_root Nano.root
