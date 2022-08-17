#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use warnings;
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

# metal pitch per layer
my %mapMP = (
	1 => 1,
	2 => 2,
	3 => 2,
	4 => 3	
);
# offset per layer
my %mapOffSet = (
	1 => 2, 
	2 => 2, 
	3 => 1, 
	4 => 1
);

# standard cell dimension
my $std_width = 10;
my $std_height = 10;


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

### YW
# [METAL] => [Vertices Name ordered by metal direction]
# Example: Odd layer 		=> 	[m4r[1-10]c1]...
# Example: Horizontal layer => 	[m3r1c[1-9]]...
my %map_metal_to_vertices = ();

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
			$numPTrackH = $1; # CFET
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
print "something\n";
print "a     # Pins              = $totalPins\n";
print "a     # Nets              = $totalNets\n";
print "something\n";
print "something\n";
print "something\n";
print "something\n";
print "something\n";

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

# YW: for gear ratio temp variable
my $MP = 0;		# curr metal mp
my $upMP = 0;	# upper metal mp
my $loMP = 0;	# lower metal mp

# offset always perpendicular to metal direction

my $row = 0;	# abs coordinate as row
my $col = 0;	# abs coordinate as col

my $upRow = 0;
my $loRow = 0;

my $upCol = 0;
my $loCol = 0;

# numTrackV and numTrackH for each layer
my %map_numTrackV = ();
my %map_numTrackH = ();

### DATA STRUCTURE:  VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### DATA STRUCTURE:  ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
# print "before iteration, $std_height by $std_width\n";
for my $metal (1 .. $numMetalLayer) {  # Odd Layers: Vertical Direction   Even Layers: Horizontal Direction
	# get current metal layer
	$MP = $mapMP{$metal};
	# print "start iteration\n";

	if ($metal == 1) {
		# print "*****metal 1*****\n";
		# store layer specific vertices
		my @temp_vertices = ();
		# numTrackV and numTrackH
		my $temp_numTrackV = 0;	#col
		my $temp_numTrackH = 0;	#row
		
		# vertical Metal direction (col-based)
		my $horOffset = $mapOffSet{$metal};
		my $verOffset = $mapOffSet{$metal + 1};

		# M2 Metal Pitch
		$upMP = $mapMP{$metal + 1}; 

		# No Lower Metal at M1
		$loMP = 0;
		
		$row = $horOffset;	# row offset horiztonally --- x
		$col = $verOffset;  # col offset vertically | y

		while ($col < $std_width) {
			# print "current col at $col\n";
			$row = $horOffset;
			# vertices w.r.t upper adjacent layer
			while ($row < $std_height) {
				# print "current row at $row\n";
				# Current vertex
				$vName = "m".$metal."r".$row."c".$col;
				# Left Vertex, horiztontal direction
				if ($col == $verOffset) { 
					# if at vertical Offset, do nothing
					$vL = "null";
				} 
				else {
					$vL = "m".$metal."r".$row."c".($col-$MP);
				}

				# Right Vertex, horizontal direction
				if ($col + $MP > $std_width) {
					# if at vertical Offset, do nothing
					$vR = "null";
				}
				else {
					$vR = "m".$metal."r".$row."c".($col+$MP);
				}
				
				# Front Vertex, vertical direction, look at row
				if ($row == $horOffset) {
					$vF = "null";
				}
				else {
					$vF = "m".$metal."r".($row-$upMP)."c".$col;
				}

				# Back Vertex
				if ($row + $upMP > $std_height) {
					$vB = "null";
				}
				else {
					$vB = "m".$metal."r".($row+$upMP)."c".$col;
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

				if ($row == $horOffset || $col == $verOffset) { ### FL Vertex
					$vFL = "null";
				}
				else {
					$vFL = "m".$metal."r".($row-$upMP)."c".($col-$MP);
				}

				if ($row == $horOffset || $col + $MP > $std_width) { ### FR Vertex
					$vFR = "null";
				}
				else {
					$vFR = "m".$metal."r".($row-$upMP)."c".($col+$MP);
				}

				if ($row + $upMP > $std_height || $col == $verOffset) { ### BL Vertex
					$vBL = "null";
				}
				else {
					$vBL = "m".$metal."r".($row+$upMP)."c".($col-$MP);
				}

				if ($row + $upMP > $std_height || $col + $MP > $std_width) { ### BR Vertex
					$vBR = "null";
				}
				else {
					$vBR = "m".$metal."r".($row+$upMP)."c".($col+$MP);
				}
				
				@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
				$vertices{$vName} = [@vertex];
				$vIndex++;

				push(@temp_vertices, $vName);

				$row += $upMP; # row abid to M2
				$temp_numTrackH += 1;
			}

			$col += $MP;
			$temp_numTrackV += 1;
		}
		$temp_numTrackH /= $temp_numTrackV;

		# map number of metal tracks
		$map_numTrackV{$metal} = int($temp_numTrackV);
		$map_numTrackH{$metal} = int($temp_numTrackH);
		
		$map_metal_to_vertices{$metal} = [@temp_vertices];
	}
	elsif ($metal == $numMetalLayer) {
		print "*****Last Layer*****\n";
		# only concern lower level

		my @temp_vertices = ();

		# numTrackV and numTrackH
		my $temp_numTrackV = 0;	#col
		my $temp_numTrackH = 0;	#row

		# Last layer is odd (vertical, col-based)
		if ($metal % 2 != 0) {
			my $horOffset = $mapOffSet{$metal - 1};
			my $verOffset = $mapOffSet{$metal};

			# low Metal Pitch
			$loMP = $mapMP{$metal - 1}; 

			# No Up Metal at M1
			$upMP = 0;
			
			$row = $horOffset;	# row offset horiztonally --- x
			$col = $verOffset;  # col offset vertically | y

			while ($col < $std_width) {
				# reset row
				$row = $horOffset;
				# vertices w.r.t lower adjacent layer
				while ($row < $std_height) {
					# Current vertex
					$vName = "m".$metal."r".$row."c".$col;
					# Left Vertex, horiztontal direction
					if ($col == $verOffset) { 
						# if at vertical Offset, do nothing
						$vL = "null";
					} 
					else {
						$vL = "m".$metal."r".$row."c".($col-$MP);
					}

					# Right Vertex, horizontal direction
					if ($col+$MP > $std_width) {
						# if at vertical Offset, do nothing
						$vR = "null";
					}
					else {
						$vR = "m".$metal."r".$row."c".($col+$MP);
					}
					
					# Front Vertex, vertical direction, look at row
					if ($row == $horOffset) {
						$vF = "null";
					}
					else {
						$vF = "m".$metal."r".($row-$loMP)."c".$col;
					}

					# Back Vertex
					if ($row + $loMP > $std_height) {
						$vB = "null";
					}
					else {
						$vB = "m".$metal."r".($row+$loMP)."c".$col;
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

					if ($row == $horOffset || $col == $verOffset) { ### FL Vertex
						$vFL = "null";
					}
					else {
						$vFL = "m".$metal."r".($row-$loMP)."c".($col-$MP);
					}

					if ($row == $horOffset || $col + $MP > $std_width) { ### FR Vertex
						$vFR = "null";
					}
					else {
						$vFR = "m".$metal."r".($row-$loMP)."c".($col+$MP);
					}

					if ($row + $loMP > $std_height || $col == $verOffset) { ### BL Vertex
						$vBL = "null";
					}
					else {
						$vBL = "m".$metal."r".($row+$loMP)."c".($col-$MP);
					}

					if ($row + $loMP > $std_height || $col + $MP > $std_width) { ### BR Vertex
						$vBR = "null";
					}
					else {
						$vBR = "m".$metal."r".($row+$loMP)."c".($col+$MP);
					}
					
					@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
					@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
					$vertices{$vName} = [@vertex];
					$vIndex++;

					push(@temp_vertices, $vName);

					$row += $loMP; # row abid to M2
					$temp_numTrackH += 1;
				}

				$col += $MP;
				$temp_numTrackV += 1;
			}

			$temp_numTrackH /= $temp_numTrackV;

		}
		# Last layer is even (horizontal, row-based)
		if ($metal % 2 == 0) {
			my $horOffset = $mapOffSet{$metal};
			my $verOffset = $mapOffSet{$metal - 1};

			# M2 Metal Pitch
			$loMP = $mapMP{$metal - 1}; 

			# No Lower Metal at M1
			$upMP = 0;
			
			$row = $horOffset;	# row offset horiztonally --- x
			$col = $verOffset;  # col offset vertically | y

			while ($row < $std_height) {
				# reset
				$col = $verOffset;
				# vertices w.r.t lower adjacent layer
				while ($col < $std_width) {
					# Current vertex
					$vName = "m".$metal."r".$row."c".$col;

					# Left Vertex, horiztontal direction
					if ($col == $verOffset) {
						# if at vertical Offset, do nothing
						$vL = "null";
					} 
					else {
						$vL = "m".$metal."r".$row."c".($col-$loMP);
					}

					# Right Vertex, horizontal direction
					if ($col+$loMP > $std_width) {
						# if at vertical Offset, do nothing
						$vR = "null";
					}
					else {
						$vR = "m".$metal."r".$row."c".($col+$loMP);
					}
					
					# Front Vertex, vertical direction, look at row
					if ($row == $horOffset) {
						$vF = "null";
					}
					else {
						$vF = "m".$metal."r".($row-$MP)."c".$col;
					}

					# Back Vertex
					if ($row + $MP > $std_height) {
						$vB = "null";
					}
					else {
						$vB = "m".$metal."r".($row+$MP)."c".$col;
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

					if ($row == $horOffset || $col == $verOffset) { ### FL Vertex
						$vFL = "null";
					}
					else {
						$vFL = "m".$metal."r".($row-$MP)."c".($col-$loMP);
					}

					if ($row == $horOffset || $col + $MP > $std_width) { ### FR Vertex
						$vFR = "null";
					}
					else {
						$vFR = "m".$metal."r".($row-$MP)."c".($col+$loMP);
					}

					if ($row + $MP > $std_height || $col == $verOffset) { ### BL Vertex
						$vBL = "null";
					}
					else {
						$vBL = "m".$metal."r".($row+$MP)."c".($col-$loMP);
					}

					if ($row + $MP > $std_height || $col + $MP > $std_width) { ### BR Vertex
						$vBR = "null";
					}
					else {
						$vBR = "m".$metal."r".($row+$MP)."c".($col+$loMP);
					}
					
					@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
					@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
					$vertices{$vName} = [@vertex];
					$vIndex++;

					push(@temp_vertices, $vName);

					$col += $loMP;
					$temp_numTrackV += 1;
				}
				$row += $MP;
				$temp_numTrackH += 1;
			}
			$temp_numTrackV /= $temp_numTrackH;
		}

		# map number of metal tracks
		$map_numTrackV{$metal} = int($temp_numTrackV);
		$map_numTrackH{$metal} = int($temp_numTrackH);

		$map_metal_to_vertices{$metal} = [@temp_vertices];
	}
	elsif ($metal % 2 == 0) { # 2, 4, 6, ...
		print "*****Even Layer*****\n";
		my @temp_vertices = ();
		# numTrackV and numTrackH
		my $temp_numTrackVup = 0;	#upcol
		my $temp_numTrackVlo = 0;	#lowcol
		my $temp_numTrackH = 0;	#row
		# horizontal Metal direction (row-based)
		my $horOffset = $mapOffSet{$metal};
		my $upVerOffset = $mapOffSet{$metal + 1};
		my $loVerOffset = $mapOffSet{$metal - 1};

		# M3 Metal Pitch, vertical col
		$upMP = $mapMP{$metal + 1}; 

		# M1 Metal Pitch, vertical col
		$loMP = $mapMP{$metal - 1}; 
		
		$row = $horOffset;	# row offset horiztonally --- x
		$upCol = $upVerOffset;  # col offset vertically | y
		$loCol = $loVerOffset;  # col offset vertically | y

		while($row < $std_height) {
			# horiztontal w.r.t upper adjacent layer
			$upCol = $upVerOffset; 
			$loCol = $loVerOffset;
			while ($upCol < $std_width) {
				$vName = "m".$metal."r".$row."c".$upCol;
				# Left Vertex, horiztontal direction
				if ($upCol == $upVerOffset) { 
					# if at vertical Offset, do nothing
					$vL = "null";
				}
				else {
					$vL = "m".$metal."r".$row."c".($upCol-$MP);
				}
				
				# Right Vertex, horizontal direction
				if ($upCol + $upMP > $std_width) {
					$vR = "null";
				}
				else {
					$vR = "m".$metal."r".$row."c".($upCol+$upMP);
				}

				# Front Vertex, vertical direction, look at row
				if ($row == $horOffset) {
					$vF = "null";
				}
				else {
					$vF = "m".$metal."r".($row-$MP)."c".$upCol;
				}
				
				# Back Vertex, vertical direction, look at row
				if ($row + $MP > $std_height) {
					$vB = "null";
				}
				else {
					$vB = "m".$metal."r".($row + $MP)."c".$upCol;
				}

				# No change
				if ($metal == $numMetalLayer) { ### Up Vertex
					$vU = "null";
				}
				else {
					$vU = "m".($metal+1)."r".$row."c".$upCol;
				}

				# No change
				if ($metal == 1) { ### Down Vertex
					$vD = "null";
				}
				else {
					$vD = "m".($metal-1)."r".$row."c".$upCol;
				}
				
				# FL Vertex, horizonal/vertical direction
				if ($row == $horOffset || $upCol == $upVerOffset) {
					$vFL = "null";
				}
				else {
					$vFL = "m".$metal."r".($row-$MP)."c".($upCol-$upMP);
				}

				# FR Vertex, horizonal/vertical direction
				if ($row == $horOffset || $upCol + $upMP > $std_width) {
					$vFR = "null";
				}
				else {
					$vFR = "m".$metal."r".($row-$MP)."c".($upCol+$upMP);
				}

				# BL Vertex, horizonal/vertical direction
				if ($row + $MP > $std_height || $upCol == $upVerOffset) {
					$vBL = "null";
				}
				else {
					$vBL = "m".$metal."r".($row+$MP)."c".($upCol-$upMP);
				}

				# BR Vertex, horizonal/vertical direction
				if ($row + $MP > $std_height || $upCol + $upMP > $std_width) {
					$vBR = "null";
				}
				else {
					$vBR = "m".$metal."r".($row+$MP)."c".($col+$upMP);
				}

				@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
				# prevent overlapping vertices being repeated created
				if (!exists $vertices{$vName}) {
					$vertices{$vName} = [@vertex];
					$vIndex++;
					$temp_numTrackVup += 1;

					push(@temp_vertices, $vName);
				}

				# jump to next col
				$upCol += $upMP; 
			}

			# vertices w.r.t lower adjacent layer
			while ($loCol < $std_width) {
				$vName = "m".$metal."r".$row."c".$loCol;
				# Left Vertex, horiztontal direction
				if ($loCol == $loVerOffset) {
					$vL = "null";
				}
				else {
					$vL = "m".$metal."r".$row."c".($loCol-$loMP);
				}

				# Right Vertex, horiztontal direction
				if ($loCol + $upMP > $std_width) {
					$vR = "null";
				}
				else {
					$vR = "m".$metal."r".$row."c".($loCol+$loMP);
				}

				# Front Vertex
				if ($row == $horOffset) {
					$vF = "null";
				}
				else {
					$vF = "m".$metal."r".($row-$MP)."c".$loCol;
				}

				# Back Vertex
				if ($row + $MP > $std_height) {
					$vB = "null";
				}
				else {
					$vB = "m".$metal."r".($row+$MP)."c".$loCol;
				}

				# No change
				# Up Vertex
				if ($metal == $numMetalLayer) {
					$vU = "null";
				}
				else {
					$vU = "m".($metal+1)."r".$row."c".$loCol;
				}

				# No change
				# Down Vertex
				if ($metal == 1) {
					$vD = "null";
				}
				else {
					$vD = "m".($metal-1)."r".$row."c".$loCol;
				}
				
				# FL Vertex
				if ($row == $horOffset || $loCol == $loVerOffset) {
					$vFL = "null";
				}
				else {
					$vFL = "m".$metal."r".($row-$MP)."c".($loCol-$loMP);
				}

				# FR Vertex
				if ($row == $horOffset || $loCol + $loMP > $std_width) {
					$vFR = "null";
				}
				else {
					$vFR = "m".$metal."r".($row-$MP)."c".($loCol+$loMP);
				}

				# BL Vertex
				if ($row + $MP > $std_height || $loCol == $loVerOffset) { 
					$vBL = "null";
				}
				else {
					$vBL = "m".$metal."r".($row+$MP)."c".($loCol-$loMP);
				}

				# BR Vertex
				if ($row + $MP > $std_height || $loCol + $loMP > $std_width) {
					$vBR = "null";
				}
				else {
					$vBR = "m".$metal."r".($row+$MP)."c".($loCol+$loMP);
				}

				@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
				# prevent overlapping vertices being repeated created
				if (!exists $vertices{$vName}) {
					$vertices{$vName} = [@vertex];
					$vIndex++;
					$temp_numTrackVlo += 1;

					push(@temp_vertices, $vName);
				}

				$loCol += $loMP; # jump to next col
			}

			$row += $MP;	# jump to next row
			$temp_numTrackH += 1;
		}

		$temp_numTrackVlo /= $temp_numTrackH;
		$temp_numTrackVup /= $temp_numTrackH;

		# map number of metal tracks
		$map_numTrackV{$metal} = int($temp_numTrackVlo + $temp_numTrackVup);
		$map_numTrackH{$metal} = int($temp_numTrackH);

		$map_metal_to_vertices{$metal} = [@temp_vertices];
	}
	elsif ($metal % 2 != 0) { # 3, 5, 7... 
		print "*****Odd Metal*****\n";
		my @temp_vertices = ();
		# numTrackV and numTrackH
		my $temp_numTrackV = 0;	#col
		my $temp_numTrackHup = 0;	#uprow
		my $temp_numTrackHlo = 0;	#lorow

		# vertical Metal direction (col-based)
		my $verOffset = $mapOffSet{$metal};
		my $upHorOffset = $mapOffSet{$metal + 1};
		my $loHorOffset = $mapOffSet{$metal - 1};

		# M4 Metal Pitch, vertical col
		$upMP = $mapMP{$metal + 1}; 

		# M2 Metal Pitch, vertical col
		$loMP = $mapMP{$metal - 1}; 

		$col = $verOffset;  # col offset vertically | y
		$upRow = $upHorOffset;	# row offset horiztonally --- x
		$loRow = $loHorOffset;	# row offset horiztonally --- x

		while($col < $std_width) {
			# reset
			$upRow = $upHorOffset;	# row offset horiztonally --- x
			$loRow = $loHorOffset;	# row offset horiztonally --- x
			while ($upRow < $std_height) {
				$vName = "m".$metal."r".$upRow."c".$col;
				# Left Vertex, horiztontal direction
				if ($col == $verOffset) {
					$vL = "null";
				}
			    else {
					$vL = "m".$metal."r".$upRow."c".($col-$MP);
				}

				# Right Vertex, horizontal direction
				if ($col + $MP > $std_width) {
					$vR = "null";
				}
				else {
					$vR = "m".$metal."r".$upRow."c".($col+$MP);
				}

				# Front Vertex
				if ($upRow == $upHorOffset) {
					$vF = "null";
				}
				else {
					$vF = "m".$metal."r".($upRow-$upMP)."c".$col;
				}

				# Back Vertex
				if ($upRow + $upMP > $std_height) {
					$vB = "null";
				}
				else {
					$vB = "m".$metal."r".($upRow+$upMP)."c".$col;
				}

				# No change
				# Up Vertex
				if ($metal == $numMetalLayer) {
					$vU = "null";
				}
				else {
					$vU = "m".($metal+1)."r".$upRow."c".$col;
				}

				# No change
				# Down Vertex
				if ($metal == 1) {
					$vD = "null";
				}
				else {
					$vD = "m".($metal-1)."r".$upRow."c".$col;
				}

				# FL Vertex
				if ($upRow == $upHorOffset || $col == $verOffset) {
					$vFL = "null";
				}
				else {
					$vFL = "m".$metal."r".($upRow-$upMP)."c".($col-$MP);
				}

				# FR Vertex
				if ($upRow == $upHorOffset || $col + $MP > $std_width) {
					$vFR = "null";
				}
				else {
					$vFR = "m".$metal."r".($upRow-$upMP)."c".($col+$MP);
				}

				# BL Vertex
				if ($upRow + $upMP > $std_height || $col == $verOffset) {
					$vBL = "null";
				}
				else {
					$vBL = "m".$metal."r".($upRow+$upMP)."c".($col-$MP);
				}

				# BR Vertex
				if ($upRow + $upMP > $std_height || $col + $MP > $std_width) {
					$vBR = "null";
				}
				else {
					$vBR = "m".$metal."r".($upRow+$upMP)."c".($col+$MP);
				}

				@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
				# prevent overlapping vertices being repeated created
				if (!exists $vertices{$vName}) {
					$vertices{$vName} = [@vertex];
					$vIndex++;
					$temp_numTrackHup += 1;

					push(@temp_vertices, $vName);
				}

				$upRow += $upMP; # jump to next row
			}

			while ($loRow <= $std_height) {
				$vName = "m".$metal."r".$upRow."c".$col;
				# Left Vertex, horiztontal direction
				if ($col == $verOffset) {
					$vL = "null";
				}
			    else {
					$vL = "m".$metal."r".$loRow."c".($col-$MP);
				}

				# Right Vertex, horizontal direction
				if ($col + $MP > $std_width) {
					$vR = "null";
				}
				else {
					$vR = "m".$metal."r".$loRow."c".($col+$MP);
				}

				# Front Vertex
				if ($loRow == $loHorOffset) {
					$vF = "null";
				}
				else {
					$vF = "m".$metal."r".($loRow-$loMP)."c".$col;
				}

				# Back Vertex
				if ($loRow + $loMP > $std_height) {
					$vB = "null";
				}
				else {
					$vB = "m".$metal."r".($loRow+$loMP)."c".$col;
				}

				# No change
				# Up Vertex
				if ($metal == $numMetalLayer) {
					$vU = "null";
				}
				else {
					$vU = "m".($metal+1)."r".$loRow."c".$col;
				}

				# No change
				# Down Vertex
				if ($metal == 1) {
					$vD = "null";
				}
				else {
					$vD = "m".($metal-1)."r".$loRow."c".$col;
				}

				# FL Vertex
				if ($loRow == $loHorOffset || $col == $verOffset) {
					$vFL = "null";
				}
				else {
					$vFL = "m".$metal."r".($loRow-$loMP)."c".($col-$MP);
				}

				# FR Vertex
				if ($loRow == $loHorOffset || $col + $MP > $std_width) {
					$vFR = "null";
				}
				else {
					$vFR = "m".$metal."r".($loRow-$loMP)."c".($col+$MP);
				}

				# BL Vertex
				if ($loRow + $loMP > $std_height || $col == $verOffset) {
					$vBL = "null";
				}
				else {
					$vBL = "m".$metal."r".($loRow+$loMP)."c".($col-$MP);
				}

				# BR Vertex
				if ($loRow + $loMP > $std_height || $col + $MP > $std_width) {
					$vBR = "null";
				}
				else {
					$vBR = "m".$metal."r".($loRow+$loMP)."c".($col+$MP);
				}

				@vADJ = ($vL, $vR, $vF, $vB, $vU, $vD, $vFL, $vFR, $vBL, $vBR);
				@vertex = ($vIndex, $vName, $metal, $row, $col, [@vADJ]);
				# prevent overlapping vertices being repeated created
				if (!exists $vertices{$vName}) {
					$vertices{$vName} = [@vertex];
					$vIndex++;
					$temp_numTrackHlo += 1;

					push(@temp_vertices, $vName);
				}

				$loRow += $loMP; # jump to next row
			}

			$col += $MP;	# jump to next row
			$temp_numTrackV += 1;
		}

		$temp_numTrackHlo /= $temp_numTrackV;
		$temp_numTrackHup /= $temp_numTrackV;
		# map number of metal tracks
		$map_numTrackV{$metal} = int($temp_numTrackV);
		$map_numTrackH{$metal} = int($temp_numTrackHlo + $temp_numTrackHup);

		$map_metal_to_vertices{$metal} = [@temp_vertices];
	}
	
}

# # YW: Debugging
# print "**** vertices:\n";
# print Dumper(\%vertices);
# print "**** numTrackV:\n";
# print Dumper(\%map_numTrackV);
# print "**** numTrackH:\n";
# print Dumper(\%map_numTrackH);
# print "**** map_metal_to_vertices:\n";
# print Dumper(\%map_metal_to_vertices);

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
my $vCost_34 = 4;	# Via Cost for layer 3 and 4
my $mCost_4 = 1;	# Metal Cost for layer 4
my $wCost = 1;		# Wire Cost

foreach my $vName (keys %vertices) {
	# regex extract vertex information
	my ($metal, $row, $col) = ($vName =~ m/m(\d+)r(\d+)c(\d+)/);
	# print "metal$metal, row$row, col$col\n";
	$udEdgeTerm1 = $vName;

	if ($metal % 2 == 0) { # Even Layers ==> Horizontal; 2, 4, 6, ...
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
			if($col % 2 == 0){
				# if col is even, construct edge to upper edge
				$udEdgeTerm2 = $vertices{$udEdgeTerm1}[5][4];
				# [index] [v] [vU] 4 4
				@udEdge = ($udEdgeIndex, $udEdgeTerm1, $udEdgeTerm2, $vCost, $vCost);
				#print "@udEdge\n";
				push (@udEdges, [@udEdge]);
				$udEdgeIndex++;
			}
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


# # YW: Debugging
# $udEdgeNumber = scalar @udEdges;
# print "a     # udEdges           = $udEdgeNumber\n";

# print "**** udEdges:\n";
# print Dumper(\@udEdges);

# YW: deleted commented

### BOUNDARY VERTICES Generation.
### DATA STRUCTURE:  Single Array includes all boundary vertices to L, R, F, B, U directions.
my @boundaryVertices = ();
my $numBoundaries = 0;

# Second Top layer
my $metal = $numMetalLayer-1;
# [METAL] => [Vertices Name ordered by metal direction]
# Example: Odd layer 		=> 	[m3r[1-10]c1]...
# Example: Even layer => 	[m4r1c[1-9]]...

my @temp_vertices = @{$map_metal_to_vertices{"$metal"}};
foreach (@temp_vertices) {
	# regex extract vertex information
	my $vName = $_;
	my ($metal, $row, $col) = ($vName =~ m/m(\d+)r(\d+)c(\d+)/);

	# print("iterate m$metal, r$row, c$col\n");
	# YW: disregard odd layer if statement
	if($metal%2!=0) { # odd layer: vertical --> col
		if($col%2 == 1){	# ignore odd col: bc metal pitch?
			next;
		}
		
		if($EXT_Parameter == 0){ # if not extensible YW: deleted commented
			my $upOffset =  $mapOffSet{$metal + 1};
			my $loOffset =  $mapOffSet{$metal - 1};
			my $upOffMP =  $mapMP{$metal + 1};
			my $loOffMP =  $mapMP{$metal - 1};
			# first row: offset
			my $firstRow = ($upOffset<$loOffset?$upOffset:$loOffset);  # take smaller offset
			# second row: offset + MP
			my $secondRow = ($upOffset+$upOffMP<$loOffset+$loOffMP?$upOffset+$upOffMP:$loOffset+$loOffMP);
			print("firstRow $firstRow, secondRow $secondRow\n");
			if ($row == $firstRow || $row == $secondRow) { # always perpendicular: why $numTrackH-4
				# only 2 specific rows?
				push (@boundaryVertices, "m".$metal."r".$row."c".$col);
			}
		}
		else{
			push (@boundaryVertices, "m".$metal."r".$row."c".$col);
		}
		
	} 
	elsif ($metal%2==0) {	# even layer: horizontal --> row
		if($row%2 == 1){	# ignore odd row: bc metal pitch?
			next;
		}

		if($EXT_Parameter == 0){ # if not extensible
			my $upOffset =  $mapOffSet{$metal + 1};
			my $loOffset =  $mapOffSet{$metal - 1};
			my $upOffMP =  $mapMP{$metal + 1};
			my $loOffMP =  $mapMP{$metal - 1};
			# first col: offset
			my $firstCol = ($upOffset<$loOffset?$upOffset:$loOffset); # take smaller offset
			# second col: offset + MP
			my $secondCol = ($upOffset+$upOffMP<$loOffset+$loOffMP?$upOffset+$upOffMP:$loOffset+$loOffMP);

			if ($col == $firstCol || $col == $secondCol) { # why $numTrackH-4
				# only 2 specific rows?
				push (@boundaryVertices, "m".$metal."r".$row."c".$col);
			}
		}
		else{
			push (@boundaryVertices, "m".$metal."r".$row."c".$col);
		}
	}
	
} 

# Top layer
$metal = $numMetalLayer;
# [METAL] => [Vertices Name ordered by metal direction]
# Example: Odd layer 		=> 	[m3r[1-10]c1]...
# Example: Even layer => 	[m4r1c[1-9]]...
my @temp_vertices = @{$map_metal_to_vertices{"$metal"}};

foreach (@temp_vertices) {
	# regex extract vertex information
	my $vName = $_;
	my ($metal, $row, $col) = ($vName =~ m/m(\d+)r(\d+)c(\d+)/);

	# print("iterate m$metal, r$row, c$col\n");
	# YW: disregard odd layer if statement
	if($metal%2!=0) { # odd layer: vertical --> col
		if($col%2 == 1){	# ignore odd col: bc metal pitch?
			next;
		}
		
		if($EXT_Parameter == 0){ # if not extensible
			# YW: deleted commented
			my $loOffset =  $mapOffSet{$metal - 1};
			my $loOffMP =  $mapMP{$metal - 1};
			# first row: offset
			my $firstRow = $loOffset;
			# second row: offset + MP
			my $secondRow = $loOffset+$loOffMP;

			if ($row == $firstRow || $row == $secondRow) { # always perpendicular: why $numTrackH-4
				# only 2 specific rows?
				push (@boundaryVertices, "m".$metal."r".$row."c".$col);
			}
		}
		else{
			push (@boundaryVertices, "m".$metal."r".$row."c".$col);
		}
		
	} 
	elsif ($metal%2==0) {	# even layer: horizontal --> row
		if($row%2 == 1){	# ignore odd row: bc metal pitch?
			next;
		}

		if($EXT_Parameter == 0){ # if not extensible
			# YW: deleted commented
			my $loOffset =  $mapOffSet{$metal - 1};
			my $loOffMP =  $mapMP{$metal - 1};
			# first row: offset
			my $firstCol = $loOffset;
			# second row: offset + MP
			my $secondCol = $loOffset+$loOffMP;

			if ($col == $firstCol || $col == $secondCol) { # why $numTrackH-4
				# only 2 specific rows?
				push (@boundaryVertices, "m".$metal."r".$row."c".$col);
			}
		}
		else{
			push (@boundaryVertices, "m".$metal."r".$row."c".$col);
		}
	}
	
} 


$numBoundaries = scalar @boundaryVertices;
print "a     # Boundary Vertices = $numBoundaries\n";

# YW: Debugging
print "**** boundaryVertices:\n";
print Dumper(\@boundaryVertices);

# [2018-10-15] Store the net information for SON simplifying
# OuterPin: I/O pin
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
			# $netName == $pin_netID
			if ($nets[$netIndex][0] eq $pins[$pinID][1]) {
				# sink (0...numSinks)
				for my $sinkIndexofNet (0 .. $nets[$netIndex][4]) {
					# [@sinks_inNet] == $pinName
					if ( $nets[$netIndex][5][$sinkIndexofNet] eq $pins[$pinID][0]) {
						# commodity info = sinkIndexofNet in [@sinks_inNet]
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

for my $metal (1 .. $numMetalLayer) { 
	my @temp_vertices = @{$map_metal_to_vertices{"$metal"}};
	# $xxx, $yyy is not used, only for placeholder
	my ($xxx, $minRow, $minCol) = ($temp_vertices[0] =~ m/m(\d+)r(\d+)c(\d+)/);
	my ($yyy, $maxRow, $maxCol) = ($temp_vertices[-1] =~ m/m(\d+)r(\d+)c(\d+)/);

	print("$minRow, $minCol, $maxRow, $maxCol\n");

	foreach (@temp_vertices) {
		my $vName = $_;
		# regex extract vertex information
		my ($metal, $row, $col) = ($vName =~ m/m(\d+)r(\d+)c(\d+)/);
		# print "metal$metal, row$row, col$col\n";
		if($metal==1 && $col % 2 == 1){
			next;
		}
		elsif($metal % 2 == 1 && $col % 2 == 1){
			next;
		}

		$cornerVertex = $vName;

		if ($col == $minCol) {
			push (@leftCorners, $cornerVertex);
			$numLeftCorners++;
		}

		if ($col == $maxCol) {
			push (@rightCorners, $cornerVertex);
			$numRightCorners++;
		}

		if ($row == $minRow) {
			push (@frontCorners, $cornerVertex);
			$numFrontCorners++;
		}

		if ($row == $maxRow) {
			push (@backCorners, $cornerVertex);
			$numBackCorners++;
		}
	}
}

#print "@backCorners\n";
print "a     # Left Corners      = $numLeftCorners\n";
print "a     # Right Corners     = $numRightCorners\n";
print "a     # Front Corners     = $numFrontCorners\n";
print "a     # Back Corners      = $numBackCorners\n";

#YW Debug:
print "**** leftCorners:\n";
print Dumper(\@leftCorners);
print "**** rightCorners:\n";
print Dumper(\@rightCorners);
print "**** frontCorners:\n";
print Dumper(\@frontCorners);
print "**** backCorners:\n";
print Dumper(\@backCorners);

# super outer node
if ( $SON == 1){
############### Pin Information Modification #####################
	for my $pinIndex (0 .. $#pins) {
		for my $outerPinIndex (0 .. $#outerPins){
			# if pin
			if ($pins[$pinIndex][0] eq $outerPins[$outerPinIndex][0] ){
				$pins[$pinIndex][0] = $keySON;
				$pins[$pinIndex][1] = "Multi";
				next;
			}   
		}
	}
############ SON Node should be last elements to use pop ###########
	my $SONFlag = 0;
	my $tmp_cnt = $#pins;
	for(my $i=0; $i<=$tmp_cnt; $i++){
		if($pins[$tmp_cnt-$i][0] eq $keySON){
			$SONFlag = 1;
			@pin = pop @pins;
		}
	}
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