#!/usr/bin/env python
###############################################################################
# vim: tabstop=4:shiftwidth=4:expandtab:
# Copyright (c) 2017 SIOS Technology Corp. All rights reserved.
##############################################################################
"""
This script will send three iQ events (one for each layer type) for a single Windows event.
Arguments:
  args[1] - Windows Event Source/Provider 
  args[2] - Windows Event ID
  args[3] - Windows Event Severity
  args[4] - Windows Event Message
  args[5] - Windows Event Time Generated in ISO 8601 format (2017-10-11T15:18:33-0500)
"""

import logging
import sys
from os.path import dirname, realpath

curr_path = dirname(realpath(__file__))
sys.path.insert(0, '{}/../../'.format(curr_path))

from SignaliQ.client import Client
from SignaliQ.model.CloudProviderEvent import CloudProviderEvent
from SignaliQ.model.ProviderEventsUpdateMessage import ProviderEventsUpdateMessage
from SignaliQ.model.CloudVM import CloudVM
from SignaliQ.model.NetworkInterface import NetworkInterface

__log__ = logging.getLogger(__name__)

env_id = 180005401            # CHANGE THIS TO LOCAL iQ ENVIRONMENT ID
vm_hwid = "00-50-56-9B-7C-76" # CHANGE THIS TO A LOCAL VM MAC ADDRESS

def main(args):
    # Setup the client and send the data!
    client = Client()
    client.connect()
    
    __log__.info( "Creating event with time {} and env id of {}".format(args[5], env_id) )

    # create message with <Source>, <ID>, and <Message> delimited by the unicode unit separator
    event_desc = args[1] + unichr(31) + args[2] + unichr(31) + args[4]

    events = [
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Compute",
            severity = args[3],
            time = args[5],
            event_type = "SDK Event",
            vms = [
                CloudVM(network_interfaces = [NetworkInterface(hw_address = vm_hwid)])
            ],
        ),
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Network",
            severity = args[3],
            time = args[5],
            event_type = "SDK Event",
            vms = [
                CloudVM(network_interfaces = [NetworkInterface(hw_address = vm_hwid)])
            ],
        ),
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Storage",
            severity = args[3],
            time = args[5],
            event_type = "SDK Event",
            vms = [
                CloudVM(network_interfaces = [NetworkInterface(hw_address = vm_hwid)])
            ],
        )
    ]

    event_message = ProviderEventsUpdateMessage(
        environment_id = env_id,
        events = events,
    )

    client.send(event_message)

    client.disconnect()


if __name__ == "__main__":
    main(sys.argv)
