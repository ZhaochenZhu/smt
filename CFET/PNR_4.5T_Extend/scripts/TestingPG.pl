print "a     9. Via-to-via spacing rule ";
	$str.=";9. Via-to-Via Spacing Rule\n";
	if ( $VR_Parameter == 0 ){
		print "is disable\n";
		$str.=";VR is disable\n";
	}
	else{  # VR Rule Enable /Disable
### Via-to-Via Spacing Rule to prevent from having too close vias and stacked vias.
### UNDIRECTED_EDGE [index] [Term1] [Term2] [Cost]
### VERTEX [index] [name] [Z-pos] [Y-pos] [X-pos] [Arr. of adjacent vertices]
### ADJACENT_VERTICES [0:Left] [1:Right] [2:Front] [3:Back] [4:Up] [5:Down] [6:FL] [7:FR] [8:BL] [9:BR]
		my $maxDistRow = $numTrackH-1;
		my $maxDistCol = $numTrackV-1;

		for my $metal (1 .. $numMetalLayer) { # no DR on M1
		#for my $metal (1 .. 1) { # no DR on M1
			if($metal == 1){
				#next;
			}
			if( ($VR_double_samenet_flag == 1) and ($metal > 1)) {
				next;
			}
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {            
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
						next;
					}
					# Via-to-via Spacing Rule
					$vName = "m".$metal."r".$row."c".$col;
					if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.
						my $tmp_str="";
						my @tmp_var = ();
						my $cnt_var = 0;
						my $cnt_true = 0;
						$tmp_str="M_$vName\_$vertices{$vName}[5][4]";
						if(!exists($h_assign{$tmp_str})){
							push(@tmp_var, $tmp_str);
							setVar($tmp_str, 2);
							$cnt_var++;
						}
						elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
							setVar_wo_cnt($tmp_str, 0);
							$cnt_true++;
						}

						for my $newRow ($row .. $numTrackH-3) {
							for my $newCol ($col .. $numTrackV-1) {
								my $distCol = $newCol - $col;
								my $distRow = $newRow - $row;

								# Check power rail between newRow and row. (Double Power Rail Rule Applying
								if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
									$distRow++;
								}
								if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
									next;
								}
								if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
									last;
								}
								
								###### # Need to consider the Power rail distance by 2 like EOL rule
								my $neighborName = $vName;
								while ($distCol > 0){
									$distCol--;
									$neighborName = $vertices{$neighborName}[5][1];
									if ($neighborName eq "null"){
										last;
									}
								}

								my $currentRow = $row; my $FlagforSecond = 0;
								while ($distRow > 0){  
									$distRow--; 
									$currentRow++;

									########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
									if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
										$FlagforSecond = 1;
										$currentRow--; 
										next;
									}
									$FlagforSecond = 0;
									####################################
									$neighborName = $vertices{$neighborName}[5][3];
									if ($neighborName eq "null"){
										last;
									}
								}
								my $neighborUp = "";
								if ($neighborName ne "null"){
									$neighborUp = $vertices{$neighborName}[5][4];
									if ($neighborUp eq "null"){
										print "ERROR : There is some bug in switch box definition !\n";
										print "$vName\n";
										exit(-1);
									}
								}
								my $col_neighbor = (split /[mrc]/, $neighborName)[3];
								if($metal > 1 && $metal % 2 == 1 && ($col_neighbor %2 == 1)){
									next;
								}
								else{
									$tmp_str="M_$neighborName\_$neighborUp";                        
									if(!exists($h_assign{$tmp_str})){
										push(@tmp_var, $tmp_str);
										setVar($tmp_str, 2);
										$cnt_var++;
									}
									elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
										setVar_wo_cnt($tmp_str, 0);
										$cnt_true++;
									}
								}
							}
						}
						if($cnt_true>0){
							if($cnt_true>1){
								print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
								exit(-1);
							}
							else{
								for my $i(0 .. $#tmp_var){
									if(!exists($h_assign{$tmp_var[$i]})){
										$h_assign_new{$tmp_var[$i]} = 0;
									}
								}
							}
						}
						else{
							if($cnt_var > 1){
								$str.="(assert ((_ at-most 1)";
								for my $i(0 .. $#tmp_var){
									if ($i == 1) {
										$str.=" (or ";
									}
									$str.=" $tmp_var[$i]";
									cnt("l", 3);
								}
								$str.=")))\n";
								cnt("c", 3);
							}
						}
					}
				}
			}
		}
		if( $VR_double_samenet_flag == 1) {
		$str.=";VIA Rule for M2~M4, VIA Rule is applied only for vias between different nets\n";
		for my $netIndex (0 .. $#nets) {
			for my $metal (2 .. $numMetalLayer) { # no DR on M1
				for my $row (0 .. $numTrackH-3) {
					for my $col (0 .. $numTrackV-1) {            
						if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
							next;
						}
						if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
							next;
						}
						# Via-to-via Spacing Rule
						$vName = "m".$metal."r".$row."c".$col;
						if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.
							my $tmp_str="";
							my @tmp_var = ();
							my $cnt_var = 0;
							my $cnt_true = 0;

							$tmp_str="N$nets[$netIndex][1]_E_$vName\_$vertices{$vName}[5][4]";
							if(!exists($h_assign{$tmp_str})){
								push(@tmp_var, $tmp_str);
								setVar($tmp_str, 2);
								$cnt_var++;
							}
							elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
								setVar_wo_cnt($tmp_str, 0);
								$cnt_true++;
							}

							for my $newRow ($row .. $numTrackH-3) {
								for my $newCol ($col .. $numTrackV-1) {
									my $distCol = $newCol - $col;
									my $distRow = $newRow - $row;

									# Check power rail between newRow and row. (Double Power Rail Rule Applying
									if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
										$distRow++;
									}
									if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
										next;
									}
									if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
										last;
									}
									
									###### # Need to consider the Power rail distance by 2 like EOL rule
									my $neighborName = $vName;
									while ($distCol > 0){
										$distCol--;
										$neighborName = $vertices{$neighborName}[5][1];
										if ($neighborName eq "null"){
											last;
										}
									}

									my $currentRow = $row; my $FlagforSecond = 0;
									while ($distRow > 0){  
										$distRow--; 
										$currentRow++;

										########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
										if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
											$FlagforSecond = 1;
											$currentRow--; 
											next;
										}
										$FlagforSecond = 0;
										####################################
										$neighborName = $vertices{$neighborName}[5][3];
										if ($neighborName eq "null"){
											last;
										}
									}
									my $neighborUp = "";
									if ($neighborName ne "null"){
										$neighborUp = $vertices{$neighborName}[5][4];
										if ($neighborUp eq "null"){
											print "ERROR : There is some bug in switch box definition !\n";
											print "$vName\n";
											exit(-1);
										}
									}
									my $col_neighbor = (split /[mrc]/, $neighborName)[3];
									if($metal > 1 && $metal % 2 == 1 && ($col_neighbor %2 == 1)){
										next;
									}
									else{
										$tmp_str="C_VIA_WO_N$nets[$netIndex][1]_E_$neighborName\_$neighborUp";                        
										if(!exists($h_assign{$tmp_str})){
											push(@tmp_var, $tmp_str);
											setVar($tmp_str, 2);
											$cnt_var++;
										}
										elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
											setVar_wo_cnt($tmp_str, 0);
											$cnt_true++;
										}
									}
								}
							}
							if($cnt_true>0){
								if($cnt_true>1){
									print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
									exit(-1);
								}
								else{
									for my $i(0 .. $#tmp_var){
										if(!exists($h_assign{$tmp_var[$i]})){
											$h_assign_new{$tmp_var[$i]} = 0;
										}
									}
								}
							}
							else{
								if($cnt_var > 1){
									$str.="(assert ((_ at-most 1)";
									for my $i(0 .. $#tmp_var){
										$str.=" $tmp_var[$i]";
										cnt("l", 3);
									}
									$str.="))\n";
									cnt("c", 3);
								}
							}
						}
					}
				}
			}
		}
		for my $metal (2 .. $numMetalLayer) { # no DR on M1
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {            
					if($metal>1 && $metal % 2 == 1 && $col % 2 == 1){
						next;
					}
					if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
						next;
					}
					# Via-to-via Spacing Rule
					$vName = "m".$metal."r".$row."c".$col;
					if ($vertices{$vName}[5][4] ne "null") { # Up Neighbor, i.e., VIA from the vName vertex.

						for my $newRow ($row .. $numTrackH-3) {
							for my $newCol ($col .. $numTrackV-1) {
								my $distCol = $newCol - $col;
								my $distRow = $newRow - $row;

								# Check power rail between newRow and row. (Double Power Rail Rule Applying
								if ( ($DoublePowerRail == 1) && (floor($newRow / ($trackEachRow + 1)) ne floor($row / ($trackEachRow + 1))) ){
									$distRow++;
								}
								if ( ($newRow eq $row) && ($newCol eq $col) ){  # Initial Value.
									next;
								}
								if ( ($distCol * $distCol + $distRow * $distRow) > ($VR_Parameter * $VR_Parameter) ){ # Check the Via Distance
									last;
								}
								
								###### # Need to consider the Power rail distance by 2 like EOL rule
								my $neighborName = $vName;
								while ($distCol > 0){
									$distCol--;
									$neighborName = $vertices{$neighborName}[5][1];
									if ($neighborName eq "null"){
										last;
									}
								}

								my $currentRow = $row; my $FlagforSecond = 0;
								while ($distRow > 0){  
									$distRow--; 
									$currentRow++;

									########### Double Power Rail Effective Flag Code --> We need to update previous PowerRailFlag with this code [Dongwon Park , 2019-01-08]
									if( ($DoublePowerRail == 1) && ($currentRow % ($trackEachRow + 1) == 0) && ($FlagforSecond == 0) ){ #power Rail
										$FlagforSecond = 1;
										$currentRow--; 
										next;
									}
									$FlagforSecond = 0;
									####################################
									$neighborName = $vertices{$neighborName}[5][3];
									if ($neighborName eq "null"){
										last;
									}
								}
								my $neighborUp = "";
								if ($neighborName ne "null"){
									$neighborUp = $vertices{$neighborName}[5][4];
									if ($neighborUp eq "null"){
										print "ERROR : There is some bug in switch box definition !\n";
										print "$vName\n";
										exit(-1);
									}
								}
								my $col_neighbor = (split /[mrc]/, $neighborName)[3];
								if($metal > 1 && $metal % 2 == 1 && ($col_neighbor %2 == 1)){
									next;
								}
								else{
									for my $netIndex (0 .. $#nets) {
										my $tmp_str_c="";
										my $tmp_str="";
										my @tmp_var = ();
										my $cnt_var = 0;
										my $cnt_true = 0;
										$tmp_str_c="C_VIA_WO_N$nets[$netIndex][1]_E_$neighborName\_$neighborUp";                        
										if(exists($h_var{$tmp_str_c})){
											for my $netIndex_sub (0 .. $#nets) {
												if($netIndex == $netIndex_sub){
													next;
												}
												$tmp_str="N$nets[$netIndex_sub][1]_E_$neighborName\_$neighborUp";                        
												if(!exists($h_assign{$tmp_str})){
													push(@tmp_var, $tmp_str);
													setVar($tmp_str, 2);
													$cnt_var++;
												}
												elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
													setVar_wo_cnt($tmp_str, 0);
													$cnt_true++;
												}
											}
										}
										if($cnt_true>0){
											if($cnt_true>1){
												print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
												exit(-1);
											}
											else{
												for my $i(0 .. $#tmp_var){
													if(!exists($h_assign{$tmp_var[$i]})){
														$h_assign_new{$tmp_var[$i]} = 0;
													}
												}
											}
										}
										else{
											if($cnt_var > 1){
												$str.="(assert (= $tmp_str_c (or";
												for my $i(0 .. $#tmp_var){
													$str.=" $tmp_var[$i]";
													cnt("l", 3);
												}
												$str.=")))\n";
												cnt("c", 3);
											}
										}
									}
								}
							}
						}
					}
				}
			}
		}
		} # End $VR_double_samenet_flag == 1
		if ($VR_stacked_via_flag == 0) {
		$str.=";Stacked via forbidden rule\n";
		for my $metal (2 .. $numMetalLayer-1) { # no DR on M1
			for my $row (0 .. $numTrackH-3) {
				for my $col (0 .. $numTrackV-1) {            
					if($col % 2 == 1){
						next;
					}
					if (($row == $numTrackH-3) && ($col == $numTrackV-1)) {
						next;
					}
					# Via-to-via Spacing Rule
					$vName = "m".$metal."r".$row."c".$col;
					# Stacked Via Rule
					if ( ($vertices{$vName}[5][4] eq "null") || ($vertices{$vName}[5][5] eq "null") ){
						print "ERROR : There is some bug in switch box definition ! [$vName $vertices{$vName}[5][4] $vertices{$vName}[5][5]]\n";
						exit(-1);
					}
					my $tmp_str="";
					my @tmp_var = ();
					my $cnt_var = 0;
					my $cnt_true = 0;
					$tmp_str="M_$vName\_$vertices{$vName}[5][4]";
					if(!exists($h_assign{$tmp_str})){
						push(@tmp_var, $tmp_str);
						setVar($tmp_str, 2);
						$cnt_var++;
					}
					elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
						setVar_wo_cnt($tmp_str, 0);
						$cnt_true++;
					}
					$tmp_str="M_$vertices{$vName}[5][5]\_$vName";
					if(!exists($h_assign{$tmp_str})){
						push(@tmp_var, $tmp_str);
						setVar($tmp_str, 2);
						$cnt_var++;
					}
					elsif(exists($h_assign{$tmp_str}) && $h_assign{$tmp_str} eq 1){
						setVar_wo_cnt($tmp_str, 0);
						$cnt_true++;
					}
					if($cnt_true>0){
						if($cnt_true>1){
							print "[ERROR] VIA2VIA: more than one G Variables are true!!!\n";
							exit(-1);
						}
						else{
							for my $i(0 .. $#tmp_var){
								if(!exists($h_assign{$tmp_var[$i]})){
									$h_assign_new{$tmp_var[$i]} = 0;
								}
							}
						}
					}
					else{
						if($cnt_var > 1){
							$str.="(assert ((_ at-most 1)";
							for my $i(0 .. $#tmp_var){
								$str.=" $tmp_var[$i]";
								cnt("l", 3);
							}
							$str.="))\n";
							cnt("c", 3);
						}
					}
				}
			}
		}
		$str.="\n";
		} # $VR_stacked_via_flag == 0
		print "has been written.\n";
	}