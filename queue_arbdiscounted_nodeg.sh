#!/bin/sh

# Simulate exp and hyp discounting for each power/energy combination

for energy in 100
do
for func in "hyp" "exp"
do
for powerratio in 0.125 0.25 0.5 1 2 4 8
do
power=$(echo "$energy*$powerratio" | bc -l)
for file in pbs/arbdiscounted_nodeg/*
do
qsub -v "power=$power,energy=$energy,func=$func" $file
sleep 90s
done
done
done
done