#!/bin/bash
#export DJANGO_CONF=/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse/xsede_warehouse/settings_localdev.conf
#export PYTHONPATH=/Users/blau/info_services/info.warehouse/trunk/apps:/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse
PYTHON=/soft/python-2.7.11/bin/python
export PYTHON
export LD_LIBRARY_PATH=/soft/python-2.7.11/lib
export PYTHONPATH=/soft/warehouse-1.0/PROD/apps/:/soft/warehouse-1.0/PROD/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-1.0/conf/settings_info_mgmt.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings
#python ./serialize_save.py
#python ./route_speedpage.py ${@:1}
#python ./speedserialize ${@:1}
$PYTHON ./routeoutages.py
