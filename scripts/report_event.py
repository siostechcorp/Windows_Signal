#!/usr/bin/env python
###############################################################################
# vim: tabstop=4:shiftwidth=4:expandtab:
# Copyright (c) 2017 SIOS Technology Corp. All rights reserved.
#
# Arguments:
#   args[1] - Windows Event Source/Provider 
#   args[2] - Windows Event ID
#   args[3] - Windows Event Severity
#   args[4] - Windows Event Message
#   args[5] - Windows Event Time Generated in ISO 8601 format (2017-10-11T15:18:33-0500)
##############################################################################
"""
This script will send three iQ events (one for each layer type) for a single Windows event.
"""

import logging
import sys
from datetime import datetime, timedelta
from time import tzname, localtime, strftime
from pytz import timezone
from os.path import dirname, realpath

curr_path = dirname(realpath(__file__))
sys.path.insert(0, '{}/../../'.format(curr_path))

from SignaliQ.client import Client
from SignaliQ.model.CloudProviderEvent import CloudProviderEvent
from SignaliQ.model.ProviderEventsUpdateMessage import ProviderEventsUpdateMessage

__log__ = logging.getLogger(__name__)

env_id = 180005401 # CHANGE THIS TO LOCAL iQ ENVIRONMENT ID
vm_uuid = ["421be947-4e42-3deb-e0e9-55ef78c3e16a"] # CHANGE THIS TO LOCAL VM UUID, must stay a list

def main(args):
    # Setup the client and send the data!
    client = Client()
    client.connect()

    # create message with <Source>, <ID>, and <Message> delimited by the unicode unit separator
    event_desc = args[1] + unichr(31) + args[2] + unichr(31) + args[4]

    events = [
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Compute",
            severity = args[3],
            time = args[5],
            event_type = "Performance",
            vm_uuids = vm_uuid,
        ),
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Network",
            severity = args[3],
            time = args[5],
            event_type = "Performance",
            vm_uuids = vm_uuid,
        ),
        CloudProviderEvent(
            description = event_desc,
            environment_id = env_id,
            layer = "Storage",
            severity = args[3],
            time = args[5],
            event_type = "Performance",
            vm_uuids = vm_uuid,
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
