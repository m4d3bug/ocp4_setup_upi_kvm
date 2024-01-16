#!/bin/bash

echo 
echo "###############################"
echo "#### OPENSHIFT BOOTSTRAPING ###"
echo "###############################"
echo 

cp install_dir/auth/kubeconfig install_dir/auth/kubeconfig.orig
export KUBECONFIG="install_dir/auth/kubeconfig"


echo "====> Waiting for Boostraping to finish: "
echo "(Monitoring activity on bootstrap.${CLUSTER_NAME}.${BASE_DOM})"
a_dones=()
a_conts=()
a_images=()
a_nodes=()
s_api="Down"
btk_started=0
no_output_counter=0
while true; do
    output_flag=0
    if [ "${s_api}" == "Down" ]; then
        ./oc get --raw / &> /dev/null && \
            { echo "  ==> Kubernetes API is Up"; s_api="Up"; output_flag=1; } || true
    else
        nodes=($(./oc get nodes 2> /dev/null | grep -v "^NAME" | awk '{print $1 "_" $2}' )) || true
        for n in ${nodes[@]}; do
            if [[ ! " ${a_nodes[@]} " =~ " ${n} " ]]; then
                echo "  --> Node $(echo $n | tr '_' ' ')"
                output_flag=1
                a_nodes+=( "${n}" )
            fi
        done
    fi

    BSIP=$(virsh domifaddr "${CLUSTER_NAME}-bootstrap" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
    if [ -z "$BSIP" ]; then
        virsh reset "${CLUSTER_NAME}-bootstrap" > /dev/null 2>&1 && { echo "====> Rebooted Bootstrap"; }
    fi

    images=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo podman images 2> /dev/null | grep -v '^REPOSITORY' | awk '{print \$1 \"-\" \$3}'" )) || true
    for i in ${images[@]}; do
        if [[ ! " ${a_images[@]} " =~ " ${i} " ]]; then
            echo "  --> Image Downloaded: ${i}"
            output_flag=1
            a_images+=( "${i}" )
        fi
    done
    dones=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "ls /opt/openshift/*.done 2> /dev/null" )) || true
    for d in ${dones[@]}; do
        if [[ ! " ${a_dones[@]} " =~ " ${d} " ]]; then
            echo "  --> Phase Completed: $(echo $d | sed 's/.*\/\(.*\)\.done/\1/')"
            output_flag=1
            a_dones+=( "${d}" )
        fi
    done
    conts=($(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo crictl ps -a 2> /dev/null | grep -v '^CONTAINER' | rev | awk '{print \$4 \"_\" \$2 \"_\" \$3}' | rev" )) || true
    for c in ${conts[@]}; do
        if [[ ! " ${a_conts[@]} " =~ " ${c} " ]]; then
            echo "  --> Container: $(echo $c | tr '_' ' ')"
            output_flag=1
            a_conts+=( "${c}" )
        fi
    done

    for i in $(seq 1 ${N_MAST}); do
      IP=$(virsh domifaddr "${CLUSTER_NAME}-master-${i}" | grep ipv4 | head -n1 | awk '{print $4}' | cut -d'/' -f1 2> /dev/null)
      if [ -z "$IP" ]; then
        virsh reset "${CLUSTER_NAME}-master-${i}" > /dev/null 2>&1 && { echo "====> Rebooted Master-$i"; }
      fi
      mco_stat=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i sshkey "core@master-${i}.${CLUSTER_NAME}.${BASE_DOM}" "sudo systemctl is-active machine-config-daemon-firstboot.service" 2> /dev/null) || true
      # 如果服务已停止，后台启动它
      if [ "${mco_stat}" = "failed" ]; then
        echo "  --> Restarting machine-config-daemon-firstboot.service on Master-${i}..."
	ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i sshkey "core@master-${i}.${CLUSTER_NAME}.${BASE_DOM}" "nohup sudo systemctl restart machine-config-daemon-firstboot.service > /dev/null 2>&1 &" 2> /dev/null
      fi
    done

    btk_stat=$(ssh -i sshkey "core@bootstrap.${CLUSTER_NAME}.${BASE_DOM}" "sudo systemctl is-active bootkube.service 2> /dev/null" ) || true
    test "$btk_stat" = "active" -a "$btk_started" = "0" && btk_started=1 || true

    test "$output_flag" = "0" && no_output_counter=$(( $no_output_counter + 1 )) || no_output_counter=0

    test "$no_output_counter" -gt "8" && \
        { echo "  --> (bootkube.service is ${btk_stat}, Kube API is ${s_api})"; no_output_counter=0; }

    test "$btk_started" = "1" -a "$btk_stat" = "inactive" -a "$s_api" = "Down" && \
        { echo '[Warning] Some thing went wrong. Bootkube service wasnt able to bring up Kube API'; }
        
    test "$btk_stat" = "inactive" -a "$s_api" = "Up" && break

    sleep 15

    # sometimes the master will unable to ready due too late to finish the deployment, we have to approve its.
    for csr in $(./oc get csr 2> /dev/null | grep -w 'Pending' | awk '{print $1}'); do
        echo -n '  --> Approving CSR: ';
        ./oc adm certificate approve "$csr" 2> /dev/null || true
        output_delay=0
    done
    
done

./openshift-install --dir=install_dir wait-for bootstrap-complete --log-level=debug | tee bootstrap.log &

echo -n "====> Removing Boostrap VM: "
if [ "${KEEP_BS}" == "no" ]; then
    virsh destroy ${CLUSTER_NAME}-bootstrap > /dev/null || err "virsh destroy ${CLUSTER_NAME}-bootstrap failed"
    virsh undefine ${CLUSTER_NAME}-bootstrap --remove-all-storage > /dev/null || err "virsh undefine ${CLUSTER_NAME}-bootstrap --remove-all-storage"; ok
else
    ok "skipping"
fi

echo -n "====> Removing Bootstrap from haproxy: "
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" \
    "sed -i '/bootstrap\.${CLUSTER_NAME}\.${BASE_DOM}/d' /etc/haproxy/haproxy.cfg" || err "failed"
ssh -i sshkey "lb.${CLUSTER_NAME}.${BASE_DOM}" "systemctl restart haproxy" || err "failed"; ok

