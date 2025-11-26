# Slurm Docker Cluster

(simplified and forked from https://github.com/giovtorres/slurm-docker-cluster)

**Slurm Docker Cluster** is a multi-container Slurm cluster designed for rapid
deployment using Docker Compose. This repository simplifies the process of
setting up a robust Slurm environment for development, testing, or lightweight
usage.

## 🏁 Getting Started

To get up and running with Slurm in Docker, make sure you have the following tools installed:

- **[Docker](https://docs.docker.com/get-docker/)**
- **[Docker Compose](https://docs.docker.com/compose/install/)**

Clone the repository:

```bash
git clone https://github.com/janchorowski/slurm-docker-cluster.git
cd slurm-docker-cluster
```

## 🏗️ Build and run

```bash
make build
make up
```

## Queue up some long running jobs

```bash
make queue-ai-jobs
make status
```

## 📦 Containers and Volumes

This setup consists of the following containers:

- **mysql**: Stores job and cluster data.
- **slurmdbd**: Manages the Slurm database.
- **slurmctld**: The Slurm controller responsible for job and resource management.
- **slurmrestd**: REST API daemon for HTTP/JSON access to the cluster.
- **c1, c2, c3, c4**: Compute nodes (running `slurmd`). They are arranged into one partition with exclusive job access (no jobs will share a machine)

### Persistent Volumes:

- `etc_munge`: Mounted to `/etc/munge` - Authentication keys
- `etc_slurm`: Mounted to `/etc/slurm` - Configuration files (allows live editing), for convenience available as `./volumes/etc_slurm`, after editing run `make reload-slurm` (see below for more explanations)
- `slurm_jobdir`: Mounted to `/data` - Job files shared across all nodes, for convenience available as `./volumes/data`
- `var_lib_mysql`: Mounted to `/var/lib/mysql` - Database persistence
- `var_log_slurm`: Mounted to `/var/log/slurm` - Log files, for convenience available as `./volumes/var_log_slurm`

## 🖥️ Using the Cluster

### Accessing the Controller

Open a shell in the Slurm controller:

```bash
make shell
# Or: docker exec -it slurmctld bash
```

Check cluster status:

```bash
[root@slurmctld /]# sinfo
PARTITION AVAIL  TIMELIMIT  NODES  STATE NODELIST
normal*      up   infinite      2   idle c[1-2]
```

### Submitting Jobs

The `/data` directory is shared across all nodes for job files:

```bash
[root@slurmctld /]# cd /data/
[root@slurmctld data]# sbatch --wrap="hostname"
Submitted batch job 2
[root@slurmctld data]# cat slurm-2.out
c1
```

## 🔄 Cluster Management

Stop the cluster (keeps data):

```bash
make down
```

Restart the cluster:

```bash
make up
```

Complete cleanup (removes all data and volumes):

```bash
make clean
```

Check cluster status:

```bash
make status
```

View logs:

```bash
make logs
```

### Live Configuration Updates

With the `etc_slurm` volume mounted, you can modify configurations without rebuilding:

**Method 1 - Direct editing:**
```bash
# The /etc/slurm directory is mounted from ./volumes/etc_slurm
vi volumes/etc_slurm/slurm.conf
make reload-slurm
```

**Method 2 - Edit files from within the container:**
```bash
[root@slurmctld data]# vi /etc/slurm/slurm.conf 
[root@slurmctld data]# scontrol reconfigure
```

This makes it easy to add/remove nodes or test new configuration settings dynamically.

## 📄 License

This project is licensed under the [MIT License](LICENSE).
