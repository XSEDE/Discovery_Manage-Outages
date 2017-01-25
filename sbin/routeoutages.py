#!/usr/bin/env python

import pprint
import os
import pwd
import re
import sys
import argparse
import logging
import logging.handlers
import signal
import datetime
from datetime import datetime, tzinfo, timedelta
from time import sleep
import httplib
import json
import csv
import ssl
import shutil

import django
django.setup()
from django.utils.dateparse import parse_datetime
from outages.models import *
from django.core import serializers

default_file = '/soft/warehouse-apps-1.0/Manage-Outages/var/allOutageReport.csv'
#snarfing the whole database is not the way to do it, for this anyway)
#databasestate = serializers.serialize("json", ProjectResource.objects.all())
with open(default_file, 'r') as my_file:
    tgcdb_csv = csv.DictReader(my_file)
    for row in tgcdb_csv:
    #    if len(row['Content'])>1023:
    #        print len(row['Content'])
        #InDBAlready = ProjectResource.objects.filter(**row)
        InDBAlready = Outages.objects.filter(OutageID=row['OutageID'])
        if not InDBAlready:
            objtoserialize={}
            objtoserialize["model"]="outages.Outages"
            objtoserialize["pk"]=row['OutageID']
            objtoserialize["fields"]=row
            jsonobj = json.dumps([objtoserialize])
            moduleobjects =serializers.deserialize("json", jsonobj)

            for obj in moduleobjects:
                obj.save()
