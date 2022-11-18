#!/bin/sh
for energy in 100
do
for cost in 500.0 1000.0 1500.0 2000.0
do
for powerratio in 0.125 0.25 0.5 1 2 4 8
do
power=$(echo "$energy*$powerratio" | bc -l)
for file in pbs/arbthroughputpenalty_nodeg/*
do
qsub -v "power=$power,energy=$energy,cost=$cost" $file
sleep 30s
done
done
done
done