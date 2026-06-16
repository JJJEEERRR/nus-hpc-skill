# nus-hpc-skill

A [Cursor Agent Skill](https://cursor.com/docs) that teaches the agent how to run
and monitor compute jobs on the **NUS HPC "Vanda"** cluster (PBS Pro scheduler,
NVIDIA A40 GPUs, free **and** paid/allocation queues) over SSH.

It captures the practical, hard-won details: free vs paid resource limits and live
busyness, how to check and spend your GPU/CPU-Hours allocation, which routing queue
to submit to, conda env setup on the login node, the CRLF / stdout-buffering
gotchas, and ready-to-use PBS job templates.

Two behaviors the skill enforces:

- **Ask first** whether to run **free / paid / mixed**, before submitting anything.
- **Only ever bill your OWN `personal-<id>` allocation — never a shared/team
  project** (e.g. a `CFP04-*` group allocation).

> Atlas (`atlas.nus.edu.sg`) is retired/offline. High-end H100/H200 GPUs are on the
> separate Hopper cluster (CFP-billed).

## Install

Clone (or copy) the `nus-hpc/` folder into your Cursor skills directory:

```bash
# Personal skill (all projects)
git clone git@github.com:<you>/nus-hpc-skill.git
cp -r nus-hpc-skill/nus-hpc ~/.cursor/skills/nus-hpc
```

Or, for a single project, put it under `<project>/.cursor/skills/nus-hpc`.

The agent will then auto-apply it when you ask things like *"run this training on
NUS HPC"* or *"submit a Vanda GPU job"*.

## Contents

```
nus-hpc/
├── SKILL.md                  # the skill (resources, allocations, queues, gotchas, workflow)
└── scripts/
    ├── gpu_job.pbs           # A40 GPU job template — FREE queue
    ├── paid_gpu_job.pbs      # A40 GPU job template — PAID (personal allocation only)
    ├── check_queues.sh       # one-shot live busyness + free A40/CPU snapshot
    └── remote_bash.ps1       # run a local bash script on Vanda from Windows
```

## Notes

- Edit the example NUSNET id / project / env path in `SKILL.md` and `scripts/` to
  your own (the paid template defaults to `personal-<id>` on purpose).
- Free queue (`auto_free` → `gpu`/`cpu_*`, `*_free` pools): no charge, tighter caps
  (≤2 GPU, 48 h). Paid queue (`auto` → `batch_*`): spends GPU/CPU-Hours, longer
  walltime and more concurrency.
