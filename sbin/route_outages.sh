#!/bin/bash
APP_BASE=/soft/warehouse-apps-1.0/Manage-Outages
WAREHOUSE_BASE=/soft/warehouse-1.0
# Override in shell environment
if [ -z "$PYTHON_BASE" ]; then
    PYTHON_BASE=/soft/python/python-3.7.6-base
fi

APP_SOURCE=${APP_BASE}/PROD
WAREHOUSE_SOURCE=${WAREHOUSE_BASE}/PROD

PYTHON_BIN=python3
export LD_LIBRARY_PATH=${PYTHON_BASE}/lib
source ${APP_BASE}/python/bin/activate

export PYTHONPATH=${APP_SOURCE}/lib:${WAREHOUSE_SOURCE}/django_xsede_warehouse
export DJANGO_CONF=${APP_BASE}/conf/django_xsede_warehouse.conf
export DJANGO_SETTINGS_MODULE=xsede_warehouse.settings

${PYTHON_BIN} ${APP_SOURCE}/sbin/route_outages.py
