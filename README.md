# VH2024Production

Self-contained lxplus Condor production for the 2024 ZHbb/ZHcc samples. Each
job selects its BB/CC masses at runtime with the Brux-compatible stratified
weight sampler, fetches the corresponding gridpacks from group EOS with
`xrdcp`, runs all CMSSW stages in worker-local scratch, and copies
validated NanoAOD outputs back with `xrdcp`.

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

Production queues 933 jobs by default. Each job runs the BB and CC workflows
with 643 events per flavour and produces both `Nano` and `PFNanoLatent`
outputs. To run 311 or 622 jobs instead, change `N_JOBS` in
`submit_vh2024.sub`. The mass sequence is the Brux sequence repeated
through `process % 311`, so these campaign sizes preserve the intended
stratified coverage.

Both submit files request the native lxplus EL8 container with
`MY.WantOS = "el8"`; no CMSSW container wrapper is needed.

If the EOS locations change, edit `GRIDPACK_XROOTD_BASE` and
`OUTPUT_XROOTD_BASE` in the submit files. The authoritative weights are
in `mass_weights_2024.tsv`; `jobs_2024.tsv` is retained only as a
legacy validation table and is not transferred to workers or used for job
queuing.

The worker clones the public latent-feature branch over HTTPS so Condor
workers do not need GitHub SSH keys:

```text
https://github.com/mondalspandan/cmssw.git
latent-features-cmssw-15-0-6
```

See [`SKILL.md`](SKILL.md) for the full production notes, CMSSW defaults,
gridpack-generation procedure, and recovery guidance.
