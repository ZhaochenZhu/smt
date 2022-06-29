#!/bin/bash
solverPath=""
#inputPath="/home/marh/SPR/VLSIJ/CFET/PNR_4.5T_Extend/inputsSMT_cfet" 	# yuw
inputPath="/home/yuwcse/Desktop/Github/smt/inputsSMT_cfet"
#inputPath="/home/marh/SPR/VLSIJ/CFET/PNR_4.5T/inputsSMT_cfet_exp1_mpo2_wopinfix"
#outputPath="/home/marh/SPR/VLSIJ/CFET/PNR_4.5T_Extend/RUN_cfet"		# yuw
outputPath="/home/yuwcse/Desktop/Github/smt/CFET/PNR_4.5T_Extend/RUN_cfet"
#LefPath="/home/marh/ConvtoLef/input_cfet_exp3_wopinfix_mpo3"
#LefPath="./solutionsSMT_cfet_exp3_loc0_wopinfix_offtrack8"
#LefPath="./solutionsSMT_cfet_exp1_loc0_wopinfix_offtrack8"
#LefPath="./solutionsSMT_cfet_exp1_loc1_woM2min_offtrack8_0"
LefPath="./home/yuwcse/Desktop/Github/smt/CFET/PNR_4.5T_Extend/solutionsSMT_cfet"
timeout=864000
nThreads="4"
#RandomSeed="17" # DFF
#RandomSeed="4" 
#RandomSeed="37"
RandomSeed="0"
maxmemory="240000"
solver=(
		"z3 -v:1 -st sat.threads=$nThreads sat.random_seed=$RandomSeed"
		)
ceil() {
	echo "define ceil (x) {if (x<0) {return x/1}\
		  else {if (scale(x)==0) {return x} \
		else {return x/1 +1 }}} ; ceil($1)" | bc
}
# Verify Parameters
if [ -d $inputPath ]
then
	echo "Input File Path [$inputPath] Verified"
else
	echo "Input File Path [$inputPath] Does not exists"
	exit -1
fi
if [ -d $outputPath ]
then
	echo "Output File Path [$outputPath] Verified"
else
	echo "Output File Path [$outputPath] Does not exists"
	while [[ $var_con != "y" && $var_con != "n" ]]; do
		read -p "Create Output Folder?(y/n): " var_con
	done
	if [ $var_con = "n" ]
	then
		echo "Check the Output File Path"
		exit -1
	else
		mkdir $outputPath
		if [ -d $outputPath ]
		then
			echo "Output File Path Created...[$outputPath]"
		else
			echo "Output File Path Creation Failed...[$outputPath]"
			exit -1
		fi
	fi
fi
var_con=""
for s in "${solver[@]}"
do
	arrSolver=( $s )
done
echo ""
if [ -z $1 ]
then 
	exit -1
fi
inputFile=$1

# Input target input file parameters
while [[ $inputFile = "" ]]; do
	read -p "Enter input file to solve: " inputFile
done

arrFile=( `cat $inputFile` )

arrInput=()
echo ""

#Target Input File Confirm
echo "Target Input File List"
for w in "${arrFile[@]}"
do
	if [ -f "$inputPath/$w.smt2" ]
	then
		echo "$w.smt2"
		arrInput+=($w)
	fi
done
echo ""
echo "Solver Option : MaxThreads=$nThreads, MaxMemory=${maxmemory}MB, Timeout=${timeout}s"
#while [[ $var_con != "y" && $var_con != "n" ]]; do
#	read -p "Run SMT Solver?(y/n): " var_con
#done
var_con="y"
if [ $var_con = "n" ]
then
	echo "Exit"
	exit -1
fi

#Solv Target Input Files
for i in "${arrInput[@]}"
do
	pinfile=${i:0:${#i}-3}
	input=$i.smt2
	output=$outputPath/$i.res
	runtimeout=$timeout
	timestamp=`date "+%Y%m%d_%H%M%S"`
	if [ -f $output ]
	then
		mv $output ${output}_$timestamp
	fi
	echo "Input File : $input"
	for s in "${solver[@]}"
	do
		arrCommand=( $s )
		tmp_out=$outputPath/$i.${arrCommand[0]}
		if [ -f $tmp_out ]
		then
			mv $tmp_out ${tmp_out}_$timestamp
		fi
		echo "Running SMT Solver[${arrCommand[0]}]"
		timeout ${runtimeout}s $s $inputPath/$input > $tmp_out
		if [ $? -eq 124 ]
		then
			echo "[${arrCommand[0]}] Timed Out[$runtimeout]"
			echo "${arrCommand[0]}, UNKNOWN, Timeout" >> $output
		else
			runtime=`awk '/:time/{print $2}' $tmp_out`
			res=`awk '/sat$/{print $1}' $tmp_out`
			re='^[0-9.]+$'
			if [[ $runtime =~ $re ]]
			then
				echo "[${arrCommand[0]}] Finished, Result = $res, RunTime = $runtime"
				echo "${arrCommand[0]}, $res, $runtime" >> $output
			else
				echo "[${arrCommand[0]}] Abnormally Finished"
				echo "${arrCommand[0]}, ABNORMAL, ABNORMAL" >> $output
			fi
		fi
		echo ""
	done
	# Conv the file
	./convSMT_cfet_v1.0.sh $i $pinfile $LefPath
done
