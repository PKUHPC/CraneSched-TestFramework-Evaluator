#include "scheduler.h"

scheduler::scheduler_type type = scheduler::scheduler_type::MF;
const double Ratio = 1.0;
const bool use_predict = true;
string name = "mf_time_pred_x" + to_string(Ratio);

vector<Node*> nodes;
vector<Task*> tasks;

void read_node(){
    ifstream fin;
    fin.open("./nodes_info.txt");
    assert(fin.is_open());
    int node_cpu, node_mem;
    string node_name;
    int num;
    while(fin >> node_cpu >> node_mem >> num){
        for(int i = 0; i < num; i++){
            Node *node = new Node(nodes.size(), {node_cpu, node_mem});
            nodes.push_back(node);
        }
    }
    fin.close();
}

void load_data(){
    read_node();
    ifstream fin;
    fin.open("./jobs_info.txt");
    assert(fin.is_open());
    int submit_time, priority, timelimit, predict_lgb, execution_time, node_num, cpu_req;
    while(fin >> submit_time >> priority >> timelimit >> predict_lgb >> execution_time >> node_num >> cpu_req){
        cpu_req /= node_num;
        int predict_time = use_predict ? predict_lgb : timelimit;

        assert(execution_time <= timelimit);
        assert(predict_time >= 1);
        assert(predict_time <= timelimit);
        
        Task *task = new Task(tasks.size(), submit_time, timelimit, predict_time, node_num, {cpu_req, 0}, execution_time);
        tasks.push_back(task);
    }
    fin.close();

    sort(tasks.begin(), tasks.end(), [](Task *a, Task *b){
        return a->submit_time < b->submit_time;
    });
    int start_time = tasks[0]->submit_time;
    for(auto &task: tasks){
        task->submit_time -= start_time;
        task->submit_time = round(task->submit_time / Ratio);
    }
}

void save_simulation_result(vector<Task*> tasks){
    ofstream fout;
    fout.open(name + "_simulation_result.txt");
    assert(fout.is_open());
    for(auto &task: tasks){
        fout << task->submit_time << " " << task->ended << " " << task->start_time << " " << task->execution_time << " " << task->node_num << " " << task->resource_req.cpu << endl;
    }
    fout.close();
    cerr << "saved to " << name + "_simulation_result.txt" << endl;
}

int main(){
    load_data();
    scheduler S(nodes, type);
    random_shuffle(tasks.begin(), tasks.end());
    for(auto &task: tasks){
        S.arrive_task_queue.push({task->submit_time, task});
    }
    S.NOW = S.arrive_task_queue.top().first;
    int st = S.NOW;
    while(!S.arrive_task_queue.empty() || !S.pending_task_queue.empty() || !S.running_task_queue.empty()){
        S.schedule();
    }
    cerr << "test name:" << name << endl;
    cerr << "Simulation done!" << endl;
    
    save_simulation_result(tasks);
    return 0;
}