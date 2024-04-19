#include "utils.h"

class scheduler {
public:
    enum scheduler_type {SJF, HRNN, MF, FIFO} mode;

    scheduler(vector<Node*>nodes, scheduler_type mode);

    void schedule();
    void add_task(Task *p);
    void start_task(Task *p);
    void end_task(Task *p);
    void check_task(Task *p);
    
    int NOW;
    vector<Node*>nodes;
    priority_queue<pair<int, Task*>, vector<pair<int, Task*>>, greater<pair<int, Task*>>> arrive_task_queue; // submit_time, task
    priority_queue<pair<double, Task*>, vector<pair<double, Task*>>, greater<pair<double, Task*>>> pending_task_queue; // submit_time / qos, task
    priority_queue<pair<int, Task*>, vector<pair<int, Task*>>, greater<pair<int, Task*>>> running_task_queue; // end_time, task
};