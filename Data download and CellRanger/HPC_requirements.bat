#!/bin/bash

#SBATCH --job-name=scRNAseq_analysis 
#SBATCH --output=scRNAseq.log
#SBATCH --error=scRNAseq_error.log
#SBATCH --partition=defq
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=48
#SBATCH --mem=192GB
#SBATCH --time=48:00:00
#SBATCH --mail-type=END
#SBATCH --mail-user=mbzir@nottingham.ac.uk

export PATH=/gpfs01/home/mbzir/githubdownloads/sratoolkit.3.1.1-ubuntu64/bin:$PATH
export PATH=/gpfs01/home/mbzir/githubdownloads/cellranger-8.0.1/bin:$PATH
 
cd /gpfs01/home/mbzir

bash scRNAseq.sh ## For additional information please visit the file 'Data_download_CellRanger.bat'