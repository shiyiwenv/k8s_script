#!/bin/sh
#Author: shiyiwen
#init kubernetes master server
h1() { printf "$(tput bold)%s...\n$(tput sgr0)" "$@" 
}
h2() { printf "$(tput setaf 3)%s\n$(tput sgr0)" "$@"
}

success() { printf "$(tput setaf 2; tput bold)✔ %s \n$(tput sgr0)" "$@"
}
error() { printf "$(tput setaf 1; tput bold) %s \n$(tput sgr0)" "$@"
exit 0
}
ret() {
if [ $? -eq 0 ]; then
    success $"Sucess"
else
    printf '\n'$(tput setaf 1; tput setab 0; tput bold)' Error '$(tput sgr0)'\n'
    exit 0
fi
}
printf '\n'$(tput setaf 1; tput setab 0; tput bold)'此脚本应用于系统安装之后的node节点部署'$(tput sgr0)'\n\n'

sleep 2


h1 $" System checking and setting proxy"
ip route del default
sleep 1
ip route add default via 192.168.1.224
ret
h2 $"    check google network registry k8s.gcr.io"
    curl -s --connect-timeout 3 -m 10 k8s.gcr.io > /dev/null
ret

h2 $"    It is Centos7.x ?"
     [[ "`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`" == "7" ]] && success $"OK!" || error $"Error please check system version"

h2 $"  Firewalld and iptables stop  "
      echo "checking firewalld"
      systemctl status firewalld > /dev/null
      [[ $? -eq 0 ]] && error $"please stop firewalld" || success $"OK!"
echo -n "Do you want to continue [Y/N]?"
read  answer
[[ "$answer" == "y" || "$answer" == "Y" ]] && h1 $"Starting install..." || error $"Exit"

h1 $" iptables setting ,Please insert then following /etc/sysconfig/iptables ,and systemctl restart iptables"
    echo "-A INPUT -s 10.10.0.0/16 -j ACCEPT
          -A FORWARD -s 10.0.0.0/8 -j ACCEPT"

h1 $"  Change kubernetes repo"

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
setenforce 0
swapoff -a
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system > /dev/null

h1 $"  Seting start server configured"
cat <<EOF >> /etc/rc.local
swapoff -a
modprobe ip_vs_rr
modprobe ip_vs_wrr
modprobe ip_vs_sh
modprobe nf_conntrack_ipv4
modprobe ip_vs
EOF
chmod +x /etc/rc.local
chmod +x /etc/rc.d/rc.local

h1 $"  install docker and change docker strong dir"
mkdir -p /data/docker
yum install -y docker > /dev/null
cat <<EOF > /usr/lib/systemd/system/docker.service
[Unit]
Description=Docker Application Container Engine
Documentation=http://docs.docker.com
After=network.target rhel-push-plugin.socket registries.service
Wants=docker-storage-setup.service
Requires=docker-cleanup.timer

[Service]
Type=notify
NotifyAccess=all
EnvironmentFile=-/run/containers/registries.conf
EnvironmentFile=-/etc/sysconfig/docker
EnvironmentFile=-/etc/sysconfig/docker-storage
EnvironmentFile=-/etc/sysconfig/docker-network
Environment=GOTRACEBACK=crash
Environment=DOCKER_HTTP_HOST_COMPAT=1
Environment=PATH=/usr/libexec/docker:/usr/bin:/usr/sbin
ExecStart=/usr/bin/dockerd-current \
          --add-runtime docker-runc=/usr/libexec/docker/docker-runc-current \
          --default-runtime=docker-runc \
          --exec-opt native.cgroupdriver=cgroupfs \
          --userland-proxy-path=/usr/libexec/docker/docker-proxy-current \
          --init-path=/usr/libexec/docker/docker-init-current \
          --seccomp-profile=/etc/docker/seccomp.json \
          --graph=/data/docker \
          \$OPTIONS \
          \$DOCKER_STORAGE_OPTIONS \
          \$DOCKER_NETWORK_OPTIONS \
          \$ADD_REGISTRY \
          \$BLOCK_REGISTRY \
          \$INSECURE_REGISTRY \
          \$REGISTRIES
ExecReload=/bin/kill -s HUP \$MAINPID
LimitNOFILE=1048576
LimitNPROC=1048576
LimitCORE=infinity
TimeoutStartSec=0
Restart=on-abnormal
KillMode=process

[Install]
WantedBy=multi-user.target
EOF
ret

h1 $" change docker log-driver=json-file"
sed -i 's/journald/json-file/g' /etc/sysconfig/docker
ret

h1 $" install kubelet、kubeadm、kubectl "
yum install -y kubelet-1.11.1 kubeadm-1.11.1 kubectl-1.11.1 > /dev/null
ret

h1 $" install epel "
yum install -y epel-release > /dev/null
ret

h1 $" install nfs glusterfs client "
yum install -y glusterfs glusterfs-fuse nfs-utils > /dev/null
ret

h1 $" start docker and kubelet"
systemctl daemon-reload

systemctl enable docker && systemctl start docker > /dev/null
ret
#systemctl restart kubelet
#ret
