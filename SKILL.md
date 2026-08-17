# VH2024Production production notes

## Scope and storage model

This workflow is designed for lxplus Condor. The worker must not `cd` into or
read mounted AFS/EOS paths. Condor transfers the proxy, small workflow files,
and the small workflow inputs into the job sandbox. The job executable creates a temporary
worker-local directory, runs all CMSSW stages there, validates the outputs,
and uses XRootD for the final EOS copies.

The group EOS endpoint is:

```text
root://eoscms.cern.ch:1094//eos/cms/store/group/phys_btag/spmondal/bb_cc_variableM/
```

To verify the gridpack directory from lxplus, use:

```bash
xrdfs eoscms.cern.ch:1094 ls -l \
  /eos/cms/store/group/phys_btag/spmondal/bb_cc_variableM/gridpacks_2024/
```

It contains 311 files named:

```text
HZJ_el8_amd64_gcc12_CMSSW_14_0_21_HZJ_<mass>.tgz
```

for every integer mass from 40 through 350.

## Proxy

Use a proxy with the requested seven-day lifetime before submission:

```bash
voms-proxy-init --rfc --voms cms --valid 192:00
python getproxy.py
voms-proxy-info -timeleft
```

`getproxy.py` copies the active proxy to `x509up_user.pem`, which is then
transferred with every job.

## Current 2024 workflow

Each production job runs both flavours. Its mass selection is copied from
the Brux `el8_wrapper.sh` `mass_for_job` function. The authoritative
BB/CC anchor weights are in `mass_weights_2024.tsv`. For every integer
mass 40--350, the selector performs the same linear interpolation and
high-mass extrapolation, then applies the same stratified inverse-CDF target
`(process % 311 + 0.5) * total / 311` separately for BB and CC. Thus
311, 622, and 933 jobs are exact repetitions of the same 311-job stratified
sequence, as on Brux. This is intentionally not `random.choice`.
Each flavour receives 643 events, preserving the existing approximately
200,000 events per flavour plan.

The stages are unchanged:

1. CMSSW 14_0_21: LHE, GEN, SIM.
2. CMSSW 14_0_21: DIGI, DATAMIX, L1, DIGI2RAW, HLT.
3. CMSSW 14_0_21: RAW2DIGI, L1Reco, RECO, RECOSIM.
4. CMSSW 15_0_6: PAT/MiniAOD.
5. CMSSW 15_0_6: standard NanoAOD.
6. CMSSW 15_0_6: latent-feature PFNano.

The 2024 settings are:

```text
GEN/SIM/RAW/AOD conditions: 140X_mcRun3_2024_realistic_v26
Mini/Nano conditions:      150X_mcRun3_2024_realistic_v2
era:                       Run3_2024
beamspot:                  DBrealistic
HLT:                       2024v14
premix input:              DBS Neutrino_E-10_gun PreMix
SCRAM_ARCH:                el8_amd64_gcc12
```

## Latent-feature setup

The worker creates CMSSW 15_0_6 in scratch, fetches the latest tip of
`latent-features-cmssw-15-0-6` from the public `mondalspandan/cmssw` fork, and
builds the source in the job. The standard CMSSW UParT V01 model is used; no
separate model copy is staged.

The latent customization is:

```text
custom_btv_overlay.PrepBTVCustomNanoAOD_MC_LatentFeatures
```

It replaces the positive AK4 UParT producer with the latent producer while
retaining the standard softmax outputs. The expected probed output shapes are
CLS `[1, 192]`, MLP `[1, 24]`, and encoder `[1, nTokens, 192]`.

## Gridpack production from scratch

The existing gridpacks were produced with CMSSW 14_0_21 and
`el8_amd64_gcc12`. For each integer mass 40–350:

1. Copy the `HZJ_125` Powheg test card to `HZJ_<mass>`.
2. Copy `process.dat` from the 125 GeV card when needed.
3. Replace the `hmass` line with the target mass.
4. Run:

```bash
./gridpack_generation.sh HZJ_<mass> test_cards/HZJ_<mass> \
  pdmv all el8_amd64_gcc12 CMSSW_14_0_21
```

5. Validate that the resulting tarball contains `runcmsgrid.sh`.

The final gridpack names must match the pattern above. Temporary `_test.tgz`
and `.incompatible.*` files are not production inputs.

## 2023 reference defaults

The older BPix workflow used:

```text
GEN/SIM release:          CMSSW 13_0_17
processing release:       CMSSW 13_0_14
SCRAM_ARCH:               el8_amd64_gcc11
conditions:               130X_mcRun3_2023_realistic_postBPix_v6
era:                      Run3_2023
beamspot:                 Realistic25ns13p6TeVEarly2023Collision
HLT:                      2023v12
premix input:             pileup_Summer23BPix.root
```

Those settings are historical reference material only; they are not used by
the 2024 submit files.

## Condor and EOS operations

The submit files use the native lxplus container selector:

```text
MY.WantOS = "el8"
```

This lets Condor run the payload in an EL8 Apptainer/Singularity container
without wrapping the executable in `cmssw-el8`. The payload still sources
`/cvmfs/cms.cern.ch/cmsset_default.sh` and initializes each CMSSW workarea
before using CMSSW tools or `git cms-init`.

The production submit file requests one CPU and uses `testmatch` to allow the
established payload to run beyond 24 hours. The pilot uses `workday` because
its event payload is tiny but still installs and builds CMSSW.

Each job selects its BB and CC mass points with `mass_selector.py`, then
fetches the corresponding gridpacks from group EOS with `xrdcp` into worker
scratch. Outputs are written locally first, checked for a nonzero ROOT file,
copied to a temporary EOS name with `xrdcp`, and renamed to the final path only
after a successful transfer.

Before production, inspect the pilot with:

```bash
condor_q
condor_q -l <jobid> -af MaxRuntime JobFlavour RequestCpus RequestMemory RequestDisk
condor_history <cluster>
```

Do not release or resubmit held jobs without reading `HoldReason`, and do not
submit the full 933-job campaign until all four pilot outputs are readable and
contain the expected event counts and latent tables.
