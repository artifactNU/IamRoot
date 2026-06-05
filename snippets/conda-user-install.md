# Miniconda user install + first environment

Quick reference for installing Miniconda for a single Linux user, configuring sane defaults, and creating a first conda-forge environment.

**Dependencies:**
wget, bash

---

## Switch to the target user

```bash
sudo -iu <username>
```

---

## Install Miniconda in user home

```bash
cd /tmp
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh -b -p ~/miniconda3
~/miniconda3/bin/conda init bash
exec bash
```

---

## Accept defaults and set channel policy

```bash
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r
conda config --add channels conda-forge
conda config --set channel_priority strict
conda config --set auto_activate_base false
conda config --show auto_activate_base
```

---

## Create and test an environment (example: RDKit)

```bash
conda create -y -n rdkit -c conda-forge python=3.11 rdkit
conda activate rdkit
python -c "from rdkit import Chem; print(Chem.MolFromSmiles('CCO'))"
conda deactivate
```

---

## Update and inspect environments

```bash
conda update -n base conda
conda update -n rdkit -c conda-forge --all
conda env list
```