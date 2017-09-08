import os
import sys
import numpy as np
import pandas as pd
import settings as cp
import magic
from dateutil import relativedelta
from sqlalchemy.exc import SQLAlchemyError


def get_data_from_extracts():
    r"""
    =======================================================
        Extract and load Input Files in Staging Area
    =======================================================
    """
    # Display progress logs on stdout

    magic.write_to_file(cp.LOG_FILE, r'''Scanning directory {}'''.format(cp.SOURCE_FILE_PATH))
    engine = magic.db_connect(connection_name='pdas_db')
    df_metadata_before = magic.get_table_to_df(engine, 'pdas_metadata')
    # Scan folder and sub-folders
    for f in df_metadata_before[df_metadata_before['etl_type'] == 'file']['src_name'].values.tolist():
        # Work with files defined in metadata table only
        magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for file {} started'''.format(f))
        timestamp_old = magic.get_table_column_values_as_list(engine, 'pdas_metadata', 'timestamp_file', {'src_name': [f]})[0].strftime("%Y-%m-%d %H:%M:%S")
        timestamp_new = magic.get_modified_date(os.path.join(cp.SOURCE_FILE_PATH, f))
        if timestamp_old == timestamp_new:
            magic.write_to_file(cp.LOG_FILE, r'''File {} already loaded for this modified date {}'''.format(f, timestamp_new))
            continue
        magic.set_table_column_value(engine, 'pdas_metadata', 'state', 'TBL', 'src_name', f)
        if os.path.splitext(os.path.join(cp.SOURCE_FILE_PATH, f))[1] in ('.xlsx', '.xls'):
            xl = pd.ExcelFile(os.path.join(cp.SOURCE_FILE_PATH, f))
            if 'PDAS' in xl.sheet_names:
                df = pd.read_excel(os.path.join(cp.SOURCE_FILE_PATH, f), sheetname='PDAS')
                magic.write_to_file(cp.LOG_FILE, r'''File {} has {} rows and {} columns'''.format(f, df.shape[0], df.shape[1]))
            else:
                magic.write_to_file(cp.LOG_FILE, r'''Couldn't process the file {} (reason: No sheet named "PDAS")'''.format(f))
                sys.exit(1)
        elif os.path.splitext(os.path.join(cp.SOURCE_FILE_PATH, f))[1] in ('.csv'):
            sep = magic.find_delimiter(os.path.join(cp.SOURCE_FILE_PATH, f))
            df = pd.read_csv(os.path.join(cp.SOURCE_FILE_PATH, f), sep=sep, error_bad_lines=False, encoding='latin-1', low_memory=False, warn_bad_lines=False)
        else:
            magic.write_to_file(cp.LOG_FILE, r'''Couldn't process the file {} (reason: File not found)'''.format(f))
            continue
        # From Pandas to staging area
        magic.convert_numeric_col(df)
        df.columns = [magic.rewrite_with_technical_convention(col) for col in df.columns]
        db_dicttypes = magic.gen_types_from_pandas_to_sql(df)
        # load the staging table
        tablename = magic.get_table_column_values_as_list(engine, 'pdas_metadata', 'table_name', {'src_name': [f]})[0]
        magic.write_to_file(cp.LOG_FILE, r'''Loading table {} in staging area'''.format(tablename))
        magic.delete_from_table(engine, tablename)
        new_names = magic.get_column_names(engine, tablename)
        df = df.rename(columns={old_col: new_col for old_col, new_col in zip(df.columns, new_names)})
        flag = magic.load_df_into_db(engine, df, tablename, dict_types=db_dicttypes, mode='append')
        if flag == 0:
            magic.write_to_file(cp.LOG_FILE, r'''FAIL Loading table {}'''.format(f))
            magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for file {} ended in error'''.format(f))
            sys.exit(1)
        else:
            magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for file {} ended successfully'''.format(f))
            # Update timestamp column
            magic.set_table_column_value(engine, 'pdas_metadata', 'timestamp_file', timestamp_new, 'src_name', f)
            magic.set_table_column_value(engine, 'pdas_metadata', 'state', 'OK', 'src_name', f)


def get_data_from_query(user_nb_months=None):
    r"""
    =======================================================
        Extract and load SQL Queries Data in Staging Area
    =======================================================
    """
    # Display progress logs on stdout
    magic.write_to_file(cp.LOG_FILE, r'''Searching for database data sources''')
    engine_target = magic.db_connect(connection_name='pdas_db')
    engine_source = magic.db_connect(connection_name='ngc_db')
    df_metadata_before = magic.get_table_to_df(engine_target, 'pdas_metadata')
    # Scan folder and sub-folders
    for f in df_metadata_before[df_metadata_before['etl_type'] == 'sql']['src_name'].values.tolist():
        # Work with files defined in metadata table only
        magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for query source {} started'''.format(f))
        timestamp_old = magic.get_table_column_values_as_list(engine_target, 'pdas_metadata', 'timestamp_file', {'src_name': [f]})[0]
        timestamp_new = pd.read_sql_query(
            r'''SELECT max(Origdd) as date_dt
                FROM Prbunhea
                WHERE Prbunhea.Misc21 IN ('CONDOR', 'JBA-VF', 'JBA-VS', 'REVA', 'S65')
                AND Prbunhea.Misc6 IN ('OCN', 'OIN', 'OSA', 'VF ASIA', 'VF INDIA', 'VF Thailand', 'VFA', 'VFA Bangladesh', 'VFA Guangzhou', 'VFA HongKong', 'VFA India', 'VFA Indonesia', 'VFA Qingdao', 'VFA Shanghai', 'VFA Vietnam', 'VFA Zhuhai', 'VFI')
                AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots')
                AND Prbunhea.Misc25 IN ('DS', 'DYO', 'PG', 'REGULAR', 'ZCS', 'ZCUS', 'ZDIR', 'ZFGP', 'ZOT', 'ZRDS', 'ZTP', 'ZVFL', 'ZVFS')
                AND Not (Prbunhea.Qtyship=0 AND Prbunhea.Done=1) AND Prbunhea.POLocation NOT IN('CANCELED')''',
            engine_source
        )['date_dt'].max()
        print(timestamp_new)
        if timestamp_old == timestamp_new:
            magic.write_to_file(cp.LOG_FILE, r'''Data snapshot {} already loaded for max Origdd = {}'''.format(f, timestamp_new))
            continue
        # Calculate relative delta
        r = relativedelta.relativedelta(timestamp_new, timestamp_old)
        magic.set_table_column_value(engine_target, 'pdas_metadata', 'state', 'TBL', 'src_name', f)
        # Extract query
        magic.write_to_file(cp.LOG_FILE, r'''Extracting data from {}, depth = {} months'''.format(f, user_nb_months if user_nb_months else r.months))
        while True:
            try:
                df = pd.read_sql_query(
                    '''SELECT DISTINCT
                            LTRIM(RTRIM(Shipped.shipment)) as shipment,
                            LTRIM(RTRIM(Prbunhea.rdacode)) as rdacode,
                            LTRIM(RTRIM(Prbunhea.rfactory)) as rfactory,
                            LTRIM(RTRIM(Prbunhea.lot)) as lot,
                            LTRIM(RTRIM(Prbunhea.misc1)) as misc1,
                            LTRIM(RTRIM(Nbbundet.size)) as size,
                            LTRIM(RTRIM(Nbbundet.color)) as color,
                            LTRIM(RTRIM(Nbbundet.dimension)) as dimension,
                            LTRIM(RTRIM(Prbunhea.plan_date)) as plan_date,
                            LTRIM(RTRIM(Shipment.closed)) as closed,
                            LTRIM(RTRIM(Prbunhea.misc6)) as misc6,
                            SUM(Nbbundet.qty) as qty,
                            SUM(Shipped.unitship) as unitship,
                            LTRIM(RTRIM(Prbunhea.style)) as style,
                            LTRIM(RTRIM(Shshipto.ship_to_1)) as ship_to_1,
                            LTRIM(RTRIM(Shshipto_2.ship_to_1)) as ship_to_1_bis,
                            LTRIM(RTRIM(Prbunhea.ship_no)) as ship_no,
                            LTRIM(RTRIM(Prbunhea.misc25)) as misc25,
                            LTRIM(RTRIM(Prbunhea.misc41)) as misc41,
                            LTRIM(RTRIM(Prbunhea.store_no)) as store_no,
                            LTRIM(RTRIM(Prbunhea.origdd)) as origdd,
                            LTRIM(RTRIM(Prbunhea.revdd)) as revdd,
                            LTRIM(RTRIM(Shipped.shipdate)) as shipdate,
                            LTRIM(RTRIM(CONVERT(VARCHAR(8000), Prbunhea.notes))) as notes,
                            LTRIM(RTRIM(Prbunhea.misc18)) as misc18,
                            LTRIM(RTRIM(Shipment.misc2)) as misc2,
                            LTRIM(RTRIM(Prscale.desce)) as desce,
                            LTRIM(RTRIM(Prbunhea.misc21)) as misc21,
                            LTRIM(RTRIM(Shipment.firstclosedon)) as firstclosedon,
                            LTRIM(RTRIM(Prbunhea.done)) as done,
                            LTRIM(RTRIM(Shipmast.shipname)) as shipname

                        FROM Prbunhea

                        LEFT OUTER JOIN Nbbundet WITH (nolock) ON (Prbunhea.Id_Cut=Nbbundet.Id_Cut)
                        LEFT OUTER JOIN Shipped WITH (nolock)ON (Prbunhea.Season=Shipped.Season AND Prbunhea.Style=Shipped.Style AND Prbunhea.Lot=Shipped.Cut AND Nbbundet.Color=Shipped.Color AND Nbbundet.Size=Shipped.Size AND Nbbundet.Dimension=Shipped.Dimension)
                        LEFT OUTER JOIN Shipment WITH (nolock)ON (Shipped.Shipment=Shipment.Shipment)
                        LEFT OUTER JOIN Shshipto WITH (nolock) ON (Prbunhea.Rdacode=Shshipto.Factory)
                        LEFT OUTER JOIN shshipto as Shshipto_2 WITH (nolock) ON (Prbunhea.Rfactory=Shshipto_2.Factory)
                        LEFT OUTER JOIN prscale WITH (nolock) ON (nbbundet.size=prscale.scale)
                        LEFT OUTER JOIN Shipmast WITH (nolock) ON (Shipmast.shipno=Prbunhea.Store_No)

                        WHERE (Prbunhea.Origdd >= (DATEADD(month, {}, GETDATE())) AND Prbunhea.Misc21 IN ('CONDOR', 'JBA-VF', 'JBA-VS', 'REVA', 'S65') AND Prbunhea.Misc6 IN ('OCN', 'OIN', 'OSA', 'VF ASIA', 'VF INDIA', 'VF Thailand', 'VFA', 'VFA Bangladesh', 'VFA Guangzhou', 'VFA HongKong', 'VFA India', 'VFA Indonesia', 'VFA Qingdao', 'VFA Shanghai', 'VFA Vietnam', 'VFA Zhuhai', 'VFI') AND Prbunhea.Misc1 IN ('50 VANS FOOTWEAR', '503', '503 VN_Footwear', '508', '508 VN_Snow Footwear', '56 VANS SNOWBOOTS', 'VANS Footwear', 'VANS FOOTWEAR', 'VANS Snowboots', 'VANS SNOWBOOTS', 'VF  Vans Footwear', 'VN_Footwear', 'VN_Snow Footwear', 'VS  Vans Snowboots') AND Prbunhea.Misc25 IN ('DS', 'DYO', 'PG', 'REGULAR', 'ZCS', 'ZCUS', 'ZDIR', 'ZFGP', 'ZOT', 'ZRDS', 'ZTP', 'ZVFL', 'ZVFS') AND Not (Prbunhea.Qtyship=0 AND Prbunhea.Done=1) AND Prbunhea.POLocation NOT IN('CANCELED') AND  Not(Nbbundet.qty=0))

                        GROUP BY Shipped.shipment, Prbunhea.rdacode, Prbunhea.rfactory, Prbunhea.lot, Prbunhea.misc1, Nbbundet.size, Nbbundet.color, Nbbundet.dimension, Prbunhea.plan_date, Shipment.closed, Prbunhea.misc6, Prbunhea.style, Shshipto.ship_to_1, Shshipto_2.ship_to_1, Prbunhea.ship_no, Prbunhea.misc25, Prbunhea.misc41, Prbunhea.store_no, Prbunhea.origdd, Prbunhea.revdd, Shipped.shipdate, CONVERT(VARCHAR(8000), Prbunhea.notes), Prbunhea.misc18, Shipment.misc2, Prscale.desce, Prbunhea.misc21, Shipment.firstclosedon, Prbunhea.done, Shipmast.shipname
                        '''.format(user_nb_months if user_nb_months else r.months),
                    engine_source
                )
            except SQLAlchemyError:
                continue
            break

        # load the staging table
        tablename = magic.get_table_column_values_as_list(engine_target, 'pdas_metadata', 'table_name', {'src_name': [f]})[0]
        magic.write_to_file(cp.LOG_FILE, r'''Loading table {} in staging area'''.format(tablename))
        magic.delete_from_table(engine_target, tablename)
        new_names = magic.get_column_names(engine_target, tablename)
        df = df.rename(columns={old_col: new_col for old_col, new_col in zip(df.columns, new_names)})
        flag = magic.load_df_into_db(engine_target, df, tablename, mode='append')
        if flag == 0:
            magic.write_to_file(cp.LOG_FILE, r'''FAIL Loading table {}'''.format(f))
            magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for query {} ended in error'''.format(f))
            sys.exit(1)
        else:
            magic.write_to_file(cp.LOG_FILE, r'''Processing ETL for query {} ended successfully ({} rows loaded)'''.format(f, df.shape[0]))
            # Update timestamp column
            magic.set_table_column_value(engine_target, 'pdas_metadata', 'timestamp_file', timestamp_new, 'src_name', f)
            magic.set_table_column_value(engine_target, 'pdas_metadata', 'state', 'OK', 'src_name', f)


if __name__ == '__main__':
    magic.write_to_file(cp.LOG_FILE, '''#### ETL BEGIN ####\n\n\n''', with_time_stamp=False)
    magic.write_to_file(cp.LOG_FILE, '''## FILES ##''', with_time_stamp=False)
    get_data_from_extracts()
    magic.write_to_file(cp.LOG_FILE, '''\n\n''', with_time_stamp=False)
    magic.write_to_file(cp.LOG_FILE, '''## QUERIES ##''', with_time_stamp=False)
    get_data_from_query(1)
    magic.write_to_file(cp.LOG_FILE, '''\n\n''', with_time_stamp=False)
    magic.write_to_file(cp.LOG_FILE, '''#### ETL END ####\n\n\n''', with_time_stamp=False)
