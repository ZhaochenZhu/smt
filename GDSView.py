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
#   python3 stdVisual.py ./CFET/PNR_4.5T_Extend/solutionsSMT_cfet/INVx2_ASAP7_75t_R_6T_0_C_5_29_27_0.conv 6 6   #
#                                                                                                               #
#################################################################################################################

class GDSCellLibrary:
    def __init__(self, conv_path, metal_pitch, cpp_width) -> None:
        # read argument
        self.conv_path = conv_path
        self.metal_pitch = metal_pitch
        self.cpp_width = cpp_width

        ########################
        self.numCpp = int(numCpp) # subject to cell
        self.numTrack = int(numTrack) # subject to cell
        self.metalPitch = int(metalPitch)
        self.cppWidth = int(cppWidth)
        self.siteName = siteName
        self.maxCellWidth = 0
        self.realTrack = 0

        self.bprFlag = bprFlag 
        self.mpoFlag = mpoFlag 
        ########################

        # extract .conv files
        self.conv_files = [file for file in listdir(self.conv_path) if isfile(join(self.conv_path, file))]

        # initialize cell library
        self.cell_lib = gdspy.GdsLibrary()
        
        # load cells into library
        for conv_file in self.conv_files:
            cell_name = Path(conv_file).stem

            logging.info("###### READING CONV FILE INTO CELL: " + cell_name + " ######")
            # add new cell
            temp_cell = self.cell_lib.new_cell(cell_name)
            # cell boundary
            boundary = gdspy.Rectangle((0, 0), (self.cellWidth / 1000.0, self.cellHeight / 1000.0))
            temp_cell.add(boundary)

        # save GDS file
        self.cell_lib.write_gds("cellLib.gds")

        # display all cells
        gdspy.LayoutViewer()

    def __testConv__(self, _cell, conv_file, num):
        for curLine in conv.split("\n"):
            
            words = curLine.split(" ")
            #print (words)
            if words[0] == "TRACK":
                #techInfo.numCpp = int(words[1])/2 + 1
                techInfo.numTrack = int(words[2])
            elif words[0] == "COST":
                techInfo.numCpp = int(int(words[1])/2)+1
                numCPP = int(int(words[1])/2)+1
            elif words[0] == "INST":
                # adding Instance
                insts.append(\
                        Instance(
                            idx=words[1], 
                            lx=words[2], 
                            ly=words[3],
                            numFinger=words[4], 
                            isFlip=words[5], 
                            totalWidth=words[6], 
                            unitWidth=words[7]
                        )
                    )
            elif words[0] == "METAL":
                metals.append( 
                            Metal(
                                layer=words[1], 
                                fromRow=words[2], 
                                fromCol=words[3],
                                toRow=words[4],
                                toCol=words[5],
                                netID=words[6])
                            )
            elif words[0] == "VIA":
                vias.append( Via(
                                fromMetal=words[1], 
                                toMetal=words[2], 
                                x=words[3],
                                y=words[4], 
                                netID=words[5])
                                )
            elif words[0] == "EXTPIN":
                extpins.append( ExtPin(words[2], words[3], words[4], words[1], words[5], words[6]) )
    
    def getLx(self, val, layer):
        if layer == 3:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) - self.cppWidth/4)/1000.0
        elif layer == 4:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) - self.metalWidth/2)/1000.0 - 0.009
        else:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) - self.metalWidth/2)/1000.0

    # BPRMODE with METAL1 / METAL2 should shift coordinates by +metalPitch/2.0
    def getLy(self, val):
        if self.bprFlag == self.BprMode.BPR:
            offset = 3*self.metalPitch/4
        if self.bprFlag == self.BprMode.METAL1 or self.bprFlag == self.BprMode.METAL2:
            offset = 3*self.metalPitch/2
        calVal = (offset \
          + val * self.metalPitch - self.metalWidth/2)/1000.0

        return calVal

    def getUx(self, val, layer):
        if layer == 3:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) + self.cppWidth/4)/1000.0
        elif layer == 4:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) + self.metalWidth/2)/1000.0 + 0.009
        else:
            return (self.cppWidth/2 \
              + val * (self.cppWidth/2) + self.metalWidth/2)/1000.0

    # BPRMODE with METAL1 / METAL2 should shift coordinates by +metalPitch/2.0
    def getUy(self, val):
        if self.bprFlag == self.BprMode.BPR:
            offset = 3*self.metalPitch/4
        if self.bprFlag == sellf.BprMode.METAL1 or self.bprFlag == self.BprMode.METAL2:
            offset = 3*self.metalPitch/2
        calVal = (offset \
          + val * self.metalPitch + self.metalWidth/2)/1000.0

        return calVal

    # Entity classes
    class Instance:
        def __init__(self, idx, lx, ly, numFinger, isFlip, totalWidth, unitWidth):
            self.idx = int(idx)
            self.lx = int(lx)
            self.ly = int(ly)
            self.numFinger = int(numFinger)
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


def main():
    args = sys.argv[1:]

    if len(args) < 3:
        print("args no match!")
        exit(0)
    
    CONV_PATH = args[0]
    gdscelllib = GDSCellLibrary(CONV_PATH, 84, 48)

if __name__ == '__main__':
    main()
    