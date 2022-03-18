脚本运行前须知
脚本执行顺序
	在执行master node前 需分别修改node_ip和master_ip
	Master:master.sh
	Node:node.sh
	执行完脚本后根据master节执行脚本后弹出的提示命令在node节点输入即可
	node节点如需重新加入新节点可以
如需node节点重新加入新master
	停掉kubelet
	systemctl stop kubelet
	删除之前的相关文件
	rm -rf /etc/kubernetes/*
	重启
	kubeadm reset 
	iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
	加入集群

3.4.3	其他说明
#-------------部署flannel网络----------
kube-flannel.yml文件可以用Wgethttps://raw.githubusercontent.com
/coreos/flannel/a70459be0084506e4ec919aa1c114638878db11b/Documentation/kube-flannel.yml拉取
注：修改镜像地址：(有可能默认不能拉取，确保能够访问到quay.io这个registery,否则修改如下内容)，把106行，120行的内容，替换如下image，替换之后查看如下为正确
[root@k8s-master ~]# cat -n  kube-flannel.yml|grep lizhenliang/flannel:v0.11.0-amd64   
106    image: lizhenliang/flannel:v0.11.0-amd64   
120    image: lizhenliang/flannel:v0.11.0-amd64
kubectl apply -f kube-flannel.yml
查看集群状态
kubectl get nodes
kubectl get pod -n kube-system
sleep 5
#-------------部署 Dashboard----------
#kubernetes-dashboard.yaml可从wget https://raw.githubusercontent.com/kubernet
es/dashboard/v1.10.1/src/deploy/recommended/kubernetes-dashboard.yaml拉取
注：
[root@k8s-master ~]# vim kubernetes-dashboard.yaml
修改内容：
109     spec:
110       containers:
111       - name: kubernetes-dashboard
112         image: lizhenliang/kubernetes-dashboard-amd64:v1.10.1   # 修改此行
157 spec:
158   type: NodePort     # 增加此行
159   ports:
160     - port: 443
161       targetPort: 8443
162       nodePort: 30001   # 增加此行
163   selector:
164     k8s-app: kubernetes-dashboard
