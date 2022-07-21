#! /usr/bin/perl

use strict 'vars'; # generates a compile-time error if you access a variable without declaration
use strict 'refs'; # generates a runtime error if you use symbolic references
use strict 'subs'; # compile-time error if you try to use a bareword identifier in an improper way.
use Data::Dumper;
use POSIX;

use Cwd;

my $numTrackV = 13;

# Mark: 2.2.9 Improve pin accessibility
if (1) { 
    my $str ="; 2.2.9 More space between two net is favorable to improve pin accesibility\n";
    if (1) {
    for my $col (0 .. $numTrackV-1){
        my $valid = 0;
        my $len = length(sprintf("%b", $numTrackV))+4; an unsigned integer, in binary # numTrackV in bit length + 4?
        #my $tmp_str="(assert (ite (and (bvsge COST_SIZE (_ bv".$col." $len)) (or ";
        #my $tmp_str="(assert (ite (bvsge COST_SIZE (_ bv".$col." $len)) (ite (and (or ";
        my $tmp_str="(assert (ite (and (or ";
        for my $netIndex (0 .. $#nets) {
            #$tmp_str.="(or ";
            my @tmp_arr = ();
            for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {	
                for my $vEdgeIndex (0 .. $#virtualEdges) {
                    my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
                    my $len = length(sprintf("%b", $numTrackV))+4;
                    if ($virtualEdges[$vEdgeIndex][2] eq "pinSON" && $col == $toCol && ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3] || $virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]) ) {
                        my $tmp_var = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
                        #push (@tmp_arr, $tmp_var);
                        $tmp_str.=" (= $tmp_var true)";
                        $valid = 1;
                    }
                }
            }
            #$tmp_str.=") ";
        }
        if ( $dint -2 < $col ) { # assume -2 has one pin
        #$tmp_str.=") (and ";
        my @tmp_arr = ();
        for my $netIndex (0 .. $#nets) {
            #$tmp_str.="(and ";
            #my @tmp_arr = ();
            print ("Net name: $nets[$netIndex][0]\n");
            for my $commodityIndex (0 .. $nets[$netIndex][4]-1) {	
                for my $vEdgeIndex (0 .. $#virtualEdges) {
                    my $toCol   = (split /[a-z]/, $virtualEdges[$vEdgeIndex][1])[3];
                    my $len = length(sprintf("%b", $numTrackV))+4;
                    #if ($virtualEdges[$vEdgeIndex][2] eq "pinSON" && ( ($col - $toCol == 2) || ($toCol - $col == 2) ) && ($col != 0) && ($toCol != 0) && ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3] || $virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]) ) {
                    if ($virtualEdges[$vEdgeIndex][2] eq "pinSON" && ( ($col - $toCol == $dint) || ($toCol - $col == $dint) ) && ($virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][3] || $virtualEdges[$vEdgeIndex][2] eq $nets[$netIndex][5][$commodityIndex]) ) {
                        my $tmp_var = "N$nets[$netIndex][1]\_C$commodityIndex\_E_$virtualEdges[$vEdgeIndex][1]_$virtualEdges[$vEdgeIndex][2]";
                        push (@tmp_arr, $tmp_var);
                        #$tmp_str.=" (= $tmp_var false) ";
                        #$valid = 1;
                    }
                }
            }
            #$tmp_str.=") ";
        }
        if ($#tmp_arr+1 > 0) {
            $tmp_str.=") (and ";
            for my $tmp_var (0 .. $#tmp_arr) {
                $tmp_str.=" (= $tmp_arr[$tmp_var] false) "
            }
            $tmp_str.=") ";
        }
        #$tmp_str.=") ";
        $tmp_str.=") (= COST_Pin_C$col true) (= COST_Pin_C$col false) ))\n";
        } else { # pin interfered by boundary
            $tmp_str.=")) (= COST_Pin_C$col false) (= COST_Pin_C$col false) ))\n";
        }
        #$tmp_str.=") (= COST_Pin_C$col true) (= COST_Pin_C$col false) ) (= COST_Pin_C$col false)))\n";
        if ($valid == 1) {
            cnt("l", 1);
            $str.=$tmp_str;
            setVar("COST_Pin_C$col", 2);	
        }
    }
    } 
}