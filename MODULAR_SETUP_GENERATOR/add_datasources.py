#!/usr/bin/env python3
import json
import xml.etree.ElementTree as ET
import sys

data_sources = []
data_modules = []

source_id = 1
module_id = 1

# parse XML file with DAQ config
root = ET.parse('conf_djpet.xml').getroot()

for xml_data_source in root.findall('DATA_SOURCE'):
    xml_data_module = xml_data_source.find('MODULES/MODULE')

    source = {
        "id" : source_id,
        "type" : xml_data_source.find('TYPE').text,
        "trbnet_address" : xml_data_source.find('TRBNET_ADDRESS').text,
        "hub_address" : xml_data_source.find('HUB_ADDRESS').text        
    }

    module = {
        "id" : module_id,
        "type" : xml_data_module.find('TYPE').text,
        "trbnet_address" : xml_data_module.find('TRBNET_ADDRESS').text,
        "channels_number" : int(xml_data_module.find('NUMBER_OF_CHANNELS').text),
        "channels_offset" : int(xml_data_module.find('CHANNEL_OFFSET').text),
        "data_source_id" : source_id
    }
    
    source_id = source_id + 1
    module_id = module_id + 1

    data_sources.append(source)
    data_modules.append(module)

# load original JSON file
with open(sys.argv[1], "r") as file:
    orig_setup = json.load(file)

# Append new structures to original dictionary    
list(orig_setup.values())[0]["data_source"] = data_sources
list(orig_setup.values())[0]["data_module"] = data_modules

channels = list(orig_setup.values())[0]["channel"]

for data_module in data_modules:
    ch_range = range(data_module["channels_offset"], data_module["channels_offset"]+data_module["channels_number"])
    dm_id = data_module["id"]
    for ch_id in ch_range:
        for ch in channels:
            if ch["id"] == ch_id:
                ch["data_module_id"] = dm_id

##########################################################################
# Write output file                                                      #
##########################################################################
with open(sys.argv[2], "w") as file:
    json.dump(orig_setup, file, indent=2)
