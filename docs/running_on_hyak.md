# Guide to Run the Exposure Workflow on HPC (Hyak)

This guide ensures that anyone starting from scratch can transfer their
`data-raw/` directory from their local machine to Hyak (Klone), verify the
files, and run the `biodiversity-horizons` workflow inside Apptainer. If you're
new to Hyak, you can refer to the official
[Get Started with Hyak](https://hyak.uw.edu/docs/) guide.

---

## Step 1: Log in to Hyak (Klone)

- Open a terminal on your local machine and connect to Hyak:

```
ssh <UWNetid>@klone.hyak.uw.edu
```

#### OPTIONAL: Allocate Resources for Parallel Execution

If you plan to use parallel execution, allocate resources before running the
workflow:

```
salloc --partition=ckpt-all --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=10G --time=2:00:00
```

You can replace `cpus-per-task` with the number of CPU cores you need.

- Create and navigate to your Hyak storage directory:

```
mkdir <UWNetid>
cd <UWNetid>
cd /gscratch/scrubbed/<UWNetid>/
```

- Create the `basics` and `data-raw/` directory (this is where .sif and data
  files will be stored):

```
mkdir -p /gscratch/scrubbed/<UWNetid>/basics
mkdir -p /gscratch/scrubbed/<UWNetid>/data-raw
mkdir -p /gscratch/scrubbed/<UWNetid>/data-raw/bien_ranges/processed
```

- Verify the directory exists:

```
ls -l /gscratch/scrubbed/<UWNetid>/
```

## Step 2: Transfer Data from Local Machine to Hyak

### Transfer using scp (Secure Copy)

- On your local machine, navigate to where your `data-raw/` directory is stored:

```
cd ~/Desktop/biodiversity-horizons/
```

- If it does not exist, create `outputs/` directory.

```
mkdir outputs
```

- Use the `scp` command to copy the entire `data-raw/` and `outputs/` folder to
  Hyak:

```
scp -r data-raw <UWNetid>@klone.hyak.uw.edu:/gscratch/scrubbed/<UWNetid>/
```

```
scp -r outputs <UWNetid>@klone.hyak.uw.edu:/gscratch/scrubbed/<UWNetid>/
```

- Use the `rsync` command to transfer BIEN ranges data from local (replace local
  path with your own directory where BIEN ranges are stored) to Hyak:

- Transfer `manifest` file (From local directory to Hyak):

```
rsync -avz ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/manifest/ <UWNetid>@klone.hyak.uw.edu:/gscratch/scrubbed/<UWNetid>/data-raw/manifest/
```

- Transfer `tif` files (From local directory to Hyak):

```
rsync -avz ~/Desktop/home/bsc23001/projects/bien_ranges/data/oct18_10k/tifs <UWNetid>@klone.hyak.uw.edu:/gscratch/scrubbed/<UWNetid>/data-raw/tifs/
```

Enter your Hyak password when prompted.

## Step 3: Verify the Data Transfer on Hyak

- Once the transfer is complete, log back into Hyak (if not already):

```
ssh <UWNetid>@klone.hyak.uw.edu
```

- Check if the `data-raw/` and `outputs/` directories are present in your Hyak
  storage:

```
ls -l /gscratch/scrubbed/<UWNetid>/data-raw/
```

```
ls -l /gscratch/scrubbed/<UWNetid>/outputs/
```

If you see your `.rds` and other data files inside `data-raw/`, the transfer was
successful.

## Step 4: Pull the .sif Image on Hyak from Container registry

```
apptainer pull /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif \
    docker://ghcr.io/uw-ssec/biodiversityhorizons:latest
```

Alternatively, try with Singularity:

```
singularity pull /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif \
    docker://ghcr.io/uw-ssec/biodiversityhorizons:latest
```

Verify the download:

```
ls -l /gscratch/scrubbed/<UWNetid>/basics/
```

## Step 5: Running on HPC (Hyak) with MPI

(Skip to Step 6 if you don't want to use MPI)

On high-performance clusters like Hyak, you can run the workflow using Apptainer
and MPI to scale across multiple nodes or cores.

#### 1. Allocate Resources with `salloc`

Use the following example to allocate 2 nodes with 2 tasks (MPI ranks) each:

```bash
salloc --partition=ckpt-all --nodes=2 --ntasks=2 --cpus-per-task=2 --mem=10G --time=2:00:00
```

Make sure `--ntasks` matches the number of MPI ranks you plan to run.

#### 2. After allocation, launch the workflow using mpiexec:

```
mpiexec -n 2 apptainer exec \
  --pwd /home/biodiversity-horizons \
  --bind /gscratch/scrubbed/<netid>/data-raw:/home/biodiversity-horizons/data-raw \
  --bind /gscratch/scrubbed/<netid>/outputs:/home/biodiversity-horizons/outputs \
  /gscratch/scrubbed/<netid>/basics/biodiversityhorizons_latest.sif \
  Rscript scripts/main.R exposure -i data-raw/shp_config.yml --workers 2
```

You can use `bien_config.yml` in place of `shp_config.yml` to run the BIEN
workflow.

## Step 6: Run Apptainer with the Transferred Data (If not using MPI)

- Start an Apptainer shell with the correct bind paths:

```
apptainer shell --bind /gscratch/scrubbed/<UWNetid>/data-raw:/home/biodiversity-horizons/data-raw,/gscratch/scrubbed/<UWNetid>/outputs:/home/biodiversity-horizons/outputs \
    /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif
```

Alternatively, try with Singularity:

```
singularity shell --bind /gscratch/scrubbed/<UWNetid>/data-raw:/home/biodiversity-horizons/data-raw,/gscratch/scrubbed/<UWNetid>/outputs:/home/biodiversity-horizons/outputs \
    /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif
```

You should now see the `Apptainer>` prompt.

Inside the Apptainer shell, verify the `data-raw/` and `outputs/` folders are
available:

```
ls -l /home/biodiversity-horizons/data-raw/
```

```
ls -l /home/biodiversity-horizons/outputs/
```

## Step 7: Navigate to the Project Directory

Move to the `biodiversity-horizons` directory inside the container:

```
cd /home/biodiversity-horizons
```

## Step 8: Run BIEN Species Conversion Utility (Optional: If want to process BIEN Ranges)

```
Rscript scripts/main.R convert_bienranges \
  --manifest data-raw/manifest \
  --ranges data-raw/tifs \
  --grid data-raw/global_grid.tif \
  --output data-raw/bien_ranges/processed \
  --parallel TRUE \
  --workers 8
```

After the command completes, you should see `.parquet` files inside
`data-raw/bien_ranges/processed/`

## Step 9: Run the Exposure Workflow Script

Run with Default Arguments in `config.yml`

For BIEN Ranges:

```
Rscript scripts/main.R exposure -i data-raw/bien_config.yml
```

For SHP:

```
Rscript scripts/main.R exposure -i data-raw/shp_config.yml
```

## Step 10: Exit the Container

```
exit
```
