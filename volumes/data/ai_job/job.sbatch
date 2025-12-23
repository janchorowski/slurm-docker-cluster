#!/bin/bash
#SBATCH --job-name=ai_job
#SBATCH --output=/data/ai_job/training_%j.out
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --time=10:00:00

# Multi-node job that runs on both compute nodes
echo "Multi-node job starting"
echo "Job ID: $SLURM_JOB_ID"
echo "Number of nodes: $SLURM_JOB_NUM_NODES"
echo "Number of tasks: $SLURM_NTASKS"
echo "Node list: $SLURM_JOB_NODELIST"

# Run hostname on each allocated node
srun hostname

for i in $(seq 1 1000); do
    sleep 1
    echo "Training step $i done"
done

echo "Training done"
