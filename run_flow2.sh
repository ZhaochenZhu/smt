#!/bin/bash

export workdir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# export workdir="$workdir/CFET/PNR_4.5T_Extend"
export workdir="$workdir/CFET/PNR_4.5T_Extend2"

# Step 1
echo "********** Generating Testcase **********"
echo "genTestCase_cfet.pl [.cdl file] [$offset]"
$workdir/scripts/genTestCase_cfet_v2.1.pl ./Library/ASAP7_PDKandLIB_v1p5/asap7libs_24/cdl/lvs/asap7_75t_R.cdl 3
cp -a ./pinLayouts_cfet_v2.1/. $workdir/pinLayouts_cfet 

# Step 2
echo "********** Generating SMT Input **********"
echo "genSMTInput_cfet.pl [.pinLayout file] [$BoundaryCondition] [$SON] [$DoublePowerRail] [$MAR_Parameter] [$EOL_Parameter] [$VR_Parameter] [$PRL_Parameter] [$SHR_Parameter] [$XOL_Parameter] [$MPL_Parameter] [$MM_Parameter] [$Local_Parameter] [$Partition_Parameter] [$BCP_Parameter] [$NDE_Parameter] [$BS_Parameter] [$PE_Parameter] [$M2_TRACK_Parameter] [$M2_Length_Parameter] [$Dint]\n\n"
testcase_dir=./pinLayouts_cfet_v2.1

for entry in "$testcase_dir"/*; do
  echo "$entry"
  $workdir/scripts/genSMTInput_Ver2.6_cfet.pl $entry 0 1 0 1 1 1 1 2 3 4 1 2 1 0 0 1 1 1 2
done

# for entry in "$testcase_dir"/*; do
#   echo "$entry"
#   $workdir/scripts/genSMTInput_Ver2.7_cfet.pl $entry 0 1 0 1 1 1 1 2 3 4 1 2 1 0 0 1 1 1 2
# done

smt_dir=./inputsSMT_cfet

for entry in "$smt_dir"/*; do
  basename $entry .smt2 >> $workdir/list_cfet_all
done

# for entry in "$smt_dir"/*; do
#   basename $entry .smt2 >> $workdir/list_cfet_all_testing
# done

# Step 3
echo "********** Generating Z3 Solution **********"
echo "run_smt_cfet_forLef3.sh list_cfet_all"
cd $workdir
./run_smt_cfet_forLef3.sh list_cfet_all
cd -

# Step 4
echo "********** Generating LEF file **********"
echo "python generate.py [$metalPitch] [$cppWidth] [$siteName] [$mpoMode]"
cd ./ConvtoLef
python3 generate_cfet_v6.0.py 48 84 coreSite 2 "$workdir/solutionsSMT_cfet/" "./output"
