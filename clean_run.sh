#!/bin/bash
export workdir=./CFET/PNR_4.5T_Extend

rm -rfv ./pinLayouts_cfet_v2.1 && mkdir pinLayouts_cfet_v2.1
rm -rfv ./inputsSMT_cfet && mkdir inputsSMT_cfet
rm $workdir/list_cfet_all 
rm -rfv $workdir/RUN_cfet && mkdir $workdir/RUN_cfet
rm -rfv $workdir/pinLayouts_cfet && mkdir $workdir/pinLayouts_cfet
rm -rfv $workdir/solutionsSMT_cfet && mkdir $workdir/solutionsSMT_cfet
rm ./ConvtoLef/*.txt
rm ./ConvtoLef/output/*.lef
rm ./ConvtoLef/output/Cell_Metrics.txt
