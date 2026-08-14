# VH2024Production

Self-contained lxplus Condor production for the 2024 ZHbb/ZHcc samples. Jobs
transfer their two gridpacks into the Condor sandbox, run all CMSSW stages in
worker-local scratch, and copy validated NanoAOD outputs to group EOS with
`xrdcp`.

The gridpacks are currently read from:

```text
root://eoscms.cern.ch:1094//eos/cms/store/group/phys_btag/spmondal/bb_cc_variableM/gridpacks_2024/
```

The production outputs currently go to:

```text
root://eoscms.cern.ch:1094//eos/cms/store/group/phys_btag/spmondal/bb_cc_variableM/2024/
```

The group EOS directory contains 311 gridpacks, `MH40` through `MH350`.

## Submit

Run from an AFS checkout on `lxplus.cern.ch`:

```bash
git clone git@github.com:mondalspandan/VH2024Production.git
cd VH2024Production
voms-proxy-init --rfc --voms cms --valid 192:00
python getproxy.py
condor_submit submit_pilot.sub
```

The pilot queues one job with 10 BB and 10 CC events. It writes four files
under the EOS `2024/pilot/` directory. Inspect those files and the Condor log
before submitting production:

```bash
condor_submit submit_vh2024.sub
```

Production queues 933 jobs. Each job runs the BB and CC workflows with 643
events per flavour and produces both `Nano` and `PFNanoLatent` outputs.

If the EOS locations change, edit `GRIDPACK_XROOTD_BASE` and
`OUTPUT_XROOTD_BASE` in the submit files. Keep the gridpack basenames and
subdirectory layout unchanged unless the job manifest is regenerated.

The worker clones the public latent-feature branch over HTTPS so Condor
workers do not need GitHub SSH keys:

```text
https://github.com/mondalspandan/cmssw.git
latent-features-cmssw-15-0-6
```

See [`SKILL.md`](SKILL.md) for the full production notes, CMSSW defaults,
gridpack-generation procedure, and recovery guidance.
