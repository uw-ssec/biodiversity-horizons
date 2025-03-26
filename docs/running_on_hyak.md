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

- Use the `scp` command to copy the entire `data-raw/` folder to Hyak:

```
scp -r data-raw <UWNetid>@klone.hyak.uw.edu:/gscratch/scrubbed/<UWNetid>/
```

Enter your Hyak password when prompted.

## Step 3: Verify the Data Transfer on Hyak

- Once the transfer is complete, log back into Hyak (if not already):

```
ssh <UWNetid>@klone.hyak.uw.edu
```

- Check if the `data-raw/` directory is present in your Hyak storage:

```
ls -l /gscratch/scrubbed/<UWNetid>/data-raw/
```

If you see your `.rds` and other data files inside `data-raw/`, the transfer was
successful.

## Step 4: Pull the .sif Image on Hyak from Container registry

```
apptainer pull /gscratch/scrubbed/<<UWNetid>/basics/biodiversityhorizons_latest.sif \
    docker://ghcr.io/uw-ssec/biodiversityhorizons:latest
```

Alternatively, try with Singularity:

```
singularity pull /gscratch/scrubbed/<<UWNetid>/basics/biodiversityhorizons_latest.sif \
    docker://ghcr.io/uw-ssec/biodiversityhorizons:latest
```

Verify the download:

```
ls -l /gscratch/scrubbed/<UWNetid>/basics/
```

## Step 5: Run Apptainer with the Transferred Data

- Start an Apptainer shell with the correct bind paths:

```
apptainer shell --bind /gscratch/scrubbed/<UWNetid>/data-raw:/home/biodiversity-horizons/data-raw \
    /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif
```

Alternatively, try with Singularity:

```
singularity shell --bind /gscratch/scrubbed/<UWNetid>/data-raw:/home/biodiversity-horizons/data-raw \
    /gscratch/scrubbed/<UWNetid>/basics/biodiversityhorizons_latest.sif
```

You should now see the `Apptainer>` prompt.

Inside the Apptainer shell, verify the `data-raw/` folder is available:

```
ls -l /home/biodiversity-horizons/data-raw/
```

## Step 6: Navigate to the Project Directory

Move to the `biodiversity-horizons` directory inside the container:

```
cd /home/biodiversity-horizons
```

## Step 7: Run the R Script

Run with Default Arguments in input_config.yml


```
Rscript scripts/main.R exposure -i data-raw/input_config.yml
```

## Step 8: Exit the Container

```
exit
```
