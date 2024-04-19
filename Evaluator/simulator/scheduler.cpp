#include "scheduler.h"

using namespace std;

const int schedule_time = 1;

scheduler::scheduler(vector<Node*>nodes, scheduler_type mode): nodes(nodes), NOW(0), mode(mode) {}

void scheduler::schedule(){
    while(!arrive_task_queue.empty() && arrive_task_queue.top().first <= NOW){
        auto p = arrive_task_queue.top().second;
        arrive_task_queue.pop();
        switch(mode){
            case SJF:{
                pending_task_queue.push({p->predict_time, p});
                break;
            }
            case HRNN:{
                double wait_time = NOW - p->submit_time;
                pending_task_queue.push({-((p->predict_time + wait_time) / p->predict_time), p});
                break;
            }
            case MF:{
                pending_task_queue.push({-p->priority, p});
                break;
            }
            case FIFO:{
                pending_task_queue.push({p->submit_time, p});
                break;
            }
        }
    }
    while(!running_task_queue.empty() && running_task_queue.top().first <= NOW){
        auto p = running_task_queue.top().second;
        running_task_queue.pop();
        end_task(p);
        cerr << "end task: " << p->id << endl;
    }

    if(pending_task_queue.empty()){
        NOW += 1;
        return ;
    }
    for(auto &node: nodes){
        node->build_time_avail_res_map();
    }
    int cnt = 0;
    while(!pending_task_queue.empty()){
        auto p = pending_task_queue.top().second;
        pending_task_queue.pop();
        add_task(p);
        cnt += 1;
    }
    NOW += schedule_time;
}

void scheduler::add_task(Task *p) {
    sort(nodes.begin(), nodes.end(), [](Node* a, Node* b){
        // return a->task_set.size() < b->task_set.size();
        return a->resource_avail.cpu > b->resource_avail.cpu;
    });
    auto &node_list = p->assigned_node;
    for(auto &node: nodes){
        if(p->resource_req <= node->resource_total){
            node_list.push_back(node);
            if(p->node_num == node_list.size()){
                break;
            }
        }
    }
    if(p->node_num != node_list.size()){
        cout << "Error: nodes not enough" << endl;
        cout << "task id: " << p->id << endl;
        cout << "node num: " << p->node_num << endl;
        cout << "node list size: " << node_list.size() << endl;
        cout << "resource req: " << p->resource_req.cpu << " " << p->resource_req.mem << endl;
        node_list.clear();
        // assert(false);
        return;
    }
    vector<pair<int, int>> bad_time_interval;
    vector<int> time_val;
    time_val.push_back(NOW);
    time_val.push_back(INF);
    for(auto &node: node_list){
        auto st = node->time_avail_res_map.upper_bound(NOW);
        assert(st != node->time_avail_res_map.begin());
        --st;
        for(auto it = st; it != node->time_avail_res_map.end(); it++){
            if(!(it->second >= p->resource_req)){
                int l = it->first;
                int r = INF;
                if(next(it) != node->time_avail_res_map.end()){
                    r = next(it)->first;
                }
                l = max(l, NOW);
                assert(l < r);
                bad_time_interval.push_back({l, r});
                time_val.push_back(l);
                time_val.push_back(r);
            }
        }
    }
    sort(time_val.begin(), time_val.end());
    time_val.erase(unique(time_val.begin(), time_val.end()), time_val.end());
    vector<int> is_bad(time_val.size(), 0);
    for(auto &interval: bad_time_interval){
        int l = lower_bound(time_val.begin(), time_val.end(), interval.first) - time_val.begin();
        int r = lower_bound(time_val.begin(), time_val.end(), interval.second) - time_val.begin();
        is_bad[l] += 1;
        is_bad[r] -= 1;
    }
    for(int i = 1; i < is_bad.size(); i++){
        is_bad[i] += is_bad[i - 1];
    }
    int start_time = time_val[0];
    for(int i = 0; i + 1 < is_bad.size(); i++){
        if(is_bad[i] != 0){
            start_time = time_val[i + 1];
        }
        else{
            if(time_val[i + 1] - start_time >= p->predict_time){
                p->start_time = start_time;
                break;
            }
        }
    }
    assert(p->start_time != -1);
    assert(p->start_time >= NOW);
    for(auto &node: node_list){
        node->add_task_to_map(p);
    }
    if(p->start_time == NOW){
        start_task(p);
    }
    else{
        node_list.clear();
        p->start_time = -1;
        arrive_task_queue.push({p->submit_time, p});
    }
}

void scheduler::start_task(Task *p) {
    cerr << "start task: " << p->id << " at " << p->start_time << endl;
    for(auto &node: p->assigned_node){
        assert(node->resource_avail >= p->resource_req);
        node->start_task(p);
    }
    running_task_queue.push({p->start_time + p->execution_time, p});
}

void scheduler::end_task(Task *p) {
    for(auto &node: p->assigned_node){
        node->end_task(p);
    }
    p->ended = true;
}

void scheduler::check_task(Task *p) {
    if(p->ended) return;
    assert(p->execution_time > p->predict_time);
}