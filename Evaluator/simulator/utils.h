#include<bits/stdc++.h>

using namespace std;

const int INF = 2147483647;

struct Resource{
    int cpu;
    int mem;

    Resource operator-(const Resource &r){
        return {cpu - r.cpu, mem - r.mem};
    }
    Resource operator+(const Resource &r){
        return {cpu + r.cpu, mem + r.mem};
    }
    bool operator <=(const Resource &r){
        return cpu <= r.cpu && mem <= r.mem;
    }
    bool operator >=(const Resource &r){
        return cpu >= r.cpu && mem >= r.mem;
    }
    bool operator ==(const Resource &r){
        return cpu == r.cpu && mem == r.mem;
    }
    Resource ckmin(const Resource &r){
        return {min(cpu, r.cpu), min(mem, r.mem)};
    }
    bool empty(){
        return cpu == 0 && mem == 0;
    }
};

struct Node;

struct Task{
    int id;
    int submit_time;

    int timelimit;
    int predict_time;

    int node_num;
    Resource resource_req;
    int execution_time;

    int priority;

    int start_time;
    vector<Node*> assigned_node;
    bool ended;

    Task(int id, int submit_time, int timelimit, int predict_time, int node_num, Resource resource_req, int execution_time):
        id(id), submit_time(submit_time), timelimit(timelimit), predict_time(predict_time), node_num(node_num), resource_req(resource_req), execution_time(execution_time), start_time(-1), ended(false) {}
};

struct Node{
    int id;
    
    Resource resource_avail;
    Resource resource_total;

    map<int, Resource> time_avail_res_map; // time -> resource
    unordered_set<Task*> task_set;

    Node(int id, Resource resource_total):
        id(id), resource_total(resource_total), resource_avail(resource_total){}

    void build_time_avail_res_map(){
        time_avail_res_map.clear();
        time_avail_res_map.insert({0, resource_total});
        for(auto &task: task_set){
            add_task_to_map(task, task->start_time, task->start_time + task->timelimit);
        }
    }

    void add_task_to_map(Task *p, int start_time = -1, int end_time = -1){
        if(start_time == -1) start_time = p->start_time;
        if(end_time == -1) end_time = start_time + p->predict_time;
        auto it = time_avail_res_map.upper_bound(start_time);
        assert(it != time_avail_res_map.begin());
        --it;
        while(it != time_avail_res_map.end() && it->first < end_time){
            Resource tmp = it->second;
            int segl = it->first;
            int segr = next(it) == time_avail_res_map.end() ? INF : next(it)->first;
            it = time_avail_res_map.erase(it);

            int l = max(segl, start_time);
            int r = min(segr, end_time);
            vector<pair<int, Resource>> tmp_vec;
            if(l > segl){
                tmp_vec.push_back({segl, tmp});
            }
            if(l < r){
                tmp_vec.push_back({l, tmp - p->resource_req});
            }
            if(r < segr){
                tmp_vec.push_back({r, tmp});
            }
            for(auto &tmp: tmp_vec){
                time_avail_res_map.insert(tmp);
            }
        }
        it = time_avail_res_map.find(start_time);
        assert(it != time_avail_res_map.end());
        while(it != time_avail_res_map.begin() && prev(it)->second == it->second){
            it = prev(time_avail_res_map.erase(it));
        }
        it = time_avail_res_map.find(end_time);
        assert(it != time_avail_res_map.end());
        while(next(it) != time_avail_res_map.end() && next(it)->second == it->second){
            time_avail_res_map.erase(next(it));
        }
        assert(time_avail_res_map.rbegin()->second == resource_total);
    }

    void start_task(Task *p){
        resource_avail = resource_avail - p->resource_req;
        task_set.insert(p);
    }

    void end_task(Task *p){
        resource_avail = resource_avail + p->resource_req;
        task_set.erase(p);
    }
};
