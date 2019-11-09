#!/bin/bash
MY_ROOT=/soft/warehouse-apps-1.0/Manage-Outages/PROD
WAREHOUSE_ROOT=/soft/warehouse-1.0/PROD

PYTHON_BASE=/soft/python/python-3.6.6-base
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib

PYTHON_ROOT=/soft/warehouse-apps-1.0/Manage-Outages/python
source ${PYTHON_ROOT}/bin/activate

#export DJANGO_CONF=/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse/xsede_warehouse/settings_localdev.conf
#export PYTHONPATH=/Users/blau/info_services/info.warehouse/trunk/apps:/Users/blau/info_services/info.warehouse/trunk/django_xsede_warehouse
export PYTHONPATH=${WAREHOUSE_ROOT}/django_xsede_warehouse
export DJANGO_CONF=/soft/warehouse-apps-1.0/Manage-Outages/conf/django_xsede_warehouse.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings

python ${MY_ROOT}/sbin/route_outages.py
