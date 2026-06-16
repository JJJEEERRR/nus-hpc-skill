---
name: nus-hpc
description: >-
  Run and monitor compute jobs on the NUS HPC "Vanda" cluster (PBS Pro scheduler,
  NVIDIA A40 GPUs, free + paid/allocation queues) over SSH. Use when the user wants
  to run training, simulation, or batch jobs on NUS HPC / Vanda / vanda.nus.edu.sg,
  set up a conda environment there, submit/monitor PBS (qsub/qstat) jobs, request
  A40 GPUs, or decide between the free queue and a paid GPU-Hours allocation.
---

# NUS HPC (Vanda) Job Runner

Practical playbook for running GPU/CPU jobs on the **NUS Vanda** cluster. Vanda has
a **free queue** (A40 GPUs, no chargeback) plus **paid queues** billed against your
GPU/CPU-Hours allocations.

> Vanda is the live cluster. **Atlas is retired** (`atlas.nus.edu.sg` still resolves
> in DNS but does not respond to ping or SSH, from on- or off-campus — do not use it).
> Higher-end GPUs (H100/H200) live on the separate **Hopper** cluster (CFP-billed).

---

## 0. ASK FIRST: free, paid, or mixed?  (do this before submitting)

Before submitting any job, **ask the user which billing mode they want** — do not
assume. Offer these three and let them pick:

1. **Free only** — `-q auto_free`, no charge. Best for dev, debugging, single runs,
   anything not urgent. Caps: ≤2 GPU, 48 h, 2 concurrent jobs; shares a busy pool.
2. **Paid only** — `-q auto` + `#PBS -P <project>`, spends GPU/CPU-Hours. Best for
   long runs (>48 h), many parallel runs (up to 4), or when the free pool is full
   and you need results fast.
3. **Mixed strategy** — develop/debug on free; once the config is locked, fan out
   the real sweep/long runs on paid. (Recommended default to propose.)

When the answer is paid or mixed, also confirm **which allocation** (see §1) — and
honor the hard rule below.

---

## 1. Your allocations — ⚠ ONLY use your OWN, never the team's

Check balances (needs your NUS password, interactive — the agent cannot type it):

```bash
amgr login            # enter NUS password at the prompt
hpc project           # lists projects, members, CPU/GPU-Hours balances
hpc project-usage     # usage detail
```

Example output has **two kinds** of project:

| Project | Kind | Rule |
|---|---|---|
| `personal-<id>` (e.g. `personal-e0900742`) | **your own** personal allocation | ✅ **USE THIS** for paid jobs |
| `CFP04-CF-039` (shared, multiple members) | **team / group** allocation | ❌ **DO NOT USE** |

**HARD RULE: never bill jobs to a shared/team project.** Only ever put your own
`personal-<id>` after `#PBS -P`. If the user explicitly insists on a shared project,
stop and make them confirm in writing first — default is always the personal one.

Typical personal balance: ~**1000 GPU-Hours** + ~**10000 CPU-Hours** (1 GPU-Hour =
1 A40 × 1 wall-hour; a 2×A40 run of ~45 min ≈ 1.5 GPU-Hours, so ~650 such runs).

---

## 2. Resources you can use

GPU on Vanda is **A40 (46 GB) only**, and **max 2 GPUs per job** (hard cap on both
free and paid — for >2 GPUs use Hopper).

### GPU

| | Free `gpu` (`-q auto_free`) | Paid `batch_gpu` (`-q auto`) |
|---|---|---|
| Cost | 0 | bills GPU-Hours |
| GPU / CPU per job | ≤2 / ≤36 | ≤2 / ≤720 |
| Max walltime | **48 h** | **168 h (7 d)** |
| Concurrent jobs / user | 2 | 4 |
| Node pool | `gpu_free` (≈18× A40, shared) | `gpu_node` (dedicated, larger) |

### CPU

| | Free `cpu_serial` | Free `cpu_parallel` | Paid `batch_cpu` (`-q auto`) |
|---|---|---|---|
| Cost | 0 | 0 | bills CPU-Hours |
| Cores | 1 | 2–160 | ≤720 |
| Mem | ≤20 GB | per node (72 c / ~500 GB) | large |
| Max walltime | 168 h | 168 h | 240 h |
| Concurrent / user | 32 | **2** | 6 |

Free CPU nodes (`cpu_free` pool): ~20× nodes, **72 cores / ~500 GB RAM** each.
**Free CPU is generous** — only pay for CPU if you need >160 cores, >7 days, or
>2 parallel big jobs.

---

## 3. Live busyness — check before you choose

```bash
qstat -Q                                   # per-queue Run/Queued/Held counts
# free A40 actually-free right now:
pbsnodes -a | awk '/node_pool/{p=$3}/resources_available.ngpus/{a=$3}/resources_assigned.ngpus/{u=$3; if(p=="gpu_free"){t+=a;us+=u}}END{print "free A40:",t-us,"of",t}'
```

See [scripts/check_queues.sh](scripts/check_queues.sh) for a one-shot snapshot.
Rules of thumb from observed snapshots:

- **Free GPU pool is often tight** — ~18 A40 shared, several may be down/offline,
  and the free `gpu` queue regularly has jobs waiting (held). Expect to queue.
- **Free CPU serial** is usually idle (instant). **Free CPU parallel** mildly busy.
- **Paid pools** (`batch_gpu` / `batch_cpu`) frequently show long queues too, but
  give 7–10 day walltime, more concurrency, and a dedicated pool.

---

## 4. Cluster facts (verified)

- **Login**: `ssh <nusnet-id>@vanda.nus.edu.sg`. Set up SSH key auth so commands
  run non-interactively.
- **OS**: RHEL 9.4. **Scheduler**: **PBS Pro** (`qsub`, `qstat`, `pbsnodes`) —
  **not** Slurm. **Modules**: Lmod (`module avail`, `module load`).
- **GPU nodes**: `gn-a40-*` = 2× A40 (46 GB) + 72 cores + ~525 GB RAM.
- **Storage**: `$HOME` on shared NFS (`/nfs/home/svu/...`), visible from compute
  nodes; `/scratch` for fast scratch.
- **Internet**: **login node has internet** (pip/git work); compute nodes may not —
  install packages and pre-download datasets/models on the login node into `$HOME`.

---

## 5. Queues — submit to the router, not the exec queue

Direct `qsub -q gpu` is **denied**. Submit to a **routing queue**:

| Submit to | Routes to | Cost | Needs `#PBS -P`? |
|-----------|-----------|------|------------------|
| `auto_free` | `cpu_serial`, `cpu_parallel`, `gpu` | **free** | no |
| `auto` | `batch_cpu`, `batch_gpu` | **charged** | **yes** (your personal project) |

```bash
qsub -q auto_free job.pbs                  # free
qsub -q auto      job.pbs                   # paid (job.pbs must set #PBS -P personal-<id>)
```

---

## 6. PBS job scripts

- Free A40 GPU: [scripts/gpu_job.pbs](scripts/gpu_job.pbs)
- Paid A40 GPU (uses your personal allocation): [scripts/paid_gpu_job.pbs](scripts/paid_gpu_job.pbs)

```bash
#!/bin/bash
#PBS -N myjob
#PBS -q gpu                       # actual submit via `qsub -q auto_free` (free)
#PBS -l select=1:ncpus=16:ngpus=1:mem=64gb
#PBS -l walltime=03:00:00
#PBS -j oe
#PBS -o myjob.log

cd "$PBS_O_WORKDIR"
module load Miniconda3            # confirm name with `module avail`
"$HOME/myenv/bin/python" -u train.py    # -u = unbuffered so .log streams live
```

For paid, add `#PBS -P personal-<id>` and submit with `-q auto`; bump
`walltime`/concurrency as needed. **Never** put a shared project name here (§1).

---

## 7. One-time environment setup (on the login node)

```bash
module load Miniconda3
conda create -y -p "$HOME/myenv" python=3.12     # prefix in $HOME (module env is read-only)
PY="$HOME/myenv/bin/python"
$PY -m pip install -U pip
$PY -m pip install -U "<your deps>"
# Pre-download any models/datasets now so compute nodes don't need internet.
```

Use the env via its absolute interpreter: `$HOME/myenv/bin/python`.

---

## 8. Monitoring

```bash
qstat -xu <nusnet-id>                       # your jobs (R=run, Q=queue, F=finished)
qstat -xf <jobid> | grep -i resources_used  # walltime/cput/mem actually used
tail -f myjob.log                           # live output (needs python -u)
```

`resources_used.walltime` of a finished job is the ground-truth elapsed time (and,
for paid jobs, what you were billed × ngpus).

---

## 9. Gotchas (learned the hard way)

1. **CRLF kills PBS scripts.** Windows-edited `.pbs` fails with `/bin/bash^M: bad
   interpreter`. Always `dos2unix job.pbs` (or write LF) before `qsub`.
2. **Submit to `auto_free` / `auto`**, not `-q gpu` (direct exec-queue is denied).
3. **Python buffers stdout** into PBS logs — add `python -u` or you see nothing
   until the job ends.
4. **Login node has no GPU.** `jax`/`torch` warn `CUDA_ERROR_NO_DEVICE` there;
   real GPUs appear only inside a GPU job.
5. **Windows PowerShell mangles quotes/pipes** in remote commands. Pipe a local
   script over stdin — see [scripts/remote_bash.ps1](scripts/remote_bash.ps1):
   ```powershell
   ((Get-Content job.sh -Raw) -replace "`r","") | ssh <id>@vanda.nus.edu.sg "bash -s"
   ```
6. **`amgr login` is interactive** (NUS password). An agent over SSH cannot type it;
   ask the user to run `amgr login && hpc project` themselves and paste the output.

---

## 10. A40 performance notes (MJX/JAX RL, for reference)

- One A40 is compute-bound fairly early; **adding a 2nd GPU helps more than adding
  parallel envs** (Brax multi-device PPO ≈ 1.6× on 2 GPUs).
- Enable a **persistent XLA compile cache** so the ~3 min JIT compile is paid once.
- Reference: a 150 M-step humanoid PPO flat run ≈ **45 min on 2× A40** (≈1.5 GPU-Hours).

---

## 11. Workflow checklist

```
- [ ] ASK user: free / paid / mixed?  If paid → confirm personal-<id> (never team)
- [ ] SSH in; scripts/check_queues.sh to see busyness + free A40 count
- [ ] module load Miniconda3; create env in $HOME; pip install; pre-download data
- [ ] scp/clone code to $HOME; write job.pbs (gpu_job.pbs free / paid_gpu_job.pbs)
- [ ] dos2unix job.pbs; qsub -q auto_free (or -q auto for paid) job.pbs
- [ ] qstat -xu <id> until R; tail -f the .log (python -u)
- [ ] on finish: check resources_used.walltime; collect outputs from $HOME
```
