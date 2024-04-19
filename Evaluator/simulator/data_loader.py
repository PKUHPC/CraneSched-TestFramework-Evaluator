import sys
import pandas as pd
import lightgbm as lgb
import shutil
import heapq

def feature_extract(job_table_path, test_end_time):
    with open(job_table_path, 'r', errors='ignore') as f:
        data = pd.read_csv(f)

    data = data.loc[data['time_submit'] < test_end_time]

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
        
        if item['state'] == 3:
            heapq.heappush(pq_running, (item['time_end'], idx))

    data['top2_mean'] = data[['top1_time', 'top2_time']].mean(axis=1)

    data = data.drop("time_start", axis=1)
    data = data.drop("time_end", axis=1)

    return data

if __name__ == '__main__':
    if len(sys.argv) != 5:
        print('Usage: python predict.py cluster_name model_path start_time end_time')
        sys.exit(1)
    
    job_table_path = '../data/' + sys.argv[1] + '/jobs_table.csv'
    node_info_path = '../data/' + sys.argv[1] + '/nodes_info.txt'
    mode_path = sys.argv[2] + '/model.txt'
    output_path = './'

    start_time = (pd.to_datetime(sys.argv[3]) - pd.to_datetime('1970-01-01')) // pd.to_timedelta('1s')
    end_time = (pd.to_datetime(sys.argv[4]) - pd.to_datetime('1970-01-01')) // pd.to_timedelta('1s')

    shutil.copyfile(node_info_path, output_path + '/nodes_info.txt')

    df = feature_extract(job_table_path, end_time)

    df = df[df['time_submit'] >= start_time]

    features = ['id_user', 'id_qos', 'cpus_req', 'nodes_alloc', 'timelimit', 'time_submit', 'sub_year', 'sub_quarter', 'sub_month', 'sub_day', 'sub_hour', 'sub_day_of_year', 'sub_day_of_month', 'sub_day_of_week', 'top1_time', 'top2_time', 'top2_mean']
    X_test = df[features]

    gbm = lgb.Booster(model_file=mode_path)
    y_pred = gbm.predict(X_test)

    df['time_pred'] = y_pred

    for idx, item in df.iterrows():
        if item['time_pred'] > item['timelimit']:
            df.at[idx, 'time_pred'] = item['timelimit']
        if item['time_pred'] <= 1:
            df.at[idx, 'time_pred'] = 1
        if item['running_time'] > item['timelimit']:
            df.at[idx, 'running_time'] = item['timelimit']
        item['time_pred'] = round(item['time_pred'])
    df['time_pred'] = df['time_pred'].astype(int)

    running_infos = ['time_submit', 'priority', 'timelimit', 'time_pred', 'running_time', 'nodes_alloc', 'cpus_req']
    df = df[running_infos]

    df = df[df['priority'] != 0]
    df = df[df['timelimit'] != 0]
    df = df[df['running_time'] != 0]
    df = df[df['nodes_alloc'] != 0]
    df = df[df['cpus_req'] != 0]

    df.sort_values(by='time_submit', inplace=True)

    df.to_csv(output_path + '/jobs_info.txt', index=False, sep=' ', header=False)
    
        

