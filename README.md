*This Guide is slightly deviated from Mark Ho's procedures. However, it follows the exact step you see on Github.*
*I will refer ./CFET/PNR_4.5T_Extend as $workdir*

# Step 1
-	Make sure you start at /smt directory
-	RUN COMMAND: $workdir/scripts/genTestCase_cfet_v2.1.pl ./Library/ASAP7_PDKandLIB_v1p5/asap7libs_24/cdl/lvs/asap7_75t_R.cdl 3
-	Now you may find the pinlayout file under ./pinLayouts_cfet_v2.1
-	Copy this folder to $workdir and change the name to ./pinLayouts_cfet, this will be used in the .z3 conversion

# Step 2
-	RUN COMMAND: 
-	Now you may find the .smt2 file under ./inputsSMT_cfet, you are ready to use Z3 solver
-	Install Z3 solver following *https://pypi.org/project/z3-solver/*

# Step 3
-	Go inside $workdir
-	Under $workdir/scripts Make sure you have Perl script named as *convSMTResult_Ver1.6.pl* which will convert the .z3 to .conv
-	Create a file called *list_cfet_all* while listing all required .smt2 filename (without file type)
-	Open *run_smt_cfet_forLef2.sh*. On the top, change the paths corresponding to your host machine.
-	RUN COMMAND: ./run_smt_cfet_forLef2.sh list_cfet_all
-	Ignore the error you see about "cp: cannot create regular file"
-	The intermediate .z3 solution is saved under $workdir/RUN_cfet/
-	Now you may find the converted output under folder $workdir/solutionsSMT_cfet/	[these can be changed from substep 4]
-	This is the converted cell layout solution file from SMT result file .z3 

# Step 4
-	Back out to the /smt directory
-	RUN COMMAND: python3 ./ConvtoLef/generate_cfet_v4.0.py 48 84 coreSite 2 "./CFET/PNR_4.5T_Extend/pinLayouts_cfet/" "[your_out_dir]"
-	Now you may find the .lef file in your output directory

COMMENT:
[YW] I know lot of the steps are awkward because the naming scheme of the original folder. We can change the script once we have a better understanding the code structure.



