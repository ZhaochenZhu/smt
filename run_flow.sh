#!/bin/bash

export workdir=~/Desktop/Github/smt/CFET/PNR_4.5T_Extend

# Step 1
$workdir/scripts/genTestCase_cfet_v2.b.pl ./Library/ASAP7_PDKandLIB_v1p5/asap7libs_24/cdl/lvs/asap7_75t_R.cdl 3
cp -a ./pinLayouts_cfet_v2.1/. $workdir/pinLayouts_cfet 

# Step 2
testcase_dir=./pinLayouts_cfet_v2.1

for entry in "$testcase_dir"/*; do
  echo "$entry"
  $workdir/scripts/genSMTInput_Ver2.6_cfet.pl $entry 0 1 0 1 1 1 1 2 3 4 1 2 1 0 0 1 1 1 2
done

smt_dir=./inputsSMT_cfet

for entry in "$smt_dir"/*; do
  basename $entry .smt2 >> $workdir/list_cfet_all
done

# Step 3
cd $workdir
./run_smt_cfet_forLef2.sh list_cfet_all

cd -

# Step 4
cd ./ConvtoLef
python3 generate_cfet_v4.0.py 48 84 coreSite 2 "$workdir/solutionsSMT_cfet/" "./output"
