from cProfile import label
import os, sys
import re
import math
from enum import Enum
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from itertools import cycle
from os import listdir
from os.path import isfile, join
from pathlib import Path
import gdspy
import logging

logging.basicConfig(level=logging.INFO)

###Example:######################################################################################################
#                                                                                                               #
#   python3 GDSView.py ./CFET/PNR_4.5T_Extend/solutionsSMT_cfet/                                                #
#                                                                                                               #
#################################################################################################################
class BprMode(Enum):
    """
    Power Rail Location
    """
    NONE = 0
    METAL1 = 1
    METAL2 = 2
    BPR = 3

class MpoMode(Enum):
    """
    Minimum Pin Openining: minimum I/O acess points
    """
    NONE = 0
    TWO = 1
    THREE = 2
    MAX = 3

class GDSCellLibrary:
    def __init__(self, conv_path, metal_pitch, cpp_width, bprFlag) -> None:
        # read argument
        self.conv_path = conv_path
        self.metal_pitch = metal_pitch
        self.cpp_width = cpp_width
        self.bprFlag = bprFlag
        # derive metal info
        self.metal_width = int(self.metal_pitch/2)
        # meta info
        self.inst_cnt = 0
        self.metal_cnt = 0
        self.net_cnt = 0
        self.via_cnt = 0
        self.extpin_cnt = 0
        # meta data structure
        self.metals = []
        self.instances = []
        self.vias = []
        self.extpins = []

        # extract .conv files
        self.conv_files = [file for file in listdir(self.conv_path) if isfile(join(self.conv_path, file))]

        # initialize cell library
        self.cell_lib = gdspy.GdsLibrary()
        
        # load cells into library
        for conv_file in self.conv_files:
            cell_name = Path(conv_file).stem
            real_path = os.path.join(self.conv_path, conv_file)
            logging.info("###### READING CONV FILE INTO CELL: " + cell_name + " ######")
            # add new cell
            temp_cell = self.cell_lib.new_cell(cell_name)
            # read conv file
            self.__readConv__(temp_cell, real_path)


        # save GDS file
        self.cell_lib.write_gds("cellLib.gds")

        # display all cells
        gdspy.LayoutViewer()

    def __readConv__(self, _cell, conv_file):
        with open(conv_file) as fp:
            for line in fp:
                line_item = re.findall(r'\w+', line)

                # skip empty line
                if len(line_item) == 0:
                    # advance ptr
                    line = fp.readline()
                    continue

                # skip comments
                if re.search(r"\S", line)[0] == '#':
                    # advance ptr
                    line = fp.readline()
                    continue
                
                if line_item[0] == "COST":
                    num_cpp = int(int(line_item[1])/2)+1
                    cell_width = num_cpp * self.cpp_width
                elif line_item[0] == "TRACK":
                    num_track_v = int(line_item[1])
                    num_track_h = int(line_item[2])
                    if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
                        real_track = num_track_h + 2
                    elif self.bprFlag == BprMode.BPR:
                        real_track = num_track_h + 0.5
                    cell_height = real_track * self.metal_pitch
                    num_fin = num_track_h/2

                    ld_place = {"layer": 10, "datatype": 26}
                    for row in range(num_track_h):
                        inst_rect = gdspy.Rectangle((self.getLx(0, layer=0), self.getLy(row)), \
                            (self.getUx(int(num_track_v/2), layer=0), self.getUy(row)), **ld_place)
                        _cell.add(inst_rect)
                elif line_item[0] == "INST":
                    self.inst_cnt += 1
                    instance = self.Instance(   
                                                idx=int(line_item[1]),
                                                lx=int(line_item[2]),
                                                ly=int(line_item[3]),
                                                num_finger=int(line_item[4]),
                                                isFlip=int(line_item[5]),
                                                totalWidth=int(line_item[6]),
                                                unitWidth=int(line_item[7])
                                            )
                    self.instances.append(instance)
                    
                elif line_item[0] == 'METAL':
                    self.metal_cnt += 1
                    metal = self.Metal(
                                        layer=int(line_item[1]), 
                                        fromRow=int(line_item[2]), 
                                        fromCol=int(line_item[3]), 
                                        toRow=int(line_item[4]), 
                                        toCol=int(line_item[5]), 
                                        netID=int(line_item[6])
                                    )
                    self.metals.append(metal)
                    ld_metal = {"layer": metal.layer, "datatype": 25}
                    metal_rect = gdspy.Rectangle((self.getLx(metal.fromCol, metal.layer), self.getLy(metal.fromRow)), \
                        (self.getUx(metal.toCol, metal.layer), self.getUy(metal.toRow)), **ld_metal)
                    _cell.add(metal_rect)
                
                elif line_item[0] == "VIA":
                    # NOTE: order is incorrect in original formulation
                    self.via_cnt += 1
                    via = self.Via( 
                                    fromMetal=int(line_item[1]), 
                                    toMetal=int(line_item[2]), 
                                    y=int(line_item[3]), 
                                    x=int(line_item[4]), 
                                    netID=int(line_item[5])
                                    )
                    self.vias.append(via)
                    offset_percent = 7000
                    ld_via = {"layer": via.fromMetal, "datatype": 25}
                    lx = self.getLx(via.x,via.fromMetal) + self.metal_width/offset_percent
                    ly = self.getLy(via.y)+ self.metal_width/offset_percent
                    ux = self.getLx(via.x,via.fromMetal) + self.metal_width/1000 - self.metal_width/offset_percent
                    uy = self.getLy(via.y)+ self.metal_width/1000 - self.metal_width/offset_percent
                    via_rect = gdspy.Rectangle((lx, ly), (ux,uy),**ld_via)
                    via_label = gdspy.Label("VIA{}{}".format(str(via.fromMetal), str(via.toMetal)), (lx + (ux - lx)/2, ly + (uy - ly)/2))
                    _cell.add(via_rect)
                    _cell.add(via_label)
                
                elif line_item[0] == "EXTPIN":
                    # why m2 can also have external pins
                    self.extpin_cnt += 1
                    extpin = self.ExtPin(   
                                            layer=int(line_item[1]), 
                                            x=int(line_item[2]), 
                                            y=int(line_item[3]), 
                                            netID=int(line_item[4]), 
                                            pinName=str(line_item[5]), 
                                            isInput=str(line_item[6])
                                        )
                    self.extpins.append(extpin)

                    offset_percent = 7000
                    ld_extpin = {"layer": extpin.layer, "datatype": 25}
                    lx = self.getLx(extpin.x,extpin.layer) + self.metal_width/offset_percent
                    ly = self.getLy(extpin.y)+ self.metal_width/offset_percent
                    ux = self.getLx(extpin.x,extpin.layer) + self.metal_width/1000 - self.metal_width/offset_percent
                    uy = self.getLy(extpin.y)+ self.metal_width/1000 - self.metal_width/offset_percent
                    extpin_rect = gdspy.Rectangle((lx, ly),(ux, uy),**ld_extpin)
                    extpin_label = gdspy.Label(extpin.pinName, (lx + (ux - lx)/2, ly + (uy - ly)/2))
                    _cell.add(extpin_rect)
                    _cell.add(extpin_label)
                
        # cell boundary
        ld_boundary = {"layer": 0, "datatype": 3}
        boundary = gdspy.Rectangle((0, 0), (cell_width / 1000.0, cell_height / 1000.0), **ld_boundary)
        _cell.add(boundary)

        # Power Rail
        rectWidth = 0
        if self.bprFlag == BprMode.METAL1:
            ld_bpr = {"layer": 1 * 2, "datatype": 4}
            rectWidth = self.metal_width
        elif self.bprFlag == BprMode.METAL2:
            ld_bpr = {"layer": 2 * 2, "datatype": 4}
        elif self.bprFlag == BprMode.BPR:
            ld_bpr = {"layer": 0, "datatype": 4}
            rectWidth = self.metal_width

        lx = 0.0
        ly = (cell_height - rectWidth) / 1000.0
        ux = cell_width / 1000.0
        uy = (cell_height + rectWidth) /1000.0
        vdd_rect = gdspy.Rectangle((lx, ly), (ux, uy), **ld_bpr)
        vdd_label = gdspy.Label("VDD", (lx + (ux - lx)/2, ly + (uy - ly)/2), "nw")
        _cell.add(vdd_rect)
        _cell.add(vdd_label)

        lx = 0.0
        ly = (-rectWidth) / 1000.0
        ux = cell_width / 1000.0
        uy = (rectWidth) / 1000.0
        vss_rect = gdspy.Rectangle((lx, ly), (ux, uy), **ld_bpr)
        vss_label = gdspy.Label("VSS", (lx + (ux - lx)/2, ly + (uy - ly)/2), "nw")
        _cell.add(vss_rect)
        _cell.add(vss_label)
    
    def getLx(self, val, layer):
        if layer == 3:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) - self.cpp_width/4)/1000.0
        elif layer == 4:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) - self.metal_width/2)/1000.0 - 0.009
        else:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) - self.metal_width/2)/1000.0

    # BPRMODE with METAL1 / METAL2 should shift coordinates by +metal_pitch/2.0
    def getLy(self, val):
        if self.bprFlag == BprMode.BPR:
            offset = 3*self.metal_pitch/4
        if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
            offset = 3*self.metal_pitch/2
        calVal = (offset \
          + val * self.metal_pitch - self.metal_width/2)/1000.0

        return calVal

    def getUx(self, val, layer):
        if layer == 3:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) + self.cpp_width/4)/1000.0
        elif layer == 4:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) + self.metal_width/2)/1000.0 + 0.009
        else:
            return (self.cpp_width/2 \
              + val * (self.cpp_width/2) + self.metal_width/2)/1000.0

    # BPRMODE with METAL1 / METAL2 should shift coordinates by +metal_pitch/2.0
    def getUy(self, val):
        if self.bprFlag == BprMode.BPR:
            offset = 3*self.metal_pitch/4
        if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
            offset = 3*self.metal_pitch/2
        calVal = (offset \
          + val * self.metal_pitch + self.metal_width/2)/1000.0

        return calVal

    # Entity classes
    class Instance:
        def __init__(self, idx, lx, ly, num_finger, isFlip, totalWidth, unitWidth):
            self.idx = int(idx)
            self.lx = int(lx)
            self.ly = int(ly)
            self.num_finger = int(num_finger)
            self.isFlip = int(isFlip)
            self.totalWidth = int(totalWidth)
            self.unitWidth = int(unitWidth)

    class Metal:
        def __init__(self, layer, fromRow, fromCol, toRow, toCol, netID):
            self.layer = int(layer)
            self.fromRow = int(fromRow)
            self.fromCol = int(fromCol)
            self.toRow = int(toRow)
            self.toCol = int(toCol)
            if (netID != ''):
                self.netID = int(netID)
            else:
                self.netID = -1

    class Via:
        def __init__(self, fromMetal, toMetal, x, y, netID):
            self.fromMetal = int(fromMetal)
            self.toMetal = int(toMetal)
            self.x = int(x)
            self.y = int(y)
            self.netID = int(netID)

    class ExtPin:
        def __init__(self, layer, x, y, netID, pinName, isInput):
            self.layer = int(layer)
            self.x = int(x)
            self.y = int(y)
            self.netID = int(netID)
            self.pinName = pinName
            self.isInput = True if isInput.startswith("I") == True else False


def main():
    args = sys.argv[1:]

    # if len(args) < 3:
    #     print("args no match!")
    #     exit(0)
    
    CONV_PATH = args[0]
    gdscelllib = GDSCellLibrary(CONV_PATH, 24, 42, BprMode.BPR)
    

if __name__ == '__main__':
    main()
    