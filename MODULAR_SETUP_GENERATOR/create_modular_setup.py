#!/usr/bin/env python3
import json
import math

import ftab_mapping

##########################################################################
# Settings                                                               #
##########################################################################
setup_id = 38
modular_layer_ids = [4]
modular_layer_radii = {4 : 38.186}
slot_id_offset = 200
first_module_theta = 7.5
scin_id_offset = 200

scin_radii = (38.416, 38.346, 38.289, 38.244, 38.212, 38.192, 38.186,
	      38.192, 38.212, 38.244, 38.289, 38.346, 38.416)
layer_4_theta_diff = 360.0/24.0

matrix_id_offset = 400
pm_id_offset = 400
channel_id_offset = 2100;

new_json_file = "modular_setup_clinical.json"

# threshold values [A,B] by PM in matrix
threshold_values = {
    1 : [30, 70],
    2 : [30, 70],
    3 : [30, 70],
    4 : [30, 70]
}

##########################################################################
# Functions                                                              #
##########################################################################
def getMatrixFromPMID(s_id):
    s_id = s_id - 401
    return int(s_id/4) + 401

def calcScinPosition(module_theta, scin_in_module):

    # calculation scheme copied from j-pet-geant4 code
    radius = scin_radii[scin_in_module-1]
    scin_in_module = scin_in_module - 7
    angle = module_theta + 1.04*scin_in_module
    angle = math.radians(angle)

    x = round(radius * math.sin(angle), 3)
    y = round(radius * math.cos(angle), 3)
    
    return (x, y)

def getChannelID(slot, scin, side, pos_in_matrix, thr_num):

    # account for mirror reflection of B side FTAB-s
    # w.r.t. scintillator numbering
    if side=="B":
        scin = 14 - scin 
    
    id = channel_id_offset + (slot-1)*2*105 + (105 if side=='B' else 0)
    id = id + ftab_mapping.FTAB_MAPPING[ (scin, pos_in_matrix, thr_num) ]    
    return id

##########################################################################
# Main                                                                   #
##########################################################################
setup = {}

##########################################################################
# Generate setup and layers manually                                     #
##########################################################################
setup["setup"] = [
    {
        "description" : "Modular J-PET - version for clinical scans",
        "id" : setup_id
    }
]

layers = []
for layer_id in modular_layer_ids:
    layers.append(
        {
            "id" : layer_id,
            "name" : f"Digital J-PET layer {layer_id}",
            "radius" : modular_layer_radii[layer_id],
            "setup_id" :setup_id
        }        
    )
    
setup["layer"] = layers
##########################################################################
# Generate the rest of the setup top-down                                #
##########################################################################
slots = []
scins = []
matrices = []
pms = []
channels = []

matrix_id = matrix_id_offset
pm_id = pm_id_offset

for nslot in range(1, 25):

    slot_id = slot_id_offset + nslot
    slot_theta = first_module_theta + 15.0*(nslot-1)
    
    slots.append(
        {
            "id" : slot_id,
            "layer_id" : modular_layer_ids[0], # for now, single layer only
            "theta" : slot_theta,
            "type" : "module"
        }
    )

    # Generate scintillators in the slot
    for nscin in range (1, 14):

        scin_id = scin_id_offset + (nslot-1)*13 + nscin
        x,y = calcScinPosition(slot_theta, nscin)

        scins.append(
            {
                "id" : scin_id,
                "slot_id" : slot_id,
                "height" : 25,
                "width" : 6,
                "length": 500,
                "xcenter" : x,
                "ycenter" : y,
                "zcenter" : 0.0,
                "rot_x" : 0.0,
                "rot_y" : 0.0,
                "rot_z" : 0.0
                
            }
        )        
        
        # Generate matrices for the scintillator
        for side in ("A", "B"):

            matrix_id = matrix_id + 1
            matrices.append(
                {
                    "id" : matrix_id,
                    "side" : side,
                    "scin_id" : scin_id
                }
            )

            # Generate PM-s for the matrix
            for pos_in_matrix in range(1,5):
                
                pm_id = pm_id + 1
                pms.append(
                    {
                        "id" : pm_id,
                        "description" : str(pm_id),
                        "pos_in_matrix" : pos_in_matrix,
                        "matrix_id" : matrix_id
                    }
                )

                # Generate channels for the PM
                for thr_num in range(1,3):

                    channel_id = getChannelID(nslot, nscin, side, pos_in_matrix, thr_num)
                    
                    channels.append(
                        {
                            "id" : channel_id,
                            "thr_num" : thr_num,
                            "pm_id" : pm_id,
                            "thr_val" : threshold_values[pos_in_matrix][thr_num-1]
                        }
                    )

            
setup["slot"] = slots
setup["scin"] = scins
setup["matrix"] = matrices
setup["pm"] = pms
setup["channel"] = channels

##########################################################################
# Wrap setup                                                             #
##########################################################################
setup_wrapped = {
    setup_id : setup
}

##########################################################################
# Write output file                                                      #
##########################################################################
with open(new_json_file, "w") as file:
    json.dump(setup_wrapped, file, indent=2)
    
