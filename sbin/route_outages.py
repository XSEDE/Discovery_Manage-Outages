#!/usr/bin/env python3

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
try:
    import http.client as httplib
except ImportError:
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
update_file = './allUpdateReport.csv'
#snarfing the whole database is not the way to do it, for this anyway)
databasestate = serializers.serialize("json", Outages.objects.filter(ID__endswith='.xsede.org'))
#print databasestate
dbstate = json.loads(databasestate)
#print dbstate
dbhash = {}
for obj in dbstate:
    #print obj
    dbhash[str(obj['pk'])]=obj
#print dbhash
updatehash = {}     # Contains all the outage updates by OutageID and sequential UpdateID
with open(update_file, 'r') as up_file:
    update_csv = csv.DictReader(up_file)
    for row in update_csv:
        if row['OutageID'] not in updatehash:
            updatehash[row['OutageID']] = {}
        updatehash[row['OutageID']][row['UpdateID']] = row
    
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
        
        #Merge updates text into the
        if row['OutageID'] in updatehash:
            myupdates = updatehash[row['OutageID']]
            for updateid in sorted(myupdates):
                anupdate = myupdates[updateid]
                # prepend update
                row['Content'] = "Update {} at {}\n\n{}\n".format(updateid, anupdate['UpdateDate'], anupdate['UpdateContent'] + row['Content'])

        rowPK = 'urn:ogf:glue2:info.xsede.org:outages:{}:{}'.format(row['OutageID'], row['ResourceID'])
        if rowPK in dbhash.keys():
            dbhash.pop(rowPK)

        # Replace the XUP WebURL with an information services one that will continue working after 9/1/2022 
        row['WebURL'] = 'https://info.xsede.org/wh1/outages/v1/outages/ID/{}/?format=html'.format(rowPK)

        objtoserialize={}
        objtoserialize["model"]="outages.Outages"
        objtoserialize["pk"]=rowPK
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
