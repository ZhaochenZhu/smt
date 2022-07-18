#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use POSIX;

use Cwd;

### Pre-processing ########################################################
my $ARGC        = @ARGV;
my $workdir     = getcwd();
#my $outdir      = "$workdir/inputsSMT_cfet_exp1_mpo2_wopinfix";
#my $outdir      = "$workdir/inputsSMT_cfet_exp3_mpo4_wopinfix";
my $outdir      = "$workdir/inputsSMT_cfet";
my $infile      = "";

my $BoundaryCondition = 0; # ARGV[1], 0: Fixed, 1: Extensible
my $SON = 0;               # ARGV[2], 0: Disable, 1: Enable
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

print "h_RTrack:\n";
print Dumper(\%h_RTrack);

# Maximum routing track index
for my $i(0 .. $mapTrack[0][1]){
	$h_mapTrack{$i} = 1;
}

print "h_mapTrack:\n";
print Dumper(\%h_mapTrack);

for my $i(0 .. $#numContact){
	$h_numCon{$numContact[$i][0]} = $numContact[$i][1] - 1;
}

print "h_numCon:\n";
print Dumper(\%h_numCon);

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
    # print "a   Version Info : 1.0 Initial Version\n";
    # print "a				: 1.1 Bug Fix\n";
    # print "a				: 1.3 BV, Bool Employed\n";
    # print "a				: 1.4 Bug Fix, Performance Tuning\n";
    # print "a				: 1.5 Added SHR, Removed Redundancy in Placement constraints\n";
    # print "a				: 1.8 Performance Tuning\n";
    # print "a				: 1.9 S/D, Gate Coordinate Change\n";
    # print "a				: 2.0 Merged/Removed Capacity Variables\n";
    # print "a				: 2.1 Unit Propagation\n";
    # print "a				: 2.2 Pin Accessibility Modification\n";
    # print "a				: 2.2.5.1 Dummy Structure support and Sink to Sink (Multifingers) Shared Structure\n";
    # print "a				: 2.2.5.6 Integrate ver 2.4\n";

    print "a        Design Rule Parameters : [MAR = $MAR_Parameter , EOL = $EOL_Parameter, VR = $VR_Parameter, PRL = $PRL_Parameter, SHR = $SHR_Parameter]\n";
    print "a        Parameter Options : [Boundary = $BoundaryCondition], [SON = $SON], [Double Power Rail = $DoublePowerRail], [MPL = $MPL_Parameter], [Maximum Metal Layer = $MM_Parameter], [Localization = $Local_Parameter]\n";
	print "a	                        [Partitioning = $Partition_Parameter], [BCP = $BCP_Parameter], [NDE = $NDE_Parameter], [BS = $BS_Parameter], [PS = $PE_Parameter], [M2Track = $M2_TRACK_Parameter]\n";
	print "a	                        [M2Length = $M2_Length_Parameter], [Dint = $dint], [Stack = $stack_struct_flag], [DVsamenet = $VR_double_samenet_flag], [Stackvia = $VR_stacked_via_flag]\n\n";

    print "a   Generating SMT-LIB 2.0 Standard inputfile based on the following files.\n";
    print "a     Input Layout:  $workdir/$infile\n";
}

### Output Directory Creation, please see the following reference:
# system "mkdir -p $outdir";

# my $outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_6T.smt2";
# if ($BCP_Parameter == 0){
# 	$outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_NBCP.smt2";
# }
# print "a     SMT-LIB2.0 File:    $outfile\n";

# Never used
# my $enc_cfc = 40;
# my $enc_euv_1 = 40;
# my $enc_euv_2 = 40;

### Variable Declarations
my $width = 0;
my $placementRow = 0;
my $trackEachRow = 0;
my $trackEachPRow = 0;
my $numTrackH = 0;
my $numTrackV = 0;
my $numMetalLayer = $MM_Parameter;      # M1~M4
my $numPTrackH = 0;
my $numPTrackV = 0;
my $tolerance = 5; #default
#my $tolerance = 55; #default
#my $tolerance = 20;
my $tolerance_adj_sameregion = 5;
#my $tolerance_adj_sameregion = 15;
#my $tolerance_adj_diffregion = 1;

### PIN variables
my @pins = ();
my @pin = ();
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
my $totalPins = -1;
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
my @DDA_PMOS = ();
my @DDA_NMOS = ();
my $numPowerPmos = 0;
my $numPowerNmos = 0;
my @inst_group = ();
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

my $infileStatus = "init";

sub combine;
sub combine_sub;
sub getAvailableNumFinger;

sub getAvailableNumFinger{
	$width = @_[0];
	$trackEachPRow = @_[1];
	# print ("[getAvailableNumFinger]: ");
	@numFinger = ();
	for my $i(0 .. $trackEachPRow-1){

		if($width % ($trackEachPRow-$i) == 0){
			push(@numFinger, $width/($trackEachPRow-$i));
			# print "$width/($trackEachPRow-$i)";
			last; #immediately causes the current iteration of a loop to become the last. No further statements are executed, and the loop ends.
		}
	}
	# print "\n";
    # numFinger only has one elements
	return @numFinger;
}

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
    my @tmp = getAvailableNumFinger(13, 7);

    # print Dumper(\@tmp);

    ## Infile Status: Instance Info
    if ($infileStatus eq "inst") {
        if ($line =~ /^i   ins(\S+)\s*(\S+)\s*(\d+)/) {	
			$instName = "ins".$1;
			$instType = $2;
			$instWidth = $3;

            print "Reading Instance Info: $instName, $instType, $instWidth \n";

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
				$instY = 0; # output transistor?
				#$instY = $numPTrackH - $instWidth/$tmp_finger[0];
			}
			push(@inst, [($instName, $instType, $instWidth, $instY)]);
			### Generate Maximum possible pin arrays for each instances
			### # of Maximum Possible pin = instWidth * 2 + 1
            # print('tmp_finger: ', $#tmp_finger, "\n");
            print('tmp_finger: ', $tmp_finger[$#tmp_finger]*2+1, "\n");
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
                
                # YW Debug
                print "Adding current pin to pins: \n";
                print Dumper(\@pin), "\n";

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

            print "Reading Pin Info: $pinName, $pin_netID, $pin_instID, $pin_type, $pinIO, $pinLength \n";

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

            print("Reading: ", $netID, " ", $netName, "\n");

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
                # if is an VDD or VSS pins
				if(exists($h_outpinId_idx{$net[$pinIndex_inNet]}) && ($pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VDD" || $pins[$h_outpinId_idx{$net[$pinIndex_inNet]}][7] eq "VSS")){
					$powerinNet = 1;
                    # 
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
}

# pin hash arrays
print "******************************************\n";
print "*** h_pin_id: ***\n", Dumper(\%h_pin_id);
print "*** h_pin_idx: ***\n", Dumper(\%h_pin_idx);
print "*** h_pinId_idx: ***\n", Dumper(\%h_pinId_idx);
print "*** h_outpinId_idx : ***\n", Dumper(\%h_outpinId_idx );
print "*** h_pin_net : ***\n", Dumper(\%h_pin_net );

# net hash arrays
print "******************************************\n"; 
print "*** h_extnets : ***\n", Dumper(\%h_extnets);
print "*** h_idx : ***\n", Dumper(\%h_idx );
print "*** h_outnets : ***\n", Dumper(\%h_outnets );
print "*** DDA_PMOS : ***\n", Dumper(\@DDA_PMOS);
print "*** DDA_NMOS : ***\n", Dumper(\@DDA_NMOS);
print "*** inst_group : ***\n", Dumper(\@inst_group);

# instance hash arrays
print "******************************************\n";
print "*** h_inst_idx : ***\n", Dumper(\%h_inst_idx );
print "*** numFinger  : ***\n", Dumper(\@numFinger  );
print "*** h_inst_group : ***\n", Dumper(\%h_idx );
print "*** inst_group_p  : ***\n", Dumper(\@inst_group_p );
print "*** inst_group_n   : ***\n", Dumper(\@inst_group_n  );

=pod
*** h_outnets : ***
$VAR1 = {
          'net4' => 1
        };
=cut