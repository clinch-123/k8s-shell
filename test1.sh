#!/bin/bash
#关闭防火墙及selinux
systemctl stop firewalld && systemctl disable firewalld
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  && setenforce 0
#关闭 swap 分区
swapoff -a
#永久
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab 
hostnamectl set-hostname k8s-node1
#内核调整,将桥接的IPv4流量传递到iptables的链
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf/k8s.conf
echo "net.bridge.bridge-nf-call-ip6tables = 1" >> /etc/sysctl.conf/k8s.conf
sysctl --system
#设置阿里源
rm -f /etc/yum.d/*
curl -o /etc/yum.repos.d/CentOS-Base.repo https://mirrors.aliyun.com/repo/Centos-7.repo
yum makecache 
#安装时钟
yum install -y ntpdate wget
ntpdate time.windows.com
#安装docker
echo "安装docker~~~~~"
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo -O /etc/yum.repos.d/docker-ce.repo
yum -y install docker-ce-18.06.1.ce-3.el7
systemctl enable docker && systemctl start docker
docker --version
#添加kubernetes YUM软件源
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=0
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
#安装kubeadm,kubelet和kubectl
yum install -y kubelet-1.15.0 kubeadm-1.15.0 kubectl-1.15.0
systemctl enable kubelet
#部署Kubernetes Master
kubeadm init --apiserver-advertise-address=192.168.100.10 --image-repository registry.aliyuncs.com/google_containers --kubernetes-version v1.15.0 --service-cidr=10.1.0.0/16 --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "创建的token"
kubeadm token create
echo "创建的token列表"
kubeadm token list
echo "获取ca证书sha256编码hash值"
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'

