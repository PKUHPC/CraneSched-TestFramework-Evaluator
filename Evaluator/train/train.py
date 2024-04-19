import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.metrics import *
import lightgbm as lgb
import heapq
import os
import sys

def feature_extract(job_table_path, test_start_time):
    with open(job_table_path, 'r', errors='ignore') as f:
        data = pd.read_csv(f)

    cols = ['id_user', 'id_qos', 'cpus_req', 'nodes_alloc', 'timelimit', 'time_submit', 'time_start', 'time_end', 'state']
    data = data[cols]

    data = data.loc[data['time_end'] < test_start_time]

    data = data.loc[data['state'] == 3]
    data = data.drop("state", axis=1)

    data['timelimit'] = data['timelimit'] * 60
    data['running_time'] = data['time_end'] - data['time_start']
    data = data[data['running_time'] <= data['timelimit'] + 60]
    
    data['time_submit_standard'] = pd.to_datetime(data['time_submit'], unit='s')

    data['sub_year'] = data['time_submit_standard'].dt.year.astype(int)
    data['sub_quarter'] = data['time_submit_standard'].dt.quarter.astype(int)
    data['sub_month'] = data['time_submit_standard'].dt.month.astype(int)
    data['sub_day'] = data['time_submit_standard'].dt.day.astype(int)
    data['sub_hour'] = data['time_submit_standard'].dt.hour.astype(int)
    # data['sub_minute'] = data['time_submit_standard'].dt.minute.astype(int)
    # data['sub_second'] = data['time_submit_standard'].dt.second.astype(int)
    data['sub_day_of_year'] = data['time_submit_standard'].dt.dayofyear.astype(int)
    data['sub_day_of_month'] = data['time_submit_standard'].dt.day.astype(int)
    data['sub_day_of_week'] = data['time_submit_standard'].dt.dayofweek.astype(int)

    data = data.drop('time_submit_standard', axis=1)
    data = data.sort_values(by='time_submit').reset_index(drop=True)

    data['top1_time'] = 0
    data['top2_time'] = 0

    pq_running = [] # (time_end, idx), sorted by time_end
    pq_finished = {} # group by user, (idx, running_time), sorted by idx
    for idx, item in data.iterrows():
        time_submit = item['time_submit']
        while len(pq_running) > 0 and pq_running[0][0] < time_submit:
            _, idx_ = heapq.heappop(pq_running)
            user = data.loc[idx_]['id_user']
            running_time = data.loc[idx_]['running_time']
            if user not in pq_finished:
                pq_finished[user] = []
            heapq.heappush(pq_finished[user], (idx_, running_time))
            if(len(pq_finished[user]) > 2):
                heapq.heappop(pq_finished[user])
                
        user = item['id_user']
        if user not in pq_finished:
            data.at[idx, 'top1_time'] = 0
            data.at[idx, 'top2_time'] = 0
        elif len(pq_finished[user]) == 1:
            data.at[idx, 'top1_time'] = pq_finished[user][0][1]
            data.at[idx, 'top2_time'] = pq_finished[user][0][1]
        else:
            data.at[idx, 'top1_time'] = pq_finished[user][1][1]
            data.at[idx, 'top2_time'] = pq_finished[user][0][1]
        
        heapq.heappush(pq_running, (item['time_end'], idx))

    data['top2_mean'] = data[['top1_time', 'top2_time']].mean(axis=1)

    data = data.drop("time_start", axis=1)
    data = data.drop("time_end", axis=1)

    return data

def train_model(df, saving_folder = './'):
    cols = ['id_user', 'id_qos', 'cpus_req', 'nodes_alloc', 'timelimit', 'time_submit', 'sub_year', 'sub_quarter', 'sub_month', 'sub_day', 'sub_hour', 'sub_day_of_year', 'sub_day_of_month', 'sub_day_of_week', 'top1_time', 'top2_time', 'top2_mean', 'running_time']
    df = df[cols]

    df['id_qos'] = df['id_qos'].astype('int')
    df['id_user'] = df['id_user'].astype('int')

    X_train, X_test, y_train, y_test = train_test_split(df.drop(['running_time'], axis=1), df['running_time'], test_size=0.2, random_state=42)
    
    train_data = lgb.Dataset(X_train, label=y_train,  free_raw_data=True)
    test_data = lgb.Dataset(X_test, label=y_test,  free_raw_data=True)
    
    metric = 'l1'
    num_leaves = 1000
    max_depth = 20
    learning_rate = 0.1

    params = {
        'boosting_type': 'gbdt',
        'objective': 'regression',
        'metric': metric,
        'num_leaves': num_leaves,
        'learning_rate': learning_rate,
        'max_depth': max_depth,
        'early_stopping_rounds': 10,
        'verbose': 2,
        'seed': 42
    }
    num_round = 1000
    gbm = lgb.train(params, train_data, num_round, valid_sets=[test_data])

    if not os.path.exists(saving_folder):
        os.makedirs(saving_folder)
    gbm.save_model(saving_folder + 'model.txt')

def train(job_table_path, test_start_time, saving_folder = './'):
    df = feature_extract(job_table_path, test_start_time)
    train_model(df, saving_folder)

if __name__ == '__main__':
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print('Usage: python train.py job_table_path [date] [saving_folder]')
        sys.exit(1)

    job_table_path = sys.argv[1]

    if len(sys.argv) >= 3:
        test_start_time = pd.to_datetime(sys.argv[2])
    else:
        test_start_time = pd.Timestamp.now()

    if len(sys.argv) >= 4:
        saving_folder = sys.argv[3]
    else:
        saving_folder = './'

    test_start_time = (test_start_time - pd.to_datetime('1970-01-01')) // pd.to_timedelta('1s')

    train(job_table_path, test_start_time, saving_folder)
