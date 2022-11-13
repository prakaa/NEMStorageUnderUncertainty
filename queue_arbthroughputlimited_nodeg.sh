#!/bin/sh
for file in pbs/arbthroughputlimited_nodeg/*
do
qsub $file
done