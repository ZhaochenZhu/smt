# Option 1
def uneven_grids_pair(  M_vert, 
                        M_hori, 
                        M_vert_total_trk, 
                        M_hori_total_trk):
    """

        Check if two tracks on pair of adjacent Metal layers can construct a feasible VIA
        
        Parameters:
        M_vert: vertical-oriented metal layer
        M_hori: horizontal-oriented metal layer
        M_vert_total_trk: total number of the vertical track
        M_hori_total_trk: total number of the horizontal track

        Return: Possible coordinates to construct VIAs

    """
    via_grid_loc = []    # list of tuples representing location of feasible vias

    # Iterate through possible location
    for vtrk in range(0, M_vert_total_trk): # 0 -> n_v
        for htrk in range(0, M_hori_total_trk): # 0 -> n_h
            # check other via rule
            via_rule = True

            if via_rule:
                via_grid_loc.append((vtrk * M_vert.metal_pitch, htrk * M_hori.metal_pitch)) # via coord

    return via_grid_loc

M0_M1_via_location = (5, 4)
assert(M0_M1_via_location in uneven_grids_pair(M0, M1, 4, 6))

# Option 2
def grid_check( x_coord_via,
                y_coord_via,
                M_vert, 
                M_hori, 
                M_vert_total_trk, 
                M_hori_total_trk):
    """

        Extract a new pair-wise grid system based on minimum metal pitches
        
        Parameters:
        list_of_vert_metal_pitch: list of vertical-oriented metal pitch
        list_of_hori_metal_pitch: list of horizontal-oriented metal pitch

        Return: grid system

    """
    x_rem = x_coord_via % M_hori
    x_fact = x_coord_via // M_hori

    y_rem = y_coord_via % M_vert
    y_fact = y_coord_via // M_vert
    
    if x_rem == 0 and x_fact <= M_hori_total_trk and y_rem == 0 and y_fact <= M_vert_total_trk:
        return True
    else:
        return False