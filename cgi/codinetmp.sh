#!/bin/csh
#$ -S /bin/csh
#$ -cwd
#$ -o output.error
#$ -e output.error
#$ -j y
#####$ -l cpu600
#$ -l i386=true
#$ -r y
#$ -N loop
#$ -p -4
#$ -t 1-iteration
#####node limitation
#####$ -l modloop

set tasks=( TOPFILES  )

set input=$tasks[$SGE_TASK_ID]

mkdir -p /usr/tmp/andras/$input
cd       /usr/tmp/andras/$input/
cp       /diva2/home/andras/html/tmploop/DIR/*.top* .
cp       /diva2/home/andras/html/tmploop/DIR/pdb*AF*pdb .

mod7v7 $input

cp *.B*  /diva2/home/andras/html/tmploop/DIR/
cp *log  /diva2/home/andras/html/tmploop/DIR/
rm -rf   /usr/tmp/andras/$input

# find best loop
cd       /diva2/home/andras/html/tmploop/DIR/
grep FUNC *.B* | sort -nr +4 | tail -1 | awk -F: '{print $1}' > winner
