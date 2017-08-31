import numpy as np
import pandas as pd
import re
import math
import os
import json
import traceback
import sys
from urllib.parse import quote_plus
import locale
from functools import reduce
locale.setlocale(locale.LC_ALL, '')
from datetime import datetime
import datefinder
from collections import Counter
import settings as cp
from sqlalchemy import Table, Column, ForeignKey, create_engine, UniqueConstraint, schema, types, update, and_
from sqlalchemy.orm import sessionmaker
from sqlalchemy.engine import reflection
from sqlalchemy.engine.url import URL
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.pool import NullPool
from sqlalchemy.types import Integer, VARCHAR, Float, Date, DateTime

metadata = schema.MetaData()


#######################################
#### String manipulation - related ####
#######################################


def rewrite_with_technical_convention(string):
    r"""
    Remove any special characters, digits or spaces and replace by underscores
    Return lowercase string
    """
    tmp = re.sub('[^a-zA-Z0-9_ ]', '', str(string))
    tmp = re.sub(' +', '_', tmp)
    return tmp.lower().strip('_')


def rewrite_with_functional_convention(string, field_name = None, field_list_to_rewrite = None):
    r"""
    Returns the input string with Capital letters and spaces instead of underscores
    """
    if string:
        if field_list_to_rewrite is None or field_name in field_list_to_rewrite:
            if is_float(string) or is_integer(string):
                return locale.format("%d", string, grouping=True)
            elif is_integer(string):
                return string
            else:
                return string.replace('_', ' ').title()

    return string


def is_integer(string):
    r"""
    Returns True if the string parameter can be converted into an integer. False otherwise
    """
    if isinstance(string, int) or (not pd.isnull(string) and re.match(cp.FORMAT_INT, str(string))):
        return True
    else:
        return False


def is_float(string):
    r"""
    Returns True if the string parameter can be converted into a float. False otherwise
    """
    if isinstance(string, float) or (not pd.isnull(string) and re.match(cp.FORMAT_FLOAT, str(string))):
        return True
    else:
        return False


def normalize_numeric_format(string):
    r"""
    Remove the special characters in a numeric string
    """
    if not pd.isnull(string):
        return str(string).replace(',', '').strip('%')


def convert_string_to_int(string):
    r"""
    Convert the input string to integer format if possible
    Otherwise return the input string parameter
    """
    # Check if string can be converted to integer
    if is_integer(string):
        return int(normalize_numeric_format(string))
    else:
        return string


def convert_string_to_float(string):
    r"""
    Convert the input string to float format if possible
    Otherwise return the input string parameter
    """
    # Check if string can be converted to float
    if is_float(string):
        return float(normalize_numeric_format(string))
    else:
        return string


def is_datetime(string):
    r"""
    Returns True if the string parameter can be converted into a datetime. False otherwise
    """
    pattern = re.compile(r"""([^0-9/\-.:]+)""")
    if not pd.isnull(string) and [l for l in datefinder.find_dates(str(string))] and not(re.search(pattern, string)):
        return True
    else:
        return False


def normalize_date_format(string):
    r"""
    Append 01 when the string is a month date format
    Remove special characters in a date string.
    """
    if not pd.isnull(string):
        format_regex = re.compile(cp.FORMAT_DATES['MONTH_DATE'])
        if re.search(format_regex, string):
            string = '01' + string
        format_regex = re.compile(cp.FORMAT_DATES['MONTH_DATE_ISO'])
        if re.search(format_regex, string):
            string = string + '01'
        return re.sub(r"""[./-]""", '', string)


def convert_string_to_datetime(string):
    r"""
    Convert the input string to datetime format if possible
    Otherwise return the input string parameter
    """
    # Check if string can be converted to datetime
    if is_datetime(string):
        return [l for l in datefinder.find_dates(str(string))]
    else:
        return string


def identify_date_format(table, column):
    r"""
    Check the datetime format by analysing ...
    """
    dict_count_format = {}
    for date_format in cp.FORMAT_DATES:
        format_regex = re.compile(cp.FORMAT_DATES[date_format])
        list_date_format = [[num, 1] if re.search(format_regex, c) else [num, 0] for num, c in enumerate(table[column]) if not pd.isnull(c)]
        dict_count_format[date_format] = sum(i[1] for i in list_date_format)
    # Count comparison
    final_format = max(dict_count_format, key=dict_count_format.get)
    return final_format


def get_pattern(filename, list_pattern):
    r"""
    Return pattern if filename matches one and exactly one of the pattern from list_pattern
    Otherwise return None
    """
    test = [pattern for pattern in list_pattern if pattern.lower() in filename.lower()]
    if test:
        return max(test, key=len)
    else:
        return None


def get_modified_date(filename):
    r"""
    Return timestamp from filename
    """
    try:
        mtime = os.path.getmtime(filename)
    except OSError:
        mtime = 0
    return datetime.fromtimestamp(mtime).strftime("%Y-%m-%d %H:%M:%S")


def compare_two_lists(firstlist, secondlist):
    r"""
    Check if two lists given in arguments are equal element by element at same index position
    """
    if firstlist is None or secondlist is None or len(firstlist) != len(secondlist):
        return False
    else:
        if [idx for idx, pair in enumerate(zip(firstlist, secondlist)) if pair[0] == pair[1]]:
            return True
        else:
            return False


def get_nested_lists_intersection(nestedlist):
    r"""
    Generates the intersection between every lists inside a list
    """
    result = set(nestedlist[0])
    for s in nestedlist[1:]:
        result.intersection_update(s)
    return result


def flattern(nestedlist):
    rt = []
    for i in nestedlist:
        if isinstance(i, list):
            rt.extend(flattern(i))
        else:
            rt.append(i)
    return rt


def read_file(inputfile):
    r"""
    [Generator] Open and read the file line by line
    """
    with open(inputfile, 'r', encoding='ISO-8859-1') as f:
            for l in f:
                yield l


def max_occurence_char_in_list(inputlist, charlist):
    r"""
    [Generator] Count character occurences in inputlist foreach character in charlist
    Returns the character and occurences with max occurences
    """
    for line in inputlist:
        yield max([(d, line.count(d)) for d in charlist], key=lambda x: x[1])


def find_delimiter(inputfile):
    r"""
    Read a flat file and returns the delimiter having the greatest number of occurences
    """

    delimiter_list = [',', ':', ';', '|', '\t', '^', '#', '+', '%', '~', '*', '-', '_', '!', '=', '&', '$']

    delimiter = Counter(
        [l for l in max_occurence_char_in_list(
            [l for l in read_file(inputfile)], delimiter_list)]
    ).most_common(1)[0][0]
    if delimiter:
        return delimiter[0]
    else:
        return None


def map_parameters(string):
    r"""
    Read a flat file and returns the delimiter having the greatest number of occurences
    """
    pattern = re.compile(r"""<(iap_param_\w+)>""")
    m = re.search(pattern, str(string))
    if m:
        #lookup DICT_PARAMETER
        if m.group(1) in cp.DICT_PARAMETER:
            return cp.DICT_PARAMETER[m.group(1)]
    else:
        return string


def write_to_file(file_path, text, with_time_stamp=True, clean_file=False):
    filename = file_path

    if clean_file: # Eventually empty the file
        open(filename, 'w').close()

    if with_time_stamp: # Eventually add timestamp
        text = datetime.now().strftime('%Y-%m-%d %H:%M:%S') + ': ' + text + '\n'

    f = open(filename, 'a')
    f.write(text)
    f.close()


##########################
#### Pandas - related ####
##########################


def str_join(df, sep, cols):
    r"""
    Returns column concatenated from list of columns
    """
    return reduce(lambda x, y: x.astype(str).str.cat(y.astype(str), sep=sep),
                  [df[col] for col in cols])


def format_dataframe_numeric_values(df, dict_formatting):
    r"""
    Returns dataframe with applied formatting
    """
    for col, formatting in dict_formatting.items():
        if formatting is None:
            continue
        if '%' in formatting:
            df[col] = np.where(pd.isnull(df[col]), formatting.format(0), df[col].apply(lambda x: formatting.format(x*100)))
        else:
            df[col] = np.where(pd.isnull(df[col]), formatting.format(0), df[col].apply(lambda x: formatting.format(x)))
    return df


def unformat_dataframe_numeric_values(df, dict_dtypes):
    r"""
    Returns dataframe with raw formatting
    """
    for col, dtype in dict_dtypes.items():
        if col in df.columns:
            if 'int' in str(dtype) or 'float' in str(dtype):
                df[col] = df[col].fillna(np.nan)
                if any('%' in str(x) for x in df[col]):
                    df[col] = df[col].apply(lambda x: x.replace(',', '.'))
                    df[col] = df[col].apply(lambda x: convert_string_to_float(x) / 100 if '.' in x else convert_string_to_int(x) / 100)
                    df[col] = df[col].astype('float64')
                else:
                    df[col] = df[col].apply(lambda x: convert_string_to_float(x) if '.' in x else convert_string_to_int(x))
                    df[col] = df[col].apply(pd.to_numeric, errors='coerce')
    return df


def drop_cols_y(table):
    r"""
    Drop overlapped cols from merge, and rename the ones we keep (get rid of the _x suffix)
    """
    to_drop = [x for x in table if x.endswith('_y')]
    to_rename = [x for x in table if x.endswith('_x')]
    dict_cols_to_rename = {x: re.sub(r'''_x$''', '', x) for x in to_rename}
    table = table.rename(columns=dict_cols_to_rename)
    return table.drop(to_drop, axis=1)


def drop_cols_null(df):
    r"""
    Drop columns with only None values
    """
    for col in df.columns:
        if (all(pd.isnull(x) for x in df[col].unique())):
            df = df.drop(col, 1)
    return df


def change_column_order(df, col_name, index):
    r"""
    Switch column position using its index
    """
    cols = df.columns.tolist()
    if not(isinstance(col_name, list)):
        col_name = [col_name]
    for col in col_name:
        cols.remove(col)
        cols.insert(index, col)
        index += 1
    return df[cols]


def transcode_col_using_dict(df, list_col, dict_transco):
    r"""
    Take an input dataframe and mapping dictionary and transcode cols to dictionary value looking up on dictionary keys
    """
    if dict_transco:
        if not(isinstance(list_col, list)):
            list_col = [list_col]
        for col in list_col:
            if col in df.columns:
                df[col] = df[col].map(lambda x: dict_transco[x])
    return df


def display_table(table, nrows):
    r"""
    Display nrows number of rows of table table using to_string method of pandas
    """
    print(table.to_string(max_rows=nrows))


def remove_header_from_df(table):
    r"""
    Iterate over dataframe rows and remove duplicated header
    """
    df = pd.DataFrame(
        [row for row in table.values.tolist() if not(compare_two_lists([str(x).lower() for x in row], table.columns))],
        columns=table.columns
    )
    return df


def chunker(seq, size):
    # from http://stackoverflow.com/a/434328
    return (seq[pos:pos + size] for pos in range(0, len(seq), size))


def load_df_into_db(engine, table, name, dict_types=None, mode='append', index=False):
    r"""
    Load the dataframe into a database ...
    """
    # Check if dataframe is empty
    if table.empty:
        return 0
    chunksize = int(len(table) / 10) if len(table) > 10 else len(table)   # 10%
    try:
        for i, cdf in enumerate(chunker(table, chunksize)):
            if mode == 'replace' and i > 0:
                mode = 'append'
            cdf.to_sql(con=engine, name=name, if_exists=mode, index=index, dtype=dict_types, schema='vcdwh')
    except SQLAlchemyError:
        exc_type, exc_value, exc_traceback = sys.exc_info()
        lines = traceback.format_exception(exc_type, exc_value, exc_traceback)
        for line in lines:
            write_to_file(cp.LOG_FILE, line)
        return 0
    else:
        return 1


def get_table_to_df(engine, table, dictfilter=None, output_cols=None):
    r"""
    Extract data from table and return a dataframe
    """
    alchemy_table = Table(table, metadata, autoload=True, autoload_with=engine, schema="vcdwh.vcdwh")
    Session = sessionmaker(bind=engine)
    session = Session()
    queryset = session.query(alchemy_table)
    if dictfilter:
        for key, values in dictfilter.items():
            if isinstance(values, dict):

                if not(isinstance(values['values'], list)):
                    values['values'] = [values['values']]
                # Lookup parameters from settings.py
                values['values'] = map_parameters(values['values'])
                # Transform string None in Python None
                values['values'] = [None if l == 'None' else l for l in values['values']]
                # convert the values in date or numeric
                if all(is_integer(l) for l in values['values']):
                    values['values'] = [convert_string_to_int(l) for l in values['values']]
                elif all(is_float(l) for l in values['values']):
                    values['values'] = [convert_string_to_float(l) for l in values['values']]
                elif all(is_datetime(l) for l in values['values']):
                    values['values'] = [convert_string_to_datetime(l) for l in values['values']]

                # Apply the various kind of filters
                if values['type'] == 'between':
                    queryset = queryset.filter(and_(getattr(alchemy_table.c, key) >= values['values'][0], getattr(alchemy_table.c, key) <= values['values'][-1]))
                if values['type'] == 'between open':
                    queryset = queryset.filter(and_(getattr(alchemy_table.c, key) > values['values'][0], getattr(alchemy_table.c, key) < values['values'][-1]))
                if values['type'] == '==':
                    queryset = queryset.filter(getattr(alchemy_table.c, key) == values['values'])
                if values['type'] == '>=':
                    queryset = queryset.filter(getattr(alchemy_table.c, key) >= values['values'])
                if values['type'] == '>':
                    queryset = queryset.filter(getattr(alchemy_table.c, key) > values['values'])
                if values['type'] == '<':
                    queryset = queryset.filter(getattr(alchemy_table.c, key) < values['values'])
                if values['type'] == '<=':
                    queryset = queryset.filter(getattr(alchemy_table.c, key) <= values['values'])
                if values['type'] == 'in':
                    if None in values['values']:
                        queryset_none = queryset.filter(getattr(alchemy_table.c, key).is_(None))
                        values['values'] = [v for v in values['values'] if v]
                        queryset_others = queryset.filter(getattr(alchemy_table.c, key).in_(values['values']))
                        queryset = queryset_none.union(queryset_others)
                    else:
                        queryset = queryset.filter(getattr(alchemy_table.c, key).in_(values['values']))
                if values['type'] == 'not in':
                        if None in values['values']:
                            queryset_none = queryset.filter(getattr(alchemy_table.c, key).isnot(None))
                            values['values'] = [v for v in values['values'] if v]
                            queryset = queryset_none.filter(getattr(alchemy_table.c, key).notin_(values['values']))
                        else:
                            queryset = queryset.filter(getattr(alchemy_table.c, key).notin_(values['values']))
                if values['type'] == 'like':
                    for pattern in values['values']:
                        queryset = queryset.filter(getattr(alchemy_table.c, key).ilike('%' + pattern + '%'))

            else:
                queryset = queryset.filter(getattr(alchemy_table.c, key).in_(values))
        result = pd.read_sql_query(queryset.statement, engine)
        result = result.rename(columns={col: col.replace(table + '_', '') for col in result.columns})
    else:
        result = pd.read_sql_table(table, engine, schema='vcdwh')
    session.close()
    # Convert dtypes to match with table types
    result = set_pandas_dtypes_with_db_table_types(result, get_column_types(engine, table))
    # output columns
    if output_cols:
        result = result[output_cols]
    return result


def merge_dfs(ldf, rdf):
    r"""
    Generic merging using dict structure like following:
    ldf/rdf = {'table': <table_name>, 'frame_data': dataframe, 'frame_rel': df_keys}
    """
    # Assign variables
    df_left = ldf['frame_data']
    df_right = rdf['frame_data']
    left_on = rdf['frame_rel']['l_field'].values[0]
    right_on = rdf['frame_rel']['r_field'].values[0]
    how = rdf['frame_rel']['how'].values[0]

    partition_fields = rdf['frame_rel']['partition_fields'].tolist()[0]
    if partition_fields and ',' in partition_fields:
        partition_fields = [x.strip() for x in partition_fields.split(',')]
    aggregation_fields = None
    if rdf['frame_rel']['aggregation_fields'].tolist()[0]:
        aggregation_fields = json.loads(rdf['frame_rel']['aggregation_fields'].tolist()[0])
    rename_fields = None
    if rdf['frame_rel']['rename_fields'].tolist()[0]:
        rename_fields = json.loads(rdf['frame_rel']['rename_fields'].tolist()[0])
    pivot_arguments = None
    if rdf['frame_rel']['pivot_arguments'].tolist()[0]:
        pivot_arguments = json.loads(rdf['frame_rel']['pivot_arguments'].tolist()[0])

    # check for pre-join aggregation
    if rdf['frame_rel']['agg_before_after_join'].values[0] and rdf['frame_rel']['agg_before_after_join'].values[0] == 'before':
        df_right = aggregate_df(df_right, partition_fields, aggregation_fields, rename_fields)
    # check for pre-join pivot
    if rdf['frame_rel']['pivot_before_after_join'].values[0] and rdf['frame_rel']['pivot_before_after_join'].values[0] == 'before':
        df_right = pivot_df(df_right, **pivot_arguments)
    # check if composite key
    if ',' in left_on:
        left_on = [x.strip() for x in left_on.split(',')]
    if ',' in right_on:
        right_on = [x.strip() for x in right_on.split(',')]
    # cross join case
    if how == 'cross':
        df_left['fake'] = 1
        df_right['fake'] = 1
        df_result = pd.merge(df_left, df_right, left_on=left_on, right_on=right_on, how='inner')
    # apply the merge for different cases
    else:
        df_result = pd.merge(df_left, df_right, left_on=left_on, right_on=right_on, how=how)
    # check for post-join aggregation
    if rdf['frame_rel']['agg_before_after_join'].values[0] and rdf['frame_rel']['agg_before_after_join'].values[0] == 'after':
        df_result = aggregate_df(df_result, partition_fields, aggregation_fields, rename_fields)
    # check for post-join pivot
    if rdf['frame_rel']['pivot_before_after_join'].values[0] and rdf['frame_rel']['pivot_before_after_join'].values[0] == 'after':
        df_result = pivot_df(df_result, **pivot_arguments)
    # Drop the duplicated columns
    df_result = drop_cols_y(df_result)
    return {'table': rdf['table'], 'frame_data': df_result, 'frame_rel': rdf['frame_rel']}


def combine_multiple_df(list_df, how='H'):
    r"""
    Combine multiple dataframes and return the resulting dataframe
    Parameters:
        - list_df: list of dictionnaries in this format {'frame': dataframe, 'key': <key_value>, 'how': <how>}
        - how: (default='H') how to combine
                H = horizontal (JOIN)
                V = vertical (UNION)
    """
    # if Join-Style
    if how == 'H':
        result = reduce(merge_dfs, list_df)['frame_data']
    else:
        if compare_two_lists(sorted(common_key), sorted(listdf_headers[0])):
            result = pd.concat(listdf)

    return result


def aggregate_df(df, partition_fields, aggregation_fields, rename_fields=None, as_index=False):
    r"""
    Aggregate a dataframe using partition_fields.
    The aggregated fields are calculated using the aggregation_fields.
    Returns a dataframe.
    """
    if partition_fields and aggregation_fields:
        for key, values in aggregation_fields.items():
            if not(isinstance(values, list)):
                values = [values]
            output = []
            for agg in values:
                output.append(cp.AGGREGATION_TYPE[agg])
            if len(output) == 1:
                output = output[0]
            aggregation_fields.update({key: output})
        df = df.groupby(partition_fields, as_index=as_index, sort=False).agg(aggregation_fields)
        #rename post-aggregation
    if rename_fields:
        if df.columns.nlevels > 1:
            df.columns = ['_'.join(col).strip('_') for col in df.columns.values]
        df = df.rename(columns=rename_fields)
    return df


def sort_df(df, sort_fields):
    r"""
    Sort a dataframe using sort_fields.
    Returns a dataframe.
    """
    if sort_fields:
        sort_columns = list(sort_fields.keys())
        sort_options = [True if sort_fields[k] == 'asc' else False for k in sort_columns if k in sort_fields]
        df = df.sort_values(sort_columns, ascending=sort_options)
    return df


def pivot_df(df, index_cols, pivot_field, value_field, aggregation_function=None, dict_rename=None):
    r"""
    Pivot a dataframe using pivot_field.
    Returns a dataframe.
    """
    if pivot_field and index_cols:
        # aggregate the dataframe to avoid duplicate index
        index_df = None
        if aggregation_function:
            dict_agg_value_field = {value_field: aggregation_function}
            partition_fields = [l for l in df.columns if l != value_field]
            df = aggregate_df(df, partition_fields, dict_agg_value_field, as_index=index_cols)
            if not(isinstance(index_cols, list)):
                index_df = df.index.get_level_values(index_cols).unique()
            df = df.reset_index()
        # do the pivot
        if 'object' in str(df[value_field].dtype):
            aggfunc = np.max
        else:
            aggfunc = np.sum
        df_result = df.pivot_table(index=index_cols, columns=pivot_field, values=value_field, aggfunc=aggfunc)
        # rename if necessary
        if dict_rename:
            df_result = df_result.rename(columns=dict_rename)
        # reindex because pivot pandas breaks the index ordering
        if index_df is not None:
            df_result = df_result.reindex(index_df)
        df_result = df_result.reset_index()
    return df_result


def unpivot_df(df, unpivoting_cols, non_moving_cols=None, output_var_name='type', output_value_col='value', pattern_to_remove_from_var_col=None):
    r"""
    Unpivots a dataframe using the parameters:
        - unpivoting_cols: the list of columns to move to row axis
        - non_moving_cols: the columns which should remain unchanged after unpivoting
        - output_var_name: the name for the created column containing the names of unpivoting_cols as values
        - output_value_col: the name of the column to receive the values contained in the unpivoting_cols
        - pattern_to_remove_from_var_col: A string pattern to remove from output_var_name values
    Returns a dataframe.
    """
    # Give default values
    if not(non_moving_cols):
        non_moving_cols = [l for l in df.columns if l not in unpivoting_cols]
    if unpivoting_cols:
        # Use melt function from Pandas
        df = pd.melt(
            df, id_vars=non_moving_cols, value_vars=unpivoting_cols, var_name=output_var_name, value_name=output_value_col
        )
        # Remove prefix from unpivoting_cols to
    if pattern_to_remove_from_var_col:
        df[output_var_name] = df[output_var_name].apply(lambda x: x.replace(pattern_to_remove_from_var_col, ''))
    return df


def convert_datetime_col(table):
    r"""
    Takes a dataframe table and convert every column with dtype object in datetime
    if the column values are in a DATETIME format like specified in cluster_params
    """
    table_test = table.head(1000)
    for col in table_test.columns:
        if all(pd.isnull(table_test[col])):
            table_test = table_test.drop(col, 1)
    list_col_candidates = [col for col in table_test.columns if table_test[col].dtype == 'object' and
                           all(is_datetime(str(l)) for l in table_test[col] if not pd.isnull(l))]
    dict_col_datetime = {col: 'datetime_{}'.format(identify_date_format(table, col)) for col in list_col_candidates}
    list_col_datetimedateUS = [e for e in dict_col_datetime.keys() if dict_col_datetime[e] == 'datetime_DATE_US']
    list_col_datetimedateEU = [e for e in dict_col_datetime.keys() if dict_col_datetime[e] == 'datetime_DATE_EU']
    list_col_datetimedateISO = [e for e in dict_col_datetime.keys() if dict_col_datetime[e] == 'datetime_DATE_ISO']
    list_col_datetimemonthdate = [e for e in dict_col_datetime.keys() if dict_col_datetime[e] == 'datetime_MONTH_DATE']
    list_col_datetimemonthdateISO = [e for e in dict_col_datetime.keys() if dict_col_datetime[e] == 'datetime_MONTH_DATE_ISO']
    # 2) apply conversion
    if list_col_datetimedateUS:
        table[list_col_datetimedateUS] = table[list_col_datetimedateUS].applymap(lambda x: normalize_date_format(x))
        table[list_col_datetimedateUS] = table[list_col_datetimedateUS].apply(pd.to_datetime, format="%m%d%Y", errors='coerce')
    if list_col_datetimedateEU:
        table[list_col_datetimedateEU] = table[list_col_datetimedateEU].applymap(lambda x: normalize_date_format(x))
        table[list_col_datetimedateEU] = table[list_col_datetimedateEU].apply(pd.to_datetime, format="%d%m%Y", errors='coerce')
    if list_col_datetimedateISO:
        table[list_col_datetimedateISO] = table[list_col_datetimedateISO].applymap(lambda x: normalize_date_format(x))
        table[list_col_datetimedateISO] = table[list_col_datetimedateISO].apply(pd.to_datetime, format="%Y%m%d", errors='coerce')
    if list_col_datetimemonthdate:
        table[list_col_datetimemonthdate] = table[list_col_datetimemonthdate].applymap(lambda x: normalize_date_format(x))
        table[list_col_datetimemonthdate] = table[list_col_datetimemonthdate].apply(pd.to_datetime, format="%d%m%Y", errors='coerce')
    if list_col_datetimemonthdateISO:
        table[list_col_datetimemonthdateISO] = table[list_col_datetimemonthdateISO].applymap(lambda x: normalize_date_format(x))
        table[list_col_datetimemonthdateISO] = table[list_col_datetimemonthdateISO].apply(pd.to_datetime, format="%Y%m%d", errors='coerce')


def convert_numeric_col(table):
    r"""
    Takes a dataframe table and convert every column with dtype object in either float or integer
    if the column values are in a FORMAT_FLOAT or FORMAT_INT format like specified in cluster_params
    """
    table_test = table.head(1000)
    for col in table_test.columns:
        if all(pd.isnull(table_test[col])):
            table_test = table_test.drop(col, 1)
    # look if majority is convertible
    list_col_float = []
    list_col_int = []
    for col in table_test.columns:
        if table_test[col].dtype == 'object':
            total_count = len([l for l in table_test[col] if not pd.isnull(l)])
            dict_count_format = {}
            dict_count_format['integer'] = sum([1 if is_integer(l) else 0 for l in table_test[col] if not pd.isnull(l)]) / total_count
            dict_count_format['float'] = sum([1 if is_float(l) else 0 for l in table_test[col] if not pd.isnull(l)]) / total_count
            max_format = max(dict_count_format, key=dict_count_format.get)
            if dict_count_format[max_format] < 0.80:
                continue
            else:
                if max_format == 'float':
                    list_col_float.append(col)
                else:
                    list_col_int.append(col)

    if list_col_int:
        table[list_col_int] = table[list_col_int].replace('-', np.NaN)
        table[list_col_int] = table[list_col_int].applymap(lambda x: normalize_numeric_format(x))  # Decision to separate INT and FLOAT although same functions applied
        table[list_col_int] = table[list_col_int].apply(pd.to_numeric, errors='coerce')
    if list_col_float:
        table[list_col_float] = table[list_col_float].replace('-', np.NaN)
        table[list_col_float] = table[list_col_float].applymap(lambda x: normalize_numeric_format(x))
        table[list_col_float] = table[list_col_float].apply(pd.to_numeric, errors='coerce')


def gen_types_from_pandas_to_sql(table):
    r"""
    Generate a dictionnary with the database types related to the dataframe dtypes
    """
    dtypedict = {}
    for i, j in zip(table.columns, table.dtypes):
        if 'object' in str(j):
            dtypedict.update({i: types.NVARCHAR(length=500)})
        if 'datetime' in str(j):
            dtypedict.update({i: types.DateTime()})
        if 'float' in str(j):
            dtypedict.update({i: types.Float(precision=3, asdecimal=True)})
        if 'int' in str(j):
            if max(
                [l for l in table[i].tolist() if not pd.isnull(l)]
            ) > cp.INT_LIMIT:
                dtypedict.update({i: types.BIGINT()})
            else:
                dtypedict.update({i: types.INT()})
    return dtypedict


def convert_dict_values_to_related_df_dtype(dataframe, inputdict):
    r"""
    First try to match the dictionnary keys to the dataframe column names.
    Returns the dict argument with values converted to the respective dtypes
    """
    dict_converted = {}
    for key, values in inputdict.items():
        if key in dataframe.columns:
            if 'datetime' in str(dataframe[key].dtype):
                dict_converted[key] = [convert_string_to_datetime(l) for l in values]
            if 'float' in str(dataframe[key].dtype):
                dict_converted[key] = [convert_string_to_float(l) for l in values]
            if 'int' in str(dataframe[key].dtype):
                dict_converted[key] = [convert_string_to_int(l) for l in values]
            else:
                dict_converted[key] = values
        else:
            continue
    return dict_converted


#################################
###### SQLALCHEMY - related #####
#################################


def db_connect(connection_name, encoding='latin-1'):
    r"""
    Performs database connection using database settings from configuration.py.
    Returns sqlalchemy engine instance
    """
    params = quote_plus(
        "DRIVER={};SERVER={};DATABASE={};UID={};PWD={}".format(
            'SQL Server Native Client 11.0',
            cp.ALCHEMY_DB[connection_name]['host'],
            cp.ALCHEMY_DB[connection_name]['database'],
            cp.ALCHEMY_DB[connection_name]['username'],
            cp.ALCHEMY_DB[connection_name]['password'],
        )
    )
    return create_engine(cp.ALCHEMY_DB[connection_name]['drivername'] + ':///?odbc_connect=%s' % params, encoding=encoding, poolclass=NullPool)


def get_table_column_values_as_list(engine, table, column, dictfilter=None):
    r"""
    Generic Select distinct values from a particular column with dictfilter as conditions
    """
    table = Table(table, metadata, autoload=True, autoload_with=engine, schema='vcdwh.vcdwh')
    Session = sessionmaker(bind=engine)
    session = Session()
    queryset = session.query(getattr(table.c, column))
    if dictfilter:
        for key, values in dictfilter.items():
            if type(values) == list:
                queryset = queryset.filter(getattr(table.c, key).in_(values))
            else:
                queryset = queryset.filter(getattr(table.c, key).ilike('%' + values + '%'))
        result = [r[0] for r in queryset.distinct()]
    else:
        result = [r[0] for r in session.query(getattr(table.c, column)).distinct()]
    session.close()
    return result


def set_table_column_value(engine, table, column, valueforupdate, colfilter, valuefilter):
    r"""
    Update generic function for a particular column with dictfilter as conditions
    """
    table = Table(table, metadata, autoload=True, autoload_with=engine, schema='vcdwh.vcdwh')
    kwargs = {column: valueforupdate}
    stmt = update(table).where(getattr(table.c, colfilter) == valuefilter).values(**kwargs)
    engine.execute(stmt)


def delete_from_table(engine, table, dictfilter=None):
    r"""
    Delete from table on conditions in dictfilter
    """
    table = Table(table, metadata, autoload=True, autoload_with=engine, schema='vcdwh.vcdwh')
    if dictfilter:
        for key, values in dictfilter.items():
            where_clause = getattr(table.c, key).in_(values)
        statement = table.delete().where(where_clause)
    else:
        statement = table.delete()
    engine.execute(statement)


def table_exists(engine, table):
    r"""
    Return True if table exists, else False
    """
    conn = engine.connect()
    test = engine.dialect.has_table(conn, table)
    conn.close()
    return test


def get_column_names(engine, table, column_type=None):
    r"""
    Return list with column names of table
    """
    insp = reflection.Inspector.from_engine(engine)
    list_of_dicts = insp.get_columns(table, schema='vcdwh')
    if column_type:
        if column_type == 'numeric':
            list_output = [col['name'] for col in list_of_dicts if col['type'] in (Integer, Float)]
        elif column_type == 'datetime':
            list_output = [col['name'] for col in list_of_dicts if col['type'] in (Date, DateTime)]
        else:
            list_output = [col['name'] for col in list_of_dicts if col['type'] in (VARCHAR)]
    else:
        list_output = [col['name'] for col in list_of_dicts]
    return list_output


def get_column_types(engine, table):
    r"""
    Return dict with column {name: type} of table
    """
    insp = reflection.Inspector.from_engine(engine)
    list_of_dicts = insp.get_columns(table)
    dict_output = {col['name']: col['type'] for col in list_of_dicts}
    return dict_output


def set_pandas_dtypes_with_db_table_types(df, dict_db_types):
    r"""
    Convert dataframe dtypes according to database table types
    """
    dict_pandastypes = {}
    for key, values in dict_db_types.items():
        if 'varchar' in str(values).lower():
            df[key] = df[key].astype('object')
        if 'datetime' in str(values).lower():
            df[key] = df[key].astype('datetime64[ns]')
        if 'float' in str(values).lower():
            df[key] = df[key].fillna(np.nan)
            df[key] = df[key].astype('float64')
        if 'int' in str(values).lower():
            df[key] = df[key].fillna(np.nan)
            df[key] = df[key].apply(pd.to_numeric, errors='coerce')
    return df


def adapt_filter_to_table(engine, table, dictfilter):
    r"""
    Return a dictionnary of filters adapted to the table passed as parameter
    """
    if dictfilter:
        # Remove fields that are not in table
        dictfilter_corrected = {}
        for k, v in dictfilter.items():
            if k in get_column_names(engine, table, None):
                dictfilter_corrected[k] = v
        dictfilter = dictfilter_corrected
    return dictfilter


def search_field_tables(engine, field):
    r"""
    Search in which table a particular field exists
    """
    insp = reflection.Inspector.from_engine(engine)
    list_of_tables = insp.get_table_names()
    list_output = []
    for table in list_of_tables:
        if field in [col['name'] for col in insp.get_columns(table)]:
            list_output.append(table)
    return list_output
