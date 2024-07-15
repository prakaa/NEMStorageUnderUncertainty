#!/bin/sh
for energy in 100
do
for powerratio in 0.125 0.25 0.5 1 2 4 8
do
power=$(echo "$energy*$powerratio" | bc -l)
for file in pbs/arbthroughputlimited_nodeg/*
do
qsub -v "power=$power,energy=$energy" $file
sleep 1m
done
done
done