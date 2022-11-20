#!/bin/sh

# costs roughly reflect a range of build costs for BESS of varuious storage duration as outlined in AEMO I&A 2021 Workbook
# for 2020-2021, costs in $/kW are ~800 $/kW (1 hr storage) and ~3000 $/kW (8 hour storage)
# translating to energy capacity, 800,000 $/MWh and 375,000 $/MWh

for energy in 100
do
for cost in 200000.0 400000.0 600000.0 800000.0
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