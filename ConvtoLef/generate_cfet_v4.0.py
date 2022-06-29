import os
import sys
import os.path

from enum import Enum

Cell_metrics_map = {}

class Instance:
  def __init__(self, idx, lx, ly, numFinger, isFlip, totalWidth, unitWidth):
    self.idx = int(idx)
    self.lx = int(lx)
    self.ly = int(ly)
    self.numFinger = int(numFinger)
    self.isFlip = int(isFlip)
    self.totalWidth = int(totalWidth)
    self.unitWidth = int(unitWidth)

  def dump(self):
    print("Instance idx: %d, (%d, %d), finger: %d, isfilp: %d, totalWidth: %d, unitWidth: %d" \
        % (self.idx, self.lx, self.ly, self.numFinger, self.isFlip, self.totalWidth, self.unitWidth))


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

  def dump(self):
    print("Metal layer: %s, (%d, %d) - (%d, %d), netID: %d" % \
        (self.getLayerName(), self.fromRow, self.fromCol, \
        self.toRow, self.toCol, self.netID))

  def getLayerName(self):
    if self.layer == 1:
      return "Poly Layer"
    elif self.layer == 2:
      return "0"
    elif self.layer == 3:
      return "1"
    elif self.layer == 4:
      return "2"

  def getLefStr(self, techInfo):
    retStr = ""
    retStr += "        RECT %.3f %.3f %.3f %.3f ;\n" \
        % (techInfo.getLx(self.fromCol, self.layer), techInfo.getLy(self.fromRow), \
        techInfo.getUx(self.toCol, self.layer), techInfo.getUy(self.toRow))
    return retStr

class Via:
  def __init__(self, fromMetal, toMetal, x, y, netID):
    self.fromMetal = int(fromMetal)
    self.toMetal = int(toMetal)
    self.x = int(x)
    self.y = int(y)
    self.netID = int(netID)

  def dump(self):
    print("Via layer (%d -> %d), (%d, %d), netID: %d" \
        % (self.fromMetal, self.toMetal, self.x, self.y, self.netID))
  
  def getLefStr(self, techInfo):
    retStr = ""
    retStr += "        RECT %.3f %.3f %.3f %.3f ;\n" \
        % (techInfo.getLx(self.y, 0), techInfo.getLy(self.x), \
        techInfo.getUx(self.y, 0), techInfo.getUy(self.x))
    return retStr

class ExtPin:
  def __init__(self, layer, x, y, netID, pinName, isInput):
    self.layer = int(layer)
    self.x = int(x)
    self.y = int(y)
    self.netID = int(netID)
    self.pinName = pinName
    self.isInput = True if isInput.startswith("I") == True else False
    
  def dump(self):
    print("ExtPin layer: %d, (%d, %d) - ID: %d: %s, isInput: %d" % (self.layer, self.x, self.y, self.netID, self.pinName, self.isInput))


class BprMode(Enum):
    NONE = 0
    METAL1 = 1
    METAL2 = 2
    BPR = 3

class MpoMode(Enum):
    NONE = 0
    TWO = 1
    THREE = 2
    MAX = 3

class TechInfo:
  def __init__(self, numCpp, numTrack, metalPitch, cppWidth, siteName, bprFlag, mpoFlag):
    self.numCpp = int(numCpp)
    self.numTrack = int(numTrack)
    self.metalPitch = int(metalPitch)
    self.cppWidth = int(cppWidth)
    self.siteName = siteName
    self.maxCellWidth = 0
    self.realTrack = 0
    
    self.bprFlag = bprFlag 
    self.mpoFlag = mpoFlag 

    self.update(False)

  def update(self, isMaxCellWidthUpdate):
    self.metalWidth = int(self.metalPitch/2)
    if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
      self.realTrack = self.numTrack + 2
    elif self.bprFlag == BprMode.BPR:
      self.realTrack = self.numTrack + 0.5

    self.cellWidth = self.numCpp * self.cppWidth
    self.cellHeight = (self.realTrack) * self.metalPitch
    self.numFin = self.numTrack/2

    # only updates maxCellWidth when isMaxCellWidthUpdate is true
    if isMaxCellWidthUpdate:
      self.maxCellWidth = max(self.maxCellWidth, self.cellWidth)

  def dump(self):
    print("numTrack: %d, realTrack: %d, metalPitch: %d nm, cppWidth: %d nm, siteName: %s" %(self.numTrack, self.realTrack, self.metalPitch, self.cppWidth, self.siteName))

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
    if self.bprFlag == BprMode.BPR:
        offset = 3*self.metalPitch/4
    if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
        offset = 3*self.metalPitch/2
    calVal = (offset \
      + val * self.metalPitch - self.metalWidth/2)/1000.0

    #if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
    #  calVal += (self.metalPitch/2.0)/1000.0

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
    if self.bprFlag == BprMode.BPR:
        offset = 3*self.metalPitch/4
    if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
        offset = 3*self.metalPitch/2
    calVal = (offset \
      + val * self.metalPitch + self.metalWidth/2)/1000.0
    
    #if self.bprFlag == BprMode.METAL1 or self.bprFlag == BprMode.METAL2:
    #  calVal += (self.metalPitch/2.0)/1000.0

    return calVal

  def getMpoStr(self):
    mpoStr = ""
    if self.mpoFlag == MpoMode.TWO:
      mpoStr = "2MPO"
    elif self.mpoFlag == MpoMode.THREE:
      mpoStr = "3MPO"
    elif self.mpoFlag == MpoMode.MAX:
      mpoStr = "MAXMPO"
    return mpoStr

  def getBprStr(self):
    bprStr = ""
    if self.bprFlag == BprMode.METAL1:
      bprStr = "M1"
    elif self.bprFlag == BprMode.METAL2:
      bprStr = "M2"
    elif self.bprFlag == BprMode.BPR:
      bprStr = "BPR"
    return bprStr

  # TODO
  def getDesignRuleStr(self):
    return "EL"

  def getCellName(self, origName):
     return "_".join(origName.split("_")[:4])
     #return "_".join(origName.split("_")[:2]) \
     #   + "_" + self.getLibraryName()

  def getLibraryName(self):
    return "%dT_%dF_%dCPP_%dMP_%s_%s_%s" \
        % (self.realTrack, self.numFin, self.cppWidth, self.metalPitch, \
        self.getMpoStr(), self.getDesignRuleStr(), self.getBprStr()) 


class PinInfo:
  def __init__(self, name, netID, via0s, metal1s, via1s, metal2s, isInput, PinMpoCnt):
    self.name = name
    self.netID = int(netID)
    self.via0s = via0s
    self.metal1s = metal1s
    self.via1s = via1s
    self.metal2s = metal2s
    self.isInput = isInput
    self.PinMpoCnt = PinMpoCnt

  def dump(self):
    print("PinInfo: [%d]: %s" % (self.netID, self.name))
    for via0 in self.via0s:
      via0.dump()
    for metal1 in self.metal1s:
      metal1.dump()
    for via1 in self.via1s:
      via1.dump()
    for metal2 in self.metal2s:
      metal2.dump()
    print("")

  def getLefStr(self, techInfo):
    retStr = ""
    retStr += "  PIN %s\n" % (self.name)
    retStr += "    DIRECTION %s ;\n" % ("INPUT" if self.isInput else "OUTPUT")
    retStr += "    USE SIGNAL ;\n"
    retStr += "    PORT\n"
    
    #retStr += "      LAYER V0\n" if len(self.via0s) >= 1 else ""
    #for via0 in self.via0s:
    #  retStr += via0.getLefStr(techInfo)
    retStr += "      LAYER V1 ;\n" if len(self.via1s) >= 1 else ""
    for via1 in self.via1s:
      retStr += via1.getLefStr(techInfo)
    retStr += "      LAYER M1 ;\n" if len(self.metal1s) >= 1 else ""
    for m1 in self.metal1s:
      retStr += m1.getLefStr(techInfo)
    retStr += "      LAYER M2 ;\n" if len(self.metal2s) >= 1 else ""
    for m2 in self.metal2s:
      retStr += m2.getLefStr(techInfo)
    retStr += "    END\n"
    retStr += "  END %s\n" % (self.name)
    return retStr

class ObsInfo:
  def __init__(self, via0s, metal1s, via1s, metal2s):
    self.via0s = via0s
    self.metal1s = metal1s
    self.via1s = via1s
    self.metal2s = metal2s

  def dump(self):
    print("ObsInfo:")
    for via0 in self.via0s:
      via0.dump()
    for metal1 in self.metal1s:
      metal1.dump()
    for via1 in self.via1s:
      via1.dump()
    for metal2 in self.metal2s:
      metal2.dump()
    print("")

  def getLefStr(self, techInfo):
    if len(self.via1s) + len(self.metal1s) + len(self.metal2s) == 0:
      return ""
    
    retStr = ""
    retStr += "  OBS\n"
    retStr += "      LAYER V1 ;\n" if len(self.via1s) >= 1 else ""
    for via1 in self.via1s:
      retStr += via1.getLefStr(techInfo)
    retStr += "      LAYER M1 ;\n" if len(self.metal1s) >= 1 else ""
    for m1 in self.metal1s:
      retStr += m1.getLefStr(techInfo)
    retStr += "      LAYER M2 ;\n" if len(self.metal2s) >= 1 else ""
    for m2 in self.metal2s:
      retStr += m2.getLefStr(techInfo)
    retStr += "  END\n"
    return retStr



def GetVddVssPinLefStr(techInfo):
  if techInfo.bprFlag == BprMode.NONE:
    return "" 
  
  lefStr = ""

  vddPrefix = ""
  vddPrefix += "  PIN VDD\n"
  vddPrefix += "    DIRECTION INOUT ;\n"
  vddPrefix += "    USE POWER ;\n"
  vddPrefix += "    SHAPE ABUTMENT ;\n"
  vddPrefix += "    PORT\n"

  vssPrefix = ""
  vssPrefix += "  PIN VSS\n"
  vssPrefix += "    DIRECTION INOUT ;\n"
  vssPrefix += "    USE GROUND ;\n"
  vssPrefix += "    SHAPE ABUTMENT ;\n"
  vssPrefix += "    PORT\n"

  # Different Metal Width with given BPR mode.
  rectWidth = 0
  if techInfo.bprFlag == BprMode.METAL1 or techInfo.bprFlag == BprMode.METAL2:
    rectWidth = techInfo.metalWidth
  elif techInfo.bprFlag == BprMode.BPR:
    #rectWidth = techInfo.metalWidth/2.0
    rectWidth = techInfo.metalWidth

  vddRectStr = "        RECT %.3f %.3f %.3f %.3f ;\n" \
      % (0.0, (techInfo.cellHeight - rectWidth) / 1000.0, \
      techInfo.cellWidth / 1000.0, \
      (techInfo.cellHeight + rectWidth) /1000.0)

  vssRectStr = "        RECT %.3f %.3f %.3f %.3f ;\n"\
      % (0.0, (-rectWidth) / 1000.0,\
      techInfo.cellWidth / 1000.0, 
      (rectWidth) / 1000.0)

  # METAL1 and BPR have M1
  if techInfo.bprFlag == BprMode.METAL1 or techInfo.bprFlag == BprMode.BPR:
    lefStr += vddPrefix
    lefStr += "      LAYER M0 ;\n"
    lefStr += vddRectStr
    lefStr += "    END\n"
    lefStr += "  END VDD\n"
    lefStr += vssPrefix
    lefStr += "      LAYER M0 ;\n"
    lefStr += vssRectStr
    lefStr += "    END\n"
    lefStr += "  END VSS\n"
  # METAL2 have M2
  elif techInfo.bprFlag == BprMode.METAL2:
    lefStr += vddPrefix
    lefStr += "      LAYER M1 ;\n"
    lefStr += vddRectStr
    lefStr += "      LAYER M2 ;\n"
    lefStr += vddRectStr
    lefStr += "    END\n"
    lefStr += "  END VDD\n"
    lefStr += vssPrefix
    lefStr += "      LAYER M1 ;\n"
    lefStr += vssRectStr
    lefStr += "      LAYER M2 ;\n"
    lefStr += vssRectStr
    lefStr += "    END\n"
    lefStr += "  END VSS\n"
  return lefStr


def GenerateLef(inputFileList, outputDir, techInfo):
  ########## Original LEF gen
  lefStr = "VERSION 5.8 ;\n"
  lefStr += 'BUSBITCHARS "[]" ;\n'
  lefStr += 'DIVIDERCHAR "/" ;\n'
  lefStr += "CLEARANCEMEASURE EUCLIDEAN ;\n\n"

  for curFile in fileList:
    if curFile.endswith(".conv") is False:
      continue
    f = open(inputDir + curFile, "r")
    cont = f.read()
    f.close()

    lefStr += GetMacroLefStr(cont, curFile[:-5], outputDir, techInfo, False)
  
  lefStr += "SITE "+techInfo.siteName+"\n"
  lefStr += "\tCLASS CORE ;\n"
  lefStr += "\tSYMMETRY X Y R90 ;\n"
  lefStr += "\tSIZE "+str(int(techInfo.cppWidth)/1000.0)+" BY "+str(int(techInfo.cellHeight)/1000.0)+" ;\n"
  lefStr += "END "+techInfo.siteName+"\n\n"

  lefStr += "END LIBRARY\n"
    
  f = open(outputDir + "/" + techInfo.getLibraryName() + ".lef", "w")
  f.write(lefStr)
  f.close()
  
  ########## Padded LEF gen
  lefStr = "VERSION 5.8 ;\n"
  lefStr += 'BUSBITCHARS "[]" ;\n'
  lefStr += 'DIVIDERCHAR "/" ;\n'
  lefStr += "CLEARANCEMEASURE EUCLIDEAN ;\n\n"

  for curFile in fileList:
    if curFile.endswith(".conv") is False:
      continue
    f = open(inputDir + curFile, "r")
    cont = f.read()
    f.close()

    lefStr += GetMacroLefStr(cont, curFile[:-5], outputDir, techInfo, True)

  lefStr += "SITE "+techInfo.siteName+"\n"
  lefStr += "CLASS CORE ;\n"
  lefStr += "SYMMETRY X Y R90 ;\n"
  lefStr += "SIZE "+str(int(techInfo.cppWidth)/1000.0)+" BY "+str(int(techInfo.cellHeight)/1000.0)+" ;\n"
  lefStr += "END "+techInfo.siteName+"\n"
  
  lefStr += "END LIBRARY\n"
    
  f = open(outputDir + "/" + techInfo.getLibraryName() + ".bloat.lef", "w")
  f.write(lefStr)
  f.close()

def GetMacroLefStr(conv, cellName, outputDir, techInfo, isUseMaxCellWidth): 
  global Cell_metrics_map;
  gridWidth = ""
  insts = []
  metals = []
  vias = []
  extpins = []
  Pin_filename = outputDir+"/RPACnt_v2.txt"
  if os.path.isfile(Pin_filename):
    print ("%s File exist"%Pin_filename)
    f = open(Pin_filename, "a")
  else:
    print ("%s File not exist"%Pin_filename)
    f = open(Pin_filename, "w")
  f.write("%s\t"%cellName)
  print ("%s: "%cellName)
  for curLine in conv.split("\n"):
    #print (curLine)
    words = curLine.split(" ")
    #print (words)
    if words[0] == "TRACK":
      #techInfo.numCpp = int(words[1])/2 + 1
      techInfo.numTrack = int(words[2])
    elif words[0] == "COST":
      techInfo.numCpp = int(int(words[1])/2)+1
      numCPP = int(int(words[1])/2)+1
    elif words[0] == "INST":
      insts.append( Instance(words[1], words[2], words[3], \
          words[4], words[5], words[6], words[7]))
    elif words[0] == "METAL":
      metals.append( Metal(words[1], words[2], words[3], \
          words[4], words[5], words[6]) )
    elif words[0] == "VIA":
      vias.append( Via(words[1], words[2], words[3], words[4], words[5]) )
    elif words[0] == "EXTPIN":
      extpins.append( ExtPin(words[2], words[3], words[4], words[1], words[5], words[6]) )

  # Prevent maxCellWidth if
  # cellName has "DFFHQ"
  isMaxCellWidthUpdate = (not ("DFFHQ" in cellName))
  techInfo.update( isMaxCellWidthUpdate )

  techInfo.dump()

  for metal in metals:
    metal.dump()

  for via in vias:
    via.dump()

  for extpin in extpins:
    extpin.dump()
  
  pinInfos = []
  pinNetId = set()
  ExtPOCnt_Map = {}
  Avg_PinMpoCnt = 0
  Min_PinMpoCnt = 100
  Max_PinMpoCnt = 0
  Avg_PinSpace = 0
  Min_PinSpace = 100
  Max_PinSpace = 0
  Avg_PinCost = 0
  Min_PinCost = 100
  Max_PinCost = 0
  Num_Pins = 0
  Num_PinSpace = 0
  for extpin in extpins:
    pinNetId.add(extpin.netID)
    via0Arr = [ via for via in vias if via.netID == extpin.netID and via.fromMetal == 2 ]
    metal1Arr = [ metal for metal in metals if metal.netID == extpin.netID and metal.layer == 3 ]
    via1Arr = [ via for via in vias if via.netID == extpin.netID and via.fromMetal == 3 ]
    metal2Arr = [ metal for metal in metals if metal.netID == extpin.netID and metal.layer == 4 ]

    (M1_PinMpoCnt, M2_PinMpoCnt) = MpoCnt(extpin, extpins, metal1Arr, metal2Arr, metals)
    PinMpoCnt = M1_PinMpoCnt + M2_PinMpoCnt
    ExtPOCnt_Map[extpin.netID] = PinMpoCnt
    pinInfos.append(PinInfo(extpin.pinName, extpin.netID, \
        via0Arr, metal1Arr, via1Arr, metal2Arr, extpin.isInput, PinMpoCnt))
    #f.write("%s\t%d\t%d\t"%(extpin.pinName, M1_PinMpoCnt, M2_PinMpoCnt))
    if PinMpoCnt < Min_PinMpoCnt:
       Min_PinMpoCnt = PinMpoCnt
    if PinMpoCnt > Max_PinMpoCnt:
       Max_PinMpoCnt = PinMpoCnt
    
    Avg_PinMpoCnt = Avg_PinMpoCnt + PinMpoCnt
    Num_Pins = Num_Pins + 1
    #Pin_space = PinSpaceCnt(extpin, extpins, metal1Arr, metal2Arr, metals)
    Pin_space = PinSpaceCnt_ADJ(extpin, extpins, metal1Arr, metal2Arr, metals)
    if Pin_space != -1: 
       #f.write("%s\t%d\t"%(extpin.pinName, Pin_space))
       if Pin_space < Min_PinSpace:
          Min_PinSpace = Pin_space
       if Pin_space > Max_PinSpace:
          Max_PinSpace = Pin_space

       Avg_PinSpace = Avg_PinSpace + Pin_space
       Num_PinSpace = Num_PinSpace + 1
    # PS3 obj
    Pin_cost = EdgeBasedPinCnt_ADJ(extpin, extpins, metal1Arr, metal2Arr, metals)
    if Pin_cost < -1:
       print ("Error: Minimum Pin cost is 0!\n")
       print ("Error Info: Cell %s, Pin: %s\n"%(cellName, extpin.pinName))
    if Pin_cost < Min_PinCost:
       Min_PinCost = Pin_cost
    if Pin_cost > Max_PinCost:
       Max_PinCost = Pin_cost
    Avg_PinCost = Avg_PinCost + Pin_cost
    #print ("Cell: %s Pin: %s Net ID: %s EdgePinCost: %f ColPinSpace: %f\n"%(cellName, extpin.pinName, extpin.netID, Pin_cost, Pin_space))    

  Avg_PinMpoCnt = float(Avg_PinMpoCnt)/float(Num_Pins);
  #if Num_PinSpace != 0:
  #   Avg_PinSpace = float(Avg_PinSpace)/float(Num_PinSpace);
  #   Avg_PinCost = float(Avg_PinCost)/float(Num_PinSpace);
  #else:
  #   Avg_PinSpace = -1
  #   Avg_PinCost = -1
  f.write("\tAverage_MPO\t%f\tMax_MPO\t%f\tMin_MPO\t%f\tPS1 M1_PinSpace\t%f\tPS1 Max_PinSpace\t%f\tPS1 Min_PinSpace\t%f\tPS3 M1_PinCost\t%f\tPS 3 Max_PinCost\t%f\tPS 3 Min_PinCost\t%f\t"\
  %(Avg_PinMpoCnt, Max_PinMpoCnt, Min_PinMpoCnt, Avg_PinSpace, Max_PinSpace, Min_PinSpace, Avg_PinCost, Max_PinCost, Min_PinCost))
  # RPA calculation
  Avg_RPA = 0  
  Min_RPA = 100.0
  RPA_Map = {}
  for extpin in extpins:
    via0Arr = [ via for via in vias if via.netID == extpin.netID and via.fromMetal == 2 ]
    metal1Arr = [ metal for metal in metals if metal.netID == extpin.netID and metal.layer == 3 ]
    via1Arr = [ via for via in vias if via.netID == extpin.netID and via.fromMetal == 3 ]
    metal2Arr = [ metal for metal in metals if metal.netID == extpin.netID and metal.layer == 4 ]
    RPA_Map[extpin.pinName] = RPACal(extpin, extpins, metal1Arr, metal2Arr, metals, ExtPOCnt_Map)
    print("Cell %s, Pin Name: %s, RPA: %f\n"%(cellName, extpin.pinName, RPA_Map[extpin.pinName]))
    Avg_RPA = Avg_RPA + RPA_Map[extpin.pinName]
    if RPA_Map[extpin.pinName] < Min_RPA:
       Min_RPA = RPA_Map[extpin.pinName]
       print("Cell %s, Pin Name: %s, Min RPA: %f\n"%(cellName, extpin.pinName, Min_RPA))
  Avg_RPA = Avg_RPA/len(extpins)  
  #f.write("%s\t%f\t"%(extpin.pinName, RPA_Map[extpin.pinName]))
  PS_Obj = PSObjCal(extpins, numCPP)
  f.write("%s\t%f\t%s\t%f\t%s\t%f\n"%("Avg RPA", Avg_RPA, "Min RPA", Min_RPA, "PS Obj: ", PS_Obj))
  f.close()
  M1Track_file = outputDir+"M1_PG_TrackCnt.txt"
  f = open(M1Track_file, "a")
  M1Track_PGUsed = CalM1TrackPG(metals)
  f.write("%s\t%f\n"%(cellName, M1Track_PGUsed))
  f.close()
  M2Resource_file = outputDir+"M2_ResourceCnt.txt"
  f = open(M2Resource_file, "a")
  (M2Track_use, M2Resource_Used) = CalM2Resource(metals)
  f.write("%s\t%f\n"%(cellName, M2Resource_Used))
  f.close()
  
  for pinInfo in pinInfos:
    pinInfo.dump()
  #print( pinNetId )
  # Store to global cell metric map
  cell_metric = [Avg_PinMpoCnt, Max_PinMpoCnt, Min_PinMpoCnt, Avg_PinSpace, Avg_PinCost, Avg_RPA, Min_RPA, PS_Obj, M2Track_use, M2Resource_Used]
  key = cellName.split("_")[0]
  if key not in Cell_metrics_map.keys():
     Cell_metrics_map[key] = cell_metric  
  # OBS handling
  via0Obs = [ via for via in vias if via.netID not in pinNetId and via.fromMetal == 2 ] 
  metal1Obs = [ metal for metal in metals if metal.netID not in pinNetId and metal.layer == 3 ]
  via1Obs = [ via for via in vias if via.netID not in pinNetId and via.fromMetal == 3 ]
  metal2Obs = [ metal for metal in metals if metal.netID not in pinNetId and metal.layer == 4 ]
  obsInfo = ObsInfo(via0Obs, metal1Obs, via1Obs, metal2Obs)

  #if len(metal1Obs) + len(via1Obs) + len(metal2Obs) > 0:
  #  print(" there is obs" )
  #  exit()

  cellName = techInfo.getCellName(cellName)

  cellWidth = techInfo.maxCellWidth if isUseMaxCellWidth and isMaxCellWidthUpdate else \
      techInfo.cellWidth
  
  print("CellName: ", cellName, "cellWidth: ", cellWidth)

  lefStr = ""
  lefStr += "MACRO %s\n" % (cellName)
  lefStr += "  CLASS CORE ;\n"
  lefStr += "  ORIGIN 0 0 ;\n"
  lefStr += "  FOREIGN %s 0 0 ;\n" %(cellName)
  lefStr += "  SIZE %.3f BY %.3f ;\n" \
      % (cellWidth / 1000.0, \
      techInfo.cellHeight / 1000.0)
  lefStr += "  SYMMETRY X Y ;\n" 
  lefStr += "  SITE %s ;\n" %(techInfo.siteName)

  for pinInfo in pinInfos:
    lefStr += pinInfo.getLefStr(techInfo)
  lefStr += GetVddVssPinLefStr(techInfo)
  lefStr += obsInfo.getLefStr(techInfo)
  lefStr += "END %s\n\n" % (cellName)  

  return lefStr

def GetMpoFlag(inpStr):
  if inpStr == "2":
    return MpoMode.TWO
  elif inpStr == "3":
    return MpoMode.THREE
  elif inpStr == "MAX":
    return MpoMode.MAX
  return MpoMode.NONE

def MpoCnt(extpin, extpins, metal1Arr, metal2Arr, metals):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  M2_PinMpoCnt = 0
  # Design Rule Definition exp11 EOL=2 (MAR=2 EOL=1)
  MAR = 2
  EOL = 0
  # M2 EOL and MAR
  M2_MAR = 2
  M2_EOL = 0
  # Check Metal1 first
  for metal_pin in metal1Arr:
    for pin_row in range (metal_pin.fromRow, metal_pin.toRow+1):
       M1_blocked_pinrow = 0
       M2_blocked_pinrow = 0
       M2_left_bound = 0
       M2_right_bound = 1000
       for metal in metals:
         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
         #if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= 2:
         #   if pin_row >= metal.fromRow and pin_row <= metal.toRow and (IsExtPin(metal.netID, extpins)==1):
               # Blocked 
         #      M1_blocked_pinrow += 1
         # Check Metal2
         if metal.netID != cur_netID and metal.layer == 4 and metal.toRow == pin_row:
           if metal_pin.toCol >= metal.fromCol and metal_pin.toCol <= metal.toCol:
              M2_blocked_pinrow = 1
           else:
              if metal_pin.toCol > metal.toCol: #left side
                 if metal.toCol > M2_left_bound: 
                    M2_left_bound = metal.toCol
              if metal_pin.toCol < metal.fromCol: #right side
                 if metal.fromCol < M2_right_bound:
                    M2_right_bound =  metal.fromCol
         # Blocked by its own M2 segments
         if metal.netID == cur_netID and metal.layer == 4 and metal.toRow == pin_row:
           if metal_pin.toCol >= metal.fromCol and metal_pin.toCol <= metal.toCol:
              M2_blocked_pinrow = 1 
         if M1_blocked_pinrow > 1 or M2_blocked_pinrow > 0 or (M2_right_bound - M2_left_bound) < MAR+EOL:
           # Blocked
           break    
       if M1_blocked_pinrow <= 1 and M2_blocked_pinrow < 1 and (M2_right_bound - M2_left_bound) >= MAR+EOL:
         # Not blocked
         M1_PinMpoCnt = M1_PinMpoCnt + 1
  # Check Metal2
  for metal_pin in metal2Arr:
    M2_PinMpoCnt = M2_PinMpoCnt + (metal_pin.toCol - metal_pin.fromCol)/2 + 1
    #for pin_col in range (metal_pin.fromCol, metal_pin.toCol+1):
    #  M2_blocked_pincol = 0
      #for metal in metals:
      #  if metal.netID != cur_netID and metal.layer == 4 and abs(metal.toRow - metal_pin.toRow) <= 1:
      #    if pin_col >= metal.fromCol and pin_col <= metal.toCol and (IsExtPin(metal.netID, extpins)==1):
            # Blocked 
      #      M2_blocked_pincol += 1
      #  if M2_blocked_pincol > 1:
      #    break
    #  if M2_blocked_pincol <= 1:
    #    M2_PinMpoCnt = M2_PinMpoCnt + 1
  
  return (M1_PinMpoCnt, M2_PinMpoCnt)

def RPACal(extpin, extpins, metal1Arr, metal2Arr, metals, POCnt_Map):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  M2_PinMpoCnt = 0
  # Design Rule Definition: exp11 EOL=2 
  MAR = 2
  EOL = 0
  # M2 Design Rule
  M2_MAR = 2
  M2_EOL = 0
  # UPA
  UPA = 0.0
  # Check Metal1 first
  for metal_pin in metal1Arr:
    for pin_row in range (metal_pin.fromRow, metal_pin.toRow+1):
       M1_blocked_pinrow = 0
       M2_blocked_pinrow = 0
       M2_left_bound = 0
       M2_right_bound = 1000
       pin_col = metal_pin.fromCol
       if IsPO (extpin, extpins, metals, pin_row, pin_col) == 0:
          # Not an pin open. => Not counted in RPA
          continue; 
       for metal in metals:
         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
         if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= MAR+EOL \
            and IsExtPin(metal.netID, extpins)==1:
            if pin_row >= metal.fromRow and pin_row <= metal.toRow:
               adj_POCnt = POCnt_Map[metal.netID]
               UPA = UPA + float(1/adj_POCnt)
  # Check Metal2  
  for metal_pin in metal2Arr:
      # All M2 is pin opening but need to align with M1
      #print("M2 starts: %d -> %d\n"%(metal_pin.fromCol, metal_pin.toCol))
      for pin_col in range (metal_pin.fromCol, metal_pin.toCol+1):
        if pin_col%2 == 0: # On M3 track
           pin_row = metal_pin.fromRow
           for metal in metals:
               if metal.netID != cur_netID and metal.layer == 4 and abs(metal.toRow - pin_row) < M2_MAR+M2_EOL \
                  and IsExtPin(metal.netID, extpins)==1:
                  if pin_col >= metal.fromCol and pin_col <= metal.toCol:
                     #print("Adj Pin ID: %s pin row: %d Adj pin row: %d\n"%(metal.netID, pin_row, metal.toRow))
                     adj_POCnt = POCnt_Map[metal.netID]
                     UPA = UPA + float(1/adj_POCnt)
  POCnt = POCnt_Map[cur_netID]
  #print("POcnt: %f UPA: %f\t"%(POCnt, UPA))
  RPA = POCnt - UPA
  #print("RPA: %f\n"%(RPA))
  return RPA

def IsPO (extpin, extpins, metals, Row, Col):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  # Design Rule Definition
  MAR = 2
  EOL = 0
  # Check Metal1 first
  #for metal_pin in metal1Arr:
  pin_row = Row   
  M1_blocked_pinrow = 0
  M2_blocked_pinrow = 0
  M2_left_bound = 0
  M2_right_bound = 1000
  for metal in metals:
    # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
    #if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= 2:
    #   if pin_row >= metal.fromRow and pin_row <= metal.toRow and (IsExtPin(metal.netID, extpins)==1):
    # Blocked 
    #      M1_blocked_pinrow += 1
    # Check Metal2
    if metal.netID != cur_netID and metal.layer == 4 and metal.toRow == pin_row:
       if Col >= metal.fromCol and Col <= metal.toCol:
          M2_blocked_pinrow = 1
       else:
          if Col > metal.toCol: #left side
            if metal.toCol > M2_left_bound: 
               M2_left_bound = metal.toCol
          if Col < metal.fromCol: #right side
             if metal.fromCol < M2_right_bound:
                M2_right_bound =  metal.fromCol
    # Blocked by its own M2 segments
    if metal.netID == cur_netID and metal.layer == 4 and metal.toRow == pin_row:
       if Col >= metal.fromCol and Col <= metal.toCol:
          M2_blocked_pinrow = 1 
    if M1_blocked_pinrow > 1 or M2_blocked_pinrow > 0 or (M2_right_bound - M2_left_bound) <= MAR+EOL:
       # Blocked
       break    
  if M1_blocked_pinrow <= 1 and M2_blocked_pinrow < 1 and (M2_right_bound - M2_left_bound) > MAR+EOL:
     # Not blocked
     return 1
  else:
     return 0

def IsExtPin (netID, extpins):
  for extpin in extpins:
    if netID == extpin.netID:
       return 1
  return 0

# ICCAD version: PS 1 objective cnt
def PinSpaceCnt(extpin, extpins, metal1Arr, metal2Arr, metals):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  M2_PinMpoCnt = 0
  # Design Rule Definition
  MAR = 2
  EOL = 0
  # Check Metal1 first
  at_least_one_pin = -1
  min_pin_space = 100
  for metal_pin in metal1Arr:
      for metal in metals:
         pin_space = 0
         found = -1
         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
         if metal.netID != cur_netID and metal.layer == 3 and metal.toCol >= metal_pin.toCol and IsExtPin(metal.netID, extpins) == 1:
            found = 1
            at_least_one_pin = 1
            hspace = metal.toCol - metal_pin.toCol
            vspace = 0
            if hspace == 0:
               if metal.fromRow > metal_pin.toRow:
                  vspace = metal.fromRow - metal_pin.toRow
            pin_space = vspace + hspace
         if found == 1 and pin_space < min_pin_space:
            min_pin_space = pin_space
  if at_least_one_pin == 1:
    return min_pin_space
  else:
    return -1

# ICCAD version PS1 objective
#def PinSpaceCnt_ADJ(extpin, extpins, metal1Arr, metal2Arr, metals):
#  cur_netID = extpin.netID
#  M1_PinMpoCnt = 0
#  M2_PinMpoCnt = 0
#  # Design Rule Definition
#  MAR = 2
#  EOL = 0
#  # Check Metal1 first
#  total_pin_space = 0
#  num_pin_shape = 0
#  for metal_pin in metal1Arr:
#      pin_space = 2
#      for metal in metals:
#         #found = -1
#         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
#         if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= MAR+EOL \
#            and IsExtPin(metal.netID, extpins) == 1:
#            #found = 1
#            at_least_one_pin = 1
#            # Overlapping
#            if (metal.toRow >= metal_pin.toRow and metal.fromRow <= metal_pin.toRow) or \
#              (metal.toRow >= metal_pin.fromRow and metal.fromRow <= metal_pin.fromRow):
#               pin_space = pin_space-1
#            #pin_space = vspace + hspace
#      
#      total_pin_space = total_pin_space + pin_space
#      num_pin_shape = num_pin_shape + 1
#  
#  return float(total_pin_space/num_pin_shape)


# TVLSI version PS1 objective-> when col == 0 -> always set to 0
# This is maximize objective: PS_obj
def PinSpaceCnt_ADJ(extpin, extpins, metal1Arr, metal2Arr, metals):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  M2_PinMpoCnt = 0
  # Design Rule Definition
  MAR = 2
  EOL = 0
  # Check Metal1 first
  total_pin_space = 0
  num_pin_shape = 0
  PS_obj = 0
  for metal_pin in metal1Arr:
      pin_space = 2
      # TVLSI: If pin is on col == 0 (Boundary)
      if metal_pin.toCol == 0:
         pin_space = pin_space - 1
      for metal in metals:
         #found = -1
         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
         if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= MAR+EOL \
            and IsExtPin(metal.netID, extpins) == 1:
            #found = 1
            at_least_one_pin = 1
            # Only check column
            pin_space = pin_space - 1
            # Overlapping -> similar to check edge-based
            #if (metal.toRow >= metal_pin.toRow and metal.fromRow <= metal_pin.toRow) or \
            #  (metal.toRow >= metal_pin.fromRow and metal.fromRow <= metal_pin.fromRow):
            #   pin_space = pin_space-1
            #pin_space = vspace + hspace
      
      total_pin_space = total_pin_space + pin_space
      num_pin_shape = num_pin_shape + 1
      if pin_space == 2:
         PS_obj = PS_obj + 1
  
  return PS_obj
  #return float(total_pin_space/num_pin_shape)

# TVLSI version PS3 objective-> when col == 0 
# This is Minimize objective
def EdgeBasedPinCnt_ADJ(extpin, extpins, metal1Arr, metal2Arr, metals):
  cur_netID = extpin.netID
  M1_PinMpoCnt = 0
  M2_PinMpoCnt = 0
  # Design Rule Definition
  MAR = 2
  EOL = 1
  # Check Metal1 first
  total_pin_cost = 0
  num_pin_shape = 0
  for metal_pin in metal1Arr:
      pin_cost = 0
      # TVLSI: If pin is on col == 0 (Boundary)
      if metal_pin.toCol == 0:
         pin_cost = pin_cost + 1
      for metal in metals:
         #found = -1
         # Check Metal1: Since gear ratio is 1:1, with MAR=1, EOL=0 it is accesible
         if metal.netID != cur_netID and metal.layer == 3 and abs(metal.toCol - metal_pin.toCol) <= MAR+EOL \
            and IsExtPin(metal.netID, extpins) == 1:
            #found = 1
            at_least_one_pin = 1
            # Col Pin Cost -> Overlapping
            if (metal.toRow >= metal_pin.toRow and metal.fromRow <= metal_pin.toRow) or \
              (metal.toRow >= metal_pin.fromRow and metal.fromRow <= metal_pin.fromRow):
               pin_cost = pin_cost + 1
            # Edge Pin Cost
            for es in range (metal_pin.fromRow, metal_pin.toRow, 1):
                   et = es + 1 # Edge end row
                   if (metal.toRow >= et and metal.fromRow <= et) or \
                     (metal.toRow >= es and metal.fromRow <= es):
                        pin_cost = pin_cost + 1
                        #print ("metal pin edge: %d - %d, interfere pin: %d - %d\n"%(es,et,metal.fromRow, metal.toRow))
            #pin_space = vspace + hspace
      
      total_pin_cost = total_pin_cost + pin_cost
      num_pin_shape = num_pin_shape + 1
   
  return total_pin_cost

 
def CalM1TrackPG(metals):
  used_track = 0
  for metal in metals:
    if metal.layer == 3:
       # Mark: Need to be modified based on cell height
       if metal.fromRow == 0 or metal.fromRow == 3 or metal.toRow == 0 or metal.toRow == 3 :
          used_track = used_track+1
  return used_track
          
def PSObjCal(extpins, numCPP):
  PS_Obj = 0
  #print ("numCPP: %d\t"%numCPP)
  for col in range(0, numCPP):
    print ("col: %d\t"%col)
    ps_tmp = 1
    found_pin = 0
    for pin in extpins:
      print("pin y: %d\t"%pin.y)
      if pin.y/2 == col:
        # Found one pin at col

        print("found one pin ps_tmp: %d\t"%ps_tmp)
        found_pin = 1
        for pin1 in extpins:
          if pin1.netID != pin.netID and abs(pin1.y/2 - col) <= 1:
            ps_tmp = 0
            break
    if found_pin == 1 and ps_tmp == 1:
      print("PS tmp count: %d"%ps_tmp)
      PS_Obj = PS_Obj + ps_tmp
    print ("\n")	
  return PS_Obj

def CalM2Resource(metals):
  totalM2 = 0
  M2Track_use = []
  for metal in metals:
    if metal.layer == 4:
       totalM2 = totalM2 + abs(metal.fromCol - metal.toCol)
       if metal.fromRow not in M2Track_use:
          M2Track_use.append(metal.fromRow)       
  return len(M2Track_use), totalM2

def DumpCellMetrics(outputDir):
   global Cell_metrics_map;
   #print (Cell_metrics_map)
   # Avg_PinMpoCnt, Max_PinMpoCnt, Min_PinMpoCnt, Avg_PinSpace, Avg_PinCost, Avg_RPA, Min_RPA, PS_Obj, M2Resource_Used
   cell_list = ["AND2x2", "AND3x1", "AND3x2", "AOI21x1", "AOI22x1", "BUFx2", "BUFx3", "BUFx4", "BUFx8", "DFFHQNx1",\
"FAx1", "INVx1", "INVx2", "INVx4", "INVx8", "NAND2x1", "NAND2x2", "NAND3x1", "NAND3x2", "NOR2x1",\
"NOR2x2", "NOR3x1", "NOR3x2","OAI21x1", "OAI22x1", "OR2x2", "OR3x1", "OR3x2", "XNOR2x1", "XOR2x1"]
   filename = outputDir + "Cell_Metrics.txt"
   f = open(filename, "w")
   f.write("Cell\tAvg_PinMpoCnt\tMax_PinMpoCnt\tMin_PinMpoCnt\tNew PS1 Obj\tPS3 Obj\tAvg_RPA\tMin_RPA\tICCAD PS_Obj\tM2Track_Used\tM2Resource_Used\n") 
   for cell in cell_list: 
       if cell in Cell_metrics_map.keys():
            f.write("%s"%(cell))
            for metric in Cell_metrics_map[cell]:
                f.write("\t%f"%metric)
            f.write("\n")
   f.close()
   return
 
# Main codes
# ==============================================================================================================
# v4.0: Adjutst M2 left and right extension 0.009um; It is still consistent with the FEOL grid-based assumption.
# ==============================================================================================================
inputDir = "./input_cfet_exp1_pinfix/"
outputDir = "./output_cfet/"

if len(sys.argv) <= 1:
  print("Usage:   python generate.py <metalPitch> <cppWidth> <siteName> <mpoMode>\n\n")
  print("         metalPitch: int")
  print("         cppWidth  : int")
  print("         siteName  : string")
  print("         mpoMode   : 2/3/MAX\n")
  print("Example: ")
  print("         python generate_cfet.py 24 42 coreSite 2")
  sys.exit(1)

if len(sys.argv) >= 6:
  inputDir = sys.argv[5]
  outputDir = sys.argv[6]
print(inputDir)
print(outputDir)
fileList = os.listdir(inputDir)
tech = TechInfo(0, 0, sys.argv[1], sys.argv[2], sys.argv[3], BprMode.NONE, \
        GetMpoFlag(sys.argv[4]))

# generate six lef files
for bprFlag in [BprMode.BPR]:
  tech.bprFlag = bprFlag
  GenerateLef(fileList, outputDir, tech)

# dump cell metrics
DumpCellMetrics(outputDir)
