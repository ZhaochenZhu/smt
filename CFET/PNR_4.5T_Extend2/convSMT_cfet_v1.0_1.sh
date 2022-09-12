#!/bin/bash
# Input target input file parameters
if [ $# -gt 0 ]; then
	infile="$1"
	echo $infile
	cellname="$2"
	echo $cellname
fi
while [[ $infile = "" ]]; do
	read -p "Enter Option input pinLayout designName: " infile
done

./scripts/convSMTResult_Ver1.6.pl RUN_cfet/$infile.z3 $cellname "/home/marh/ConvtoLef/input_cfet_LOC_BS"
