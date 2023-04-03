#!/bin/sh

# Simulate 4 different degrees of cap contracting
# 0% of power rating (equivalent to arbthroughputpenalty with penalty of 500,000 AUD/MWh)
# 50% of power rating
# 100% of power rating
# 200% of power rating

for energy in 100
do
for cap_frac in 0.0 0.5 1.0 2.0
do
for powerratio in 0.125 0.25 0.5 1 2 4 8
do
power=$(echo "$energy*$powerratio" | bc -l)
cap=$(echo "$power*$cap_frac$" | bc -l)
for file in pbs/arbcapcontracted_nodeg/*
do
qsub -v "power=$power,energy=$energy,cap=$cap" $file
sleep 30s
done
done
done
done