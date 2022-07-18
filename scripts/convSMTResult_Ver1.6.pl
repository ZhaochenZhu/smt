#! /usr/bin/perl

use strict 'vars';
use strict 'refs';
use strict 'subs';

use POSIX;

use Cwd;

### Revision History : Ver 1.5 #####
# 2019-03-18 SMT Result Converter
# 2019-06-27 Line Data Merge Applied
# 2020-02-19 Generate lef file generator compatible .conv file
### Pre-processing ########################################################
my $ARGC        = @ARGV;
my $workdir     = getcwd();
my $outdir      = "$workdir/solutionsSMT_cfet";
my $pinLayoutdir      = "$workdir/pinLayouts_cfet";
my $infile      = "";
my $cellname	= "";
my $lefgen_inputdir = "";

if ($ARGC != 3) {
    print "\n*** Error:: Wrong CMD";
    print "\n   [USAGE]: ./PL_FILE [inputfile_result] [org_cell_name]\n\n";
    exit(-1);
} else {
    $infile             = $ARGV[0];
    $cellname			= $ARGV[1];
    $lefgen_inputdir            = $ARGV[2];
}

if (!-e "./$infile") {
    print "\n*** Error:: FILE DOES NOT EXIST..\n";
    print "***         $workdir/$infile\n\n";
    exit(-1);
}
if (!-e "$pinLayoutdir/$cellname.pinLayout") {
    print "\n*** Error:: PinLayout FILE DOES NOT EXIST..\n";
    print "***         $pinLayoutdir/$cellname.pinLayout\n\n";
    exit(-1);
}

### Output Directory Creation, please see the following reference:
system "mkdir -p $outdir";

my $infileStatus = "init";

## Instance Info
my @inst = ();
my %h_inst = ();
my $idx_inst = 0;
## Metal/VIA Info
my @metal = ();
my @via = ();
my @final_metal = ();
my @final_via = ();
my @m_metal = ();
my %h_metal = ();
my %h_m_metal = ();
my $idx_m_metal = 0;
## Wire
my @wire = ();
my @via_wire = ();
my %h_wire = ();
my %h_via_wire = ();
## Internal Pin Info
my @pin = ();
my @extpin = ();
my %h_pin = ();
my %h_extpin = ();
## Net
my @net = ();
my %h_net = ();
## Cost
my $cost_placement = 0;
my $cost_ml = 0;
my $cost_ml2 = 0;
my $cost_wl = 0;
my $no_m2_track = 0;

my $isFirst = 1;
my $subIndex = 0;

my $out;
my $outfile = "";
### Read External Pin Name
my %h_extpinname = ();
my %h_extpintype = ();
my $numTrackV = 0;
my $numTrackH = 0;
my $numTrackHPerClip = 0;
my $numRoutingClip = 0;
open (my $in, "$pinLayoutdir/$cellname.pinLayout");
while (<$in>) {
    my $line = $_;
    chomp($line);

    if ($line =~ /^i.*pin.*net(\d+) ext (\S+) t -1 (\S+)/) {
		my $netID = $1;
		my $pinName = $2;
		my $pinType = $3;
		$h_extpinname{$1}=$2;
		$h_extpintype{$1}=$3;
	}
    if ($line =~ /^a.*Height of Routing Clip.*= (\S+)/) {
		$numRoutingClip = $1;
	}
    if ($line =~ /^a.*Width of Routing Clip.*= (\S+)/) {
		$numTrackV = $1;
	}
    if ($line =~ /^a.*Tracks per Placement Row.*= (\S+)/) {
		$numTrackHPerClip = $1;
	}
}
close($in);
$numTrackH = $numRoutingClip * $numTrackHPerClip - 2;

### Read Inputfile and Build Data Structure
open (my $in, "./$infile");
while (<$in>) {
    my $line = $_;
    chomp($line);

	if ($line =~ /^sat/){
		if($isFirst == 1){
			$isFirst = 0;
			next;
		}
		else{
			$cost_placement++;
			$outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_$subIndex\_C_$cost_placement\_$cost_ml\_$cost_wl\_$no_m2_track.conv";
			open ($out,'>', $outfile);
			printResult();
			close($out);
			@inst = ();
			%h_inst = ();
			$idx_inst = 0;
			@metal = ();
			@via = ();
			@pin = ();
			%h_pin = ();
			@wire = ();
			@via_wire = ();
			%h_wire = ();
			%h_via_wire = ();
			$cost_placement = 0;
			$cost_ml = 0;
			$cost_ml2 = 0;
			$cost_wl = 0;
			$subIndex++;
		}
	}

    ### Instance
    if ($line =~ /^.*\(define-fun x(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		if($line =~ /^\s+#x(\S+)\)/){
			$line =~ s/^\s+#x(\S+)\)/$1/g;
			$line = eval("0x$line");
		}
		else{
			$line =~ s/^\s+#b(\S+)\)/$1/g;
			$line = eval("0b$line");
		}
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][1] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, $line, -1, -1, -1, -1, -1)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    elsif ($line =~ /^.*\(define-fun y(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		if($line =~ /^\s+#x(\S+)\)/){
			$line =~ s/^\s+#x(\S+)\)/$1/g;
			$line = eval("0x$line");
		}
		else{
			$line =~ s/^\s+#b(\S+)\)/$1/g;
			$line = eval("0b$line");
		}
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][2] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, -1, $line, -1, -1, -1, -1)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    elsif ($line =~ /^.*\(define-fun nf(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+#b(\S+)\)/$1/g;
		$line = eval("0b$line");
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][3] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, -1, -1, $line, -1, -1, -1)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    elsif ($line =~ /^.*\(define-fun ff(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][4] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, -1, -1, -1, $line, -1, -1)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    elsif ($line =~ /^.*\(define-fun w(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		if($line =~ /^\s+#x(\S+)\)/){
			$line =~ s/^\s+#x(\S+)\)/$1/g;
			$line = eval("0x$line");
		}
		else{
			$line =~ s/^\s+#b(\S+)\)/$1/g;
			$line = eval("0b$line");
		}
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][5] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, -1, -1, -1, -1, $line, -1)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    elsif ($line =~ /^.*\(define-fun uw(\d+)/) {
		my $tmp = $1;
		$line = <$in>;
		chomp($line);
		if($line =~ /^\s+#x(\S+)\)/){
			$line =~ s/^\s+#x(\S+)\)/$1/g;
			$line = eval("0x$line");
		}
		else{
			$line =~ s/^\s+#b(\S+)\)/$1/g;
			$line = eval("0b$line");
		}
		if(exists($h_inst{$tmp})){
			$inst[$h_inst{$tmp}][6] = $line;
		}
		else{
			#@inst = [InstID, xPos, yPos, numFinger, flipFlag, width, unitWidth]
			push(@inst, [($tmp, -1, -1, -1, -1, -1, $line)]);
			$h_inst{$tmp} = $idx_inst;
			$idx_inst++;
		}
    } 
    ### Metal
    if ($line =~ /^.*\(define-fun M_m(\d+)r(\d+)c(\d+)_m(\d+)r(\d+)c(\d+)/) {
		my $fromM = $1;
		my $toM = $4;
		my $fromR = $2;
		my $toR = $5;
		my $fromC = $3;
		my $toC = $6;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
#$line = sprintf("%d", $line);
		$line = $line eq "true"?1:0;

		if($line == 1){
			# Metal Line
			if($fromM == $toM){
				#@metal = [numLayer, fromRow, fromCol, toRow, toCol];
				push(@metal, [($fromM, $fromR, $fromC, $toR, $toC)]);
				if($toM == 4){
					$cost_ml2 = $cost_ml2 + 4;
				}
				elsif($toM >= 2){
					$cost_ml2++;
				}
			}
			else{
				#@via = [fromMetalLayer, toMetalLayer, Row, Col]
				push(@via, [($fromM, $toM, $fromR, $fromC)]);
				if($toM == 4){
					$cost_ml2 = $cost_ml2 + 8;
				}
				elsif($toM >= 2){
					$cost_ml2 = $cost_ml2 + 4;
				}
#print "VIA $fromM $toM $fromR $fromC\n";
			}
		}
    } 
    ### Wire
    if ($line =~ /^.*\(define-fun N(\S+)_C(\S+)_E_m(\d+)r(\d+)c(\d+)_m(\d+)r(\d+)c(\d+)/) {
		my $fromM = $3;
		my $toM = $6;
		my $fromR = $4;
		my $toR = $7;
		my $fromC = $5;
		my $toC = $8;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;

		if($line == 1){
			if(!exists($h_wire{$fromM."_".$toM."_".$fromR."_".$fromC."_".$toR."_".$toC})){
				#print "VIA_WIRE $fromM $toM $fromR $fromC $toR $toC\n";
				# Metal Line
				if($fromM == $toM){
					#@metal = [numLayer, fromRow, fromCol, toRow, toCol];
					push(@wire, [($fromM, $fromR, $fromC, $toR, $toC)]);
					if($toM == 4){
						$cost_wl = $cost_wl + 4;
					}
					elsif($toM >= 2){
						$cost_wl++;
					}
				}
				else{
					#@via = [fromMetalLayer, toMetalLayer, Row, Col]
					push(@via_wire, [($fromM, $toM, $fromR, $fromC)]);
					#print "VIA $fromM $toM $fromR $fromC\n";
					if($toM == 4){
						$cost_wl = $cost_wl + 8;
					}
					elsif($toM >= 2){
						$cost_wl = $cost_wl + 4;
					}
				}
				$h_wire{$fromM."_".$toM."_".$fromR."_".$fromC."_".$toR."_".$toC} = 1;
			}
		}
    } 
    ### Net
    if ($line =~ /^.*\(define-fun N(\S+)_E_m(\d+)r(\d+)c(\d+)_m(\d+)r(\d+)c(\d+)/) {
		my $netID = $1;
		my $fromM = $2;
		my $toM = $5;
		my $fromR = $3;
		my $toR = $6;
		my $fromC = $4;
		my $toC = $7;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;

		if($line == 1){
			if(!exists($h_net{$fromM."_".$toM."_".$fromR."_".$fromC."_".$toR."_".$toC})){
				#@net = [numLayer, fromRow, fromCol, toRow, toCol];
				push(@net, [($fromM, $fromR, $fromC, $toR, $toC)]);
				$h_net{$fromM."_".$toM."_".$fromR."_".$fromC."_".$toR."_".$toC} = $netID;
				$h_net{$fromM."_".$toM."_".$toR."_".$fromC."_".$fromR."_".$toC} = $netID;
				$h_net{$fromM."_".$toM."_".$fromR."_".$toC."_".$toR."_".$fromC} = $netID;
				$h_net{$toM."_".$fromM."_".$fromR."_".$fromC."_".$toR."_".$toC} = $netID;
			}
		}
    } 
    ### Pin
    if ($line =~ /^.*\(define-fun M_.*(pin[a-zA-Z0-9_]+)_r(\d+)c(\d+)/) {
		my $pinName = $1;
		my $row = $2;
		my $col = $3;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;
		if($line == 1){
			if(!exists($h_pin{$pinName})){
				#@pin = [pinName, row, col]
				push(@pin, [($pinName, $row, $col)]);
				$h_pin{$pinName} = 1;
			}
		}
	}
	elsif ($line =~ /^.*\(define-fun N.*C.*m1r(\d+)c(\d+)_(pin[a-zA-Z0-9_]+)/) {
		my $pinName = $3;
		my $row = $1;
		my $col = $2;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;
		if($line == 1){
			    
#if(!exists($h_pin{$pinName})){
				#@pin = [pinName, row, col]
				push(@pin, [($pinName, $row, $col)]);
				$h_pin{$pinName} = 1;
#}
		}
	}
    ### ExtPin
	if ($line =~ /^.*\(define-fun N(\d+)_E_m(\d+)r(\d+)c(\d+)_pinSON/) {
		my $net = $1;
		my $metal = $2;
		my $row = $3;
		my $col = $4;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;
		if($line == 1){
			if(!exists($h_extpin{$net})){
				#@pin = [pinName, row, col]
				push(@extpin, [($net, $metal, $row, $col)]);
				$h_extpin{$net} = 1;
			}
		}
	}
    ### Cost
    if ($line =~ /^.*\(define-fun COST_SIZE /) {
		$line = <$in>;
		chomp($line);
		if($line =~ /^\s+#x(\S+)\)/){
			$line =~ s/^\s+#x(\S+)\)/$1/g;
			$line = eval("0x$line");
		}
		else{
			$line =~ s/^\s+#b(\S+)\)/$1/g;
			$line = eval("0b$line");
		}
		if($line>$cost_placement){
			$cost_placement = $line + 2;
		}
	}
    if ($line =~ /^.*\(define-fun cost_ML/) {
		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\d+)\)/$1/g;
		$cost_ml = $line;
	}
    ### M2 Track
    if ($line =~ /^.*\(define-fun M2_TRACK_(\d+)/) {
		my $row = $1;

		$line = <$in>;
		chomp($line);
		$line =~ s/^\s+(\S+)\)/$1/g;
		$line = $line eq "true"?1:0;
		if($line == 1){
			$no_m2_track++;
		}
	}
}
close ($in);
$outfile     = "$outdir/".(split /\./, (split /\//, $infile)[$#_])[0]."_$subIndex\_C_$cost_placement\_$cost_ml2\_$cost_wl\_$no_m2_track.conv";
open ($out,'>', $outfile);
mergeVertices();
printResult();
close($out);

sub mergeVertices{
	my $idx_metal = 0;
	for my $i(0 .. (scalar @metal) -1){
		push(@final_metal, [($metal[$i][0], $metal[$i][1], $metal[$i][2], $metal[$i][3], $metal[$i][4])]);
		$h_metal{$metal[$i][0]."_".$metal[$i][0]."_".$metal[$i][1]."_".$metal[$i][2]."_".$metal[$i][3]."_".$metal[$i][4]} = $idx_metal;
		$idx_metal++;
	}
	for my $i(0 .. (scalar @via) -1){
		push(@final_via, [($via[$i][0], $via[$i][1], $via[$i][2], $via[$i][3])]);
	}
	my $prev_cnt = 0;
	my $cur_cnt = 0;
	$prev_cnt = keys %h_metal;
	$cur_cnt = keys %h_metal;
	while($cur_cnt > 0){
		if($prev_cnt == $cur_cnt){
			foreach my $key(keys %h_metal){
				my $idx = $h_metal{$key};
				my $netID = $h_net{$final_metal[$idx][0]."_".$final_metal[$idx][0]."_".$final_metal[$idx][1]."_".$final_metal[$idx][2]."_".$final_metal[$idx][3]."_".$final_metal[$idx][4]};
				push(@m_metal, [($final_metal[$idx][0], $final_metal[$idx][1], $final_metal[$idx][2], $final_metal[$idx][3], $final_metal[$idx][4], $netID)]);
				$h_m_metal{ $final_metal[$idx][0]."_".$final_metal[$idx][1]."_".$final_metal[$idx][2]."_".$final_metal[$idx][3]."_".$final_metal[$idx][4]} = $idx_m_metal;
				$idx_m_metal++;
				delete $h_metal{$key};
#				print "NEW METAL $final_metal[$idx][0]: $final_metal[$idx][1] -> $final_metal[$idx][3], $final_metal[$idx][2] -> $final_metal[$idx][4]\n";
				last;
			}
		}
		$prev_cnt = keys %h_metal;
		foreach my $key(keys %h_metal){
			my $idx = $h_metal{$key};
			for(my $i=0; $i<=$#m_metal; $i++){
				if($m_metal[$i][0] eq $final_metal[$idx][0]){
					# Vertical
					if($final_metal[$idx][1] != $final_metal[$idx][3] && $m_metal[$i][1] != $m_metal[$i][3] && $m_metal[$i][2] == $m_metal[$i][4]){
						if($m_metal[$i][1] == $final_metal[$idx][3] && $m_metal[$i][2] == $final_metal[$idx][2]){
							$m_metal[$i][1] = $final_metal[$idx][1];
							delete $h_metal{$key};
#print "EXT METAL $final_metal[$idx][0]: $final_metal[$idx][1] -> $final_metal[$idx][3], $final_metal[$idx][2] -> $final_metal[$idx][4]";
#print " => $m_metal[$i][1] -> $m_metal[$i][3], $m_metal[$i][2] -> $m_metal[$i][4]\n";
						}
						elsif($m_metal[$i][3] == $final_metal[$idx][1] && $m_metal[$i][2] == $final_metal[$idx][2] && $m_metal[$i][2] == $m_metal[$i][4]){
							$m_metal[$i][3] = $final_metal[$idx][3];
							delete $h_metal{$key};
#print "EXT METAL $final_metal[$idx][0]: $final_metal[$idx][1] -> $final_metal[$idx][3], $final_metal[$idx][2] -> $final_metal[$idx][4]";
#print " => $m_metal[$i][1] -> $m_metal[$i][3], $m_metal[$i][2] -> $m_metal[$i][4]\n";
						}
					}
					# Horizontal
					elsif($final_metal[$idx][2] != $final_metal[$idx][4] && $m_metal[$i][2] != $m_metal[$i][4] && $m_metal[$i][1] == $m_metal[$i][3]){
						if($m_metal[$i][2] == $final_metal[$idx][4] && $m_metal[$i][1] == $final_metal[$idx][1]){
							$m_metal[$i][2] = $final_metal[$idx][2];
							delete $h_metal{$key};
#print "EXT METAL $final_metal[$idx][0]: $final_metal[$idx][1] -> $final_metal[$idx][3], $final_metal[$idx][2] -> $final_metal[$idx][4]";
#print " => $m_metal[$i][1] -> $m_metal[$i][3], $m_metal[$i][2] -> $m_metal[$i][4]\n";
						}
						elsif($m_metal[$i][4] == $final_metal[$idx][2] && $m_metal[$i][1] == $final_metal[$idx][1] && $m_metal[$i][1] == $m_metal[$i][3]){
							$m_metal[$i][4] = $final_metal[$idx][4];
							delete $h_metal{$key};
#print "EXT METAL $final_metal[$idx][0]: $final_metal[$idx][1] -> $final_metal[$idx][3], $final_metal[$idx][2] -> $final_metal[$idx][4]";
#print " => $m_metal[$i][1] -> $m_metal[$i][3], $m_metal[$i][2] -> $m_metal[$i][4]\n";
						}
					}
				}
			}
		}
		$cur_cnt = keys %h_metal;
	}
}

sub printResult{
	print $out "COST $cost_placement $cost_ml $cost_wl\r\n";
	print $out "TRACK $numTrackV $numTrackH\r\n";
	for my $i(0 .. (scalar @inst) -1){
		#print "$inst[$i][0] x=$inst[$i][1] y=$inst[$i][2] nf=$inst[$i][3] ff=$inst[$i][4] w=$inst[$i][5] uw=$inst[$i][6]\n";
		print $out "INST $inst[$i][0] $inst[$i][1] $inst[$i][2] $inst[$i][3] $inst[$i][4] $inst[$i][5] $inst[$i][6]\r\n";
	}
	for my $i(0 .. (scalar @pin) -1){
		#print "Internal PIN : Name => $pin[$i][0] Row=$pin[$i][1] Col=$pin[$i][2]\n";
		print $out "PIN $pin[$i][0] $pin[$i][1] $pin[$i][2]\r\n";
	}
	for my $i(0 .. (scalar @m_metal) -1){
		#print "Metal Layer => $m_metal[$i][0] fromRow=$m_metal[$i][1] fromCol=$m_metal[$i][2] toRow=$m_metal[$i][3] toCol=$m_metal[$i][4]\n";
		if($m_metal[$i][0] == 1){
			my $netID = $h_net{$m_metal[$i][0]."_".$m_metal[$i][0]."_".$m_metal[$i][1]."_".$m_metal[$i][2]."_".$m_metal[$i][3]."_".$m_metal[$i][4]};
			print $out "METAL $m_metal[$i][0] $m_metal[$i][1] $m_metal[$i][2] $m_metal[$i][3] $m_metal[$i][4] $m_metal[$i][5]\r\n";
		}
	}
	for my $i(0 .. (scalar @m_metal) -1){
		#print "Metal Layer => $m_metal[$i][0] fromRow=$m_metal[$i][1] fromCol=$m_metal[$i][2] toRow=$m_metal[$i][3] toCol=$m_metal[$i][4]\n";
		if($m_metal[$i][0] == 2){
			my $netID = $h_net{$m_metal[$i][0]."_".$m_metal[$i][0]."_".$m_metal[$i][1]."_".$m_metal[$i][2]."_".$m_metal[$i][3]."_".$m_metal[$i][4]};
			print $out "METAL $m_metal[$i][0] $m_metal[$i][1] $m_metal[$i][2] $m_metal[$i][3] $m_metal[$i][4] $m_metal[$i][5]\r\n";
		}
	}
	for my $i(0 .. (scalar @m_metal) -1){
		#print "Metal Layer => $m_metal[$i][0] fromRow=$m_metal[$i][1] fromCol=$m_metal[$i][2] toRow=$m_metal[$i][3] toCol=$m_metal[$i][4]\n";
		if($m_metal[$i][0] == 3){
			my $netID = $h_net{$m_metal[$i][0]."_".$m_metal[$i][0]."_".$m_metal[$i][1]."_".$m_metal[$i][2]."_".$m_metal[$i][3]."_".$m_metal[$i][4]};
			print $out "METAL $m_metal[$i][0] $m_metal[$i][1] $m_metal[$i][2] $m_metal[$i][3] $m_metal[$i][4] $m_metal[$i][5]\r\n";
		}
	}
	for my $i(0 .. (scalar @m_metal) -1){
		#print "Metal Layer => $m_metal[$i][0] fromRow=$m_metal[$i][1] fromCol=$m_metal[$i][2] toRow=$m_metal[$i][3] toCol=$m_metal[$i][4]\n";
		if($m_metal[$i][0] == 4){
			my $netID = $h_net{$m_metal[$i][0]."_".$m_metal[$i][0]."_".$m_metal[$i][1]."_".$m_metal[$i][2]."_".$m_metal[$i][3]."_".$m_metal[$i][4]};
			print $out "METAL $m_metal[$i][0] $m_metal[$i][1] $m_metal[$i][2] $m_metal[$i][3] $m_metal[$i][4] $m_metal[$i][5]\r\n";
		}
	}
	for my $i(0 .. (scalar @wire) -1){
		#print "Metal Layer => $wire[$i][0] fromRow=$wire[$i][1] fromCol=$wire[$i][2] toRow=$wire[$i][3] toCol=$wire[$i][4]\n";
		if($wire[$i][0] == 1){
			if($wire[$i][1]>$wire[$i][3]){
				print $out "WIRE $wire[$i][0] $wire[$i][3] $wire[$i][2] $wire[$i][1] $wire[$i][4]\r\n";
			}
			elsif($wire[$i][2]>$wire[$i][4]){
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][4] $wire[$i][3] $wire[$i][2]\r\n";
			}
			else{
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][2] $wire[$i][3] $wire[$i][4]\r\n";
			}
		}
	}
	for my $i(0 .. (scalar @via_wire) -1){
		#print "VIA_WIRE : FromMetal => $via_wire[$i][0] ToMetal=$via_wire[$i][1] Row=$via_wire[$i][2] Col=$via_wire[$i][3]\n";
		if($via_wire[$i][0] == 1 && $via_wire[$i][1] == 2){
			print $out "VIA_WIRE $via_wire[$i][0] $via_wire[$i][1] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
		if($via_wire[$i][0] == 2 && $via_wire[$i][1] == 1){
			print $out "VIA_WIRE $via_wire[$i][1] $via_wire[$i][0] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
	}
	for my $i(0 .. (scalar @wire) -1){
		#print "Metal Layer => $wire[$i][0] fromRow=$wire[$i][1] fromCol=$wire[$i][2] toRow=$wire[$i][3] toCol=$wire[$i][4]\n";
		if($wire[$i][0] == 2){
			if($wire[$i][1]>$wire[$i][3]){
				print $out "WIRE $wire[$i][0] $wire[$i][3] $wire[$i][2] $wire[$i][1] $wire[$i][4]\r\n";
			}
			elsif($wire[$i][2]>$wire[$i][4]){
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][4] $wire[$i][3] $wire[$i][2]\r\n";
			}
			else{
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][2] $wire[$i][3] $wire[$i][4]\r\n";
			}
		}
	}
	for my $i(0 .. (scalar @via_wire) -1){
		#print "VIA_WIRE : FromMetal => $via_wire[$i][0] ToMetal=$via_wire[$i][1] Row=$via_wire[$i][2] Col=$via_wire[$i][3]\n";
		if($via_wire[$i][0] == 2 && $via_wire[$i][1] == 3){
			print $out "VIA_WIRE $via_wire[$i][0] $via_wire[$i][1] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
		if($via_wire[$i][0] == 3 && $via_wire[$i][1] == 2){
			print $out "VIA_WIRE $via_wire[$i][1] $via_wire[$i][0] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
	}
	for my $i(0 .. (scalar @wire) -1){
		#print "Metal Layer => $wire[$i][0] fromRow=$wire[$i][1] fromCol=$wire[$i][2] toRow=$wire[$i][3] toCol=$wire[$i][4]\n";
		if($wire[$i][0] == 3){
			if($wire[$i][1]>$wire[$i][3]){
				print $out "WIRE $wire[$i][0] $wire[$i][3] $wire[$i][2] $wire[$i][1] $wire[$i][4]\r\n";
			}
			elsif($wire[$i][2]>$wire[$i][4]){
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][4] $wire[$i][3] $wire[$i][2]\r\n";
			}
			else{
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][2] $wire[$i][3] $wire[$i][4]\r\n";
			}
		}
	}
	for my $i(0 .. (scalar @via_wire) -1){
		#print "VIA_WIRE : FromMetal => $via_wire[$i][0] ToMetal=$via_wire[$i][1] Row=$via_wire[$i][2] Col=$via_wire[$i][3]\n";
		if($via_wire[$i][0] == 3 && $via_wire[$i][1] == 4){
			print $out "VIA_WIRE $via_wire[$i][0] $via_wire[$i][1] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
		if($via_wire[$i][0] == 4 && $via_wire[$i][1] == 3){
			print $out "VIA_WIRE $via_wire[$i][1] $via_wire[$i][0] $via_wire[$i][2] $via_wire[$i][3]\r\n";
		}
	}
	for my $i(0 .. (scalar @wire) -1){
		#print "Metal Layer => $wire[$i][0] fromRow=$wire[$i][1] fromCol=$wire[$i][2] toRow=$wire[$i][3] toCol=$wire[$i][4]\n";
		if($wire[$i][0] == 4){
			if($wire[$i][1]>$wire[$i][3]){
				print $out "WIRE $wire[$i][0] $wire[$i][3] $wire[$i][2] $wire[$i][1] $wire[$i][4]\r\n";
			}
			elsif($wire[$i][2]>$wire[$i][4]){
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][4] $wire[$i][3] $wire[$i][2]\r\n";
			}
			else{
				print $out "WIRE $wire[$i][0] $wire[$i][1] $wire[$i][2] $wire[$i][3] $wire[$i][4]\r\n";
			}
		}
	}
	for my $i(0 .. (scalar @final_via) -1){
		#print "VIA : FromMetal => $final_via[$i][0] ToMetal=$final_via[$i][1] Row=$final_via[$i][2] Col=$final_via[$i][3]\n";
		if($final_via[$i][0] == 3 && $final_via[$i][1] == 4){
			my $netID = $h_net{$final_via[$i][0]."_".$final_via[$i][1]."_".$final_via[$i][2]."_".$final_via[$i][3]."_".$final_via[$i][2]."_".$final_via[$i][3]};
			print $out "VIA $final_via[$i][0] $final_via[$i][1] $final_via[$i][2] $final_via[$i][3] $netID\r\n";
		}
	}
	for my $i(0 .. (scalar @final_via) -1){
		#print "VIA : FromMetal => $final_via[$i][0] ToMetal=$final_via[$i][1] Row=$final_via[$i][2] Col=$final_via[$i][3]\n";
		if($final_via[$i][0] == 2 && $final_via[$i][1] == 3){
			my $netID = $h_net{$final_via[$i][0]."_".$final_via[$i][1]."_".$final_via[$i][2]."_".$final_via[$i][3]."_".$final_via[$i][2]."_".$final_via[$i][3]};
			print $out "VIA $final_via[$i][0] $final_via[$i][1] $final_via[$i][2] $final_via[$i][3] $netID\r\n";
		}
	}
	for my $i(0 .. (scalar @final_via) -1){
		#print "VIA : FromMetal => $final_via[$i][0] ToMetal=$final_via[$i][1] Row=$final_via[$i][2] Col=$final_via[$i][3]\n";
		if($final_via[$i][0] == 1 && $final_via[$i][1] == 2){
			my $netID = $h_net{$final_via[$i][0]."_".$final_via[$i][1]."_".$final_via[$i][2]."_".$final_via[$i][3]."_".$final_via[$i][2]."_".$final_via[$i][3]};
			print $out "VIA $final_via[$i][0] $final_via[$i][1] $final_via[$i][2] $final_via[$i][3] $netID\r\n";
		}
	}
	for my $i(0 .. (scalar @extpin) -1){
		#print "External PIN : Net => $extpin[$i][0] Metal=$extpin[$i][1] Row=$extpin[$i][2] Col=$extpin[$i][3]\n";
		print $out "EXTPIN $extpin[$i][0] $extpin[$i][1] $extpin[$i][2] $extpin[$i][3] $h_extpinname{$extpin[$i][0]} $h_extpintype{$extpin[$i][0]}\r\n";
	}
	print "Converting Result Completed!\nOutput : $outfile\n";
	`cp $outfile $lefgen_inputdir`;
}
