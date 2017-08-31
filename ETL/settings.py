"""""""""""""""""
Settings for ETL
"""""""""""""""""

import os
from datetime import datetime

# Build paths inside the project like this: os.path.join(BASE_DIR, ...)
SCRIPT_DIR = os.path.dirname((os.path.abspath(__file__)))
SOURCE_FILE_PATH = r'C:\Users\Jonathan\Dropbox\VANS\Sources\Masters\ETL'
LOG_FILE = SCRIPT_DIR + '\log\\' + datetime.now().strftime('%Y-%m-%d') + '_etl.log'
####################################
####### DATABASE PARAMETERS ########
####################################

ALCHEMY_DB = {
    'pdas_db': {
        'drivername': 'mssql+pyodbc',
        'host': 'DESKTOP-S24764E',
        'username': 'vfa_dev',
        'password': 'VF2017!',
        'database': 'vcdwh'
    },
    'ngc_db': {
        'drivername': 'mssql+pyodbc',
        'host': 'ITGC2W000187',
        'username': 'brioread',
        'password': 'Brio!@23',
        'database': 'ESPSODV14RPT'
    }
}


DEFAULT_SIZE = 500

INT_LIMIT = 1000000000


####################################
######### ETL PARAMETERS ###########
####################################

FORMAT_DATES = {
    # MM/DD/YYYY
    'DATE_US': r"""^(?:0?[1-9]|1[0-2])[/-](?:(?:0[1-9])|(?:[12][0-9])|(?:3[01])|[1-9])[/-](?:\d\d){1,2}""",
    # DD/MM/YYYY
    'DATE_EU': r"""^(?:(?:0[1-9])|(?:[12][0-9])|(?:3[01])|[1-9])[./-](?:0?[1-9]|1[0-2])[./-](?:\d\d){1,2}""",
    # YYYY/MM/DD
    'DATE_ISO': r"""^(?:\d{4})[./-]?(?:0?[1-9]|1[0-2])[./-](?:(?:0[1-9])|(?:[12][0-9])|(?:3[01])|[1-9])""",
    # MM/YYYY
    'MONTH_DATE': r"""^(?:0?[1-9]|1[0-2])[./-](?:\d\d){1,2}$""",
    # YYYY/MM
    'MONTH_DATE_ISO': r"""^(?:\d{4})[./-]?(?:0?[1-9]|1[0-2])$"""
}

FORMAT_FLOAT = r"""^\d+(,\d+)*\.\d+%?$"""

FORMAT_INT = r"""^\d+(,\d+)*%?$"""
