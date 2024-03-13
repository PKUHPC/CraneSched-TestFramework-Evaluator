#!/usr/bin/env python3

import os
import yaml
import argparse
import resource
import ipaddress as ipa
from time import sleep
from functools import partial
from mininet.topo import Topo
from mininet.net import Mininet
from mininet.node import Host
from mininet.link import TCLink
from mininet.log import setLogLevel
from mininet.cli import CLI
from mininet.clean import cleanup

# Constants
HostPath = "/etc/hosts"
LogPath = "/tmp/output/{}.log"
StdoutPath = "/tmp/output/{}.out"
StderrPath = "/tmp/output/{}.err"
HostName = "slrmd{}"

# (A, B) means contents in B will be persisted in A.
PersistList = [("/tmp/output", "/tmp/output")]

# Each host's temporary directory is invisible to others.
TempList = ["/tmp/slurm", "/tmp/munge"]


class NodeConfig:
    """Node configuration"""

    def __init__(self, name) -> None:
        self.name = name
        self.num = 3
        self.offset = 1
        self.subnet = ipa.IPv4Network("10.0.0.0/8", strict=True)
        self.addr = ipa.IPv4Interface("192.168.0.10/24")

    def __str__(self) -> str:
        return (
            f"NodeConfig(name={self.name}, num={self.num}, "
            f"offset={self.offset}, subnet={self.subnet}, addr={self.addr})"
        )

    def hosts(self, cidr=True):
        for idx in range(self.offset, self.num + self.offset):
            yield (
                HostName.format(idx),
                f"{self.subnet[idx - self.offset + 1]}"
                + (f"/{self.subnet.prefixlen}" if cidr else ""),
            )


class ClusterConfig:
    """Cluster configuration"""

    def __init__(self, args) -> None:
        self.nodes = {}
        self.this = NodeConfig("")
        thisname = os.popen("hostname").read().strip()
        try:
            with open(args.conf, "r") as file:
                config = yaml.safe_load(file)  # type: dict
            for name, params in config["cluster"].items():
                if name == thisname:
                    node = self.setThisNode(thisname, params, args)
                else:
                    node = NodeConfig(name)
                    node.num = params["HostNum"]
                    node.offset = params["Offset"]
                    node.subnet = ipa.IPv4Network(params["Subnet"])
                    node.addr = ipa.IPv4Interface(params["NodeAddr"])
                self.nodes[name] = node
        except FileNotFoundError or TypeError or KeyError or ValueError:
            print("Invalid config, fall back to defaults")
            self.setThisNode(thisname, {}, args)
            self.nodes = {thisname: self.this}

    def __str__(self) -> str:
        return f"ClusterConfig(this={self.this}, nodes={self.nodes})"

    def setThisNode(self, name: str, param: dict, args) -> NodeConfig:
        """
        Set `.this`. Specify default values here.
        """
        self.this.name = name
        self.this.num = args.num if args.num else param.get("HostNum", 3)
        self.this.offset = args.offset if args.offset else param.get("Offset", 1)
        self.this.subnet = ipa.IPv4Network(
            args.subnet if args.subnet else param.get("Subnet", "10.0.0.0/8")
        )
        self.this.addr = ipa.IPv4Interface(
            args.addr if args.addr else param.get("NodeAddr", "192.168.0.10/24")
        )
        return self.this

    def getHostEntry(self) -> list[tuple[str, str]]:
        entry = []
        for n in self.nodes:
            for name, addr in self.nodes[n].hosts(cidr=False):
                entry.append((name, addr))
        return entry

    def getRouteEntry(self) -> list[tuple[str, str]]:
        """
        Get needed routes for `this` host to reach subnets on other hosts.
        """
        entry = []
        for name, node in self.nodes.items():
            if name == self.this.name:
                continue
            entry.append(
                (
                    f"{node.subnet.network_address}/{node.subnet.prefixlen}",
                    str(node.addr.ip),
                )
            )
        return entry


class SingleSwitchTopo(Topo):
    """Single switch connected to n hosts."""

    def __init__(self, config: NodeConfig, **opts):
        Topo.__init__(self, **opts)
        switch = self.addSwitch("switch1")

        for name, ip in config.hosts(cidr=True):
            host = self.addHost(name=name, ip=ip)
            self.addLink(
                host,
                switch,
                # bw=100,
                # delay="1ms",
                # loss=0,
                # max_queue_size=1000,
                # use_htb=True,
            )


def writeHostfile(entry: list[tuple[str, str]] = [], clean=False):
    """Generate hostfile for Slurm"""
    smark = "# BEGIN Mininet hosts #\n"
    emark = "# END Mininet hosts #\n"

    # Read all and check
    with open(HostPath, "r") as file:
        lines = file.readlines()

    try:
        start = lines.index(smark)
        end = lines.index(emark) + 1
        del lines[start:end]
    except ValueError:
        if clean:
            return

    # Write back and mark
    with open(HostPath, "w") as file:
        file.writelines(lines)
        if not clean:
            file.write(smark)
            for hostname, addr in entry:
                file.write(f"{addr}\t{hostname}\n")
            file.write(emark)


def writeRoute(entry: list[tuple[str, str]], clean=False):
    """
    Check and add required route.
    """
    for dest, nexthop in entry:
        # Clean existing routes
        ret = os.popen(f"ip route del {dest}").read()
        if len(ret) and "No such process" not in ret:
            print(ret)
        if clean:
            continue

        # Write new routes
        ret = os.popen(f"ip route add {dest} via {nexthop}").read()
        if len(ret):
            print(ret)


def reset():
    cleanup()
    # Kill all Slurmd
    os.system(r"pkill -SIGINT -e -f '^slurmd\s'")
    os.system(r"pkill -SIGINT -e -f 'munged\s-F'")
    # Reset hosts and routes
    writeHostfile(clean=True)
    try:
        writeRoute(Cluster.getRouteEntry(), clean=True)
    except NameError:
        pass


def setMaxLimit():
    """
    Set the max limit of file descriptors and process number
    """
    maxLimit = 4194304
    try:
        soft_limit, hard_limit = resource.getrlimit(resource.RLIMIT_NOFILE)
        resource.setrlimit(resource.RLIMIT_NOFILE, (maxLimit, maxLimit))
        print(f"File descriptor limit set to {maxLimit} successfully!")
    except ValueError as e:
        print(f"Error setting limit: {e}")
    except resource.error as e:
        print(f"Error setting limit: {e}")

    # Kernel settings
    kernelParams = {
        "kernel.pid_max": "4194304",
        "kernel.threads-max": "8388608",  
        "net.core.somaxconn": "8192",
        "vm.max_map_count": "131072",
    }
    for param, value in kernelParams.items():
        ret = os.system(f"sysctl -w {param}={value}")
        if ret != 0:
            print(f"Error setting {param} to {value}")
        else:
            print(f"Set {param} to {value}")


def Run(config: NodeConfig):
    """Create network and run the simulation"""
    topo = SingleSwitchTopo(config)
    net = Mininet(
        ipBase=str(config.subnet),
        topo=topo,
        host=partial(Host, privateDirs=PersistList + TempList),  # type: ignore
        link=TCLink,
    )
    net.addController("c1")

    # We DO NOT need NAT. Only use this to create a gateway node.
    nat = net.addNAT(ip=f"{config.subnet[-2]}/{config.subnet.prefixlen}")
    nat.configDefault()
    # Disable firewall on gateway node
    nat.cmd("iptables -t nat -F")
    nat.cmd("iptables -F")

    net.start()

    print("Testing connectivity")
    if (
        net.pingAll()
        if config.num < 10
        else net.ping(hosts=[net.hosts[0], net.hosts[-1]])
    ) > 0:
        print("Network not fully connected, exiting...")
        return

    print("Starting Slurmd..." + ("Dryrun=True, won't start Slurmd" if Dryrun else ""))
    for h in net.hosts:
        # Ignore NATs
        if not isinstance(h, Host):
            continue

        # Reset output files
        slurmdlog = LogPath.format(h.name)
        mungedlog = LogPath.format(f"{h.name}.munged")
        outfile = StdoutPath.format(h.name)
        errfile = StderrPath.format(h.name)
        h.cmd("echo >", slurmdlog)  # Maybe useful for debugging
        h.cmd("echo >", mungedlog)
        h.cmd("echo >", outfile)
        h.cmd("echo >", errfile)

        # Mount cgroup manually
        h.cmd(
            "mount",
            "-t",
            "cgroup2",
            "-o",
            "rw,nosuid,nodev,noexec,relatime,seclabel,nsdelegate,memory_recursiveprot",
            "cgroup2",
            "/sys/fs/cgroup",
        )

        # Enable controllers for subtree
        h.cmd(
            r"echo '+cpuset +cpu +io +memory +pids' > /sys/fs/cgroup/cgroup.subtree_control"
        )

        # Start Munge at first
        h.cmd(f"chmod munge:munge -R {TempList[1]}")
        h.cmdPrint(
            "sudo -u munge",
            "/usr/sbin/munged -F -f",
            f"--socket={TempList[1]}/munge.socket",
            f"--pid-file={TempList[1]}/munged.pid",
            f"--seed-file={TempList[1]}/munge.seed",
            "&>",
            mungedlog,
            "&",
        )

        if not Dryrun:
            h.cmdPrint(
                "slurmd -D -N",
                "-D",  # Foreground
                "-N",  # Use host name instead of hostname
                h.name,
                "-f",  # Specify config file
                ConfPath,
                "-L",  # Specify log file
                slurmdlog,
                ">",
                outfile,
                "2>",
                errfile,
                "&",
            )
            sleep(0.1)

    # Open CLI for debugging
    CLI(net)

    # Slurm must be killed
    os.system(r"pkill -SIGINT -e -f '^slurmd\s'")
    os.system(r"pkill -SIGINT -e -f 'munged\s-F'")
    net.stop()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="SLURM in Mininet")
    parser.add_argument(
        "-c",
        "--conf",
        type=str,
        default="config.yaml",
        help="cluster configuration in YAML format",
    )
    parser.add_argument("-n", "--num", type=int, help="number of virtual hosts")
    parser.add_argument(
        "--offset", type=int, help="naming offset of virtual hosts, default=1"
    )
    parser.add_argument("--subnet", type=str, help="subnet for virtual hosts")
    parser.add_argument("--slurm-conf", type=str, help="`slurm.conf` for slurmd")
    parser.add_argument(
        "--addr", type=str, help="primary IP (CIDR) of this node used in the cluster"
    )
    parser.add_argument("--dryrun", action="store_true", help="Do not starting slurmd")
    parser.add_argument("--clean", action="store_true", help="clean the environment")

    args = parser.parse_args()

    reset()
    if args.clean:
        exit()
    setLogLevel("info")
    setMaxLimit()

    # Always from CLI
    ConfPath = os.path.abspath(
        args.slurm_conf if args.slurm_conf else "/etc/slurm/slurm.conf"
    )
    Dryrun = args.dryrun if args.dryrun else False

    # Build ClusterConfig
    Cluster = ClusterConfig(args)

    # Generate hostfile and route
    writeHostfile(Cluster.getHostEntry())
    if len(Cluster.nodes) > 1:
        writeRoute(Cluster.getRouteEntry())

    Run(Cluster.this)
