import os
import sys
import numpy as np
import pandas as pd
import settings as cp
import magic
from sqlalchemy.exc import SQLAlchemyError


def get_data_from_extracts():
    r"""
    =======================================================
        Extract and load Input Files in Staging Area
    =======================================================
    """
    # Display progress logs on stdout

    magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Scanning directory {}'''.format(cp.SOURCE_FILE_PATH))
    engine = magic.db_connect(connection_name='pdas_db')
    df_metadata_before = magic.get_table_to_df(engine, 'pdas_metadata')
    # Scan folder and sub-folders
    for f in df_metadata_before[df_metadata_before['etl_type'] == 'file']['src_name'].values.tolist():
        # Work with files defined in metadata table only
        if not(os.path.isfile(cp.SOURCE_FILE_PATH + '\\' + f)):
            continue
        magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Processing ETL for file {} started'''.format(f))
        timestamp_old = magic.get_table_column_values_as_list(engine, 'pdas_metadata', 'timestamp_file', {'src_name': [f]})[0].strftime("%Y-%m-%d %H:%M:%S")
        timestamp_new = magic.get_modified_date(os.path.join(cp.SOURCE_FILE_PATH, f))
        if timestamp_old == timestamp_new:
            magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''File {} already loaded for this modified date {}'''.format(f, timestamp_new))
            continue
        magic.set_table_column_value(engine, 'pdas_metadata', 'state', 'TBL', 'src_name', f)
        if os.path.splitext(os.path.join(cp.SOURCE_FILE_PATH, f))[1] in ('.xlsx', '.xls'):
            xl = pd.ExcelFile(os.path.join(cp.SOURCE_FILE_PATH, f))
            if 'PDAS' in xl.sheet_names:
                df = pd.read_excel(os.path.join(cp.SOURCE_FILE_PATH, f), sheetname='PDAS')
                magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''File {} has {} rows and {} columns'''.format(f, df.shape[0], df.shape[1]))
            else:
                magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Couldn't process the file {} (reason: No sheet named "PDAS")'''.format(f))
                sys.exit(1)
        elif os.path.splitext(os.path.join(cp.SOURCE_FILE_PATH, f))[1] in ('.csv'):
            sep = magic.find_delimiter(os.path.join(cp.SOURCE_FILE_PATH, f))
            df = pd.read_csv(os.path.join(cp.SOURCE_FILE_PATH, f), sep=sep, error_bad_lines=False, encoding='latin-1', low_memory=False, warn_bad_lines=False)
        else:
            magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Couldn't process the file {} (reason: File not found)'''.format(f))
            continue
        # From Pandas to staging area
        magic.convert_numeric_col(df)
        df.columns = [magic.rewrite_with_technical_convention(col) for col in df.columns]
        db_dicttypes = magic.gen_types_from_pandas_to_sql(df)
        # load the staging table
        tablename = magic.get_table_column_values_as_list(engine, 'pdas_metadata', 'table_name', {'src_name': [f]})[0]
        magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Loading table {} in staging area'''.format(tablename))
        magic.delete_from_table(engine, tablename)
        new_names = magic.get_column_names(engine, tablename)
        df = df.rename(columns={old_col: new_col for old_col, new_col in zip(df.columns, new_names)})
        flag = magic.load_df_into_db(engine, df, tablename, dict_types=db_dicttypes, mode='append')
        if flag == 0:
            magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''FAIL Loading table {}'''.format(f))
            magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Processing ETL for file {} ended in error'''.format(f))
            sys.exit(1)
        else:
            magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, r'''Processing ETL for file {} ended successfully'''.format(f))
            # Update timestamp column
            magic.set_table_column_value(engine, 'pdas_metadata', 'timestamp_file', timestamp_new, 'src_name', f)
            magic.set_table_column_value(engine, 'pdas_metadata', 'state', 'OK', 'src_name', f)



if __name__ == '__main__':
    magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, '''#### ETL BEGIN ####\n\n\n''', with_time_stamp=False)
    magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, '''## FILES ##''', with_time_stamp=False)
    get_data_from_extracts()
    magic.write_to_file(cp.LOG_FILE_SHARED_DRIVE, '''\n\n''', with_time_stamp=False)
