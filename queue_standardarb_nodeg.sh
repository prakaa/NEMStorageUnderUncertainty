#!/bin/sh
for file in pbs/standardarb_nodeg/*
do
qsub $file
done