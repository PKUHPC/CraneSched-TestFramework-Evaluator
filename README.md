# Test Framework for HPC Scheduling Systems

This is a framework utilizing Mininet and Linux Namespace to test scheduling systems in large virtulized cluster.

## Quick Start 

1. Clone this repo with Git
2. Initialize the testing environment: 
```sh
bash utils/inst/init.sh
```
3. Install Mininet and the software to be tested: 
```sh
bash util/inst/XXX-install.sh
```
4. Modify `config.yaml` and `XXX-config.yaml` files according to your testing scenario.
5. Launch the test framework. 
    - On head node: 
    ```sh
    python crane-mininet.sh -c config.yaml --head
    ```
    - On other nodes:   
    ```sh
    python crane-mininet.sh -c config.yaml --crane-conf crane-config.yaml
    ```
6. After testing, you can clean the environment.
```sh
python crane-mininet.sh -c config.yaml --clean
```

(The instructions provided above utilize CraneSched as an illustrative example.)

## Directory Structure

This framework is organized into several key directories and files:

- `XXX-mininet.py`: The main script that launches the test framework.
- `config.yaml`: Contains test configurations, such as cluster details and IP subnet, which the framework reads.
- `crane-mininet.yaml`: Specifies the Crane configuration, which is read by the launched Craned instances.
- `slurm-mininet.conf`, `cgroup.conf`: Configuration files for Slurm, read by the launched Slurmd instances.
- `sync.sh`: A utility script to synchronize files across cluster nodes. The files to be synced are listed in `.sync_config`.
- `utils/`: A directory housing helper scripts.
- `testcase/`: Contains scripts for individual test cases.
- `predictor/`: Stores files used by the CraneSched Predictor Module. 

## Notes

- You may need to adjust executable path in python scripts.
- A single node could be virtualized as 1000 virtual hosts.
- You may add more hosts via deploying multiple switches in topology. However, this increase the communication overhead. 
