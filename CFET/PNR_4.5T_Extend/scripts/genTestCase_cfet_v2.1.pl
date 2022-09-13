#! /usr/bin/perl

use strict 'vars';
use strict 'refs';
use strict 'subs';
#use Data::Dump qw(dump);
use POSIX;

use Cwd;

### Revision History : Ver 2.1 #####
# 2019-03-18 Test Case Generator
# 2020-02-19 Add external pin information for lef generation
# 2020-02-19 Fix even finger S/D assignment from v2.0
### Pre-processing ########################################################
my $ARGC        = @ARGV;
my $workdir     = getcwd();
my $outdir      = "$workdir/pinLayouts_cfet_v2.1";
my $infile      = "";
#my @StdCells	= ("A2O1A1Ixp33_ASAP7_75t_R", "A2O1A1O1Ixp25_ASAP7_75t_R", "AND2x2_ASAP7_75t_R", "AND2x4_ASAP7_75t_R", "AND2x6_ASAP7_75t_R", "AND3x1_ASAP7_75t_R", "AND3x2_ASAP7_75t_R", "AND3x4_ASAP7_75t_R", "AND4x1_ASAP7_75t_R", "AND4x2_ASAP7_75t_R", "AND5x1_ASAP7_75t_R", "AND5x2_ASAP7_75t_R", "AO211x2_ASAP7_75t_R", "AO21x1_ASAP7_75t_R", "AO21x2_ASAP7_75t_R", "AO221x1_ASAP7_75t_R", "AO221x2_ASAP7_75t_R", "AO222x2_ASAP7_75t_R", "AO22x1_ASAP7_75t_R", "AO22x2_ASAP7_75t_R", "AO31x2_ASAP7_75t_R", "AO322x2_ASAP7_75t_R", "AO32x1_ASAP7_75t_R", "AO32x2_ASAP7_75t_R", "AO331x1_ASAP7_75t_R", "AO331x2_ASAP7_75t_R", "AO332x1_ASAP7_75t_R", "AO332x2_ASAP7_75t_R", "AO333x1_ASAP7_75t_R", "AO333x2_ASAP7_75t_R", "AO33x2_ASAP7_75t_R", "AOI211x1_ASAP7_75t_R", "AOI211xp5_ASAP7_75t_R", "AOI21x1_ASAP7_75t_R", "AOI21xp33_ASAP7_75t_R", "AOI21xp5_ASAP7_75t_R", "AOI221x1_ASAP7_75t_R", "AOI221xp5_ASAP7_75t_R", "AOI222xp33_ASAP7_75t_R", "AOI22x1_ASAP7_75t_R", "AOI22xp33_ASAP7_75t_R", "AOI22xp5_ASAP7_75t_R", "AOI311xp33_ASAP7_75t_R", "AOI31xp33_ASAP7_75t_R", "AOI31xp67_ASAP7_75t_R", "AOI321xp33_ASAP7_75t_R", "AOI322xp5_ASAP7_75t_R", "AOI32xp33_ASAP7_75t_R", "AOI331xp33_ASAP7_75t_R", "AOI332xp33_ASAP7_75t_R", "AOI333xp33_ASAP7_75t_R", "AOI33xp33_ASAP7_75t_R", "ASYNC_DFFHx1_ASAP7_75t_R", "BUFx10_ASAP7_75t_R", "BUFx12_ASAP7_75t_R", "BUFx12f_ASAP7_75t_R", "BUFx16f_ASAP7_75t_R", "BUFx24_ASAP7_75t_R", "BUFx2_ASAP7_75t_R", "BUFx3_ASAP7_75t_R", "BUFx4_ASAP7_75t_R", "BUFx4f_ASAP7_75t_R", "BUFx5_ASAP7_75t_R", "BUFx6f_ASAP7_75t_R", "BUFx8_ASAP7_75t_R", "DFFHQNx1_ASAP7_75t_R", "DFFHQNx2_ASAP7_75t_R", "DFFHQNx3_ASAP7_75t_R", "DFFHQx4_ASAP7_75t_R", "DFFLQNx1_ASAP7_75t_R", "DFFLQNx2_ASAP7_75t_R", "DFFLQNx3_ASAP7_75t_R", "DFFLQx4_ASAP7_75t_R", "DHLx1_ASAP7_75t_R", "DHLx2_ASAP7_75t_R", "DHLx3_ASAP7_75t_R", "DLLx1_ASAP7_75t_R", "DLLx2_ASAP7_75t_R", "DLLx3_ASAP7_75t_R", "FAx1_ASAP7_75t_R", "HAxp5_ASAP7_75t_R", "HB1xp67_ASAP7_75t_R", "HB2xp67_ASAP7_75t_R", "HB3xp67_ASAP7_75t_R", "HB4xp67_ASAP7_75t_R", "ICGx1_ASAP7_75t_R", "ICGx2_ASAP7_75t_R", "ICGx3_ASAP7_75t_R", "INVx11_ASAP7_75t_R", "INVx13_ASAP7_75t_R", "INVx1_ASAP7_75t_R", "INVx2_ASAP7_75t_R", "INVx3_ASAP7_75t_R", "INVx4_ASAP7_75t_R", "INVx5_ASAP7_75t_R", "INVx6_ASAP7_75t_R", "INVx8_ASAP7_75t_R", "INVxp33_ASAP7_75t_R", "INVxp67_ASAP7_75t_R", "MAJIxp5_ASAP7_75t_R", "MAJx2_ASAP7_75t_R", "MAJx3_ASAP7_75t_R", "NAND2x1_ASAP7_75t_R", "NAND2x1p5_ASAP7_75t_R", "NAND2x2_ASAP7_75t_R", "NAND2xp33_ASAP7_75t_R", "NAND2xp5_ASAP7_75t_R", "NAND2xp67_ASAP7_75t_R", "NAND3x1_ASAP7_75t_R", "NAND3x2_ASAP7_75t_R", "NAND3xp33_ASAP7_75t_R", "NAND4xp25_ASAP7_75t_R", "NAND4xp75_ASAP7_75t_R", "NAND5xp2_ASAP7_75t_R", "NOR2x1_ASAP7_75t_R", "NOR2x1p5_ASAP7_75t_R", "NOR2x2_ASAP7_75t_R", "NOR2xp33_ASAP7_75t_R", "NOR2xp67_ASAP7_75t_R", "NOR3x1_ASAP7_75t_R", "NOR3x2_ASAP7_75t_R", "NOR3xp33_ASAP7_75t_R", "NOR4xp25_ASAP7_75t_R", "NOR4xp75_ASAP7_75t_R", "NOR5xp2_ASAP7_75t_R", "O2A1O1Ixp33_ASAP7_75t_R", "O2A1O1Ixp5_ASAP7_75t_R", "OA211x2_ASAP7_75t_R", "OA21x2_ASAP7_75t_R", "OA221x2_ASAP7_75t_R", "OA222x2_ASAP7_75t_R", "OA22x2_ASAP7_75t_R", "OA31x2_ASAP7_75t_R", "OA331x1_ASAP7_75t_R", "OA331x2_ASAP7_75t_R", "OA332x1_ASAP7_75t_R", "OA332x2_ASAP7_75t_R", "OA333x1_ASAP7_75t_R", "OA333x2_ASAP7_75t_R", "OA33x2_ASAP7_75t_R", "OAI211xp5_ASAP7_75t_R", "OAI21x1_ASAP7_75t_R", "OAI21xp33_ASAP7_75t_R", "OAI21xp5_ASAP7_75t_R", "OAI221xp5_ASAP7_75t_R", "OAI222xp33_ASAP7_75t_R", "OAI22x1_ASAP7_75t_R", "OAI22xp33_ASAP7_75t_R", "OAI22xp5_ASAP7_75t_R", "OAI311xp33_ASAP7_75t_R", "OAI31xp33_ASAP7_75t_R", "OAI31xp67_ASAP7_75t_R", "OAI321xp33_ASAP7_75t_R", "OAI322xp33_ASAP7_75t_R", "OAI32xp33_ASAP7_75t_R", "OAI331xp33_ASAP7_75t_R", "OAI332xp33_ASAP7_75t_R", "OAI333xp33_ASAP7_75t_R", "OAI33xp33_ASAP7_75t_R", "OR2x2_ASAP7_75t_R", "OR2x4_ASAP7_75t_R", "OR2x6_ASAP7_75t_R", "OR3x1_ASAP7_75t_R", "OR3x2_ASAP7_75t_R", "OR3x4_ASAP7_75t_R", "OR4x1_ASAP7_75t_R", "OR4x2_ASAP7_75t_R", "OR5x1_ASAP7_75t_R", "OR5x2_ASAP7_75t_R", "SDFHx1_ASAP7_75t_R", "SDFHx2_ASAP7_75t_R", "SDFHx3_ASAP7_75t_R", "SDFHx4_ASAP7_75t_R", "SDFLx1_ASAP7_75t_R", "SDFLx2_ASAP7_75t_R", "SDFLx3_ASAP7_75t_R", "SDFLx4_ASAP7_75t_R", "TIEHIx1_ASAP7_75t_R", "TIELOx1_ASAP7_75t_R", "XNOR2x1_ASAP7_75t_R", "XNOR2x2_ASAP7_75t_R", "XNOR2xp5_ASAP7_75t_R", "XOR2x1_ASAP7_75t_R", "XOR2x2_ASAP7_75t_R", "XOR2xp5_ASAP7_75t_R", "TGx1_ASAP7_75t_R");

#my @StdCells = ("BUFx2_ASAP7_75t_R", "BUFx3_ASAP7_75t_R", "OAI22x1_ASAP7_75t_R", "TIELOx1_ASAP7_75t_R", "TIEHIx1_ASAP7_75t_R", "XOR2x1_ASAP7_75t_R", "NAND2x1_ASAP7_75t_R", "NOR2x1_ASAP7_75t_R", "XNOR2x1_ASAP7_75t_R", "XOR2x1_ASAP7_75t_R", "OAI22x1_ASAP7_75t_R", "AOI22x1_ASAP7_75t_R", "DFFHQNx1_ASAP7_75t_R", "FAx1_ASAP7_75t_R");
#my @StdCells = ("INVx1_ASAP7_75t_R", "INVx2_ASAP7_75t_R", "INVx4_ASAP7_75t_R", "INVx8_ASAP7_75t_R", "BUFx2_ASAP7_75t_R", "BUFx3_ASAP7_75t_R", "BUFx4_ASAP7_75t_R", "BUFx8_ASAP7_75t_R", "MUX2x1_ASAP7_75t_R", "OAI22x1_ASAP7_75t_R", "AND2x1_ASAP7_75t_R", "AND2x2_ASAP7_75t_R", "AND3x1_ASAP7_75t_R", "AND3x2_ASAP7_75t_R", "NAND2x1_ASAP7_75t_R", "NAND2x2_ASAP7_75t_R", "NAND3x1_ASAP7_75t_R", "NAND3x2_ASAP7_75t_R", "NAND4x1_ASAP7_75t_R", "NAND4x2_ASAP7_75t_R", "NOR2x1_ASAP7_75t_R", "NOR2x2_ASAP7_75t_R", "NOR3x1_ASAP7_75t_R", "NOR3x2_ASAP7_75t_R", "NOR4x1_ASAP7_75t_R", "NOR4x2_ASAP7_75t_R", "XNOR2x1_ASAP7_75t_R", "XOR2x1_ASAP7_75t_R", "OAI21x1_ASAP7_75t_R", "OAI21x2_ASAP7_75t_R", "OAI22x1_ASAP7_75t_R", "OAI22x2_ASAP7_75t_R", "AOI22x1_ASAP7_75t_R", "AOI21x1_ASAP7_75t_R", "AOI21x2_ASAP7_75t_R", "AOI22x1_ASAP7_75t_R", "AOI22x2_ASAP7_75t_R", "AND2x1_ASAP7_75t_R", "OR2x2_ASAP7_75t_R", "OR2x1_ASAP7_75t_R", "OR3x1_ASAP7_75t_R", "OR3x2_ASAP7_75t_R");
my @StdCells = ( "XOR2x1_ASAP7_75t_R");
foreach my $cell (@StdCells) {
	print ("cell: $cell\n");
}
my @mapTrack = ([1,1], [2,1], [3,1], [4,2], [5,2], [6,3], [7,3]);  # Horizontal Track Mapping
my @mapNS = ([1,1], [2,2], [3,2]);  # Horizontal Fin Mapping to Nanosheets

sub getTrack{
	my $track = @_[0];
	my $nTrack = -1;
	for my $i(0 .. $#mapTrack){
		if($mapTrack[$i][0] == $track){
			$nTrack = $mapTrack[$i][1];
		}
	}
	if($nTrack == -1){
		print "[ERROR] Track Matching Failed. Input Track => $track\n";
		exit(-1);
	}
	return $nTrack;
}

sub convertNanoSheet{
	my $nfin = @_[0];
        my $nNS = 0;
	my $fin_perFET = 3;
	my $multiple = int($nfin/$fin_perFET);
	my $residual = $nfin%$fin_perFET;
	if ($residual > 0) {
		$multiple = $multiple + 1;
	}
	
	$nNS = $nNS + $multiple*2;
	#for my $i(0 .. $#mapNS){
        #        if($mapNS[$i][0] == $residual){
        #                $nNS = $nNS + $mapNS[$i][1];
        #        }
        #}
	print "\nConvert nfinger: $multiple => nNS: $nNS\n";
	return $nNS;
}

my %h_mapTrack = ();
for my $i(0 .. $#mapTrack){
	$h_mapTrack{$mapTrack[$i][1]} = 1;
}

my $sizeOffset = 0;
if ($ARGC != 2) {
    print "\n*** Error:: Wrong CMD";
    print "\n   [USAGE]: ./PL_FILE [inputfile_spfile] [numTrackV Offset]\n\n";
    exit(-1);
} else {
    $infile             = $ARGV[0];
    $sizeOffset         = $ARGV[1];
}

if (!-e "$infile") {
    print "\n*** Error:: FILE DOES NOT EXIST..\n";
    print "***         $infile\n\n";
    exit(-1);
} else {
    print "\n";
    print "a   Version Info : 1.0 Initial Version\n";
    print "a   Generating TestCase pinLayout based on the following files.\n";
    print "a     Input Circuit :  $infile\n";
}

### Output Directory Creation, please see the following reference:
system "mkdir -p $outdir";

my $designName = "";

my @ext_pins = ();
my @ext_powerpins = ();
my @pins = ();
my @nets = ();
my @inst = ();

my %h_inst = ();
my %h_nets = ();
my %h_name_nets = ();
my %h_nets_source = ();
my %h_pintype = ();
my %h_netcnt = ();
my %h_pinmatch = ();

my $idx_inst = 0;
my $idx_net = 0;
my $idx_pin = 0;

my $sizeNMOS = 0;
my $sizePMOS = 0;

#my $numPTrackH = 3;
# is it because the fin channels? Refer to Mark's thesis Fig 1.7
my $numPTrackH = 2; # 2 nanosheets per FET
my $numTrackH = 6; # 4 routing tracks; 2 power/ground tracks
#my $numClip = 2; # PMOS and NMOS region in FinFET
my $numClip = 1; # PMOS and NMOS region for CFET
my $subckt_flag = 0;
### Read Inputfile and Build Data Structure
open (my $in, "$infile");
my $outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0].".pinLayout";

while (<$in>) {
    my $line = $_;
    chomp($line);

    ### Status of Input File
    if ($line =~ /\.SUBCKT (\S+)/) {
		$outfile     = "";
		$designName = "";
		@ext_pins = ();
		@ext_powerpins = ();
		@pins = ();
		@nets = ();
		@inst = ();
		%h_inst = ();
		%h_nets = ();
		%h_nets_source = ();
		%h_name_nets = ();
		%h_pintype = ();
		%h_netcnt = ();
		%h_pinmatch = (); # store pinID of the opposite of MOS terminals: S <-> D
		$idx_inst = 0;
		$idx_net = 0;
		$idx_pin = 0;
		$sizeNMOS = 0;
		$sizePMOS = 0;

		$designName = $1;
		print $designName;
		for my $cell (@StdCells) {
			if ($designName eq $cell) {
				print "a     Cell Design Name :    $designName\n";
				$subckt_flag = 1;
				$outfile = "$outdir/".(split /\./, (split /\//, $designName)[$#_])[0].".pinLayout";
				last;
			}
		}
    }
    elsif ($subckt_flag == 1 and $line =~ /\.ENDS/) {
	foreach my $key(keys %h_netcnt){
		print "$key => $h_netcnt{$key}\n";
	}

	$subckt_flag = 0;
	# Process data
	# Add External Pins
	# @ext_powerpins = (pinName, pinType)
	for my $i(0 .. $#ext_powerpins){
		# @pins = (pinID, netID, instID, pinName, pinDirection, pinLength)
		push(@pins, [($idx_pin, $h_nets{$ext_powerpins[$i][0]}, "ext", $ext_powerpins[$i][0], "t", "-1")]);
		# update net info
		$nets[$h_nets{$ext_powerpins[$i][0]}][1] = $nets[$h_nets{$ext_powerpins[$i][0]}][1] + 1;
		$nets[$h_nets{$ext_powerpins[$i][0]}][2] = ("pin$idx_pin ".$nets[$h_nets{$ext_powerpins[$i][0]}][2]);
		$idx_pin++;
	}
	# @ext_pins = (pinName, pinType)
	for my $i(0 .. $#ext_pins){
		# @pins = (pinID, netID, instID, pinName, pinDirection, pinLength)
		push(@pins, [($idx_pin, $h_nets{$ext_pins[$i][0]}, "ext", $ext_pins[$i][0], "t", "-1")]);
		# update net info
		$nets[$h_nets{$ext_pins[$i][0]}][1] = $nets[$h_nets{$ext_pins[$i][0]}][1] + 1;
		$nets[$h_nets{$ext_pins[$i][0]}][2] = ("pin$idx_pin ".$nets[$h_nets{$ext_pins[$i][0]}][2]);
		$idx_pin++;
	}
	for my $i(0 .. $#inst){
		print "a     Instance Info : ID => $inst[$i][0], Type => $inst[$i][1], Width => $inst[$i][2]\n";
		if($inst[$i][1] eq "NMOS"){
			$sizeNMOS = $sizeNMOS + 2*ceil($inst[$i][2]/$numPTrackH) + 1;
			print "sizeNMOS: $sizeNMOS\n";
		}
		else{
			$sizePMOS = $sizePMOS + 2*ceil($inst[$i][2]/$numPTrackH) + 1;
			print "sizePMOS: $sizePMOS\n";
		}
	}
	$sizeNMOS += $sizeOffset;
	$sizePMOS += $sizeOffset;
	my %h_touchedpin = ();
	for my $i(0 .. $#pins){

		if($pins[$i][2] ne "ext" && $pins[$i][3] ne "G" && !exists($h_touchedpin{$pins[$i][0]})){
			my $instType = $inst[$h_inst{$pins[$i][2]}][1];
			my $prefix_type = "";
			if($instType eq "PMOS"){
				$prefix_type = "P";
			}
			else{
				$prefix_type = "N";
			}
			my $numCon_cur = $h_netcnt{"$prefix_type\_$pins[$i][1]"};
			my $numCon_match = $h_netcnt{"$prefix_type\_$pins[$h_pinmatch{$pins[$i][0]}][1]"};

			print "$pins[$i][0] $pins[$i][3] $h_pintype{$pins[$i][3]} $numCon_cur vs $pins[$h_pinmatch{$pins[$i][0]}][0] $pins[$h_pinmatch{$pins[$i][0]}][3] $h_pintype{$pins[$h_pinmatch{$pins[$i][0]}][3]} $numCon_match\n";

			if($pins[$i][3] eq "S" && $numCon_cur < $numCon_match){
				$pins[$i][3] = "D";
				$pins[$h_pinmatch{$pins[$i][0]}][3] = "S";
			}
			elsif($pins[$i][3] eq "D" && $numCon_cur > $numCon_match){
				$pins[$i][3] = "S";
				$pins[$h_pinmatch{$pins[$i][0]}][3] = "D";
			}
			elsif($numCon_cur == $numCon_match){
				if($h_pintype{$h_name_nets{$pins[$i][1]}} eq "P"){
					$pins[$i][3] = "S";
					$pins[$h_pinmatch{$pins[$i][0]}][3] = "D";
				}
				elsif($h_pintype{$h_name_nets{$pins[$h_pinmatch{$pins[$i][0]}][1]}} eq "P"){
					$pins[$i][3] = "D";
					$pins[$h_pinmatch{$pins[$i][0]}][3] = "S";
				}
			}
			$h_touchedpin{$pins[$i][0]} = 1;
			$h_touchedpin{$h_pinmatch{$pins[$i][0]}} = 1;
		}


		if($pins[$i][2] ne "ext"){
			print "a     Pin Info : ID => $pins[$i][0], NetID => $pins[$i][1]($nets[$pins[$i][1]][1]PinNet), InstID => $pins[$i][2], PinName => $pins[$i][3], Direction => $pins[$i][4]\n";
		}
		else{
			print "a     Pin Info : ID => $pins[$i][0], NetID => $pins[$i][1]($nets[$pins[$i][1]][1]PinNet), InstID => $pins[$i][2], PinName => $pins[$i][3], Direction => $pins[$i][4], Type => $h_pintype{$pins[$i][3]}\n";
		}
	}
	for my $i(0 .. $#nets){
		print "a     Net Info : ID => $nets[$i][0], #Pin => $nets[$i][1], PinList => $nets[$i][2]\n";
	}

	if($sizeNMOS %2 == 0){
		$sizeNMOS++;
	}
	if($sizePMOS %2 == 0){
		$sizePMOS++;
	}

	# Output file
	### Write PinLayout
	print "a   Write PinLayout\n";
	print "a     Width of Routing Clip    = ".($sizeNMOS>$sizePMOS?$sizeNMOS:$sizePMOS)."\n";
	print "a     Height of Routing Clip   = $numClip\n";
	print "a     Tracks per Placement Row = $numTrackH\n";
	print "a     Width of Placement Clip  = ".($sizeNMOS>$sizePMOS?$sizeNMOS:$sizePMOS)."\n";
	print "a     Tracks per Placement Clip = $numPTrackH\n";
	open (my $out, '>', $outfile);
	print $out "a   PNR Testcase Generation::  DesignName = $designName\n";
	print $out "a   Output File:\n";
	print $out "a   $outfile\n";
	print $out "a   Width of Routing Clip    = ".($sizeNMOS>$sizePMOS?$sizeNMOS:$sizePMOS)."\n";
	print $out "a   Height of Routing Clip   = $numClip\n";
	print $out "a   Tracks per Placement Row = $numTrackH\n";
	print $out "a   Width of Placement Clip  = ".($sizeNMOS>$sizePMOS?$sizeNMOS:$sizePMOS)."\n";
	print $out "a   Tracks per Placement Clip = $numPTrackH\n";
	print $out "i   ===InstanceInfo===\n";
	print $out "i   InstID Type Width\n";
	for my $i(0 .. $#inst){
		if($inst[$i][1] eq "PMOS"){
			print $out "i   ins$inst[$i][0] $inst[$i][1] $inst[$i][2]\n";
		}
	}
	for my $i(0 .. $#inst){
		if($inst[$i][1] eq "NMOS"){
			print $out "i   ins$inst[$i][0] $inst[$i][1] $inst[$i][2]\n";
		}
	}
	print $out "i   ===PinInfo===\n";
	print $out "i   PinID NetID InstID PinName PinDirection PinLength\n";
	for my $i(0 .. $#pins){
		if($pins[$i][2] ne "ext"){
			print $out "i   pin$pins[$i][0] net$pins[$i][1] ".($pins[$i][2] eq "ext"?"ext":"ins".$pins[$i][2])." $pins[$i][3] $pins[$i][4] $pins[$i][5]\n";
		}
		else{
			print $out "i   pin$pins[$i][0] net$pins[$i][1] ".($pins[$i][2] eq "ext"?"ext":"ins".$pins[$i][2])." $pins[$i][3] $pins[$i][4] $pins[$i][5] $h_pintype{$pins[$i][3]}\n";
		}
	}
	print $out "i   ===NetInfo===\n";
	print $out "i   NetID N-PinNet PinList\n";
	for my $i(0 .. $#nets){
		print $out "i   net$nets[$i][0] $nets[$i][1]PinNet $nets[$i][2]\n";
	}
	close ($out);
	print "a   Test Case Generation Complete!!\n";
	print "a   PinLayout FILE: $outfile\n\n";
		
    } 
    elsif ($subckt_flag == 1 and $line =~ /\.PININFO/) {
		my @tmp_arr = ();
		print $line;
		@tmp_arr = split /\s+/, $line;
		for my $i(1 .. $#tmp_arr){
			my $pinType = "";
			my $pinName = "";
			if ($tmp_arr[$i] =~ /(\S+):(\S+)/){
				$pinName = $1;
				$pinType = $2;
				if($pinType eq "I" || $pinType eq "O" || ($pinType eq "B" && $pinName eq "VDD") || ($pinType eq "B" && $pinName eq "VSS")){
					print "a     External Pin Info : $pinName [".(($pinType eq "I")?"Input":(($pinType eq "O")?"Output":(($pinType eq "P")?"Power":"Ground")))."]\n";
					# @ext_pins = (pinName, pinType)
				 	if($pinType eq "B"){
						$pinType = "P";
					}
					# @ext_pins = (pinName, pinType)
				
					$h_pintype{$pinName} = $pinType;	
					if($pinType eq "I" || $pinType eq "O"){
						push(@ext_pins, [($pinName, $pinType)]);
					}
					else{
						push(@ext_powerpins, [($pinName, $pinType)]);
					}
				}
			}	
		}
    }
    elsif ($subckt_flag == 1 and $line =~ /^(MM\d*) (\S+) (\S+) (\S+) (\S+) (\S+) w=(\S+) l=(\S+) nfin=(\d+)/) {
		my $inst = $1;
		my $instID = $1;
		my $net_s = $4;
		my $net_g = $3;
		my $net_d = $2;
		my $instType = ($6 eq "nmos_rvt")?"NMOS":"PMOS";
		my $nFin = $9;

		if(!exists($h_inst{$instID})){
			# @inst = (instID, Type, Width)
			push(@inst, [($instID, $instType,  convertNanoSheet($nFin))]);
			print "Inst => ID:$1, Type:$instType, Width:$nFin -> ".convertNanoSheet($nFin)."\n";
			$h_inst{$instID} = $idx_inst;
			$idx_inst++;
		}
		else{
			# update width
			$inst[$h_inst{$instID}][2] +=  convertNanoSheet($nFin);
		}
		if(!exists($h_nets{$net_s})){
			# @nets = (netID, N-pinNet, PinList)
			push(@nets, [($idx_net, 0, "")]);
			$h_nets{$net_s} = $idx_net;
			$h_name_nets{$idx_net} = $net_s;
			$idx_net++;
		}
		if(!exists($h_nets{$net_g})){
			# @nets = (netID, N-pinNet, PinList)
			push(@nets, [($idx_net, 0, "")]);
			$h_nets{$net_g} = $idx_net;
			$h_name_nets{$idx_net} = $net_g;
			$idx_net++;
		}
		if(!exists($h_nets{$net_d})){
			# @nets = (netID, N-pinNet, PinList)
			push(@nets, [($idx_net, 0, "")]);
			$h_nets{$net_d} = $idx_net;
			$h_name_nets{$idx_net} = $net_d;
			$idx_net++;
		}
		if($instType eq "PMOS"){
			if(!exists($h_netcnt{"P_$h_nets{$net_s}"})){
				$h_netcnt{"P_$h_nets{$net_s}"} = 1;
				print "$net_s P_$h_nets{$net_s} $h_netcnt{\"P_$h_nets{$net_s}\"}\n";
			}
			elsif ($net_s ne "VDD" && $net_s ne "VSS" ) {
				$h_netcnt{"P_$h_nets{$net_s}"} += 1;
				print "$net_s P_$h_nets{$net_s} $h_netcnt{\"P_$h_nets{$net_s}\"}\n";
			}
			if(!exists($h_netcnt{"P_$h_nets{$net_d}"})){
				$h_netcnt{"P_$h_nets{$net_d}"} = 1;
				print "$net_d P_$h_nets{$net_d} $h_netcnt{\"P_$h_nets{$net_d}\"}\n";
			}
			elsif ($net_d ne "VDD" && $net_d ne "VSS" ) {
				$h_netcnt{"P_$h_nets{$net_d}"} += 1;
				print "$net_d P_$h_nets{$net_d} $h_netcnt{\"P_$h_nets{$net_d}\"}\n";
			}
		}
		else{
			if(!exists($h_netcnt{"N_$h_nets{$net_s}"})){
				$h_netcnt{"N_$h_nets{$net_s}"} = 1;
				print "$net_s N_$h_nets{$net_s} $h_netcnt{\"N_$h_nets{$net_s}\"}\n";
			}
			elsif ($net_s ne "VDD" && $net_s ne "VSS" ) {
				$h_netcnt{"N_$h_nets{$net_s}"} += 1;
				print "$net_s N_$h_nets{$net_s} $h_netcnt{\"N_$h_nets{$net_s}\"}\n";
			}
			if(!exists($h_netcnt{"N_$h_nets{$net_d}"})){
				$h_netcnt{"N_$h_nets{$net_d}"} = 1;
				print "$net_d N_$h_nets{$net_d} $h_netcnt{\"N_$h_nets{$net_d}\"}\n";
			}
			elsif ($net_d ne "VDD" && $net_d ne "VSS" ) {
				$h_netcnt{"N_$h_nets{$net_d}"} += 1;
				print "$net_d N_$h_nets{$net_d} $h_netcnt{\"N_$h_nets{$net_d}\"}\n";
			}
		}

		my $isSource = 0;
		if(!exists($h_nets_source{$net_s})){
			$isSource = 1;
			$h_nets_source{$net_s} = $idx_pin;
		}
		# @pins = (pinID, netID, instID, pinName, pinDirection, pinLength)
		push(@pins, [($idx_pin, (exists($h_nets{$net_s})?$h_nets{$net_s}:$idx_net), $instID, "S", ($isSource==1?"s":"t"), $inst[$h_inst{$1}][2] )]);
		# update net info
		$nets[$h_nets{$net_s}][1] = $nets[$h_nets{$net_s}][1] + 1;
		$nets[$h_nets{$net_s}][2] = $isSource==1?(($nets[$h_nets{$net_s}][2] eq ""?"":" ").$nets[$h_nets{$net_s}][2]."pin$idx_pin"):("pin$idx_pin ".$nets[$h_nets{$net_s}][2]);
		my $idx_pin_s = $idx_pin;
		$idx_pin++;
		$isSource = 0;
		if(!exists($h_nets_source{$net_g})){
			$isSource = 1;
			$h_nets_source{$net_g} = $idx_pin;
		}
		# @pins = (pinID, netID, instID, pinName, pinDirection, pinLength)
		push(@pins, [($idx_pin, (exists($h_nets{$net_g})?$h_nets{$net_g}:$idx_net), $instID, "G", ($isSource==1?"s":"t"), $inst[$h_inst{$1}][2] )]);
		# update net info
		$nets[$h_nets{$net_g}][1] = $nets[$h_nets{$net_g}][1] + 1;
		$nets[$h_nets{$net_g}][2] = $isSource==1?(($nets[$h_nets{$net_g}][2] eq ""?"":" ").$nets[$h_nets{$net_g}][2]."pin$idx_pin"):("pin$idx_pin ".$nets[$h_nets{$net_g}][2]);
		$idx_pin++;
		$isSource = 0;
		if(!exists($h_nets_source{$net_d})){
			$isSource = 1;
			$h_nets_source{$net_d} = $idx_pin;
		}
		# @pins = (pinID, netID, instID, pinName, pinDirection, pinLength)
		push(@pins, [($idx_pin, (exists($h_nets{$net_d})?$h_nets{$net_d}:$idx_net), $instID, "D", ($isSource==1?"s":"t"), $inst[$h_inst{$1}][2] )]);
		# update net info
		$nets[$h_nets{$net_d}][1] = $nets[$h_nets{$net_d}][1] + 1;
		$nets[$h_nets{$net_d}][2] = $isSource==1?(($nets[$h_nets{$net_d}][2] eq ""?"":" ").$nets[$h_nets{$net_d}][2]."pin$idx_pin"):("pin$idx_pin ".$nets[$h_nets{$net_d}][2]);
		$h_pinmatch{$idx_pin_s} = $idx_pin;
		$h_pinmatch{$idx_pin} = $idx_pin_s;
		$idx_pin++;
	
	}
	#elsif ($subckt_flag == 1) {
	#	print "Else if end: $line\n";
	#}
}
close ($in);

