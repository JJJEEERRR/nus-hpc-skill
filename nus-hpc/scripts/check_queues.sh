#!/bin/bash
# One-shot Vanda busyness snapshot. Run on the login node (or pipe via SSH):
#   ((Get-Content check_queues.sh -Raw) -replace "`r","") | ssh <id>@vanda.nus.edu.sg "bash -s"

echo "===== Queues: Run / Queued / Held ====="
qstat -Q 2>/dev/null

echo
echo "===== FREE A40 (gpu_free pool) available right now ====="
pbsnodes -a 2>/dev/null | awk '
/node_pool/{p=$3}
/resources_available.ngpus/{a=$3}
/resources_assigned.ngpus/{u=$3; if(p=="gpu_free"){t+=a; us+=u}}
END{print "free A40:", t-us, "of", t, "(note: some nodes may be down/offline)"}'

echo
echo "===== FREE CPU (cpu_free pool) cores available ====="
pbsnodes -a 2>/dev/null | awk '
/node_pool/{p=$3}
/resources_available.ncpus/{a=$3}
/resources_assigned.ncpus/{u=$3; if(p=="cpu_free"){t+=a; us+=u}}
END{print "free CPU cores:", t-us, "of", t}'

echo
echo "===== My jobs ====="
qstat -xu "$(whoami)" 2>/dev/null | tail -n +1
