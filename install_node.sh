#!/bin/sh
#Author: 907765003@qq.com
#init kubernetes node server
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

h2 $" iptables setting ,Please insert then following /etc/sysconfig/iptables ,and systemctl restart iptables"
    echo "-A INPUT -s 10.10.0.0/16 -j ACCEPT
          -A FORWARD -s 10.0.0.0/8 -j ACCEPT"

h2 $"  Change kubernetes repo"

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

h2 $"  Init IPVS modules......"
setenforce 0
swapoff -a
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system > /dev/null

cat > /etc/sysconfig/modules/ipvs.modules <<EOF
#!/bin/bash
ipvs_modules="ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack_ipv4"
for kernel_module in \${ipvs_modules}; do
    /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        /sbin/modprobe \${kernel_module}
    fi
done
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && /bin/bash /etc/sysconfig/modules/ipvs.modules
ret

h2 $"  Checking DNS configured"
dnssum=`cat /etc/resolv.conf |egrep -v "^#" |grep nameserver|wc -l`

if [[ $dnssum -gt 3 ]];then
    dns=`cat /etc/resolv.conf |egrep -v "^#" |grep nameserver|awk 'NR <=3 {print $0}'`
    echo "$dns" > /etc/resolv.conf
fi
ret

h2 $"  Setting start server configured"
cat <<EOF >> /etc/rc.local
swapoff -a
EOF
chmod +x /etc/rc.local
chmod +x /etc/rc.d/rc.local

h2 $"  install docker and change docker strong dir"
mkdir -p /data/docker
yum install -y -q docker > /dev/null
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

h2 $" change docker log-driver=json-file"
sed -i 's/journald/json-file/g' /etc/sysconfig/docker
ret

h2 $" install kubelet、kubeadm、kubectl "
yum install -y -q kubelet-1.11.1 kubeadm-1.11.1 kubectl-1.11.1 kubernetes-cni-0.6.0> /dev/null 2>&1
ret

h2 $" install epel "
yum install -y epel-release > /dev/null
ret

h2 $" install nfs glusterfs client "
yum install -y glusterfs glusterfs-fuse nfs-utils --disablerepo=epel> /dev/null
ret

h2 $" start docker and kubelet"
sed -i 's/EXTRA_ARGS$/EXTRA_ARGS --runtime-cgroups=\/systemd\/system.slice --kubelet-cgroups=\/systemd\/system.slice/g' \
/etc/systemd/system/kubelet.service.d/10-kubeadm.conf
ret
systemctl daemon-reload

systemctl enable docker -q && systemctl start docker > /dev/null
ret
systemctl enable kubelet -q
/bin/bash /etc/sysconfig/modules/ipvs.modules
ret