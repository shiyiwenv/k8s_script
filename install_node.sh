#!/bin/sh

h1() { printf "$(tput bold)%s\n" "$@" 
}

seccess() { printf "$(tput setaf 76)✔ %s \n" "$@"
}

ret() {
if [ $? -eq 0 ]; then
    seccess "Sucess"
else
    printf '\n'$(tput setaf 1; tput setab 0; tput bold)' Error '$(tput sgr0)'\n'
fi
}
printf '\n'$(tput setaf 1; tput setab 0; tput bold)'此脚本应用于系统安装之后的master节点部署'$(tput sgr0)'\n\n'

sleep 2


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

h1 " (1) install docker and change docker strong dir"
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

h1 " install kubelet、kubeadm、kubectl "
yum install -y kubelet-1.11.1 kubeadm-1.11.1 kubectl-1.11.1
#sed -i "s/cgroup-driver=systemd/cgroup-driver=cgroupfs/g" /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
systemctl daemon-reload

systemctl enable docker && systemctl start docker > /dev/null
ret
#systemctl restart kubelet
#ret
