#!/bin/sh

# Simulate 4 different degrees of cap contracting
# 0 MW (equivalent to arbthroughputpenalty with penalty of 500,000 AUD/MWh)
# 25 MW
# 50 MW
# 100 MW
# 200 MW
# 400 MW
# 800 MW
# Restrict modelled power ratings to 25 MW, 100 MW, 400 MW

for energy in 100
do
for cap_mw in 0.0 25.0 50.0 100.0 200.0 400.0 800.0
do
for powerratio in 0.25 1 4
do
power=$(echo "$energy*$powerratio" | bc -l)
for file in pbs/arbcapcontracted_nodeg/*
do
qsub -v "power=$power,energy=$energy,cap=$cap_mw" $file
sleep 30s
done
done
done
done