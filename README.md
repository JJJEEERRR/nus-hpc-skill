# nus-hpc-skill

A [Cursor Agent Skill](https://cursor.com/docs) that teaches the agent how to run
and monitor compute jobs on the **NUS HPC "Vanda"** cluster (PBS Pro scheduler,
NVIDIA A40 GPUs, free queue) over SSH.

It captures the practical, hard-won details: which routing queue to submit to,
how to set up a conda env on the login node, the CRLF / stdout-buffering gotchas,
and a ready-to-use PBS job template.

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
├── SKILL.md                  # the skill (cluster facts, queues, gotchas, workflow)
└── scripts/
    ├── gpu_job.pbs           # A40 GPU job template for the free queue
    └── remote_bash.ps1       # run a local bash script on Vanda from Windows
```

## Notes

- Edit the example NUSNET id / env path in `SKILL.md` and `scripts/` to your own.
- The free queue (`auto_free` → `gpu`, `gpu_free` pool) is meant for testing /
  education / FYP; production runs use a Call-for-Projects allocation.
