#!/bin/bash
MY_ROOT=/soft/warehouse-apps-1.0/Manage-Outages/PROD
WAREHOUSE_ROOT=/soft/warehouse-1.0/PROD
PYTHON=/soft/python-current/bin/python
export LD_LIBRARY_PATH=/soft/python-current/lib/

#export DJANGO_CONF=/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse/xsede_warehouse/settings_localdev.conf
#export PYTHONPATH=/Users/blau/info_services/info.warehouse/trunk/apps:/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse
export PYTHONPATH=${WAREHOUSE_ROOT}/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-1.0/conf/django_prod_mgmt.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings

${PYTHON} ${MY_ROOT}/sbin/routeoutages.py
