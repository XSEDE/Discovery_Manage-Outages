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
from processing_status.process import ProcessingActivity

class UTC(tzinfo):
    def utcoffset(self, dt):
        return timedelta(0)
    def tzname(self, dt):
        return 'UTC'
    def dst(self, dt):
        return timedelta(0)
utc = UTC()

#default_file = '/soft/warehouse-apps-1.0/Manage-Outages/var/allOutageReport.csv'
default_file = './allOutageReport.csv'
#snarfing the whole database is not the way to do it, for this anyway)
databasestate = serializers.serialize("json", Outages.objects.all())
#print databasestate
dbstate = json.loads(databasestate)
#print dbstate
dbhash = {}
for obj in dbstate:
    #print obj
    dbhash[str(obj['pk'])]=obj
#print dbhash
with open(default_file, 'r') as my_file:
    tgcdb_csv = csv.DictReader(my_file)
    #Start ProcessActivity
    pa_application=os.path.basename(__file__)
    pa_function='main'
    pa_topic = 'Outages'
    pa_id = pa_topic
    pa_about = 'xsede.org'
    pa = ProcessingActivity(pa_application, pa_function, pa_id , pa_topic, pa_about)
    for row in tgcdb_csv:
    #    if len(row['Content'])>1023:
    #        print len(row['Content'])
        #InDBAlready = ProjectResource.objects.filter(**row)
        #InDBAlready = Outages.objects.filter(OutageID=row['OutageID'])
        #if not InDBAlready:
        #print row['OutageID']
        #print dbhash
        #print dbhash[row['OutageID']]
        #hash is just tracking what we've seen, we do the same thing for updates or not
        if row['OutageID']+":"+row['ResourceID'] in dbhash.keys():
            dbhash.pop(row['OutageID']+":"+row['ResourceID'])
        #    print "%s found in database already" % row['OutageID']
        #else:
        objtoserialize={}
        objtoserialize["model"]="outages.Outages"
        objtoserialize["pk"]=row['OutageID']+":"+row['ResourceID']
        objtoserialize["fields"]=row
        jsonobj = json.dumps([objtoserialize])
        moduleobjects =serializers.deserialize("json", jsonobj)

        for obj in moduleobjects:
            obj.save()
                
    #print dbhash.keys()
    for key in dbhash.keys():
        #print "key %s not in this update" % key
        Outages.objects.filter(ID=key).delete()
    pa.FinishActivity(0, "")
