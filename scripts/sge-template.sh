#!/bin/sh
#$ -S /bin/sh
#$ -cwd
#$ -o output.error
#$ -e output.error
#$ -j y
#$ -l scratch=1G -l netappsali=1G
#$ -r y
#$ -N loop
#$ -p -4
#$ -t 1-iteration

input="loop-@JOBID@.py"
output="${SGE_TASK_ID}.log"

# Create local scratch directory
tmpdir="/scratch/modloop/$JOB_ID/$SGE_TASK_ID"
mkdir -p $tmpdir
cd $tmpdir

# Get input files
cp DIR/$input DIR/pdb*AF*pdb .

/salilab/diva1/home/modeller/mod9v7 - ${SGE_TASK_ID} < $input >& $output

# Copy back PDB
cp *.B* DIR

# Copy back log file (first 5000 lines only, and only for some tasks, in
# case a huge log file was produced):
if [ "${SGE_TASK_ID}" -lt 6 ]; then
  head -5000 $output > DIR/$output
fi

rm -rf $tmpdir
