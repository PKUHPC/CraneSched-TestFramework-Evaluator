import pandas as pd
import os
import sys

def read_csv(job_table_path, columns):
    with open(job_table_path, 'r', errors='ignore') as f:
        df = pd.read_csv(f, names=columns, header=None)
    return df

def data_clean(df):
    cols = ['id_user', 'id_qos', 'cpus_req', 'nodes_alloc', 'timelimit', 'time_submit', 'time_start', 'time_end', 'priority', 'state']
    df = df[cols]

    df = df.loc[df['time_start'] != 0]
    df = df.loc[df['time_end'] != 0]
    df = df.loc[df['time_submit'] != 0]
    df = df.loc[df['timelimit'] != 0]

    df['id_user'] = pd.factorize(df['id_user'])[0]

    print(df.head())

    return df

if __name__ == '__main__':
    job_table_path = sys.argv[1]
    job_table_desc_path = sys.argv[2]
    output_path = sys.argv[3]

    job_table_desc = pd.read_csv(job_table_desc_path, header=None)
    columns = job_table_desc.iloc[0].tolist()
    df = read_csv(job_table_path, columns)
    df = data_clean(df)

    df.to_csv(output_path, index=False)


