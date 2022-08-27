#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use POSIX;

use Cwd;

### Revision History : Ver 2.2 #####
# 2019-03-18 SMT Input Code Generator Base Version
# 2019-03-19 V1.1 : Bug Fix for commodity flag
# 2019-03-27 V1.2 : Compact Version(Assume Minimum Number of Finger, Fix y position to the edge of each region)
# 2019-03-27 V1.3 : BitVector, Bool Concept
# 2019-03-27 V1.4 : Bug Fix, Improved reliability
# 2019-04-02 V1.5 : ADD SHR, Removed redundant constraints for placement
# 2019-06-24 V1.8 : Performance Tuning
# 2019-06-24 V1.9 : S/D, Gate Coordinate Change
# 2019-07-03 V2.0 : Removed Capacity Variables
# 2019-10-02 V2.1 : Variable/Clause Compaction(Unit Propagation, False Assignment Removal)
# 2019-10-04 V2.2 : Pin Acc. Modification
# 2020-02-17 V2.2.4 : 1. CFET Dummy G/S/D strucutre as split structure 2. Physical information link back to commodity flow constraints
# 2020-02-18 V2.2.5 : 1. CFET Dummy G/S/D strucutre flag controlled. Dummy_g_struct_flag/Dummy_sd_struct_flag 1. Split, 2. Share
# 2020-02-22 V2.2.6 : Integrate partition to enhance performance
# 2020-02-22 V2.2.7 : Fix COST_SIZE issue: Set COST_SIZE constraint for Dummy G/S/D structure
# 2020-02-22 V2.2.8 : Exculde mutilple M1 nets on same gate column: pin accessibility
# 2020-02-22 V2.3 : Dummy S/D only one possible location for VDD and VSS (Relatively tight constraint compared to V2.3.1)
# 2020-02-22 V2.3.1 : Dummy S/D without instance region can have two possible location
# 2020-02-22 V2.3.2 : Add M2 Track Parameter to control M2 minimization
# 2020-06-05 V2.3.4 : Fix Maximum 1 for internal pin connection
# 2020-06-10 V2.3.5 : Add M2 Length minimization objective function; Cell size>PS>M2 Track>M2 Min>TotalML
# 2020-06-11 V2.3.6 : Add edge-based PS function; PE_parameter = 2
# 2020-07-02 V2.3.7 : Fix via rule at least 1 rules; VR - Via spacing rules
# 2020-07-02 V2.3.8 : Allow double via of same net; VR - Via spacing rules
# 2020-07-02 V2.4 : NFET on PFET control
# 2020-07-14 V2.4.1 : Allow stacked via control; $VR_stacked_via_flag
# 2020-07-14 V2.4.2 : 1. Rewrite PS=1 code for performance; 2. Update PS=2 for more than one interfere col case; 3. DV at same net control ($VR_double_samenet_flag).
# 2020-07-21 V2.4.3 : Add PE_Parameter = 3 => PE=1 +PE=2
# 2020-07-24 V2.4.4 : Consider boundary pin interference
# 2020-07-24 V2.4.4.1 (from v2.4.4) : Fixing Localization Multifinger on gate case
# 2020-08-17 V2.5 (from v2.4.4.1) : Fixing N-on-P shared soure to sink and shared sink to sink mismatch
### Pre-processing ########################################################
my $ARGC        = @ARGV;
my $workdir     = getcwd();
#my $outdir      = "$workdir/inputsSMT_cfet_exp1_mpo2_wopinfix";
#my $outdir      = "$workdir/inputsSMT_cfet_exp3_mpo4_wopinfix";
my $outdir      = "$workdir/inputsSMT_cfet";
my $infile      = "";

my $BoundaryCondition = 0; # ARGV[1], 0: Fixed, 1: Extensible
my $SON = 0;               # ARGV[2], 0: Disable, 1: Enable # [SON Mode] Super Outer Node Simplifying
my $DoublePowerRail = 0;   # ARGV[3], 0: Disable, 1: Enable
my $MAR_Parameter = 0;     # ARGV[4], 2: (Default), Integer
my $EOL_Parameter = 1;     # ARGV[5], 2: (Default), Integer
my $VR_Parameter = 0;      # ARGV[6], sqrt(2)=1.5 : (Default), Floating
my $PRL_Parameter = 0;     # ARGV[7], 1 : (Default). Integer
my $SHR_Parameter = 0;     # ARGV[8], 2 : (Default),  <2 -> No need to implement.
my $XOL_Parameter = 2;      # Should be 2
my $MPL_Parameter = 2;      # ARGV[9], 3: (Default) Other: Maximum Number of MetalLayer
my $MM_Parameter = 3;      # ARGV[10], 3: (Default) Other: Maximum Number of MetalLayer
my $Local_Parameter = 0;     # ARGV[11], 0: Disable(Default) 1: Localization for Internal node within same diffusion region
my $Partition_Parameter = 0;     # ARGV[12], 0: Disable(Default) 1: General Partitioning 2. Manual Partitioning
my $BCP_Parameter = 1;     # ARGV[13], 0: Disable 1: Enable BCP(Default)
my $NDE_Parameter = 0;     # ARGV[14], 0: Disable(Default) 1: Enable NDE
my $BS_Parameter = 0;     # ARGV[15], 0: Disable(Default) 1: Enable BS(Breaking Symmetry)
my $EXT_Parameter = 0;
my $PE_Parameter = 3;	# ARGV[16], 1: Pin Enhancement Function 2: Edge-based Pin Separation 3: Minimize PS=1 and PS=2
my $PE1_newflag = 1;   # 0: use virtual-edge based implementation (old), 1: use edge-based implementation (new) for performance (AND3x2, OR3x2, AOI22x1)
my $M2_TRACK_Parameter = 1; # ARGV[17], 1: M2 track minimization
my $M2_Length_Parameter = 1; # ARGV[18], 1; M2 Length minimization
my $dint = 2; # ARGV[19], 2; Default 1 M1 pitch
my $VR_stacked_via_flag = 0; # 1: Allow stacked via 0: Not allow stacked via
my $VR_double_samenet_flag = 1; # 1: Allow double via for same net; 0: Not allow double via for same net.
# CFET DSS control
my $dummy_g_struct_flag = "Share"; #Identify Dummy structure as Split or Share
my $dummy_sd_struct_flag = "Split"; #Identify Dummy structure as Split or Share
# CFET PFET/NFET control
my $stack_struct_flag = "PN"; #Identify PFET on NFET [PN] or NFET on PFET [NP] ; ICCAD=PN

#my @mapTrack = ([0,5], [1,4], [2,4], [3,1], [4,1], [5,0]);  # Placement vs. Routing Horizontal Track Mapping Array [Placement, Routing]
#my @mapTrack = ([0,5], [1,4]);  # Placement vs. Routing Horizontal Track Mapping Array [Placement, Routing]
my @mapTrack = ([0,3], [1,0]);  # CFET 4 tracks can be used to routing. 2 nanosheets => mapping to top and bottom tracks 
#my @numContact = ([1,2], [2,2], [3,2]);  # Number of Routing Contact for Each Width of FET
my @numContact = ([1,2], [2,2], [3,2]);  # Number of Routing Contact for Each Width of FET; Not used in CFET
my %h_mapTrack = ();
my %h_RTrack = ();
my %h_numCon = ();
for my $i(0 .. $#mapTrack){
#	$h_mapTrack{$mapTrack[$i][1]} = 1;
	$h_RTrack{$mapTrack[$i][0]} = $mapTrack[$i][1];
}

# ref to Mark's thesis: Fig 2.5
print("h_RTrack\n");
print(Dumper\%h_RTrack);
# $VAR1 = {
#           '1' => 0,
#           '0' => 3
#         };

# Maximum routing track index
for my $i(0 .. $mapTrack[0][1]){
	$h_mapTrack{$i} = 1;
}

for my $i(0 .. $#numContact){
	$h_numCon{$numContact[$i][0]} = $numContact[$i][1] - 1;
}

if ($ARGC != 20) {
	print "\n*** Error:: Wrong CMD";
	print "\n   [USAGE]: ./PL_FILE [inputfile_pinLayout] [Boundary, 0: Fixed] [SON, 0: Disable] [Double Power Rail, 0: Disable] [MAR, 2(D)] [EOL, 2(D)] [VR, sqrt(2)(D)] [PRL, 1(D)], [SHR, 2(D)], [MPL, 2(D)], [MM, 3(D)], [LOCAL, 0(D)], [PART, 0(D)], [BCP, 1(D)], [NDE, 0(D)], [BS, 0(D)], [PS, 1(D)], [M2Track, 1[D]], [M2Min, 1[D]], [Dint, 2[D]]\n\n";
	exit(-1);
} else {
	$infile             = $ARGV[0];
	$BoundaryCondition  = $ARGV[1];
	$SON                = $ARGV[2];
	$DoublePowerRail    = $ARGV[3];
	$MAR_Parameter      = $ARGV[4];
	$EOL_Parameter      = $ARGV[5];
	$VR_Parameter       = $ARGV[6];
	$PRL_Parameter      = $ARGV[7];
	$SHR_Parameter      = $ARGV[8];
	$MPL_Parameter       = $ARGV[9];
	$MM_Parameter       = $ARGV[10];
	$Local_Parameter       = $ARGV[11];
	$Partition_Parameter       = $ARGV[12];
	$BCP_Parameter       = $ARGV[13];
	$NDE_Parameter       = $ARGV[14];
	$BS_Parameter       = $ARGV[15];
	$PE_Parameter = $ARGV[16];
	$M2_TRACK_Parameter = $ARGV[17];
	$M2_Length_Parameter = $ARGV[18];
	$dint = $ARGV[19];

	if ($MAR_Parameter == 0){
		print "\n*** Disable MAR (When Parameter == 0) ***\n";
	}
	if ($EOL_Parameter == 0){
		print "\n*** Disable EOL (When Parameter == 0) ***\n";
	}     
	if ( $VR_Parameter == 0){
		print "\n*** Disable VR (When Parameter == 0) ***\n";
	}
	if ( $PRL_Parameter == 0){
		print "\n*** Disable PRL (When Parameter == 0) ***\n";
	}
	if ( $SHR_Parameter < 2){
		print "\n*** Disable SHR (When Parameter <= 1) ***\n";
	}
}

if (!-e "./$infile") {
	print "\n*** Error:: FILE DOES NOT EXIST..\n";
	print "***         $workdir/$infile\n\n";
	exit(-1);
} else {
	print "\n";
	print "a   Version Info : 1.0 Initial Version\n";
	print "a				: 1.1 Bug Fix\n";
	print "a				: 1.3 BV, Bool Employed\n";
	print "a				: 1.4 Bug Fix, Performance Tuning\n";
	print "a				: 1.5 Added SHR, Removed Redundancy in Placement constraints\n";
	print "a				: 1.8 Performance Tuning\n";
	print "a				: 1.9 S/D, Gate Coordinate Change\n";
	print "a				: 2.0 Merged/Removed Capacity Variables\n";
	print "a				: 2.1 Unit Propagation\n";
	print "a				: 2.2 Pin Accessibility Modification\n";
	print "a				: 2.2.5.1 Dummy Structure support and Sink to Sink (Multifingers) Shared Structure\n";
	print "a				: 2.2.5.6 Integrate ver 2.4\n";

	print "a        Design Rule Parameters : [MAR = $MAR_Parameter , EOL = $EOL_Parameter, VR = $VR_Parameter, PRL = $PRL_Parameter, SHR = $SHR_Parameter]\n";
	print "a        Parameter Options : [Boundary = $BoundaryCondition], [SON = $SON], [Double Power Rail = $DoublePowerRail], [MPL = $MPL_Parameter], [Maximum Metal Layer = $MM_Parameter], [Localization = $Local_Parameter]\n";
	print "a	                        [Partitioning = $Partition_Parameter], [BCP = $BCP_Parameter], [NDE = $NDE_Parameter], [BS = $BS_Parameter], [PS = $PE_Parameter], [M2Track = $M2_TRACK_Parameter]\n";
	print "a	                        [M2Length = $M2_Length_Parameter], [Dint = $dint], [Stack = $stack_struct_flag], [DVsamenet = $VR_double_samenet_flag], [Stackvia = $VR_stacked_via_flag]\n\n";

	print "a   Generating SMT-LIB 2.0 Standard inputfile based on the following files.\n";
	print "a     Input Layout:  $workdir/$infile\n";
}

### Output Directory Creation, please see the following reference:
system "mkdir -p $outdir";

my $outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_6T.smt2";
if ($BCP_Parameter == 0){
	$outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_NBCP.smt2";
}
print "a     SMT-LIB2.0 File:    $outfile\n";

my $enc_cfc = 40;
my $enc_euv_1 = 40;
my $enc_euv_2 = 40;

### Variable Declarations
my $width = 0;						# arbitrary 
my $placementRow = 0;				# number of placement row at active layer ?
my $trackEachRow = 0;				# Tracks per Placement Row
my $trackEachPRow = 0;				# Tracks per Placement Clip
my $numTrackH = 0;					# $placementRow * $trackEachRow
my $numTrackV = 0;					# Width of Routing Clip
my $numMetalLayer = $MM_Parameter;  # M1~M4
my $numPTrackH = 0;					# Tracks per Placement Clip
my $numPTrackV = 0;					# Width of Placement Clip
my $tolerance = 5; #default
#my $tolerance = 55; #default
#my $tolerance = 20;
my $tolerance_adj_sameregion = 5;	# not used ???
#my $tolerance_adj_sameregion = 15;
#my $tolerance_adj_diffregion = 1;

### PIN variables
my @pins = ();						# list of pin: push (@pins, [@pin]);
my @pin = ();						# pin information @pin = ($pinName, $pin_netID, $pinIO, $pinLength, $pinXpos, [@pinYpos], $pin_instID, $pin_type);
my $pinName = "";					
my $pin_netID = ""; 
my $pin_instID = "";			
my $pin_type = "";		
my $pin_type_IO = "";		
my $pinIO = "";
my $pinXpos = -1;
my @pinYpos = ();
my $pinLength = -1;
my $pinStart = -1;
my $totalPins = -1;					# length of @pins
my $pinIDX = 0;						
my $pinTotalIDX = 0;
my %h_pin_id = ();
my %h_pin_idx = ();
my %h_pinId_idx = ();
my %h_outpinId_idx = ();
my %h_pin_net = ();

### NET variables
my @nets = ();
my @net = ();
my $netName = "";
my $netID = -1;
my $N_pinNets = 0;
my $numSinks = -1;
my $source_ofNet = "";
my @pins_inNet = ();
my @sinks_inNet = ();
my $totalNets = -1;
my $idx_nets = 0;
my $numNets_org = 0;
my %h_extnets = ();
my %h_idx = ();
my %h_outnets = ();
my %h_net_idx = ();

### Instance variables
my $numInstance = 0;
my $instName = "";
my $instType = "";
my $instWidth = 0;
my $instGroup = 0;
my $instY = 0;
my @inst = ();
my $lastIdxPMOS = -1;
my %h_inst_idx = ();
my @numFinger = ();
my $minWidth = 0;
my @DDA_PMOS = ();			# DDA = (instanceID, FlipFlag)
my @DDA_NMOS = ();			# DDA = (instanceID, FlipFlag)
my $numPowerPmos = 0;		# = $lastIdxPMOS
my $numPowerNmos = 0;		# = $lastIdxPMOS (NMOS)
my @inst_group = ();		# list of [($instName, $instType, $instGroup)]
my %h_inst_group = ();
my @inst_group_p = ();
my @inst_group_n = ();

### Power Net/Pin Info
my %h_pin_power = ();
my %h_net_power = ();
my %h_net_opt = ();
my %h_net_track = ();
my %h_net_track_n = ();
my %h_net_track_t = ();
my %h_track_net = ();

sub combine;
sub combine_sub;
sub getAvailableNumFinger{
	$width = @_[0];
	$trackEachPRow = @_[1];
	print ("[getAvailableNumFinger]: ");
	@numFinger = ();
	for my $i(0 .. $trackEachPRow-1){
		if($width % ($trackEachPRow-$i) == 0){
			push(@numFinger, $width/($trackEachPRow-$i));
			print "$width/($trackEachPRow-$i)";
			last;
		}
	}
	print "\n";
	return @numFinger;
}
sub combine {
	my ($list, $n) = @_;
	die "Insufficient list members" if $n > @$list;

	return map [$_], @$list if $n <= 1;

	my @comb;

	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		my @rest = @$list[$i+1..$#$list];
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
		if($i==0){
			last;
		}
	}

	return @comb;
}
sub combine_sub {
	my ($list, $n) = @_;
	die "Insufficient list members" if $n > @$list;

	return map [$_], @$list if $n <= 1;

	my @comb;

	for (my $i = 0; $i+$n <= @$list; ++$i){
		my $val = $list->[$i];
		my @rest = @$list[$i+1..$#$list];
		push @comb, [$val, @$_] for combine_sub \@rest, $n-1;
	}

	return @comb;
}

my $infileStatus = "init";

### Read Inputfile and Build Data Structure
open (my $in, "./$infile");
while (<$in>) {
	my $line = $_;
	chomp($line);

	### Status of Input File
	if ($line =~ /===InstanceInfo===/) {
		$infileStatus = "inst";
	} 
	elsif ($line =~ /===NetInfo===/) {
		$infileStatus = "net";
		for(my $i=0; $i<=$#pins; $i++){
#print "$i $pins[$i][0] $pins[$i][1] $pins[$i][2] $pins[$i][7]\n";
			if(exists($h_pin_net{$pins[$i][1]})){
				if($pins[$i][2] eq "s"){
					$h_pin_net{$pins[$i][1]} = $h_pin_net{$pins[$i][1]}." ".$pins[$i][0];
				}
				else{
					$h_pin_net{$pins[$i][1]} = $pins[$i][0]." ".$h_pin_net{$pins[$i][1]};
				}
			}
			else{
				$h_pin_net{$pins[$i][1]} = $pins[$i][0];
			}
		}
	}
	elsif ($line =~ /===PinInfo===/) {
		$infileStatus = "pin";
	}
	elsif ($line =~ /===PartitionInfo===/) {
		$infileStatus = "partition";
	}
	elsif ($line =~ /===M2TrackAssignInfo===/) {
		$infileStatus = "track";
	}
	elsif ($line =~ /===NetOptInfo===/) {
		$infileStatus = "netopt";
	}

	### Infile Status: init
	if ($infileStatus eq "init") {
		if ($line =~ /Width of Routing Clip\s*= (\d+)/) {
			$width = $1;
			$numTrackV = $width;
			print "a     # Vertical Tracks   = $numTrackV\n";
		}
		elsif ($line =~ /Height of Routing Clip\s*= (\d+)/) {
			$placementRow = $1;
		}
		elsif ($line =~ /Tracks per Placement Row\s*= (\d+)/) {
			$trackEachRow = $1;
			$numTrackH = $placementRow * $trackEachRow;
			print "a     # Horizontal Tracks = $numTrackH\n";
		}
		elsif ($line =~ /Width of Placement Clip\s*= (\d+)/) {
			$width = $1;
			$numPTrackV = $width;
			print "a     # Vertical Placement Tracks   = $numPTrackV\n";
		}
		elsif ($line =~ /Tracks per Placement Clip\s*= (\d+)/) {
			#$numPTrackH = $1*2;
			$numPTrackH = $1; # CFET is always 2
			$trackEachPRow = $1;
			print "a     # Horizontal Placement Tracks = $numPTrackH\n";
		}
	}

	### Infile Status: Instance Info
	if ($infileStatus eq "inst") {
		if ($line =~ /^i   ins(\S+)\s*(\S+)\s*(\d+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			$instWidth = $3;

			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($instWidth, $trackEachPRow);

			if($instType eq "NMOS"){
				if($lastIdxPMOS == -1){
					$lastIdxPMOS = $numInstance - 1;
				}
				$instY = 0;
			}
			else{
				# Mark: PMOS Y is set to 0
				$instY = 0;
				#$instY = $numPTrackH - $instWidth/$tmp_finger[0];
			}
			push(@inst, [($instName, $instType, $instWidth, $instY)]);
			### Generate Maximum possible pin arrays for each instances
			### # of Maximum Possible pin = instWidth * 2 + 1
			for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
				if($i==0){
					$h_pin_idx{$instName} = $pinIDX;
				}
				@pinYpos = ();
				for my $pinRow (1 .. $trackEachPRow) {
					push (@pinYpos, $pinRow );
				}
				@pin = ("pin$1_$i", "", "t", $trackEachPRow, $i, [@pinYpos], $instName, "");
				push (@pins, [@pin]);
				$h_pinId_idx{"pin$1_$i"} = $pinIDX;
				$pinIDX++;
				$pinTotalIDX++;
#print "$instName => pin$1_$i, , t, $trackEachPRow, $i, [@pinYpos], $instName, $pin_type\n";
			}
			$h_inst_idx{$instName} = $numInstance;
			$numInstance++;
		}
	}

	print("inst:\n");
	print(Dumper\@inst);
	# $VAR1 = [
    #       [
    #         'insMM1',
    #         'PMOS',
    #         '2',
    #         0
    #       ],
    #       [
    #         'insMM0',
    #         'NMOS',
    #         '2',
    #         0
    #       ]
    #     ];

	print("h_inst_idx:\n");
	print(Dumper\%h_inst_idx);
	# $VAR1 = {
    #       'insMM0' => 1,
    #       'insMM1' => 0
    #     };


	### Infile Status: pin
	if ($infileStatus eq "pin") {
		if ($line =~ /^i   pin(\d+)\s*net(\d+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)/) {
			$pin_type_IO = $7;
		}
		if ($line =~ /^i   pin(\d+)\s*net(\d+)\s*(\S+)\s*(\S+)\s*(\S+)\s*(\S+)/) {
			$pinName = "pin".$1;
			$pin_netID = "net".$2; 
			$pin_instID = $3;
			$pin_type = $4;
			$pinIO = $5;
			$pinLength = $6;
			my @tmp_finger = ();
			@tmp_finger = getAvailableNumFinger($inst[$h_inst_idx{$pin_instID}][2], $trackEachPRow);
			if($pin_instID ne "ext" && $pin_type eq "S"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i%4==0){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==0){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID ne "ext" && $pin_type eq "D"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i>=2 && ($i-2)%4==0){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==2){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID ne "ext" && $pin_type eq "G"){
				for my $i(0 .. ($tmp_finger[$#tmp_finger]*2+1)-1){
					if($i>=1 && ($i)%2==1){
						$pins[$h_pin_idx{$pin_instID}+$i][1] = $pin_netID;
						$pins[$h_pin_idx{$pin_instID}+$i][7] = $pin_type;
						if($i==1){
							$pins[$h_pin_idx{$pin_instID}+$i][2] = $pinIO;
						}
					}
				}
			}
			elsif($pin_instID eq "ext"){
				@pin = ($pinName, $pin_netID, $pinIO, $pinLength, $pinXpos, [@pinYpos], $pin_instID, $pin_type);
				push (@pins, [@pin]);
				$h_outpinId_idx{$pinName} = $pinTotalIDX;
				$pinTotalIDX++;
				if($pin_type ne "VDD" && $pin_type ne "VSS"){
					$h_extnets{$2} = 1;
				}
				if($pin_type_IO eq "O"){
#if($pin_type eq "QN" || $pin_type eq "ZN" || $pin_type eq "Q" || $pin_type eq "S" || $pin_type eq "CO" || $pin_type eq "CON"){
					$h_outnets{$pin_netID} = 1;
					print "OUTPUT NET : $pin_netID\n";
				}	
			} 
			$h_pin_id{$pin_instID."_".$pin_type} = $2;
		}
	}

	print("pins:\n");
	print(Dumper\@pins);

	### Infile Status: net
	if ($infileStatus eq "net") {
		if ($line =~ /^i   net(\S+)\s*(\d+)PinNet/) {
			$numNets_org++;
			$netID = $1;
			$netName = "net".$netID;
			my $powerinNet = 0;
			my $powerNet = "";
			if(exists($h_pin_net{$netName})){
				print "$netName => $h_pin_net{$netName}\n";
				@net = split /\s+/, $h_pin_net{$netName};
			}
			else{
				print "[ERROR] Parsing Net Info : Net Information is not correct!! [$netName]\n";
				exit(-1);
			}
			for my $pinIndex_inNet (0 .. $#net) {
				if(exists($h_outpinId_idx{$net[$pinIndex_inNet]}) && ($pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VDD" || $pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VSS")){
					$powerinNet = 1;
					$powerNet = $net[$pinIndex_inNet];
				}
			}
			if($powerinNet == 0){
				$N_pinNets = $#net+1;
				@pins_inNet = ();
				my $num_outpin = 0;
				for my $pinIndex_inNet (0 .. $N_pinNets-1) {
					push (@pins_inNet, $net[$pinIndex_inNet]);
				}
				$source_ofNet = $pins_inNet[$N_pinNets-1];
				$numSinks = $N_pinNets - 1;
				@sinks_inNet = ();
				for my $sinkIndex_inNet (0 .. $numSinks-1) {
					push (@sinks_inNet, $net[$sinkIndex_inNet]);
				}
				$numSinks = $numSinks - $num_outpin;
				@net = ($netName, $netID, $N_pinNets, $source_ofNet, $numSinks, [@sinks_inNet], [@pins_inNet]);
				push (@nets, [@net]);
				#$h_net_idx{$netName} = $idx_nets;
				$idx_nets++;
			}
			else{
				my $subidx_net = 0;
				
				for my $pinIndex_inNet (0 .. $#net) {
					$h_pin_power{$net[$pinIndex_inNet]} = 1;
					$N_pinNets = 2;
					@pins_inNet = ();
					@sinks_inNet = ();
					if($net[$pinIndex_inNet] ne $powerNet){
						push (@pins_inNet, $powerNet);
						push (@pins_inNet, $net[$pinIndex_inNet]);
						$source_ofNet = $net[$pinIndex_inNet];
						$numSinks = 1;
						push (@sinks_inNet, $powerNet);
						my @tmpnet = ($netName."_".$subidx_net, $netID."_".$subidx_net, $N_pinNets, $source_ofNet, $numSinks, [@sinks_inNet], [@pins_inNet]);
						push (@nets, [@tmpnet]);
						my $tmp_net_name = $netName."_".$subidx_net;
						#$h_net_idx{$tmp_net_name} = $idx_nets;
						$h_net_power{$netName."_".$subidx_net} = 1;
						$pins[$h_outpinId_idx{$powerNet}][1] = $netName."_".$subidx_net;
						$pins[$h_pinId_idx{$source_ofNet}][1] = $netName."_".$subidx_net;
						$pins[$h_pinId_idx{$source_ofNet}][2] = "s";
						print "  $netName\_$subidx_net => $powerNet $source_ofNet (will be removed)\n";
						$idx_nets++;
						$subidx_net++;
						## Generate Instance Information for applying DDA
						if($pins[$h_pinId_idx{$source_ofNet}][7] eq "S"){
							my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$source_ofNet}][6]};
							my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
							my $FlipFlag = 0;
							if($tmp_finger[0]%2 == 0){
								$FlipFlag = 2;
							}
							# DDA = (instanceID, FlipFlag)
							if($instIdx <= $lastIdxPMOS){
								push(@DDA_PMOS, [($instIdx, $FlipFlag)]);
								$numPowerPmos++;
							}
							else{
								push(@DDA_NMOS, [($instIdx, $FlipFlag)]);
								$numPowerNmos++;
							}
						}
						elsif($pins[$h_pinId_idx{$source_ofNet}][7] eq "D"){
							my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$source_ofNet}][6]};
							my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);
							my $FlipFlag = 0;
							if($tmp_finger[0]%2 == 1){
								$FlipFlag = 1;
							}
							else{
								next;
							}
							# DDA = (instanceID, FlipFlag)
							if($instIdx <= $lastIdxPMOS){
								push(@DDA_PMOS, [($instIdx, $FlipFlag)]);
								$numPowerPmos++;
							}
							else{
								push(@DDA_NMOS, [($instIdx, $FlipFlag)]);
								$numPowerNmos++;
							}
						}
					}
				}
			}
		}
	}
	### Infile Status: Partition Info
	if ($Partition_Parameter == 2 && $infileStatus eq "partition") {
		if ($line =~ /^i   ins(\S+)\s*(\S+)\s*(\d+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			$instGroup = $3;

			if(!exists($h_inst_idx{$instName})){
				print "[ERROR] Instance [$instName] in PartitionInfo not found!!\n";
				exit(-1);
			}
			my $idx = $h_inst_idx{$instName};

			print "[Instance Group] $instName => Group $instGroup\n";

			push(@inst_group, [($instName, $instType, $instGroup)]);
			$h_inst_group{$instName} = $instGroup;
		}
	}
	### Infile Status: TrackUsageInfo
	if ($infileStatus eq "track") {
		if ($line =~ /^i   net(\d+)\s*(\d+)/) {	
			my $net_idx = $1;
			my $net_track = $2;

			print "[M2 Track Assign] net$net_idx => $net_track track\n";
			$h_net_track{"$net_idx\_$net_track"} = 1;
			$h_net_track_n{$net_idx} = 1;
			$h_net_track_t{$net_track} = 1;
			if(exists($h_track_net{$net_track})){
				$h_track_net{$net_track} = $h_track_net{$net_track}."_".$net_idx;
			}
			else{
				$h_track_net{$net_track} = $net_idx;
			}
		}
	}
	### Infile Status: NetOptimizationInfo
	if ($infileStatus eq "netopt") {
		if ($line =~ /^i   net(\d+)\s*(\S+)/) {	
			my $net_idx = $1;
			my $net_opt = $2;

			print "[Net Optimization] net$net_idx => $net_opt\n";
			$h_net_opt{$net_idx} = $net_opt;
		}
	}
}
close ($in);

# Generating Instance Group Array
if ($Partition_Parameter == 2){
	my @inst_sorted = ();
	@inst_sorted = sort { (($a->[2] =~ /(\d+)/)[0]||0) <=> (($b->[2] =~ /(\d+)/)[0]||0) || $a->[2] cmp $b->[2] } @inst_group;

	my $prev_group_p = -1;
	my $prev_group_n = -1;
	my @arr_tmp_p = ();
	my @arr_tmp_n = ();
	my $isRemain_P = 0;
	my $isRemain_N = 0;
	for my $i(0 .. $#inst_sorted){
		if($h_inst_idx{$inst_sorted[$i][0]} <= $lastIdxPMOS){
			if($prev_group_p != -1 && $prev_group_p != $inst_sorted[$i][2]){
				push(@inst_group_p, [($prev_group_p, [@arr_tmp_p])]);
				@arr_tmp_p = ();
			}
			push(@arr_tmp_p, $h_inst_idx{$inst_sorted[$i][0]});
			$prev_group_p = $inst_sorted[$i][2];
			$isRemain_P = 1;
		}
		else{
			if($prev_group_n != -1 && $prev_group_n != $inst_sorted[$i][2]){
				push(@inst_group_n, [($prev_group_n, [@arr_tmp_n])]);
				@arr_tmp_n = ();
			}
			push(@arr_tmp_n, $h_inst_idx{$inst_sorted[$i][0]});
			$prev_group_n = $inst_sorted[$i][2];
			$isRemain_N = 1;
		}
	}
	if($isRemain_P == 1){
		push(@inst_group_p, [($prev_group_p, [@arr_tmp_p])]);
	}
	if($isRemain_N == 1){
		push(@inst_group_n, [($prev_group_n, [@arr_tmp_n])]);
	}

	for my $i(0 .. $#inst_group_p){
		for my $j(0 .. $#{$inst_group_p[$i][1]}){
			print "PMOS $inst_group_p[$i][0] => $inst_group_p[$i][1][$j]\n";
		}
	}
	for my $i(0 .. $#inst_group_n){
		for my $j(0 .. $#{$inst_group_n[$i][1]}){
			print "NMOS $inst_group_n[$i][0] => $inst_group_n[$i][1][$j]\n";
		}
	}
}


print "DDA : numPowerPmos :$numPowerPmos numPowerNmos :$numPowerNmos\n";

### Remove Power Pin/Net Information from data structure 
my @tmp_pins = ();
my @tmp_nets = ();
my @nets_sorted = ();

$pinIDX = 0;
for my $i (0 .. (scalar @pins)-1){
	if(!exists($h_pin_power{$pins[$i][0]})){
		push(@tmp_pins, $pins[$i]);
		$h_pinId_idx{$pins[$i][0]} = $pinIDX;
		if($pins[$i][7] ne "S" && $pins[$i][7] ne "D" && $pins[$i][7] ne "G"){
			$h_outpinId_idx{$pins[$i][0]} = $pinIDX;
		}
		$pinIDX++;
	}
}
my $tmp_net_idx = 0;
for my $i (0 .. (scalar @nets)-1){
	if(!exists($h_net_power{$nets[$i][0]})){
		push(@tmp_nets, $nets[$i]);
		print "push $nets[$i][0] $nets[$i][1] to h_idx\n";
		$h_net_idx{$nets[$i][0]} = $tmp_net_idx;
		$h_idx{$nets[$i][1]} = $tmp_net_idx;
		$tmp_net_idx++;
	}
}
@pins = @tmp_pins;
@nets = @tmp_nets;

@nets_sorted = sort { (($b->[2] =~ /(\d+)/)[0]||0) <=> (($a->[2] =~ /(\d+)/)[0]||0) || $b->[2] cmp $a->[2] } @nets;

$totalPins = scalar @pins;
$totalNets = scalar @nets;
print "a     # Pins              = $totalPins\n";
print "a     # Nets              = $totalNets\n";

### VERTEX Generation
### VERTEX Variables
my %vertices = ();
my @vertex = ();
my $numVertices = -1;
my $vIndex = 0;
my $vName = "";
my @vADJ = ();
my $vL = "";
my $vR = "";
my $vF = "";
my $vB = "";
my $vU = "";
my $vD = "";
my $vFL = "";
my $vFR = "";
my $vBL = "";
my $vBR = "";

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
for my $metal (1 .. $numMetalLayer) { 
	for my $row (0 .. $numTrackH-3) { # horiztonal dir
		for my $col (0 .. $numTrackV-1) { # vertical dir
			$vName = "m".$metal."r".$row."c".$col;
			if ($col == 0) { ### Left Vertex
				$vL = "null";
			} 
			else {
				$vL = "m".$metal."r".$row."c".($col-1);
			}
			if ($col == $numTrackV-1) { ### Right Vertex
				$vR = "null";
			}
			else {
				$vR = "m".$metal."r".$row."c".($col+1);
			}
			if ($row == 0) { ### Front Vertex
				$vF = "null";
			}
			else {
				$vF = "m".$metal."r".($row-1)."c".$col;
			}
			if ($row == $numTrackH-3) { ### Back Vertex
				$vB = "null";
			}
			else {
				$vB = "m".$metal."r".($row+1)."c".$col;
			}
			if ($metal == $numMetalLayer) { ### Up Vertex
				$vU = "null";
			}
			else {
				$vU = "m".($metal+1)."r".$row."c".$col;
			}
			if ($metal == 1) { ### Down Vertex
				$vD = "null";
			}
			else {
				$vD = "m".($metal-1)."r".$row."c".$col;
			}
			if ($row == 0 || $col == 0) { ### FL Vertex
				$vFL = "null";
			}
			else {
				$vFL = "m".$metal."r".($row-1)."c".($col-1);
			}
			if ($row == 0 || $col == $numTrackV-1) { ### FR Vertex
				$vFR = "null";
			}
			else {
				$vFR = "m".$metal."r".($row-1)."c".($col+1);
			}
			if ($row == $numTrackH-3 || $col == 0) { ### BL Vertex
				$vBL = "null";
			}
			else {
				$vBL = "m".$metal."r".($row+1)."c".($col-1);
			}
			if ($row == $numTrackH-3 || $col == $numTrackV-1) { ### BR Vertex
				$vBR = "null";
			}
			else {
				$vBR = "m".$metal."r".($row+1)."c".($col+1);
			}
			@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
			@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
			$vertices{$vName} = [@vertex];
			$vIndex++;
		}
	}
}

# print "**** vertices:\n";
# print Dumper(\%vertices);
#print $out "(minimize METAL_SIZE)\n";

### UNDIRECTED EDGE Generation
### UNDIRECTED EDGE Variables
my @udEdges = ();
my @udEdge = ();
my $udEdgeTerm1 = "";
my $udEdgeTerm2 = "";
my $udEdgeIndex = 0;
my $udEdgeNumber = -1;
my $vCost = 4;
my $mCost = 1;
my $vCost_1 = 4;
my $mCost_1 = 1;
my $vCost_34 = 4;	# Cost for layer 3 and 4
my $mCost_4 = 1;
my $wCost = 1;

### DATA STRUCTURE:  UNDIRECTED_EDGE [index] [vertex1] [vertex2] [mCost] [wCost]
### DATA STRUCTURE:  UNDIRECTED_EDGE [index] [Term1] [Term2] [mCost] [wCost]
for my $metal (1 .. $numMetalLayer) {     # Odd Layers: Vertical Direction   Even Layers: Horizontal Direction
	for my $row (0 .. $numTrackH-3) {
		for my $col (0 .. $numTrackV-1) {
			$udEdgeTerm1 = "m".$metal."r".$row."c".$col;

			if ($metal % 2 == 0) { # Even Layers ==> Horizontal; 2, 4, 6, ...

				#[5] = [@vADJ] = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				if ($vertices{$udEdgeTerm1}[5][1] ne "null") { # Right Edge
					$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][1]; # connects to vR
					if($metal == 4){
						# if last metal: 
						# [index] [v] [vR] 1 1
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost_4, $wCost);
					}
					else{
						# metal 1, 2, 3
						# [index] [v] [vR] 1 1
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost, $wCost);
					}
					#print "@udEdge\n";
					push (@udEdges, [@udEdge]);
					$udEdgeIndex++;
				}

				if ($vertices{$udEdgeTerm1}[5][4] ne "null") { # Up Edge
					# if($col % 2 == 0){
					# if col is even, construct edge to upper edge
					$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
					# [index] [v] [vU] 4 4
					@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost, $vCost);
					#print "@udEdge\n";
					push (@udEdges, [@udEdge]);
					$udEdgeIndex++;
					# }
				}
			}
			else { # Odd Layers ==> Vertical; 1, 3, 5, ...

				if($metal > 1 && $col %2 == 1){
					# if metal is 3, 5, 7... and col is odd, ignore
					# why col cannot be odd
					next;
				}

				# if metal is 1, or col is even
				if ($vertices{$udEdgeTerm1}[5][3] ne "null") { # Back Edge
					# if vB exists
					$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][3];
					if($metal == 3){
						# if metal is 3
						# [index] [v] [vB] 1, 1
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost, $wCost);
					}
					else{
						# if metal is 3
						# [index] [v] [vB] 1, 1
						@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $mCost_1, $wCost);
					}
					#print "@udEdge\n";
					push (@udEdges, [@udEdge]);
					$udEdgeIndex++;
				}

				if ($vertices{$udEdgeTerm1}[5][4] ne "null") { # Up Edge
					if($metal == 1){
						# if metal is 1 and vU exists
						$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
						if($metal == 3){
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_34, $vCost);
						}
						else{
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_1, $vCost);
						}
						#print "@udEdge\n";
						push (@udEdges, [@udEdge]);
						$udEdgeIndex++;
					}
					elsif($col % 2 == 0){
						# exact same code as above, why???
						$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
						if($metal == 3){
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_34, $vCost);
						}
						else{
							@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost_1, $vCost);
						}
						#print "@udEdge\n";
						push (@udEdges, [@udEdge]);
						$udEdgeIndex++;
					}
				}
			}
		}
	}
}
$udEdgeNumber = scalar @udEdges;
print "a     # udEdges           = $udEdgeNumber\n";

# print "**** udEdges:\n";
# print Dumper(\@udEdges);

### BOUNDARY VERTICES Generation.
### DATA STRUCTURE:  Single Array includes all boundary vertices to L, R, F, B, U directions.
my @boundaryVertices = ();
my $numBoundaries = 0;

### Normal External Pins - Top&top-1 layer only
for my $metal ($numMetalLayer-1 .. $numMetalLayer) { 
	for my $row (0 .. $numTrackH-3) {
		for my $col (0 .. $numTrackV-1) {
			if($metal%2==0){
				if($col%2 == 1){
					next;
				}
#				if($EXT_Parameter == 0){
##				if ($col%4==0 && $row == $numTrackH-3) {
##					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
##				}
##				elsif($col%4!=0 && $row == 0){
##					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
##				}
#					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
#				}
#				else{
#					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
#				}
			}
			else{
				if($col%2 == 1){
					next;
				}
				if($EXT_Parameter == 0){
#				if ($col%4==0 && $row == $numTrackH-3) {
#					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
#				}
#				elsif($col%4!=0 && $row == 0){
#					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
#				}
#if ($row == 0 || $row == $numTrackH-3) {
					if ($row == 1 || $row == $numTrackH-4) { # why $numTrackH-4
						push (@boundaryVertices, "m".$metal."r".$row."c".$col);
					}
				}
				else{
					push (@boundaryVertices, "m".$metal."r".$row."c".$col);
				}
			}
		}
	}
}
$numBoundaries = scalar @boundaryVertices;
print "a     # Boundary Vertices = $numBoundaries\n";

# YW: Debugging
print "**** boundaryVertices:\n";
print Dumper(\@boundaryVertices);
# $VAR1 = [
#           'm3r1c0',
#           'm3r1c2',
#           'm3r1c4',
#           'm3r1c6',
#           'm3r2c0',
#           'm3r2c2',
#           'm3r2c4',
#           'm3r2c6'
#         ];


# [2018-10-15] Store the net information for SON simplifying
my @outerPins = ();
my @outerPin = ();
my %h_outerPin = ();
my $numOuterPins = 0;
my $commodityInfo = -1;

for my $pinID (0 .. $#pins) {
	# $pinXpos by default its -1
	if ($pins[$pinID][3] == -1) {
		$commodityInfo = -1;
		# Initializing
		# Find Commodity Infomation
		for my $netIndex (0 .. $#nets) {
			if ($nets[$netIndex][0] eq $pins[$pinID][1]) {
				for my $sinkIndexofNet (0 .. $nets[$netIndex][4]) {
					if ( $nets[$netIndex][5][$sinkIndexofNet] eq $pins[$pinID][0]) {
						$commodityInfo = $sinkIndexofNet; 
					}
				}
			}
		}
		if ($commodityInfo == -1){
			print "ERROR: Cannot Find the commodity Information!!\n\n";
		}
		@outerPin = ($pins[$pinID][0],$pins[$pinID][1],$commodityInfo);
		push (@outerPins, [@outerPin]) ;
		$h_outerPin{$pins[$pinID][0]} = 1;
	}
}
$numOuterPins = scalar @outerPins;

print "**** outerPin:\n";
print Dumper(\@outerPin);

print "**** outerPins:\n";
print Dumper(\@outerPins);
# $VAR1 = [
        #   [
        #     'pin8',
        #     'net1',
        #     0
        #   ],
        #   [
        #     'pin9',
        #     'net2',
        #     0
        #   ]
        # ];

print "**** h_outerPin:\n";
print Dumper(\%h_outerPin);
# $VAR1 = {
#           'pin8' => 1,
#           'pin9' => 1
#         };
# $pinName, $pin_netID, $pinIO, $pinLength, $pinXpos, [@pinYpos], $pin_instID, $pin_type
# [PIN_NAME][NET_ID][pinIO][PIN_LENGTH][pinXpos][@pinYpos][INST_ID][PIN_TYPE]
print "**** pins:\n";
print Dumper(\@pins);
# $VAR1 = [
# 			[
# 			'pinMM1_1',
# 			'net1',
# 			't',
# 			2,
# 			1,
# 			[
# 				1,
# 				2
# 			],
# 			'insMM1',
# 			'G'
# 			],
# 			[
# 			'pinMM1_2',
# 			'net2',
# 			't',
# 			2,
# 			2,
# 			[
# 				1,
# 				2
# 			],
# 			'insMM1',
# 			'D'
# 			],
# 			[
# 			'pinMM0_1',
# 			'net1',
# 			's',
# 			2,
# 			1,
# 			[
# 				1,
# 				2
# 			],
# 			'insMM0',
# 			'G'
# 			],
# 			[
# 			'pinMM0_2',
# 			'net2',
# 			's',
# 			2,
# 			2,
# 			[
# 				1,
# 				2
# 			],
# 			'insMM0',
# 			'D'
# 			],
# 			[
# 			'pin8',
# 			'net1',
# 			't',
# 			-1,
# 			-1,
# 			[
# 				1,
# 				2
# 			],
# 			'ext',
# 			'A'
# 			],
# 			[
# 			'pin9',
# 			'net2',
# 			't',
# 			-1,
# 			-1,
# 			[
# 				1,
# 				2
# 			],
# 			'ext',
# 			'Y'
# 			]
# 		];


print "**** nets:\n";
print Dumper(\@nets);
	#$VAR1 = [
			#   [
			#     'net1',
			#     '1',
			#     3,
			#     'pinMM0_1',
			#     2,
			#     [
			#       'pin8',
			#       'pinMM1_1'
			#     ],
			#     [
			#       'pin8',
			#       'pinMM1_1',
			#       'pinMM0_1'
			#     ]
			#   ],
			#   [
			#     'net2',
			#     '2',
			#     3,
			#     'pinMM0_2',
			#     2,
			#     [
			#       'pin9',
			#       'pinMM1_2'
			#     ],
			#     [
			#       'pin9',
			#       'pinMM1_2',
			#       'pinMM0_2'
			#     ]
			#   ]
			# ];

### (LEFT | RIGHT | FRONT | BACK) CORNER VERTICES Generation
my @leftCorners = ();
my $numLeftCorners = 0;
my @rightCorners = ();
my $numRightCorners = 0;
my @frontCorners = ();
my $numFrontCorners = 0;
my @backCorners = ();
my $numBackCorners = 0;
my $cornerVertex = "";

for my $metal (1 .. $numMetalLayer) { # At the top-most metal layer, only vias exist.
	for my $row (0 .. $numTrackH-3) {
		for my $col (0 .. $numTrackV-1) {
			# skip metal 1 and odd col
			if($metal == 1 && $col % 2 == 1){
				next;
			}
			# skipping
			elsif($metal % 2 == 1 && $col % 2 == 1){
				next;
			}
			$cornerVertex = "m".$metal."r".$row."c".$col;
			if ($col == 0) {
				push (@leftCorners, $cornerVertex);
				$numLeftCorners++;
			}
			if ($col == $numTrackV-1) {
				push (@rightCorners, $cornerVertex);
				$numRightCorners++;
			}
			if ($row == 0) {
				push (@frontCorners, $cornerVertex);
				$numFrontCorners++;
			}
			if ($row == $numTrackH-3) {
				push (@backCorners, $cornerVertex);
				$numBackCorners++;
			}
		}
	}
}

#print "@backCorners\n";
print "a     # Left Corners      = $numLeftCorners\n";
print "a     # Right Corners     = $numRightCorners\n";
print "a     # Front Corners     = $numFrontCorners\n";
print "a     # Back Corners      = $numBackCorners\n";

print "**** leftCorners:\n";
print Dumper(\@leftCorners);
# $VAR1 = [
#           'm1r0c0',
#           'm1r1c0',
#           'm1r2c0',
#           'm1r3c0',
#           'm2r0c0',
#           'm2r1c0',
#           'm2r2c0',
#           'm2r3c0',
#           'm3r0c0',
#           'm3r1c0',
#           'm3r2c0',
#           'm3r3c0',
#           'm4r0c0',
#           'm4r1c0',
#           'm4r2c0',
#           'm4r3c0'
#         ];


print "**** rightCorners:\n";
print Dumper(\@rightCorners);
# $VAR1 = [
#           'm1r0c6',
#           'm1r1c6',
#           'm1r2c6',
#           'm1r3c6',
#           'm2r0c6',
#           'm2r1c6',
#           'm2r2c6',
#           'm2r3c6',
#           'm3r0c6',
#           'm3r1c6',
#           'm3r2c6',
#           'm3r3c6',
#           'm4r0c6',
#           'm4r1c6',
#           'm4r2c6',
#           'm4r3c6'
#         ];


print "**** frontCorners:\n";
print Dumper(\@frontCorners);
# $VAR1 = [
#           'm1r0c0',
#           'm1r0c2',
#           'm1r0c4',
#           'm1r0c6',
#           'm2r0c0',
#           'm2r0c1',
#           'm2r0c2',
#           'm2r0c3',
#           'm2r0c4',
#           'm2r0c5',
#           'm2r0c6',
#           'm3r0c0',
#           'm3r0c2',
#           'm3r0c4',
#           'm3r0c6',
#           'm4r0c0',
#           'm4r0c1',
#           'm4r0c2',
#           'm4r0c3',
#           'm4r0c4',
#           'm4r0c5',
#           'm4r0c6'
#         ];


print "**** backCorners:\n";
print Dumper(\@backCorners);
# $VAR1 = [
#           'm1r3c0',
#           'm1r3c2',
#           'm1r3c4',
#           'm1r3c6',
#           'm2r3c0',
#           'm2r3c1',
#           'm2r3c2',
#           'm2r3c3',
#           'm2r3c4',
#           'm2r3c5',
#           'm2r3c6',
#           'm3r3c0',
#           'm3r3c2',
#           'm3r3c4',
#           'm3r3c6',
#           'm4r3c0',
#           'm4r3c1',
#           'm4r3c2',
#           'm4r3c3',
#           'm4r3c4',
#           'm4r3c5',
#           'm4r3c6'
#         ];

### SOURCE and SINK Generation.  All sources and sinks are supernodes.
### DATA STRUCTURE:  SOURCE or SINK [netName] [#subNodes] [Arr. of sub-nodes, i.e., vertices]
my %sources = ();
my %sinks = ();
my @source = ();
my @sink = ();
my @subNodes = ();
my $numSubNodes = 0;
my $numSources = 0;
my $numSinks = 0;

my $outerPinFlagSource = 0;
my $outerPinFlagSink = 0;
my $keyValue = "";

# Super Outer Node Keyword
my $keySON = "pinSON";

for my $pinID (0 .. $#pins) {
	@subNodes = ();
	if ($pins[$pinID][2] eq "s") { # source
		if ($pins[$pinID][3] == -1) {
			if ($SON == 1){
				if ($outerPinFlagSource == 0){
					print "a        [SON Mode] Super Outer Node Simplifying - Source Case (Not Yet!)\n";
					@subNodes = @boundaryVertices;
					$outerPinFlagSource = 1;
					$keyValue = $keySON;
				}
				else{
					next;
				}
			}
			else{   # SON Disable
				@subNodes = @boundaryVertices;
				$keyValue = $pins[$pinID][0];
			}
		} else {
			for my $node (0 .. $pins[$pinID][3]-1) {
				push (@subNodes, "m1r".$pins[$pinID][5][$node]."c".$pins[$pinID][4]);
			}
			$keyValue = $pins[$pinID][0];
		}
		$numSubNodes = scalar @subNodes;
		@source = ($pins[$pinID][1], $numSubNodes, [@subNodes]);
		# Outer Pin should be at last in the input File Format [2018-10-15]
		$sources{$keyValue} = [@source];
	}
	elsif ($pins[$pinID][2] eq "t") { # sink
		if ($pins[$pinID][3] == -1) { # if ext pin
			if ( $SON == 1) {        
				if ($outerPinFlagSink == 0){
					print "a        [SON Mode] Super Outer Node Simplifying - Sink\n";
					@subNodes = @boundaryVertices;
					$outerPinFlagSink = 1;
					$keyValue = $keySON;
				}
				else{
					next;
				}
			}
			else{ 
				@subNodes = @boundaryVertices;
				$keyValue = $pins[$pinID][0];
			}
		} else { # if ext pin
			for my $node (0 .. $pins[$pinID][3]-1) {
				push (@subNodes, "m1r".$pins[$pinID][5][$node]."c".$pins[$pinID][4]);
			}
			$keyValue = $pins[$pinID][0];
		}
		$numSubNodes = scalar @subNodes;
		@sink = ($pins[$pinID][1], $numSubNodes, [@subNodes]);
		$sinks{$keyValue} = [@sink];
	}
}
my $numExtNets = keys %h_extnets;
$numSources = keys %sources;
$numSinks = keys %sinks;
print "a     # Ext Nets          = $numExtNets\n";
print "a     # Sources           = $numSources\n";
print "a     # Sinks             = $numSinks\n";

print "**** sources:\n";
print Dumper(\%sources);
# $VAR1 = {
#           'pinMM0_1' => [
#                           'net1',
#                           2,
#                           [
#                             'm1r1c1',
#                             'm1r2c1'
#                           ]
#                         ],
#           'pinMM0_2' => [
#                           'net2',
#                           2,
#                           [
#                             'm1r1c2',
#                             'm1r2c2'
#                           ]
#                         ]
#         };


print "**** sinks:\n";
print Dumper(\%sinks);
# $VAR1 = {
#           'pinMM1_1' => [
#                           'net1',
#                           2,
#                           [
#                             'm1r1c1',
#                             'm1r2c1'
#                           ]
#                         ],
#           'pinMM1_2' => [
#                           'net2',
#                           2,
#                           [
#                             'm1r1c2',
#                             'm1r2c2'
#                           ]
#                         ],
#           'pinSON' => [
#                         'net1',
#                         8,
#                         [
#                           'm3r1c0',
#                           'm3r1c2',
#                           'm3r1c4',
#                           'm3r1c6',
#                           'm3r2c0',
#                           'm3r2c2',
#                           'm3r2c4',
#                           'm3r2c6'
#                         ]
#                       ]
#         };

# super outer node
if ( $SON == 1){
############### Pin Information Modification #####################
	print "**** before MOD pins:\n";
	for my $pinIndex (0 .. $#pins) {
		for my $outerPinIndex (0 .. $#outerPins){
			# if pinname is outerpin name
			if ($pins[$pinIndex][0] eq $outerPins[$outerPinIndex][0] ){
				$pins[$pinIndex][0] = $keySON; # pinName = pinSON
				$pins[$pinIndex][1] = "Multi"; # Net = Multi
				next;
			}
		}
	}
############ SON Node should be last elements to use pop ###########
	my $SONFlag = 0;
	my $tmp_cnt = $#pins;
	print "**** after MOD pins:\n";
	print Dumper(\@pins);
	# pop elements in reverse order
	for(my $i=0; $i<=$tmp_cnt; $i++){
		# pop from SONpins
		if($pins[$tmp_cnt-$i][0] eq $keySON){
			$SONFlag = 1;
			@pin = pop @pins;
		}
	}

	print "**** pop pins:\n";
	print Dumper(\@pins);

	#only push one pin
	if ($SONFlag == 1){
		push (@pins, @pin);
	}
}
############### Net Information Modification from Outer pin to "SON"
if ( $SON == 1 ){
	for my $netIndex (0 .. $#nets) {
		for my $sinkIndex (0 .. $nets[$netIndex][4]-1){
			for my $outerPinIndex (0 .. $#outerPins){
				if ($nets[$netIndex][5][$sinkIndex] eq $outerPins[$outerPinIndex][0] ){
					$nets[$netIndex][5][$sinkIndex] = $keySON;
					next;
				}
			}
		}
		for my $pinIndex (0 .. $nets[$netIndex][2]-1){
			for my $outerPinIndex (0 .. $#outerPins){
				if ($nets[$netIndex][6][$pinIndex] eq $outerPins[$outerPinIndex][0] ){
					$nets[$netIndex][6][$pinIndex] = $keySON;
					next;
				}
			}
		}
	}
}
print "**** SON pins:\n";
print Dumper(\@pins);

### VIRTUAL EDGE Generation
### We only define directed virtual edges since we know the direction based on source/sink information.
### All supernodes are having names starting with 'pin'.
### DATA STRUCTURE:  VIRTUAL_EDGE [index] [Origin] [Destination] [Cost=0] [instIdx]
my @virtualEdges = ();
my @virtualEdge = ();
my $vEdgeIndex = 0;
my $vEdgeNumber = 0;
my $virtualCost = 0;

print("numTrackH: $numTrackH\n");
print("numTrackV: $numTrackV\n");

for my $pinID (0 .. $#pins) {
	# if [pinIO] is "source"
	if ($pins[$pinID][2] eq "s") { # source
		# pins: [PIN_NAME][NET_ID][pinIO][PIN_LENGTH][pinXpos][@pinYpos][INST_ID][PIN_TYPE]
		# if pin is a source pin
		if(exists $sources{$pins[$pinID][0]}){
			# if pin related instance ID existed in h_inst_idx
			if(exists($h_inst_idx{$pins[$pinID][6]})){
				# retrieve instance index
				my $instIdx = $h_inst_idx{$pins[$pinID][6]};
				# inst: $instName, $instType, $instWidth, $instY
				# get number of fingers based on [$instwidth] and track each placement row
				my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

				# if instance is a PMOS
				if($h_inst_idx{$pins[$pinID][6]} <= $lastIdxPMOS){
					#my $ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					#my $rl = $h_RTrack{$numPTrackH-1};
					# $numPTrackH in CFET is always 2
					# Routing Tracks index
					my $ru = $h_RTrack{0};				# upper
					my $rl = $h_RTrack{$numPTrackH-1};	# lower
					#for my $row (0 .. $numTrackH/2-2){

					# subject to M1 Only
					for my $row (0 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								#@virtualEdge = ($vEdgeIndex, $pins[$pinID][0], "m1r".$row."c".$col, $virtualCost, $InstIdx);
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
					
				}
				else
				# if instance is an NMOS
				{
					#my $ru = $h_RTrack{0};
					#my $rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					my $ru = $h_RTrack{0};
					my $rl = $h_RTrack{$numPTrackH-1};
					#for my $row ($numTrackH/2-1 .. $numTrackH-3){
					for my $row (0 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
#@virtualEdge = ($vEdgeIndex, $pins[$pinID][0], "m1r".$row."c".$col, $virtualCost, $InstIdx);
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
			}
			else{
				print "[ERROR] Virtual Edge Generation : Instance Information not found!!\n";
				exit(-1);
			}
		}
	}
	elsif ($pins[$pinID][2] eq "t") { # sink
		if(exists $sinks{$pins[$pinID][0]}){
			if($pins[$pinID][0] eq $keySON){
			for my $term (0 ..  $sinks{$pins[$pinID][0]}[1]-1){
					@virtualEdge = ($vEdgeIndex, $sinks{$pins[$pinID][0]}[2][$term], $pins[$pinID][0], $virtualCost);
					push (@virtualEdges, [@virtualEdge]);
					$vEdgeIndex++;
				}
			}
			elsif(exists($h_inst_idx{$pins[$pinID][6]})){
				my $instIdx = $h_inst_idx{$pins[$pinID][6]};
				my @tmp_finger = getAvailableNumFinger($inst[$instIdx][2], $trackEachPRow);

				if($h_inst_idx{$pins[$pinID][6]} <= $lastIdxPMOS){
					#my $ru = $h_RTrack{$numPTrackH-1-$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					#my $rl = $h_RTrack{$numPTrackH-1};
					my $ru = $h_RTrack{0};
					my $rl = $h_RTrack{$numPTrackH-1};

					#for my $row (0 .. $numTrackH/2-2){
					for my $row (0 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
				else{
					#my $ru = $h_RTrack{0};
					#my $rl = $h_RTrack{$h_numCon{$inst[$instIdx][2]/$tmp_finger[0]}};
					my $ru = $h_RTrack{0};
					my $rl = $h_RTrack{$numPTrackH-1};

					#for my $row ($numTrackH/2-1 .. $numTrackH-3){
					for my $row (0 .. $numTrackH-3){
						for my $col (0 .. $numTrackV-1){
							if(exists($h_mapTrack{$row}) && $row<=$ru && $row>=$rl){
								if($pins[$pinID][7] eq "G" && $col%2 == 1){
									next;
								}
								elsif($pins[$pinID][7] ne "G" && $col%2 == 0){
									next;
								}
								@virtualEdge = ($vEdgeIndex, "m1r".$row."c".$col, $pins[$pinID][0], $virtualCost);
								push (@virtualEdges, [@virtualEdge]);
								$vEdgeIndex++;
							}
						}
					}
				}
			}
			else{
				print "[ERROR] Virtual Edge Generation : Instance Information not found!!\n";
				exit(-1);
			}
		}
	}
}

print("Virtual Edge:\n");
print(Dumper\@virtualEdges);
# $VAR1 = [
#           63,
#           'm3r2c6',
#           'pinSON',
#           0
#         ];

my %edge_in = ();
my %edge_out = ();
for my $edge (0 .. @udEdges-1){
	push @{ $edge_out{$udEdges[$edge][1]} }, $edge;
	push @{ $edge_in{$udEdges[$edge][2]} }, $edge;
}
my %vedge_in = ();
my %vedge_out = ();
for my $edge (0 .. @virtualEdges-1){
	push @{ $vedge_out{$virtualEdges[$edge][1]} }, $edge;
	push @{ $vedge_in{$virtualEdges[$edge][2]} }, $edge;
}

## Variable, Constraints Number Count
my $c_v_placement = 0;
my $c_v_placement_aux = 0;
my $c_v_routing = 0;
my $c_v_routing_aux = 0;
my $c_v_connect = 0;
my $c_v_connect_aux = 0;
my $c_v_dr = 0;
my $c_c_placement = 0;
my $c_c_routing = 0;
my $c_c_connect = 0;
my $c_c_dr = 0;
my $c_l_placement = 0;
my $c_l_routing = 0;
my $c_l_connect = 0;
my $c_l_dr = 0;

my $type = "";
my $idx = 0;
sub cnt{
	$type = @_[0];
	$idx = @_[1];

	## Variable
	if($type eq "v"){
		if($idx == 0){
			$c_v_placement++;
		}
		elsif($idx == 1){
			$c_v_placement_aux++;
		}
		elsif($idx == 2){
			$c_v_routing++;
		}
		elsif($idx == 3){
			$c_v_routing_aux++;
		}
		elsif($idx == 4){
			$c_v_connect++;
		}
		elsif($idx == 5){
			$c_v_connect_aux++;
		}
		elsif($idx == 6){
			$c_v_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	## Constraints
	elsif($type eq "c"){
		if($idx == 0){
			$c_c_placement++;
		}
		elsif($idx == 1){
			$c_c_routing++;
		}
		elsif($idx == 2){
			$c_c_connect++;
		}
		elsif($idx == 3){
			$c_c_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	## Literals
	elsif($type eq "l"){
		if($idx == 0){
			$c_l_placement++;
		}
		elsif($idx == 1){
			$c_l_routing++;
		}
		elsif($idx == 2){
			$c_l_connect++;
		}
		elsif($idx == 3){
			$c_l_dr++;
		}
		else{
			print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
			exit(-1);
		}
	}
	else{
		print "[Warning] Count Option is Invalid!! [type=$type, idx=$idx]\n";
		exit(-1);
	}
	return;
}

$vEdgeNumber = scalar @virtualEdges;
print "a     # Virtual Edges     = $vEdgeNumber\n";

### END:  DATA STRUCTURE ##############################################################################################

open (my $out, '>', $outfile);
print "a   Generating SMT-LIB 2.0 Standard Input Code.\n";

### INIT
print $out ";Formulation for SMT\n";
print $out ";	Format: SMT-LIB 2.0\n";
print $out ";	Version: 1.0\n";
print $out ";	Input File:  $workdir/$infile\n";

print $out ";Layout Information\n";
print $out ";	Placement\n";
print $out ";	# Vertical Tracks   = $numPTrackV\n";
print $out ";	# Horizontal Tracks = $numPTrackH\n";
print $out ";	# Instances         = $numInstance\n";
print $out ";	Routing\n";
print $out ";	# Vertical Tracks   = $numTrackV\n";
print $out ";	# Horizontal Tracks = $numTrackH\n";
print $out ";	# Nets              = $totalNets\n";
print $out ";	# Pins              = $totalPins\n";
print $out ";	# Sources           = $numSources\n";
print $out ";	List of Sources   = ";
foreach my $key (keys %sources) {
	print $out "$key ";
}
print $out "\n";
print $out ";	# Sinks             = $numSinks\n";
print $out ";	List of Sinks     = ";
foreach my $key (keys %sinks) {
	print $out "$key ";
}
print $out "\n";
print $out ";	# Outer Pins        = $numOuterPins\n";
print $out ";	List of Outer Pins= ";
for my $i (0 .. $#outerPins) {              # All SON (Super Outer Node)
	print $out "$outerPins[$i][0] ";        # 0 : Pin number , 1 : net number
}
print $out "\n";
print $out ";	Outer Pins Information= ";
for my $i (0 .. $#outerPins) {              # All SON (Super Outer Node)
	print $out " $outerPins[$i][1]=$outerPins[$i][2] ";        # 0 : Net number , 1 : Commodity number
}
print $out "\n";
print $out "; Parameters: SON=$SON DPR=$DoublePowerRail MAR=$MAR_Parameter EOL=$EOL_Parameter VR=$VR_Parameter PRL=$PRL_Parameter SHR=$SHR_Parameter MPL=$MPL_Parameter\n";
print $out "; Parameters: MM=$MM_Parameter LOC=$Local_Parameter PART=$Partition_Parameter BCP=$BCP_Parameter NDE=$NDE_Parameter BS=$BS_Parameter PE=$PE_Parameter\n";
print $out "; Parameters: M2Track=$M2_TRACK_Parameter M2Length=$M2_Length_Parameter Dint=$dint Stack=$stack_struct_flag, DVsamenet = $VR_double_samenet_flag, Stackvia = $VR_stacked_via_flag\n";
print $out "\n\n";

my $str = "";
my %h_var = ();
my $idx_var = 1;
my $idx_clause = 1;
my %h_assign = ();
my %h_assign_new = ();
my $isFirstLoop = 1;

sub setVar{
	my $varName = @_[0];
	my $type = @_[1];

	if(!exists($h_var{$varName})){
		cnt("v", $type);
		$h_var{$varName} = $idx_var;
		$idx_var++;
	}
	return;
}
sub setVar_wo_cnt{
	my $varName = @_[0];
	my $type = @_[1];

	if(!exists($h_var{$varName})){
		$h_var{$varName} = -1;
	}
	return;
}

### Z3 Option Set ###
print $out ";(set-option :produce-unsat-cores true)\n";
print $out ";Begin SMT Formulation\n\n";

print $out "(declare-const COST_SIZE (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
print $out "(declare-const COST_SIZE_P (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
print $out "(declare-const COST_SIZE_N (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
for my $i (0 .. $numTrackH-3){
	print $out "(declare-const M2_TRACK_$i Bool)\n";
}
foreach my $key(keys %h_extnets){
	for my $i (0 .. $numTrackH-3){
		print $out "(declare-const N".$key."_M2_TRACK_$i Bool)\n";
	}
	print $out "(declare-const N".$key."_M2_TRACK Bool)\n";
}
#print $out "(declare-const METAL_SIZE (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";
### Placement ###
print "a   A. Variables for Placement\n";
print $out ";A. Variables for Placement\n";
print $out "(define-fun max ((x (_ BitVec ".(length(sprintf("%b", $numTrackV))+4).")) (y (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))) (_ BitVec ".(length(sprintf("%b", $numTrackV))+4).")\n";
print $out "  (ite (bvsgt x y) x y)\n";
print $out ")\n";

for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print $out "(declare-const x$i (_ BitVec ".(length(sprintf("%b", $numTrackV))+4)."))\n";     # instance x position
	cnt("v", 0);
	print $out "(declare-const ff$i Bool)\n";    # instance flip flag
	cnt("v", 0);
	### just for solution converter
	print $out "(declare-const y$i (_ BitVec ".(length(sprintf("%b", $numPTrackH)))."))\n";     # instance y position
	print $out "(declare-const uw$i (_ BitVec ".(length(sprintf("%b", $trackEachPRow)))."))\n";	# unit width
	print $out "(declare-const w$i (_ BitVec ".(length(sprintf("%b", (2*$tmp_finger[0]+1))))."))\n";		# width
	print $out "(declare-const nf$i (_ BitVec ".(length(sprintf("%b", $tmp_finger[0])))."))\n";    # num of finger
	cnt("v", 0);
	cnt("v", 0);
	cnt("v", 0);
	cnt("v", 0);

}

print "a   B. Constraints for Placement\n";
print $out "\n";
print $out ";B. Constraints for Placement\n";

print("trackEachPRow ".$trackEachPRow."\n");
for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print(Dumper\@tmp_finger);
	#print $out "(assert (and (>= x$i 0) (<= x$i ".($numPTrackV - 2*$tmp_finger[0] + 1).")))\n";
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $len2 = length(sprintf("%b", 0));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_first = "#b".$tmp_str."0";
	$len2 = length(sprintf("%b", $numPTrackV - 2*$tmp_finger[0] + 1));
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-$len2-1){
			$tmp_str.="0";
		}
	}
	my $s_second = "#b".$tmp_str.sprintf("%b", ($numPTrackV - 2*$tmp_finger[0]));
	#print $out "(assert (and (bvuge x$i $s_first) (bvule x$i $s_second)))\n";
	print $out "(assert (and (bvsge x$i (_ bv0 $len)) (bvsle x$i (_ bv".($numPTrackV - 2*$tmp_finger[0] - 1)." $len))))\n";
	cnt("l", 0);
	cnt("l", 0);
	cnt("c", 0);
}

for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	#print $out "(assert (= y$i (_ bv".($numPTrackH-$inst[$i][2]/$tmp_finger[0])." ".length(sprintf("%b", $numPTrackH)).")))\n";
	print $out "(assert (= y$i (_ bv0 ".length(sprintf("%b", $numPTrackH)).")))\n"; # CFET y coordinate overlapping
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= nf$i (_ bv".$tmp_finger[0]." ".length(sprintf("%b", $tmp_finger[0])).")))\n";
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= uw$i (_ bv".$inst[$i][2]/$tmp_finger[0]." ".(length(sprintf("%b", $trackEachPRow))).")))\n";
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= w$i (_ bv".(2*$tmp_finger[0]+1)." ".length(sprintf("%b", 2*$tmp_finger[0]+1)).")))\n";
	cnt("l", 0);
	cnt("c", 0);
}

for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	print $out "(assert (= y$i (_ bv0 ".length(sprintf("%b", $numPTrackH)).")))\n";
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= nf$i (_ bv".$tmp_finger[0]." ".length(sprintf("%b", $tmp_finger[0])).")))\n";
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= uw$i (_ bv".$inst[$i][2]/$tmp_finger[0]." ".(length(sprintf("%b", $trackEachPRow))).")))\n";
	cnt("l", 0);
	cnt("c", 0);
	print $out "(assert (= w$i (_ bv".(2*$tmp_finger[0]+1)." ".length(sprintf("%b", 2*$tmp_finger[0]+1)).")))\n";
	cnt("l", 0);
	cnt("c", 0);
}

for my $i (0 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	my $len = length(sprintf("%b", $numTrackV))+4;
	my $tmp_str = "";
	if($len>1){
		for my $i(0 .. $len-2){
			$tmp_str.="0";
		}
	}
	#print $out "(assert (= (bvsmod x$i (_ bv2 $len)) (_ bv0 $len)))\n";
	print $out "(assert (= ((_ extract 0 0) x$i) #b1))\n";
	cnt("l", 0);
	cnt("c", 0);
}

my $tmp_minWidth = 0;
for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	$tmp_minWidth+=2*$tmp_finger[0];
}
$minWidth = $tmp_minWidth;
$tmp_minWidth = 0;
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	$tmp_minWidth+=2*$tmp_finger[0];
}
if($tmp_minWidth>$minWidth){
	$minWidth = $tmp_minWidth;
}

if($BS_Parameter == 1){
	print $out ";Removing Symmetric Placement Cases\n";
	my $numPMOS = $lastIdxPMOS + 1;
	my $numNMOS = $numInstance - $numPMOS;
	print "numPMOS : $numPMOS  numNMOS : $numNMOS\n";
	my @arr_pmos = ();
	my @arr_nmos = ();

	for my $i (0 .. $lastIdxPMOS){
		push(@arr_pmos, $i);
	}
	for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
		push(@arr_nmos, $i);
	}


	my @comb_l_pmos = ();
	my @comb_l_nmos = ();
	my @comb_c_pmos = ();
	my @comb_c_nmos = ();
	my @comb_r_pmos = ();
	my @comb_r_nmos = ();

	if($numPMOS % 2 == 0){
		my @tmp_comb_l_pmos = combine([@arr_pmos],$numPMOS/2);
		for my $i(0 .. $#tmp_comb_l_pmos){
			my @tmp_comb = ();
			my $isComb = 0;
			for my $j(0 .. $lastIdxPMOS){
				for my $k(0 .. $#{$tmp_comb_l_pmos[$i]}){
					if($tmp_comb_l_pmos[$i][$k] == $j){
						$isComb = 1;
						last;
					}
				}
				if($isComb == 0){
					push(@tmp_comb, $j);
				}
				$isComb = 0;
			}
			push(@comb_l_pmos, $tmp_comb_l_pmos[$i]);
			push(@comb_r_pmos, [@tmp_comb]);
			if($#tmp_comb_l_pmos == 1){
				last;
			}
		}
	}
	else{
		for my $m(0 .. $numPMOS - 1){
			@arr_pmos = ();
			for my $i (0 .. $lastIdxPMOS){
				if($i!=$m){
					push(@arr_pmos, $i);
				}
			}
			my @tmp_comb_l_pmos = combine([@arr_pmos],($numPMOS-1)/2);
			for my $i(0 .. $#tmp_comb_l_pmos){
				my @tmp_comb = ();
				my $isComb = 0;
				for my $j(0 .. $lastIdxPMOS){
					for my $k(0 .. $#{$tmp_comb_l_pmos[$i]}){
						if($tmp_comb_l_pmos[$i][$k] == $j || $j == $m){
							$isComb = 1;
							last;
						}
					}
					if($isComb == 0){
						push(@tmp_comb, $j);
					}
					$isComb = 0;
				}
				push(@comb_l_pmos, $tmp_comb_l_pmos[$i]);
				push(@comb_r_pmos, [@tmp_comb]);
				push(@comb_c_pmos, [($m)]);
				if($#tmp_comb_l_pmos == 1){
					last;
				}
			}
		}
	}
	if($numNMOS % 2 == 0){
		my @tmp_comb_l_nmos = combine([@arr_nmos],$numNMOS/2);
		for my $i(0 .. $#tmp_comb_l_nmos){
			my @tmp_comb = ();
			my $isComb = 0;
			for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
				for my $k(0 .. $#{$tmp_comb_l_nmos[$i]}){
					if($tmp_comb_l_nmos[$i][$k] == $j){
						$isComb = 1;
						last;
					}
				}
				if($isComb == 0){
					push(@tmp_comb, $j);
				}
				$isComb = 0;
			}
			push(@comb_l_nmos, $tmp_comb_l_nmos[$i]);
			push(@comb_r_nmos, [@tmp_comb]);
			if($#comb_l_nmos == 1){
				last;
			}
		}
	}
	else{
		for my $m ($lastIdxPMOS + 1 .. $numInstance - 1) {
			@arr_nmos = ();
			for my $i (0 .. $numNMOS-1){
				if($i+$lastIdxPMOS+1!=$m){
					push(@arr_nmos, $i+$lastIdxPMOS+1);
				}
			}
			my @tmp_comb_l_nmos = combine([@arr_nmos],($numNMOS-1)/2);
			for my $i(0 .. $#tmp_comb_l_nmos){
				my @tmp_comb = ();
				my $isComb = 0;
				for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
					for my $k(0 .. $#{$tmp_comb_l_nmos[$i]}){
						if($tmp_comb_l_nmos[$i][$k] == $j || $j == $m){
							$isComb = 1;
							last;
						}
					}
					if($isComb == 0){
						push(@tmp_comb, $j);
					}
					$isComb = 0;
				}
				push(@comb_l_nmos, $tmp_comb_l_nmos[$i]);
				push(@comb_r_nmos, [@tmp_comb]);
				push(@comb_c_nmos, [($m)]);
				if($#tmp_comb_l_nmos == 1){
					last;
				}
			}
		}
	}

	for my $i(0 .. $#comb_l_pmos){
		print $out "(assert (or";
		for my $l(0 .. $#{$comb_l_pmos[$i]}){
			for my $m(0 .. $#{$comb_r_pmos[$i]}){
				print $out " (bvslt x$comb_l_pmos[$i][$l] x$comb_r_pmos[$i][$m])";
				cnt("l", 0);
				for my $n(0 .. $#{$comb_c_pmos[$i]}){
					print $out " (bvslt x$comb_l_pmos[$i][$l] x$comb_c_pmos[$i][$n])";
					print $out " (bvsgt x$comb_r_pmos[$i][$m] x$comb_c_pmos[$i][$n])";
					cnt("l", 0);
					cnt("l", 0);
				}
			}
		}
		print $out "))\n";
		#print $out " (and";
		#for my $j(0 .. $#comb_l_nmos){
		#	print $out " (or";
		#	for my $l(0 .. $#{$comb_l_nmos[$j]}){
		#		for my $m(0 .. $#{$comb_r_nmos[$j]}){
		#			print $out " (bvslt x$comb_l_nmos[$j][$l] x$comb_r_nmos[$j][$m])";
		#			cnt("l", 0);
		#			for my $n(0 .. $#{$comb_c_nmos[$j]}){
		#				print $out " (bvslt x$comb_l_nmos[$j][$l] x$comb_c_nmos[$j][$n])";
		#				print $out " (bvsgt x$comb_r_nmos[$j][$m] x$comb_c_nmos[$j][$n])";
		#				cnt("l", 0);
		#				cnt("l", 0);
		#			}
		#		}
		#	}
		#	print $out ")";
		#}
		#print $out ")))\n";
		cnt("c", 0);
	}
	print $out ";Set flip status to false for FETs which have even numbered fingers\n";
	for my $i (0 .. $lastIdxPMOS) {
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		if($tmp_finger[0]%2==0){
			print $out "(assert (= ff$i false))\n";
			cnt("l", 0);
			cnt("c", 0);
		}
	}
	for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
		my @tmp_finger = ();
		@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
		if($tmp_finger[0]%2==0){
			print $out "(assert (= ff$i false))\n";
			cnt("l", 0);
			cnt("c", 0);
		}
	}
	print $out ";End of Symmetric Removal\n";
}

my @g_p_h1 = ();
my @g_p_h2 = ();
my @g_p_h3 = ();
my @g_n_h1 = ();
my @g_n_h2 = ();
my @g_n_h3 = ();
my $w_p_h1 = 0;
my $w_p_h2 = 0;
my $w_p_h3 = 0;
my $w_n_h1 = 0;
my $w_n_h2 = 0;
my $w_n_h3 = 0;
my %h_g_inst = ();
#for my $i (0 .. $lastIdxPMOS) {
#	my @tmp_finger = ();
#	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
#	if($tmp_finger[0]%2==0){
#		print $out "(assert (= ff$i false))\n";
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#}
#for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
#	my @tmp_finger = ();
#	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
#	if($tmp_finger[0]%2==0){
#		print $out "(assert (= ff$i false))\n";
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#}
# Mark: Only m<=3 is expected? We might have larger width
for my $i (0 .. $lastIdxPMOS) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	if($inst[$i][2]/$tmp_finger[0] == 1){
		push(@g_p_h1, $i);
		$w_p_h1+=2*$tmp_finger[0];
		$h_g_inst{$i} = 1;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 2){
		push(@g_p_h2, $i);
		$w_p_h2+=2*$tmp_finger[0];
		$h_g_inst{$i} = 2;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 3){
		push(@g_p_h3, $i);
		$w_p_h3+=2*$tmp_finger[0];
		$h_g_inst{$i} = 3;
	}
}
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	my @tmp_finger = ();
	@tmp_finger = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
	if($inst[$i][2]/$tmp_finger[0] == 1){
		push(@g_n_h1, $i);
		$w_n_h1+=2*$tmp_finger[0];
		$h_g_inst{$i} = 1;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 2){
		push(@g_n_h2, $i);
		$w_n_h2+=2*$tmp_finger[0];
		$h_g_inst{$i} = 2;
	}
	elsif($inst[$i][2]/$tmp_finger[0] == 3){
		push(@g_n_h3, $i);
		$w_n_h3+=2*$tmp_finger[0];
		$h_g_inst{$i} = 3;
	}
}

if($NDE_Parameter == 1) {
#for my $i (0 .. $#g_p_h1){
#	for my $j (0 .. $#g_p_h2){
#		print $out "(assert (bvslt x$g_p_h1[$i] x$g_p_h2[$j]))\n";
#		cnt("l", 0);
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#	for my $k (0 .. $#g_p_h3){
#		print $out "(assert (bvslt x$g_p_h1[$i] x$g_p_h3[$k]))\n";
#		cnt("l", 0);
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#	print $out "(assert (bvslt x$g_p_h1[$i] (_ bv".($numTrackV - 1 - ($w_p_h2>0?($w_p_h2+1):0) - ($w_p_h3>0?($w_p_h3+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#}
#for my $j (0 .. $#g_p_h2){
#	for my $k (0 .. $#g_p_h3){
#		print $out "(assert (bvslt x$g_p_h2[$j] x$g_p_h3[$k]))\n";
#		cnt("c", 0);
#	}
#	print $out "(assert (bvslt x$g_p_h2[$j] (_ bv".($numTrackV - 1 - ($w_p_h3>0?($w_p_h3+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#	print $out "(assert (bvsgt x$g_p_h2[$j] (_ bv".(($w_p_h1>0?($w_p_h1+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#}
#for my $k (0 .. $#g_p_h3){
#	print $out "(assert (bvslt x$g_p_h3[$k] (_ bv".($numTrackV - 1)." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#	print $out "(assert (bvsgt x$g_p_h3[$k] (_ bv".(($w_p_h1>0?($w_p_h1+1):0) + ($w_p_h2>0?($w_p_h2+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";
#	cnt("l", 0);
#	cnt("c", 0);
#}
#for my $i (0 .. $#g_n_h1){
#	for my $j (0 .. $#g_n_h2){
#		print $out "(assert (bvslt x$g_n_h1[$i] x$g_n_h2[$j]))\n";
#		cnt("l", 0);
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#	for my $k (0 .. $#g_n_h3){
#		print $out "(assert (bvslt x$g_n_h1[$i] x$g_n_h3[$k]))\n";
#		cnt("l", 0);
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#	print $out "(assert (bvslt x$g_n_h1[$i] (_ bv".($numTrackV - 1 - ($w_n_h2>0?($w_n_h2+1):0) - ($w_n_h3>0?($w_n_h3+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#}
#for my $j (0 .. $#g_n_h2){
#	for my $k (0 .. $#g_n_h3){
#		print $out "(assert (bvslt x$g_n_h2[$j] x$g_n_h3[$k]))\n";
#		cnt("l", 0);
#		cnt("l", 0);
#		cnt("c", 0);
#	}
#	print $out "(assert (bvslt x$g_n_h2[$j] (_ bv".($numTrackV - 1 - ($w_n_h3>0?($w_n_h3+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#	print $out "(assert (bvsgt x$g_n_h2[$j] (_ bv".(($w_n_h1>0?($w_n_h1+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#}
#for my $k (0 .. $#g_n_h3){
#	print $out "(assert (bvslt x$g_n_h3[$k] (_ bv".($numTrackV - 1)." ".(length(sprintf("%b", $numTrackV))+4).")))\n";;
#	cnt("l", 0);
#	cnt("c", 0);
#	print $out "(assert (bvsgt x$g_n_h3[$k] (_ bv".(($w_n_h1>0?($w_n_h1+1):0) + ($w_n_h2>0?($w_n_h2+1):0))." ".(length(sprintf("%b", $numTrackV))+4).")))\n";
#	cnt("l", 0);
#	cnt("c", 0);
#}
}

for my $i (0 .. $lastIdxPMOS) {
	for my $j (0 .. $lastIdxPMOS) {
		if($i != $j){
			my $tmp_key_S_i = $h_pin_id{"$inst[$i][0]_S"};
			my $tmp_key_D_i = $h_pin_id{"$inst[$i][0]_D"};
			my $tmp_key_S_j = $h_pin_id{"$inst[$j][0]_S"};
			my $tmp_key_D_j = $h_pin_id{"$inst[$j][0]_D"};
			my @tmp_finger_i = ();
			@tmp_finger_i = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
			my @tmp_finger_j = ();
			@tmp_finger_j = getAvailableNumFinger($inst[$j][2], $trackEachPRow);

			my $height_i = $inst[$i][2]/$tmp_finger_i[0];
			my $height_j = $inst[$j][2]/$tmp_finger_j[0];
			
			my $tmp_str_ij = "";
			my $tmp_str_ji = "";
			if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
				$tmp_str_ij = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
				$tmp_str_ji = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$j false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_D_j) (= $tmp_key_S_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "(= ff$j false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_D_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$i false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_D_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "(= ff$i false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_S_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
#				$tmp_str_ij = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_S_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$j 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (= $tmp_key_D_i $tmp_key_S_j))))";
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ij = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ij = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ij = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ij = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ij = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = ffj
								$tmp_str_ij = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ij = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj =0
								$tmp_str_ij = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ij = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0
								$tmp_str_ij = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ij = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0 and ffj=0
								$tmp_str_ij = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ij = "(= #b1 #b0)";
							}
						}
					}
				}
				# nli = nrj
#				$tmp_str_ji = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_D_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (= $tmp_key_S_i $tmp_key_D_j))))";
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ji = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ji = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ji = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ji = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ji = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = ffj
								$tmp_str_ji = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ji = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj =0
								$tmp_str_ji = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ji = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0
								$tmp_str_ji = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ji = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0 and ffj=0
								$tmp_str_ji = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ji = "(= #b1 #b0)";
							}
						}
					}
				}
			}
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $len2 = length(sprintf("%b", 2*$tmp_finger_i[0]));
			my $tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $f_wi = "(_ bv".(2*$tmp_finger_i[0])." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_j[0]));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $f_wj = "(_ bv".(2*$tmp_finger_j[0])." $len)";
			$len2 = length(sprintf("%b", $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol = "(_ bv".$XOL_Parameter." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_i[0] + $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol_i = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter)." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_j[0] + $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol_j = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter)." $len)";
			if(($height_i == $height_j) && ($tmp_key_S_i == $tmp_key_S_j || $tmp_key_S_i == $tmp_key_D_j || $tmp_key_D_i == $tmp_key_S_j || $tmp_key_D_i == $tmp_key_D_j)){
				print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
				print $out "        (ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
				print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
				print $out "	    (ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
				print $out "	    (= #b1 #b0))))))\n";
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("c", 0);
			}
			else{
				print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
				print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
				print $out "	    (= #b1 #b0))))\n";
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("c", 0);
			}
		}
	}
}
for my $i ($lastIdxPMOS + 1 .. $numInstance - 1) {
	for my $j ($lastIdxPMOS + 1 .. $numInstance - 1) {
		if($i != $j){
			my $tmp_key_S_i = $h_pin_id{"$inst[$i][0]_S"};
			my $tmp_key_D_i = $h_pin_id{"$inst[$i][0]_D"};
			my $tmp_key_S_j = $h_pin_id{"$inst[$j][0]_S"};
			my $tmp_key_D_j = $h_pin_id{"$inst[$j][0]_D"};
			my @tmp_finger_i = ();
			@tmp_finger_i = getAvailableNumFinger($inst[$i][2], $trackEachPRow);
			my @tmp_finger_j = ();
			@tmp_finger_j = getAvailableNumFinger($inst[$j][2], $trackEachPRow);
			
			my $height_i = $inst[$i][2]/$tmp_finger_i[0];
			my $height_j = $inst[$j][2]/$tmp_finger_j[0];

			my $tmp_str_ij = "";
			my $tmp_str_ji = "";
			if($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 0){
				$tmp_str_ij = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
				$tmp_str_ji = "(= (_ bv$tmp_key_S_i ".length(sprintf("%b", $numNets_org)).") (_ bv$tmp_key_S_j ".length(sprintf("%b", $numNets_org))."))";
			}
			elsif($tmp_finger_i[0] % 2 == 0 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$j false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_D_j) (= $tmp_key_S_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$j true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_D_j){
						$tmp_str_ji = "(= ff$j false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_D_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 0){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
				if($tmp_key_S_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "";
					}
					else{
						$tmp_str_ij = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_S_j){
						$tmp_str_ij = "(= ff$i false)";
					}
					else{
						$tmp_str_ij = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ij = "(ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j) (= $tmp_key_D_i $tmp_key_S_j))";
				# nli = nrj
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "";
					}
					else{
						$tmp_str_ji = "(= ff$i true)";
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						$tmp_str_ji = "(= ff$i false)";
					}
					else{
						$tmp_str_ji = "(= #b0 #b1)";
					}
				}
				#$tmp_str_ji = "(ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_S_j) (= $tmp_key_S_i $tmp_key_S_j))";
			}
			elsif($tmp_finger_i[0] % 2 == 1 && $tmp_finger_j[0] % 2 == 1){
				# if nf % 2 == 1, if ff = 1 nl = $tmp_key_D, nr = $tmp_key_S
				#                 if ff = 0 nl = $tmp_key_S, nr = $tmp_key_D
				# nri = nlj
#				$tmp_str_ij = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_S_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$i 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ij = $tmp_str_ij." (ite (= ff$j 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ij = $tmp_str_ij." (= $tmp_key_D_i $tmp_key_S_j))))";
				if($tmp_key_S_i == $tmp_key_D_j){
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ij = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ij = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ij = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ij = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ij = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi = ffj
								$tmp_str_ij = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ij = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_S_i == $tmp_key_S_j){
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ij = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffj =0
								$tmp_str_ij = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ij = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_D_i == $tmp_key_D_j){
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0
								$tmp_str_ij = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ij = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_D_i == $tmp_key_S_j){
								## ffi=0 and ffj=0
								$tmp_str_ij = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ij = "(= #b1 #b0)";
							}
						}
					}
				}
				# nli = nrj
#				$tmp_str_ji = "(ite (and (= ff$i 1) (= ff$j 1)) (= $tmp_key_D_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$i 1) (= $tmp_key_D_i $tmp_key_D_j)";
#				$tmp_str_ji = $tmp_str_ji." (ite (= ff$j 1) (= $tmp_key_S_i $tmp_key_S_j)";
#				$tmp_str_ji = $tmp_str_ji." (= $tmp_key_S_i $tmp_key_D_j))))";
				if($tmp_key_D_i == $tmp_key_S_j){
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = 0,1, ffj = 0,1
								$tmp_str_ji = "";
							}
							else{
								## ffi,ffj!=0 at the same time
								$tmp_str_ji = "(or (>= ff$i true) (>= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ~(ffi=0 & ffj=1)
								$tmp_str_ji = "(or (and (= ff$i true) (= ff$j true)) (= ff$j false))";
							}
							else{
								## ffi = 1
								$tmp_str_ji = "(= ff$i true)";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj=1 or (ffi = 0 and ffj= 0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j false)) (= ff$j true))";
							}
							else{
								## ffj=1
								$tmp_str_ji = "(= ff$j true)";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi = ffj
								$tmp_str_ji = "(= ff$i ff$j)";
							}
							else{
								## ffi=1 and ffj=1
								$tmp_str_ji = "(and (= ff$i true) (= ff$j true))";
							}
						}
					}
				}
				else{
					if($tmp_key_D_i == $tmp_key_D_j){
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## (ffi=0 and ffj=1) or ffj=0
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (= ff$j false))";
							}
							else{
								## (ffi=0 and ffj=1) or (ffi=1 and ffj=0)
								$tmp_str_ji = "(or (and (= ff$i false) (= ff$j true)) (and (= ff$i true) (= ff$j false)))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffj =0
								$tmp_str_ji = "(= ff$j false)";
							}
							else{
								## ffi=1 and ffj=0
								$tmp_str_ji = "(and (= ff$i true) (= ff$j false))";
							}
						}
					}
					else{
						if($tmp_key_S_i == $tmp_key_S_j){
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0
								$tmp_str_ji = "(= ff$i false)";
							}
							else{
								## ffi=0 and ffj=1
								$tmp_str_ji = "(and (= ff$i false) (= ff$j true))";
							}
						}
						else{
							if($tmp_key_S_i == $tmp_key_D_j){
								## ffi=0 and ffj=0
								$tmp_str_ji = "(and (= ff$i false) (= ff$j false))";
							}
							else{
								## ffi=0 and ffj=0
								$tmp_str_ji = "(= #b1 #b0)";
							}
						}
					}
				}
			}
			my $len = length(sprintf("%b", $numTrackV))+4;
			my $len2 = length(sprintf("%b", 2*$tmp_finger_i[0]));
			my $tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $f_wi = "(_ bv".(2*$tmp_finger_i[0])." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_j[0]));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $f_wj = "(_ bv".(2*$tmp_finger_j[0])." $len)";
			$len2 = length(sprintf("%b", $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol = "(_ bv".$XOL_Parameter." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_i[0] + $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol_i = "(_ bv".(2*$tmp_finger_i[0] + $XOL_Parameter)." $len)";
			$len2 = length(sprintf("%b", 2*$tmp_finger_j[0] + $XOL_Parameter));
			$tmp_str = "";
			if($len>1){
				for my $i(0 .. $len-$len2-1){
					$tmp_str.="0";
				}
			}
			my $xol_j = "(_ bv".(2*$tmp_finger_j[0] + $XOL_Parameter)." $len)";
			if(($height_i == $height_j) && ($tmp_key_S_i == $tmp_key_S_j || $tmp_key_S_i == $tmp_key_D_j || $tmp_key_D_i == $tmp_key_S_j || $tmp_key_D_i == $tmp_key_D_j)){
				print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
				print $out "        (ite (and (= (bvadd x$i ".($f_wi).") x$j) $tmp_str_ij) (= (bvadd x$i ".($f_wi).") x$j)\n";
				print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
				print $out "	    (ite (and (= (bvsub x$i ".($f_wj).") x$j) $tmp_str_ji) (= (bvsub x$i ".($f_wj).") x$j)\n";
				print $out "	    (= #b1 #b0))))))\n";
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("c", 0);
			}
			else{
				print $out "(assert (ite (bvslt (bvadd x$i ".($f_wi).") x$j) (bvsle (bvadd x$i $xol_i) x$j)\n";
				print $out "	    (ite (bvsgt (bvsub x$i ".($f_wj).") x$j) (bvsge (bvsub x$i $xol_j) x$j)\n";
				print $out "	    (= #b1 #b0))))\n";
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("l", 0);
				cnt("c", 0);
			}
		}
	}
}
print $out "\n";

### Routing ###
print "a   C. Variables for Routing\n";
#### Metal binary variables
#for my $udeIndex (0 .. $#udEdges) {
#    print $out "(declare-const M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] Bool)\n";
#	cnt("v", 2);
#}
#for my $vEdgeIndex (0 .. $#virtualEdges) {
#    print $out "(declare-const M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] Bool)\n";
#	cnt("v", 2);
#}
#### Extensible Boundary variables
## In Extensible Case , Metal binary variables
#for my $leftVertex (0 .. $#leftCorners) {
#	my $metal = (split /[a-z]/, $leftCorners[$leftVertex])[1];
#	if ($metal % 2 == 0) {
#		print $out "(declare-const M_LeftEnd_$leftCorners[$leftVertex] Bool)\n";
#		cnt("v", 2);
#	}
#}
#for my $rightVertex (0 .. $#rightCorners) {
#	my $metal = (split /[a-z]/, $rightCorners[$rightVertex])[1];
#	if ($metal % 2 == 0) {
#		print $out "(declare-const M_$rightCorners[$rightVertex]_RightEnd Bool)\n";
#		cnt("v", 2);
#	}
#}
#for my $frontVertex (0 .. $#frontCorners) {
#	my $metal = (split /[a-z]/, $frontCorners[$frontVertex])[1];
#	if ($metal % 2 == 1) {
#		print $out "(declare-const M_FrontEnd_$frontCorners[$frontVertex] Bool)\n";
#		cnt("v", 2);
#	}
#}
#for my $backVertex (0 .. $#backCorners) {
#	my $metal = (split /[a-z]/, $backCorners[$backVertex])[1];
#	if ($metal % 2 == 1) {
#		print $out "(declare-const M_$backCorners[$backVertex]_BackEnd Bool)\n";
#		cnt("v", 2);
#	}
#}
#### Edge binary variables
#for my $netIndex (0 .. $#nets) {
#    for my $udeIndex (0 .. $#udEdges) {
#        print $out "(declare-const N$nets[$netIndex][1]_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] Bool)\n";
#		cnt("v", 2);
#    }
#    ### VIRTUAL_EDGE [index] [Origin] [Destination] [Cost=0]
#    #@net = ($netName, $netID, $N_pinNets, $source_ofNet, $numSinks, [@sinks_inNet], [@pins_inNet]);
#    for my $vEdgeIndex (0 .. $#virtualEdges) {
#		my $isInNet = 0;
#        if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
#			if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
#				$isInNet = 1;
#			}
#			if($isInNet == 1){
#				print $out "(declare-const N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] Bool)\n";
#				cnt("v", 2);
#			}
#			$isInNet = 0;
#			for my $i (0 .. $nets[$netIndex][4]-1){
#				if($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$i]){
#					$isInNet = 1;
#				}
#			}
#			if($isInNet == 1){
#				print $out "(declare-const N$nets[$netIndex][1]_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] Bool)\n";
#				cnt("v", 2);
#			}
#        }
#    }
#}
#### Commodity Flow binary variables
#for my $netIndex (0 .. $#nets) {
#    for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
#        for my $udEdgeIndex (0 .. $#udEdges) {
#            print $out "(declare-const N$nets[$netIndex][1]_C$commodityIndex\_E_$udEdges[$udEdgeIndex][1]_$udEdges[$udEdgeIndex][2] Bool)\n";
#			cnt("v", 2);
#        }
#        for my $vEdgeIndex (0 .. $#virtualEdges) {
#            if ($virtualEdges[$vEdgeIndex][2] =~ /^pin/) { # source
#				if ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3]){
#					print $out "(declare-const N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] Bool)\n";
#					cnt("v", 2);
#				}
#				elsif ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]){
#					print $out "(declare-const N$nets[$netIndex][1]_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2] Bool)\n";
#					cnt("v", 2);
#				}
#            }
#        }
#    }
#}
#
#### Geometric binary variables  [2019-01-11] Geometric binary variables update
#for my $metal (1 .. $numMetalLayer) { 
#    for my $row (0 .. $numTrackH-3) {
#        for my $col (0 .. $numTrackV-1) {
#            $vName = "m".$metal."r".$row."c".$col;
#			if ($metal % 2 == 1){
#				if($col % 2 == 1){
#					next;
#				}
#				print $out "(declare-const GF_V_$vName Bool)\n";
#				cnt("v", 6);
#				print $out "(declare-const GB_V_$vName Bool)\n";
#				cnt("v", 6);
#			}
#            elsif ($metal % 2 == 0) {
#                print $out "(declare-const GL_V_$vName Bool)\n";
#				cnt("v", 6);
#                print $out "(declare-const GR_V_$vName Bool)\n";
#				cnt("v", 6);
#            }
#            else {
#                print $out "(declare-const GF_V_$vName Bool)\n";
#				cnt("v", 6);
#                print $out "(declare-const GB_V_$vName Bool)\n";
#				cnt("v", 6);
#            }
#        }
#    }
#}
#print $out "\n";

print "a   D. Constraints for Routing\n";

### SOURCE and SINK DEFINITION per NET per COMMODITY and per VERTEX (including supernodes, i.e., pins)
print "a     10. Variable conditions, e.g., bound and binary, ";
### Preventing from routing Source/Drain Node using M1 Layer. Only Gate Node can use M1 between PMOS/NMOS Region
### UNDIRECTED_EDGE [index] [Term1] [Term2] [Cost]
#";Source/Drain Node between PMOS/NMOS region can not connect using M1 Layer.\n\n"; 
# Mark: This need to be modified as conditional constraints for shared and split structure. (In CFET, we use M1 as LI.)
#for my $udeIndex (0 .. $#udEdges) {
#    my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
#    my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
#    my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
#    my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
#    my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
#    my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
#		if($fromCol % 2 == 1 || $toCol %2 == 1){
#			if($fromMetal == 1 && $toMetal == 1){
#				print $out "(assert (= M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false))\n";
#				$h_assign{"M_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
#			}
#		}
#}
#for my $netIndex (0 .. $#nets) {
#    for my $udeIndex (0 .. $#udEdges) {
#		my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
#		my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
#		my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
#		my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
#		my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
#		my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
#			if($fromCol % 2 == 1 || $toCol %2 == 1){
#				if($fromMetal == 1 && $toMetal == 1){
#					print $out "(assert (= N$nets[$netIndex][1]\_";
#					print $out "E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false))\n";
#					$h_assign{"N$nets[$netIndex][1]\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
#				}
#			}
#    }
#}
#for my $netIndex (0 .. $#nets) {
#    for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {
#        for my $udeIndex (0 .. $#udEdges) {
#			my $fromCol = (split /[a-z]/, $udEdges[$udeIndex][1])[3]; # 1:metal 2:row 3:col
#			my $toCol   = (split /[a-z]/, $udEdges[$udeIndex][2])[3];
#			my $fromRow = (split /[a-z]/, $udEdges[$udeIndex][1])[2]; # 1:metal 2:row 3:col
#			my $toRow   = (split /[a-z]/, $udEdges[$udeIndex][2])[2];
#			my $fromMetal = (split /[a-z]/, $udEdges[$udeIndex][1])[1]; # 1:metal 2:row 3:col
#			my $toMetal = (split /[a-z]/, $udEdges[$udeIndex][2])[1];
#				if($fromCol % 2 == 1 || $toCol %2 == 1){
#					if($fromMetal == 1 && $toMetal == 1){
##						print $out "(assert (= N$nets[$netIndex][1]\_";
##						print $out "C$commodityIndex\_";
##						print $out "E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2] false))\n";
#						$h_assign{"N$nets[$netIndex][1]\_C$commodityIndex\_E_$udEdges[$udeIndex][1]_$udEdges[$udeIndex][2]"} = 0;
#					}
#				}
#            }
#    }
#}
my %NMOS_forbidden = {};
my %PMOS_forbidden = {};
# YW data structure: $virtualEdges
#		[
#           [vEindex],
#           [vertex],
#           [pinSON/SIN],
#           [edge_COST]
#       ];
if ($stack_struct_flag eq "PN") {
	# Mark: Forbidden access NMOS on the second and third track
	for my $vEdgeIndex (0 .. $#virtualEdges) {
		# print("virtualEdges: $virtualEdges[$vEdgeIndex][1]\n");
		# Extract Col and Row information from vertex name
		my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
		# print("toCol ".$toCol."\n");
		my $toRow   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[2];
		# print("toRow ".$toRow."\n");
		my $len = length(sprintf("%b", $numTrackV))+4;

		my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$virtualEdges[$vEdgeIndex][2]}][6]};
		if($instIdx > $lastIdxPMOS && ($toRow != 0 && $toRow != 3 ) && ($toCol > 0 && $toCol <= $numTrackV-2) && ($virtualEdges[$vEdgeIndex][2] ne "pinSON")) {
			#print "Forbidden M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]\n";
			my $tmp_name = "M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
			print("tmp_name, $tmp_name\n");
			if (! exists($NMOS_forbidden{$tmp_name}) ) {
				$NMOS_forbidden{$tmp_name} = 0;
			}
		}	
	}
} else {
	# stack_struct_flag == "NP"
	# Mark: Forbidden access PMOS on the second and third track
	for my $vEdgeIndex (0 .. $#virtualEdges) {
		
		my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
		my $toRow   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[2];
		my $len = length(sprintf("%b", $numTrackV))+4;

		my $instIdx = $h_inst_idx{$pins[$h_pinId_idx{$virtualEdges[$vEdgeIndex][2]}][6]};
		if($instIdx <= $lastIdxPMOS && ($toRow != 0 && $toRow != 3 ) && ($toCol > 0 && $toCol <= $numTrackV-2) && ($virtualEdges[$vEdgeIndex][2] ne "pinSON")) {
			#print "Forbidden M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]\n";
			my $tmp_name = "M_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
			print("tmp_name, $tmp_name\n");
			if (! exists($PMOS_forbidden{$tmp_name}) ) {
				$PMOS_forbidden{$tmp_name} = 0;
			}
		}	
	}
}