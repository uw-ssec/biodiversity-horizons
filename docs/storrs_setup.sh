
# Adapting instructions for Hayak to Storrs
# https://github.com/uw-ssec/biodiversity-horizons/blob/main/docs/running_on_hyak.md

#----
#---- Local
#----

pd=~/projects/exposure
biosrc=$pd/src/biodiversity-horizons
# Make sure the repo is up to date
git -C $biosrc pull

pdr=${pd/$HOME/'~'}

# Make the directory and upload data-raw
ssh storrs "mkdir -p $pdr/data"

scp -r $biosrc/data-raw storrs:$pdr/data

# Also set up the output directory here
ssh storrs "mkdir -p $pdr/analysis/outputs"

#----
#---- Storrs
#----

ssh storrs

pd=~/projects/exposure

cd $pd

ls -l $pd/data/data-raw
ls -l $pd/data/basics
ls -l $pd/analysis/outputs

# Run apptainer in a compute node
# salloc was doing strange things, so I just used srun. Maybe try salloc followed by srun --pty bash
#salloc --partition=debug --nodes=1 --ntasks=1 --cpus-per-task=4 --mem=10G --time=30

srun -n 4 --mem 30GB -p debug --pty bash

pd=~/projects/exposure

cd $pd

module unload gcc
module load apptainer


apptainer --version #apptainer version 1.1.3

#---- Get the sif file

#I had to add --disable-cache to get this to work
# builds in ~8 min on a login node
apptainer pull --disable-cache $pd/data/basics/biodiversityhorizons_latest.sif \
    docker://ghcr.io/uw-ssec/biodiversityhorizons:latest

# $HOME is mounted by default, unless set up differently in the system configuration
# See: https://apptainer.org/docs/user/main/bind_paths_and_mounts.html
# This appears to be the case on storrs
# Where is the setting?
apptainer config global --get "bind path" #/etc/localtime,/etc/hosts
echo $APPTAINER_BIND # empty
echo $APPTAINER_BINDPATH # empty

# Here is the setting
apptainer config global --get "mount home" #Set to "yes"

# So, add --no-home to avoid the home directory being mounted
# Also, apptainer> $HOME is still set to home directory
# You can't change it using --env HOME=/home/biodiversity-horizons in the shell call,
#  you get a warning. But you may be able to set it in the container definition file

# Need to add --unsquash to get the bind to work
# And --no-home to avoid the home directory being mounted
# Also had to mount outputs
# can add --debug

#=== First approach
# This approach both builds the sandbox (unsquash) and runs the container
# But it is very slow (feels like a couple minutes), since it has the build the sandbox every time
# Also super slow when exiting
apptainer shell --cleanenv --no-home \
  --bind $pd/data/data-raw:/home/biodiversity-horizons/data-raw --unsquash \
  --bind $pd/analysis/outputs:/home/biodiversity-horizons/outputs --unsquash \
    $pd/data/basics/biodiversityhorizons_latest.sif

#=== Better approach
# Alternative approach build the sandbox as a separate step, so you only do it once
apptainer build --disable-cache --sandbox $pd/data/basics/bh_sandbox \
  $pd/data/basics/biodiversityhorizons_latest.sif

# Now run the sandbox, note lack of --unsquash. Environment opens immediately!
apptainer shell --cleanenv --no-home \
  --bind $pd/data/data-raw:/home/biodiversity-horizons/data-raw \
  --bind $pd/analysis/outputs:/home/biodiversity-horizons/outputs \
    $pd/data/basics/bh_sandbox

ls -l /home/biodiversity-horizons/data-raw/
ls -l /home/biodiversity-horizons/outputs/

cd /home/biodiversity-horizons

env # This shows all environment variables
env | grep HOME #Filter to show that HOME is still set to my local home directory

#Try setting this by default in the container definition file so you don't have to do this
# %environment
#     export HOME=/home/biodiversity-horizons

HOME=/home/biodiversity-horizons

#=== Best approach

# Build sandbox first, as above
# Then, set the home directory when launching apptainer
apptainer shell --cleanenv \
  --no-home --home /home/biodiversity-horizons \
  --bind $pd/data/data-raw:/home/biodiversity-horizons/data-raw \
  --bind $pd/analysis/outputs:/home/biodiversity-horizons/outputs \
    $pd/data/basics/bh_sandbox

Rscript scripts/main.R exposure -i data-raw/input_config.yml
