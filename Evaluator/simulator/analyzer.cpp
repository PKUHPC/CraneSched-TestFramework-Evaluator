#include "utils.h"

vector<Node*> nodes;
vector<Task*> tasks;

void read_node(){
    ifstream fin;
    fin.open("nodes_info.txt");
    if(!fin.is_open()){
        cerr << "nodes_info.txt not found" << endl;
        exit(1);
    }
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

void analysis_simulation_result(vector<Task*> tasks, int l, int r, string name = ""){
    tasks.clear();
    string file_name = name + "_simulation_result.txt";
    ifstream fin;
    fin.open(file_name);
    if (!fin.is_open()) {
        cerr << file_name << " not found" << endl;
        return ;
    }
    while(!fin.eof()){
        int submit_time, ended, start_time, execution_time, node_num, cpu_req;
        fin >> submit_time >> ended >> start_time >> execution_time >> node_num >> cpu_req;
        if(fin.eof()) break;
        tasks.push_back(new Task(tasks.size(), submit_time, 0, 0, node_num, {cpu_req, 0}, execution_time));
        tasks.back()->ended = ended;
        tasks.back()->start_time = start_time;
    }
    fin.close();

    int test_task_num = 0;
    double avg_pending_time = 0;
    double avg_bounded_slowdown = 0;
    double cpu_used_time = 0;

    for(auto &task: tasks){
        if(!task->ended) {
            continue;
        }
        test_task_num += 1;
        avg_pending_time += task->start_time - task->submit_time;
        avg_bounded_slowdown += (double)(task->start_time - task->submit_time + max(task->execution_time, 60)) / max(task->execution_time, 60);
        if(task->start_time + task->execution_time < l) {
            continue;
        }
        if(task->start_time > r) {
            continue;
        }
        cpu_used_time += (double)task->node_num * task->resource_req.cpu * (min(r, task->start_time + task->execution_time) - max(l, task->start_time));
    }

    avg_pending_time /= test_task_num;
    avg_bounded_slowdown /= test_task_num;
    double cpu_total_time = accumulate(nodes.begin(), nodes.end(), 0.0, [](double a, Node* b){
        return a + b->resource_total.cpu;
    }) * (r - l);
    
    // cout << name << ": " << endl;
    // cout << "avg_pending_time: " << avg_pending_time << endl;
    // cout << "avg_bounded_slowdown: " << avg_bounded_slowdown << endl;
    // cout << "cpu_utilization: " << cpu_used_time / cpu_total_time << endl;

    ofstream fout;
    fout.open(name + "_analysis_result.txt");
    assert(fout.is_open());
    fout << "avg_pending_time: " << avg_pending_time << endl;
    fout << "avg_bounded_slowdown: " << avg_bounded_slowdown << endl;
    fout << "cpu_utilization: " <<cpu_used_time / cpu_total_time << endl;
    fout.close();
}


int main(int argc, char *argv[]){
    if(argc < 2){
        cerr << "Missing time interval length (days)" << endl;
        return 1;
    }
    if(argc > 2){
        cerr << "Too many arguments" << endl;
        return 1;
    }
    int interval = stoi(argv[1]);
    read_node();
    cerr << "node loaded" << endl;

    string policys[] = {"mf", "sjf", "hrnn", "fifo"};
    string predicts[] = {"timelimit", "time_pred"};
    string ratios[]  = {"x0.200000", "x0.400000", "x0.600000", "x0.800000", "x1.000000", "x1.200000", "x1.400000", "x1.600000", "x1.800000", "x2.000000"};
    
    for(int i = 0; i < 4; i++){
        for(int j = 0; j < 2; j++){
            for(int k = 0; k < 10; k++){
                string name = policys[i] + "_" + predicts[j] + "_" + ratios[k];
                analysis_simulation_result(tasks, 0, 60 * 60 * 24 * interval / (0.2 * (k + 1)), name);
            }
        }
    }
    return 0;
}