#!/bin/bash
#关闭防火墙及selinux
systemctl stop firewalld && systemctl disable firewalld
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config  && setenforce 0
#关闭 swap 分区
swapoff -a
#永久
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab 
hostnamectl set-hostname k8s-master
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
kubeadm token create
openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'
kubectl apply -f kube-flannel.yml
#-----------查看集群状态-----------------
kubectl get nodes
kubectl get pod -n kube-system
sleep 5
#-------------部署 Dashboard----------
echo "部署 Dashboard"
kubectl apply -f kubernetes-dashboard.yaml
kubectl create serviceaccount dashboard-admin -n kube-system
kubectl create clusterrolebinding dashboard-admin --clusterrole=cluster-admin --serviceaccount=kube-system:dashboard-admin
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
#------------------------
mkdir key && cd key
#生成证书
openssl genrsa -out dashboard.key 2048 
#写自己的ip
openssl req -new -out dashboard.csr -key dashboard.key -subj '/CN=10.10.9.201'
openssl x509 -req -in dashboard.csr -signkey dashboard.key -out dashboard.crt 
#删除原有的证书secret，这步因为注释了yaml中证书的配置，所以不需要
kubectl delete secret kubernetes-dashboard-certs -n kube-system
#创建新的证书secret
kubectl create secret generic kubernetes-dashboard-certs --from-file=dashboard.key --from-file=dashboard.crt -n kube-system
#查看pod
kubectl get pod -n kube-system
#重启pod
kubectl delete pod kubernetes-dashboard-78dc5f9d6b-zgvr6  -n kube-system
#-------------标注-----------
echo "如需登录输入密钥输入一下密钥即可："
kubectl describe secrets -n kube-system $(kubectl -n kube-system get secret | awk '/dashboard-admin/{print $1}')
echo "如需加入node节点，只需执行node.sh后，执行以下命令"
kubeadm token create --ttl 0 --print-join-command
