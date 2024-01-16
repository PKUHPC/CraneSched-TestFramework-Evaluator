import os
import sys
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

Dryrun = False
NodeNum = 3
Subnet = ipa.ip_network("10.0.0.0/24")

HostPath = "/etc/hosts"
ConfPath = "/etc/slurm/slurm.conf"

LogPath = "/tmp/output/{}.log"
StdoutPath = "/tmp/output/{}.out"
StderrPath = "/tmp/output/{}.err"

# (A, B) means contents in B will be persisted in A.
PersistList = [("/tmp/output", "/tmp/output")]

# Each node's temporary directory is invisible to others.
TempList = ["/tmp/slurm"]

Hosts = {}


class SingleSwitchTopo(Topo):
    """Single switch connected to n hosts."""

    def __init__(self, n=2, **opts):
        Topo.__init__(self, **opts)
        switch = self.addSwitch("switch1")

        for h in range(n):
            name = f"slurmd{h+1}"
            addr = ipa.ip_address(Subnet[h + 1])
            host = self.addHost(name, ip=str(addr))
            Hosts[name] = str(addr)
            self.addLink(
                host,
                switch,
                # bw=100,
                # delay="1ms",
                # loss=0,
                # max_queue_size=1000,
                # use_htb=True,
            )


def WriteHostfile():
    """Write hostfile for Slurm"""
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
        pass

    # Write back and mark
    with open(HostPath, "w") as file:
        file.writelines(lines)
        file.write(smark)
        for hostname, addr in Hosts.items():
            file.write(f"{addr}\t{hostname}\n")
        file.write(emark)


def CleanHostfile():
    """Clean hostfile for Slurm"""
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
        return

    # Write back
    with open(HostPath, "w") as file:
        file.writelines(lines)
        if lines[-1] != "\n":
            file.write("\n")


def reset():
    cleanup()
    CleanHostfile()
    # Kill all Slurmd
    os.system(r"pkill -SIGINT -e -f '^slurmd\s'")


def setMaxLimit():
    """
    Set the max limit of file descriptors and process number
    """
    MaxLimit = 1048576
    try:
        soft_limit, hard_limit = resource.getrlimit(resource.RLIMIT_NOFILE)
        resource.setrlimit(resource.RLIMIT_NOFILE, (MaxLimit, MaxLimit))
        print("File descriptor limit set to %d successfully!" % MaxLimit)
    except ValueError as e:
        print(f"Error setting limit: {e}")
    except resource.error as e:
        print(f"Error setting limit: {e}")

    with open("/proc/sys/kernel/pid_max", "w") as f:
        f.write(str(MaxLimit))


def PerfTest():
    """Create network and run simple performance test"""
    topo = SingleSwitchTopo(n=NodeNum)
    net = Mininet(
        topo=topo,
        host=partial(Host, privateDirs=PersistList + TempList),  # type: ignore
        link=TCLink,
    )
    net.addController("c1")

    nataddr = ipa.ip_address(Subnet[-1])
    net.addNAT(ip=str(nataddr)).configDefault()

    WriteHostfile()

    net.start()
    print("Testing connectivity")
    if net.pingAll() > 0:
        print("Network not fully connected, exiting...")
        return

    print("Starting Slurmd...")

    for h in net.hosts:
        # Ignore NATs
        if not isinstance(h, Host):
            continue

        # Reset output files
        logfile = LogPath.format(h.name)
        outfile = StdoutPath.format(h.name)
        errfile = StderrPath.format(h.name)
        h.cmd("echo >", outfile)
        h.cmd("echo >", errfile)

        # Mount cgroup manually
        h.cmdPrint(
            "mount",
            "-t",
            "cgroup2",
            "-o",
            "rw,nosuid,nodev,noexec,relatime,seclabel,nsdelegate,memory_recursiveprot",
            "cgroup2",
            "/sys/fs/cgroup",
        )

        # Enable controllers for subtree
        h.cmdPrint(
            r"echo '+cpuset +cpu +io +memory +pids' > /sys/fs/cgroup/cgroup.subtree_control"
        )

        if not Dryrun:
            h.cmdPrint(
                "slurmd",
                "-D",  # Foreground
                "-N",  # Use host name instead of hostname
                h.name,
                "-f",  # Specify config file
                ConfPath,
                "-L",  # Specify log file
                logfile,
                ">",
                outfile,
                "2>",
                errfile,
                "&",
            )
            sleep(0.1)
        else:
            print("Dryrun = True, will not spawn Slurmd.")

    # Open CLI for debugging
    CLI(net)

    # Slurm must be killed
    os.system(r"pkill -SIGINT -e -f '^slurmd\s'")
    net.stop()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        NodeNum = int(sys.argv[1])
        Subnet = ipa.ip_network(sys.argv[2]) if len(sys.argv) > 2 else Subnet
        ConfPath = os.path.abspath(sys.argv[3]) if len(sys.argv) > 3 else ConfPath
        Dryrun = sys.argv[4] if len(sys.argv) > 4 else Dryrun

    print(f"NodeNum = {NodeNum}")
    print(f"Subnet = {Subnet}")
    print(f"ConfPath = {ConfPath}")

    reset()
    setLogLevel("info")
    setMaxLimit()
    PerfTest()
