#!/usr/bin/env python
###############################################################################
# vim: tabstop=4:shiftwidth=4:expandtab:
# Copyright (c) 2017 SIOS Technology Corp. All rights reserved.
##############################################################################
"""
This script will send three iQ events (one for each layer type) for a single Windows event.
Arguments:
  args[1] - SIOS iQ environment id (format 123456789)
  args[2] - localhost MAC address (format 00-00-00-00-00-00)
  args[3] - Windows Event Source/Provider 
  args[4] - Windows Event ID
  args[5] - Windows Event Severity
  args[6] - Windows Event Message
  args[7] - Windows Event Time Generated in ISO 8601 format (2017-10-11T15:18:33-0500)
  args[8] - Custom Event Summary (from JSON file originally)
  args[9] - Custom Event Type
  args[10] - Custom Event Category
  args[11] - Custom Event Layer
"""

import logging
import sys
from os.path import dirname, realpath
from os import getenv

# add potential paths to the Signal_iQ repo, could just use an arg instead
if getattr(sys, 'frozen', False):
    # The application is frozen. This path needs to be used for py2exe support.
    curr_path = dirname(sys.executable)
else:
    # The application is not frozen. This will work when run with installed python27.
    curr_path = dirname(realpath(__file__))

sys.path.insert(0, '{}/../../'.format(curr_path))

from SignaliQ.client import Client
from SignaliQ.model.CloudProviderEvent import CloudProviderEvent
from SignaliQ.model.ProviderEventsUpdateMessage import ProviderEventsUpdateMessage
from SignaliQ.model.CloudVM import CloudVM
from SignaliQ.model.NetworkInterface import NetworkInterface

__log__ = logging.getLogger(__name__)

def main(args):
    # Setup the client and send the data!
    client = Client()
    client.connect()

    __log__.info( "Creating event with time {} and env id of {}".format(args[7], args[1]) )

    # create message with <Summary>, <ID>, and <Message> delimited by the unicode unit separator
    event_desc = args[8] + unichr(31) + args[4] + unichr(31) + args[6]

    events = [
        CloudProviderEvent(
            environment_id = args[1],
            description    = event_desc,
            source         = args[3],
            severity       = args[5],
            time           = args[7],
            event_type     = args[9],
            category       = args[10],
            layer          = args[11],
            vms = [
                CloudVM(network_interfaces = [NetworkInterface(hw_address = args[2])])
            ],
        )
    ]

    event_message = ProviderEventsUpdateMessage(
        environment_id = args[1],
        events = events,
    )

    client.send(event_message)

    client.disconnect()


if __name__ == "__main__":
    main(sys.argv)
