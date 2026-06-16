---
name: nus-hpc
description: >-
  Run and monitor compute jobs on the NUS HPC "Vanda" cluster (PBS Pro scheduler,
  NVIDIA A40 GPUs, free queue) over SSH. Use when the user wants to run training,
  simulation, or batch jobs on NUS HPC / Vanda / vanda.nus.edu.sg, set up a conda
  environment there, submit/monitor PBS (qsub/qstat) jobs, or request A40 GPUs.
---

# NUS HPC (Vanda) Job Runner

Practical playbook for running GPU/CPU jobs on the **NUS Vanda** cluster. Vanda
is a hybrid HPC system with a **free queue** (A40 GPUs, no chargeback), good for
students / FYP / exploratory work.

## Cluster facts (verified)

- **Login**: `ssh <nusnet-id>@vanda.nus.edu.sg` (e.g. `e0900742@vanda.nus.edu.sg`).
  Set up SSH key auth once so commands run non-interactively.
- **OS**: RHEL 9.4. **Scheduler**: **PBS Pro** (`qsub`, `qstat`, `pbsnodes`) —
  **not** Slurm. **Modules**: Lmod (`module avail`, `module load`).
- **GPU nodes**: `gn-a40-*`, each = **2× NVIDIA A40 (46 GB)** + 72 CPU cores +
  ~525 GB RAM.
- **Storage**: `$HOME` is on shared NFS (`/nfs/home/svu/...`), visible from
  compute nodes. `/scratch` for fast scratch.
- **Internet**: the **login node has internet** (pip/git work). Compute nodes may
  not — so install packages and pre-download datasets/models on the login node
  into `$HOME` (NFS), then compute nodes can read them.

## Queues — submit to the router, not the exec queue

`qsub -q gpu ...` is **denied** ("Access to queue is denied"). Submit to a
**routing queue** which dispatches by the resources you request:

| Submit to | Routes to | Cost | Use for |
|-----------|-----------|------|---------|
| `auto_free` | `cpu_serial`, `cpu_parallel`, `gpu` | **free** (charge_rate 0) | default / GPU testing |
| `auto` | charged exec queues | charged | when you have an allocation |

The free `gpu` exec queue uses the `gpu_free` node pool, **max 2 GPUs**, walltime
up to **48 h**. So: `qsub -q auto_free job.pbs`.

## PBS job script

See [scripts/gpu_job.pbs](scripts/gpu_job.pbs) for a ready template. Key parts:

```bash
#!/bin/bash
#PBS -N myjob
#PBS -q gpu                       # routed via `qsub -q auto_free` (see below)
#PBS -l select=1:ncpus=16:ngpus=1:mem=64gb
#PBS -l walltime=03:00:00
#PBS -j oe
#PBS -o myjob.log

cd "$PBS_O_WORKDIR"
module load Miniconda3            # check exact name with `module avail`
python -u train.py               # -u = unbuffered, so the .log streams live
```

Request 1 GPU with `ngpus=1` (use `ngpus=2` for both A40s on a node; scale
`ncpus`/`mem` accordingly, e.g. 32 cpus / 128 gb). Submit with:

```bash
dos2unix job.pbs                  # MANDATORY if edited on Windows (see Gotchas)
qsub -q auto_free job.pbs         # prints e.g. 1179233.stdct-mgmt-02
```

## One-time environment setup (run on the login node)

```bash
module load Miniconda3
conda create -y -p "$HOME/myenv" python=3.12     # prefix in $HOME (module env is read-only)
PY="$HOME/myenv/bin/python"
$PY -m pip install -U pip
$PY -m pip install -U "<your deps>"
# Pre-download any models/datasets now so compute nodes don't need internet.
```

Use the env in jobs via its absolute interpreter: `$HOME/myenv/bin/python`.

## Monitoring

```bash
qstat -xu <nusnet-id>                       # your jobs (R=run, Q=queue, F=finished)
qstat -xf <jobid> | grep -i resources_used  # walltime/cput/mem actually used
tail -f myjob.log                           # live output (needs python -u)
```

For a finished job, `resources_used.walltime` is the ground-truth elapsed time.

## Gotchas (learned the hard way)

1. **CRLF kills PBS scripts.** A Windows-edited `.pbs` fails with
   `/bin/bash^M: bad interpreter`. Always `dos2unix job.pbs` (or write LF) before
   `qsub`.
2. **Submit to `auto_free`**, not `-q gpu` (direct exec-queue access is denied).
3. **Python buffers stdout** into PBS log files — add `python -u` or you'll see
   nothing until the job ends.
4. **Login node has no GPU.** `jax`/`torch` will warn `CUDA_ERROR_NO_DEVICE`
   there; that's expected — real GPUs appear only inside a GPU job.
5. **Running remote commands from Windows PowerShell** mangles quotes/pipes.
   Pipe a local script over stdin instead — see
   [scripts/remote_bash.ps1](scripts/remote_bash.ps1):
   ```powershell
   ((Get-Content job_probe.sh -Raw) -replace "`r","") | ssh <id>@vanda.nus.edu.sg "bash -s"
   ```

## A40 performance notes (MJX/JAX RL, for reference)

- One A40 is compute-bound fairly early; **adding a 2nd GPU helps more than adding
  parallel envs** (Brax multi-device PPO ≈ 1.6× on 2 GPUs).
- Enable a **persistent XLA compile cache** so the ~3 min JIT compile is paid once.

## Workflow checklist

```
- [ ] SSH in; `qstat -Q` to confirm queues, `pbsnodes -a | grep -i a40` for GPUs
- [ ] module load Miniconda3; create env in $HOME; pip install; pre-download data
- [ ] scp/clone code to $HOME; write job.pbs (use scripts/gpu_job.pbs)
- [ ] dos2unix job.pbs; qsub -q auto_free job.pbs
- [ ] qstat -xu <id> until R; tail -f the .log (python -u)
- [ ] on finish: check resources_used.walltime; collect outputs from $HOME
```
