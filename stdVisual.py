from cProfile import label
import os, sys
import re
import math
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from itertools import cycle

###Example:######################################################################################################
#                                                                                                               #
#       python3 stdVisual.py ./CFET/PNR_4.5T_Extend/solutionsSMT_cfet/INVx2_ASAP7_75t_R_6T_0_C_5_29_27_0.conv   #
#                                                                                                               #
################################################################################################################# 

class StdVisual:
    def __init__(self, convFile) -> None:
        # input file
        self.convFile = convFile
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

        # Assume dimension
        self.width = 100
        self.height = 100
        self.MP = 10
        self.metalWidth = 4
        self.x_offset = 2
        self.y_offset = 2

        # read conv file
        self.__readConv()

    def __readConv(self) -> None:
        with open(self.convFile) as fp:
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

                if line_item[0] == "INST":
                    self.inst_cnt += 1
                    instance = self.Instance(   
                                                idx=int(line_item[1]),
                                                lx=int(line_item[2]),
                                                ly=int(line_item[3]),
                                                numFinger=int(line_item[4]),
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
                
                elif line_item[0] == "VIA":
                    self.via_cnt += 1
                    via = self.Via( 
                                    fromMetal=int(line_item[1]), 
                                    toMetal=int(line_item[2]), 
                                    x=int(line_item[3]), 
                                    y=int(line_item[4]), 
                                    netID=int(line_item[5])
                                    )

                    self.vias.append(via)
                
                elif line_item[0] == "EXTPIN":
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

    def display_std(self) -> None:
        #define Matplotlib figure and axis
        fig, ax = plt.subplots(figsize=(8,8), dpi=50)

        # Plt config
        ax.margins(x=0.05, y=0.05)
        ax.set_aspect('equal', adjustable='box')

        # Construct grid
        x, y = np.meshgrid(np.linspace(0, self.width, self.MP + 1),\
             np.linspace(0, self.height, self.MP + 1))
        
        ax.plot(x, y, c='b', alpha=0.1) # use plot, not scatter
        ax.plot(np.transpose(x), np.transpose(y), c='b', alpha=0.2) # add this here

        # color bank
        cycol = cycle('bgrcmk')

        # metal layer color map
        layer_colors = {}
        handles = []
        
        # construct metal block
        for metal_idx, metal in enumerate(self.metals):
            if metal.layer in layer_colors:
                layer_color = layer_colors[metal.layer]

                seen = True
            else:
                layer_color = next(cycol)
                layer_colors[metal.layer] = layer_color

                seen = False
            
            if metal.layer % 2 == 0:
                # even => horizontal
               ax.add_patch(Rectangle((self.x_offset * 10 + metal.fromCol * 10 - math.floor(self.metalWidth / 2),
                                        self.y_offset * 10 + metal.fromRow * 10 - math.floor(self.metalWidth / 2)),
                                        10 * (metal.toCol - metal.fromCol) + self.metalWidth, 
                                        self.metalWidth,
                                        alpha=0.2, zorder=1000, facecolor=layer_color, edgecolor='darkblue', label="M"+str(metal.layer) if not seen else ""))
            else:
                # odd => vertical
                ax.add_patch(Rectangle((self.x_offset * 10 + metal.fromCol * 10 - math.floor(self.metalWidth / 2), 
                                        self.y_offset * 10 + metal.fromRow * 10 - math.floor(self.metalWidth / 2)),
                                        self.metalWidth,
                                        10 * (metal.toRow - metal.fromRow) + self.metalWidth,
                                        alpha=0.2, zorder=1000, facecolor=layer_color, edgecolor='darkblue', label="M"+str(metal.layer) if not seen else ""))
        # construct via block
        for via_idx, via in enumerate(self.vias):
            ax.add_patch(Rectangle((self.x_offset * 10 + via.x * 10 - math.floor(self.metalWidth / 2),
                                    self.y_offset * 10 + via.y * 10 - math.floor(self.metalWidth / 2)),
                                    self.metalWidth, 
                                    self.metalWidth,
                                    linewidth=3, alpha=0.5, zorder=1000, facecolor="none", edgecolor='red'))
        
        # construct via block
        for extpin_idx, extpin in enumerate(self.extpins):
            ax.add_patch(Rectangle((self.x_offset * 10 + extpin.x * 10 - math.floor(self.metalWidth / 2),
                                    self.y_offset * 10 + extpin.y * 10 - math.floor(self.metalWidth / 2)),
                                    self.metalWidth, 
                                    self.metalWidth,
                                    linewidth=3, alpha=0.5, zorder=1000, facecolor="none", edgecolor='blue'))


        ax.legend(loc=2, prop={'size': 20})
        plt.show()
        plt.close('all')

    class Layer:
        def __init__(self) -> None:
            self.nets = []
            self.metals = []
            self.vias = []
            self.extpins = []

    class Metal:
        def __init__(self, layer, fromRow, fromCol, toRow, toCol, netID) -> None:
            self.layer = layer
            self.fromRow = fromRow
            self.fromCol = fromCol
            self.toRow = toRow
            self.toCol = toCol
            self.netID = netID

    class Via:
        def __init__(self, fromMetal, toMetal, x, y, netID) -> None:
            self.fromMetal = fromMetal
            self.toMetal = toMetal
            self.x = x
            self.y = y
            self.netID = netID

    class ExtPin:
        def __init__(self, layer, x, y, netID, pinName, isInput) -> None:
            self.layer = layer
            self.x = x
            self.y = y
            self.netID = netID,
            self.pinName = pinName
            self.isInput = isInput

    class Instance:
        def __init__(self, idx, lx, ly, numFinger, isFlip, totalWidth, unitWidth) -> None:
            self.idx = idx
            self.lx = lx
            self.ly = ly
            self.numFinger = numFinger
            self.isFilp = isFlip
            self.totalWidth = totalWidth
            self.unitWidth = unitWidth

def main():
    args = sys.argv[1:]

    if len(args) != 1:
        print("args no match!")
        exit(0)
    
    CONV_FILE = args[0]
    print("********************* Reading .conv File ", CONV_FILE)
    std_vis = StdVisual(CONV_FILE)

    std_vis.display_std()

if __name__ == '__main__':
    main()
    