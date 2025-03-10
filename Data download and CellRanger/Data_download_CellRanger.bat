#!/bin/bash

WORKING_DIR="/path/" ## Define path to working directory
IDENTIFIERS_FILE="$WORKING_DIR/identifiers.txt" ## Define the path to the file containing the identifiers to download
TRANSCRIPTOME_PATH="$WORKING_DIR/Drerio_genome" ## Path to the reference transcriptome

## Decompress the GFT file
GTF_FILE="$TRANSCRIPTOME_PATH/genes/genes.gtf.gz" ## Define the path to the compressed GTF file containing the transcript names
if [[ -f "$GTF_FILE" ]]; then ## Check if the GTF file exists
    gunzip "$GTF_FILE" ## Decompress the GTF file
    if [[ $? -ne 0 ]]; then
        echo "Error decompressing GTF file: $GTF_FILE" ## Print error message if gunzip was not successful in decompressing the GFT file
        exit 1 ## Exit with error code 1
    fi
    GTF_FILE="${GTF_FILE%.gz}" ## Remove the .gz extension from the filename
fi

## Check command status and error logs
check_status() {
    if [[ $1 -ne 0 ]]; then ## Check if the command's exit code is non-zero (error)
        echo "Error: $2" ## Print the error message provided as the second argument
        exit 1 ## Exit with error code 1
    fi
}

## Check commands are available
for cmd in prefetch fastq-dump gzip cellranger; do
    command -v $cmd >/dev/null 2>&1 || { echo "Command $cmd not found. Aborting."; exit 1; } ## Check if each command exists, exit if not
done

## Read each line (identifier) from the file
while IFS= read -r identifier; do
    trimmed_identifier=$(echo "$identifier" | xargs) ## Trim leading and trailing whitespace

    ## Create a directory for each identifier if it's not empty
    if [[ -n "$trimmed_identifier" ]]; then ## Check if the trimmed identifier is not empty
	    out_path="$WORKING_DIR/$trimmed_identifier" ## Define the output directory for the identifier

        ## Use prefetch to download the data
        echo "Starting prefetch for $trimmed_identifier"
        time prefetch "$trimmed_identifier" -O "$out_path" --max-size u ## Download sample information using prefetch, save to output directory, set max size to unlimited
        check_status $? "prefetch failed for $trimmed_identifier" ## Check if prefetch was successful
        echo "Completed prefetch for $trimmed_identifier"

	    ## Use fastq-dump to download a portion of the data and split files
	    echo "Starting fastq-dump for $trimmed_identifier"
	    time fastq-dump "$out_path/$trimmed_identifier" --split-files --outdir "$out_path/fastq_files/" -v ## Download FASTQ data using fastq-dump, split files, save to fastq_files directory
	    check_status $? "fastq-dump failed for $trimmed_identifier" ## Check if fastq-dump was successful
        echo "Completed fastq-dump for $trimmed_identifier"

	    ## Compress the FASTQ files
	    echo "Compressing FASTQ files for $trimmed_identifier"
        cd "$out_path/fastq_files" ## Change directory to fastq_files folder
        check_status $? "Failed to change directory to $out_path/fastq_files" ## Check if cd was successful
        
        for file in *.fastq; do ## Loop through all fastq files
            gzip "$file" ## Compress the file using gzip
            check_status $? "Failed to compress $file" ## Check if gzip was successful
        done

        ## Rename the FASTQ files
        echo "Renaming FASTQ files for $trimmed_identifier"
        files=($(ls -S *.fastq.gz))  ## List files by size ## List files by size, store in array
        ## For additional information please visit: https://www.10xgenomics.com/support/software/cell-ranger/latest/analysis/inputs/cr-specifying-fastqs (FASTQ file naming convention)

        mv "${files[0]}" "${trimmed_identifier}_S1_R2_001.fastq.gz"
	    check_status $? "Failed to rename ${files[0]}"
        mv "${files[1]}" "${trimmed_identifier}_S1_R1_001.fastq.gz" 
	    check_status $? "Failed to rename ${files[1]}"
        mv "${files[2]}" "${trimmed_identifier}_S1_I1_001.fastq.gz" 
	    check_status $? "Failed to rename ${files[2]}"
        mv "${files[3]}" "${trimmed_identifier}_S1_I2_001.fastq.gz" ## Remove this line if the original FASTQ file only contains one identifier
	    check_status $? "Failed to rename ${files[3]}" ## Remove this line if the original FASTQ file only contains one identifier

        ## Run cellranger count
	    echo "Starting CellRanger for $trimmed_identifier"
        time cellranger count \
            --id="$trimmed_identifier" \ ## Set the sample ID
            --transcriptome="$TRANSCRIPTOME_PATH" \ ## Set the path to the reference transcriptome
            --fastqs="$out_path/fastq_files/" \ ## Set the FASTQ file directory
            --output-dir="$out_path/cellranger/" \ ## Set the output directory
            ## --r1-length=26 \ ## Run this line if the original FASTQ files present reads smaller than 28bp (default 10X)
            --create-bam=true \ ## Create a BAM file
	        --include-introns=true \ ## Include introns in the analysis

    fi

done < "$IDENTIFIERS_FILE"

echo "Processing completed successfully." ## Print completion message
