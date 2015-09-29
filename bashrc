#  .bashrc for user smilart

PATH_CONTAINERS="/var/lib/smilart_srv/repos/";
PATH_SERVICES="/usr/lib64/systemd/skel"

function create_etcd2_service_func(){
    local CLUSTER_INSTALLED='/etc/smilart/cluster_installed';
    local PATH_ETCD2_SERVICE='';
    local MASTER_IP=`cat $CLUSTER_INSTALLED`;
    local MASTER_PORT='2379';
    local HOST_NAME=`hostname`;
    local HOST_IP=`cat /etc/systemd/network/static.network | grep 'Address' | sed s#"Address="##g | awk -F '/' ' {print $1} '`;
    local HOST_PORT_PEER='2380';
    local HOST_PORT_CLIENT='2379';
    local INITIAL_CLUSTER='';
    local line PEER_URL INITIAL_CLUSTER NAME;
    
      # etcd2.service
      sudo cp -f $PATH_SERVICES/etcd2.service /etc/systemd/system/etcd2.service;
      if [[ $? != 0 ]];then
        echo -e "\E[31mERROR: Cannot copying files for $PATH_SERVICES to /etc/systemd/system/.">&2; tput sgr0;
        return 1;
      fi;

      sudo sed -i -e s#__HOST_NAME__#$HOST_NAME#g                /etc/systemd/system/etcd2.service;
      sudo sed -i -e s#__HOST_IP__#$HOST_IP#g                    /etc/systemd/system/etcd2.service;
      sudo sed -i -e s#__HOST_PORT_PEER__#$HOST_PORT_PEER#g      /etc/systemd/system/etcd2.service;
      sudo sed -i -e s#__HOST_PORT_CLIENT__#$HOST_PORT_CLIENT#g  /etc/systemd/system/etcd2.service;
      
    # etcd2 prestart configure
    if [[ $MASTER_IP == 'single' ]];then
      sudo cp -f $PATH_SERVICES/etcd2-master.service /run/systemd/system/etcd-cluster.service;
     
    else
      
      # Get node to cluster 
      for line in `curl -s http://$MASTER_IP:$MASTER_PORT/v2/members | sed s#{#"\n"{#g | grep name`
      do
          NAME=`echo $line | sed s#,\"#"\n",{#g | grep name | awk -F '"' ' {print $3} '`
          PEER_URL=`echo $line | sed s#,\"#"\n",{#g | grep peerURLs | awk -F '"' ' {print $3} '`
          INITIAL_CLUSTER=`echo "$INITIAL_CLUSTER,$NAME=$PEER_URL"`
      done
      INITIAL_CLUSTER=`echo $INITIAL_CLUSTER | sed s#\^,#"-initial-cluster "#g`
   
      sudo cp -f $PATH_SERVICES/etcd2-slave.service /run/systemd/system/etcd-cluster.service;
    fi;
    
     sudo sed -i -e s#__HOST_NAME__#$HOST_NAME#g                /run/systemd/system/etcd-cluster.service;
     sudo sed -i -e s#__HOST_IP__#$HOST_IP#g                    /run/systemd/system/etcd-cluster.service;
     sudo sed -i -e s#__HOST_PORT_PEER__#$HOST_PORT_PEER#g      /run/systemd/system/etcd-cluster.service;
     sudo sed -i -e s#__HOST_PORT_CLIENT__#$HOST_PORT_CLIENT#g  /run/systemd/system/etcd-cluster.service;
       
     cat "/run/systemd/system/etcd-cluster.service"
     echo $INITIAL_CLUSTER
     sudo sed -i -e s#__INITIAL_CLUSTER__#$INITIAL_CLUSTER#g    /run/systemd/system/etcd-cluster.service;
      
     if [[  -n `cat /run/systemd/system/etcd-cluster.service | grep ' ,'` ]]; then
        echo -e "\E[31mERROR: Incorrect cluster etcd2-service file.">&2; tput sgr0;
        return 1;
     fi;   
}

function create_skydns_service_func(){
    local CLUSTER_INSTALLED='/etc/smilart/cluster_installed';
    local MASTER_IP=`cat $CLUSTER_INSTALLED`;
    local DNS_SERVER=`cat /etc/smilart/dns-host`;
    local HOST_PORT_CLIENT='2379';
    local HOST_IP=`cat /etc/systemd/network/static.network | grep 'Address' | sed s#"Address="##g | awk -F '/' ' {print $1} '`;

    if [[ $MASTER_IP == 'single' ]];then
      # Configure skydns
      
      #Ping dns
      nc -vz -w 2 $DNS_SERVER 53 > /dev/null 2>&1;
      if [[ $? != 0 ]];then
        echo -e "\E[31mERROR: Incorrect ip from dns server.">&2; tput sgr0;
        return 1;
      fi;

      curl -XPUT http://127.0.0.1:$HOST_PORT_CLIENT/v2/keys/skydns/config -d value='{"dns_addr":"127.0.0.1:53", "nameservers": ["'$DNS_SERVER':53"]}';
      # Create obr configure
      curl -XPUT http://127.0.0.1:$HOST_PORT_CLIENT/v2/keys/skydns/local/smilart/obr -d value='{"host":"127.0.0.1"}';
    fi;
    
    # Create myhost configure
    curl -XPUT http://127.0.0.1:$HOST_PORT_CLIENT/v2/keys/skydns/local/smilart/`hostname` -d value='{"host":"'$HOST_IP'"}';    
}

sudo setterm -msg off;

  sudo mkdir -p /etc/smilart;
  if [ ! -e /etc/smilart/first_boot ]; then

    #Configuring network
    if [ ! -e /etc/smilart/network_installed ]; then
        network-config;
        if [[ $? == 0 ]];then
            touch /etc/smilart/network_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured network.";tput sgr0;
            sleep 1;
        fi;
    fi;

    #Configuring time
    if [ ! -e /etc/smilart/datetime_installed ]; then
        datetime-config;
        if [[ $? == 0 ]];then
            touch /etc/smilart/datetime_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured time.";tput sgr0;
            sleep 1;
        fi;
    fi;

    #Configuring cluster
    if [ ! -e /etc/smilart/cluster_installed ]; then
        cluster-config;
        if [[ $? == 0 ]];then
            touch /etc/smilart/cluster_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured cluster";tput sgr0;
            sleep 1;
        fi;
    fi;
    
    #Empty etcd config
    if [[ `cat /etc/smilart/cluster_installed` == '' ]]; then
        echo -e "\E[33mWARN: File cluster_installed is empty.";tput sgr0;
        echo "Not configuring node etcd.";
    else
        create_etcd2_service_func;
        if [ $? -ne 0 ];then
            echo -e "\E[31m Etcd2 service is not created!" >&2;tput sgr0;
        else
            echo -e "\E[32m Etcd2 service is created.";tput sgr0;
        fi;
        sudo systemctl daemon-reload;
        sudo systemctl restart systemd-networkd;
        sudo systemctl enable etcd2.service;
        sudo systemctl enable skydns.service;
        sudo systemctl start etcd-cluster.service;
        if [ $? -ne 0 ];then
            echo -e "\E[31m Etcd2 service is not started! Look is /run/systemd/system/etcd-cluster.service ." >&2;tput sgr0;
        else
            echo -e "\E[32m Etcd2 service is started.";tput sgr0;
        fi;
        sleep 1;
        echo;
      
        echo "Configuring skydns"
        create_skydns_service_func;
        if [ $? -ne 0 ];then
            echo -e "\E[31m Skydns service is not configured!" >&2;tput sgr0;
        else
            echo -e "\E[32m Skydns service is configured.";tput sgr0;
        fi;
        sudo systemctl restart skydns.service;
    fi;

    PATH_CONTAINERS="/var/lib/smilart_srv/repos/*";
    for LIST_CONTAINERS in $PATH_CONTAINERS; do
        echo "Processing $LIST_CONTAINERS file...";
        sudo /usr/sbin/sam installfile $LIST_CONTAINERS;
    done;
    unset PATH_CONTAINERS;
    unset LIST_CONTAINERS;

    if [ ! -e /etc/smilart/product_installed ]; then
        sudo /opt/bin/installproduct;
        if [ $? -ne 0 ];then
            echo -e "\E[31mERROR: Product is'nt installed correctly.";tput sgr0;
        fi;
        sudo touch /etc/smilart/product_installed;
    fi;

    clear;
    echo "Installation complete.";
    echo "System will reboot after 15 seconds.";
    sleep 15;
    sudo /sbin/reboot;

  fi;
#fi;
