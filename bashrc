#  .bashrc for user smilart

PATH_CONTAINERS="/var/lib/smilart_srv/repos/*";
PATH_CONFIGURE_DIR="/etc/smilart";

function wait_func(){
local TIMEOUT=$1;
echo -n "Wait -- ";
while [ $TIMEOUT -gt 0 ]; do
  echo -n "$TIMEOUT ";
  TIMEOUT=$(($TIMEOUT-1));
  sleep 1;
  echo -n $'\177';
  echo -n $'\177';
done;
echo -n "OK";
}

function create_etcd2_service_func(){
    local line PEER_URL INITIAL_CLUSTER NAME;
    local HOST_IP=`cat /etc/systemd/network/static.network | grep 'Address' | sed s#"Address="##g | awk -F '/' ' {print $1} '`;
    
     
    # Configure etcd2.service 
    echo "ETCD_DATA_DIR=\"/var/lib/etcd2\""                                        > $PATH_CONFIGURE_DIR/etcd2.service.env;
    echo "ETCD_NAME=\"`hostname`\""                                               >> $PATH_CONFIGURE_DIR/etcd2.service.env;
    echo "ETCD_LISTEN_PEER_URLS=\"http://$HOST_IP:2380\""                         >> $PATH_CONFIGURE_DIR/etcd2.service.env;
    echo "ETCD_LISTEN_CLIENT_URLS=\"http://$HOST_IP:2379,http://127.0.0.1:2379\"" >> $PATH_CONFIGURE_DIR/etcd2.service.env;
    echo "ETCD_ADVERTISE_CLIENT_URLS=\"http://$HOST_IP:2379\""                    >> $PATH_CONFIGURE_DIR/etcd2.service.env;

    # etcd2 prestart configure

    echo "ETCD_DATA_DIR=\"/var/lib/etcd2\""                                          > $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    echo "ETCD_NAME=\"`hostname`\""                                                 >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    echo "ETCD_LISTEN_CLIENT_URLS=\"http://$HOST_IP:2379,http://127.0.0.1:2379\""   >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    echo "ETCD_ADVERTISE_CLIENT_URLS=\"http://$HOST_IP:2379\""                      >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    echo "ETCD_INITIAL_CLUSTER_TOKEN=\"smilart-cluster\""                           >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    if [[ `cat $PATH_CONFIGURE_DIR/cluster_installed` == 'single' ]];then
       
      echo "ETCD_INITIAL_ADVERTISE_PEER_URLS=\"http://$HOST_IP:2380\""              >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
      echo "ETCD_LISTEN_PEER_URLS=\"http://$HOST_IP:2380,http://127.0.0.1:2380\""   >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
      echo "ETCD_INITIAL_CLUSTER_STATE=\"new\""                                     >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
      echo "ETCD_INITIAL_CLUSTER=\"`hostname`=http://$HOST_IP:2380\""               >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    else

      for line in `curl -s http://\`cat $PATH_CONFIGURE_DIR/cluster_installed\`:2379/v2/members | sed s#{#"\n"{#g | grep name`
        do
          NAME=`echo $line | sed s#,\"#"\n",{#g | grep name | awk -F '"' ' {print $3} '`;
          PEER_URL=`echo $line | sed s#,\"#"\n",{#g | grep peerURLs | awk -F '"' ' {print $3} '`;
          INITIAL_CLUSTER=`echo "$INITIAL_CLUSTER,$NAME=$PEER_URL"`;
      done
      INITIAL_CLUSTER=`echo $INITIAL_CLUSTER | sed s#\^,##g`;
      echo "ETCD_INITIAL_CLUSTER=\"$INITIAL_CLUSTER,`hostname`=http://$HOST_IP:2380\""                                                                                                                                   >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
      echo "ETCD_LISTEN_PEER_URLS=\"http://$HOST_IP:2380\""                         >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
      echo "ETCD_INITIAL_CLUSTER_STATE=\"existing\""                                >> $PATH_CONFIGURE_DIR/etcd2-cluster.service.env;
    fi;
}

function create_skydns_service_func(){
    local CLUSTER_INSTALLED="$PATH_CONFIGURE_DIR/cluster_installed";
    local MASTER_IP=`cat $CLUSTER_INSTALLED`;
    local DNS_SERVER=`cat $PATH_CONFIGURE_DIR/dns-host`;
    local HOST_PORT_CLIENT='2379';
    local HOST_IP=`cat /etc/systemd/network/static.network | grep 'Address' | sed s#"Address="##g | awk -F '/' ' {print $1} '`;
    local i=0   

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

    curl -XPUT http://127.0.0.1:$HOST_PORT_CLIENT/v2/keys/skydns/local/smilart/`hostname` -d value='{"host":"'$HOST_IP'"}';    
}

if [[ $- =~ "i" && $USER == "smilart" ]]; then
 
  sudo setterm -msg off;

  sudo mkdir -p $PATH_CONFIGURE_DIR;
  if [ ! -e $PATH_CONFIGURE_DIR/first_boot ]; then

    #Configuring network
    if [ ! -e $PATH_CONFIGURE_DIR/network_installed ]; then
        network-config;
        if [[ $? == 0 ]];then
            touch $PATH_CONFIGURE_DIR/network_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured network.";tput sgr0;
            sleep 1;
        fi;
    fi;

    #Configuring time
    if [ ! -e $PATH_CONFIGURE_DIR/datetime_installed ]; then
        datetime-config;
        if [[ $? == 0 ]];then
            touch $PATH_CONFIGURE_DIR/datetime_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured time.";tput sgr0;
            sleep 1;
        fi;
    fi;

    #Configuring cluster
    if [ ! -e $PATH_CONFIGURE_DIR/cluster_installed ]; then
        cluster-config;
        if [[ $? == 0 ]];then
            touch $PATH_CONFIGURE_DIR/cluster_installed;
        else
            echo;
            echo -e "\E[33mWARN: Not configured cluster.";tput sgr0;
            sleep 1;
        fi;
    fi;
    
    #Empty etcd config
    if [[ `cat $PATH_CONFIGURE_DIR/cluster_installed` == '' ]]; then
        echo -e "\E[33mWARN: File cluster_installed is empty.";tput sgr0;
        echo "Not configuring node etcd.";
    else
        clear;
        create_etcd2_service_func;
        sudo systemctl daemon-reload;
        sudo systemctl restart systemd-networkd;
        sudo systemctl enable etcd2.service;
        sudo systemctl enable skydns.service;
        sudo systemctl start etcd2-cluster.service;    
        if [ $? -ne 0 ];then
            echo -e "\E[31m Etcd2 service is not started!" >&2;tput sgr0;
        else
            echo -e "\E[32m Etcd2 service is started.";tput sgr0;
        fi;
        echo;
        wait_func 5;
        echo;
      
        echo "Configuring skydns"
        create_skydns_service_func;
        if [ $? -ne 0 ];then
            echo -e "\E[31m Skydns service is not configured!" >&2;tput sgr0;
        else
            echo -e "\E[32m Skydns service is configured.";tput sgr0;
        fi;
        sudo systemctl start skydns.service;
    fi;

    for LIST_CONTAINERS in $PATH_CONTAINERS; do
        echo "Processing $LIST_CONTAINERS file...";
        sudo /usr/sbin/sam installfile $LIST_CONTAINERS;
    done;
    unset PATH_CONTAINERS;
    unset LIST_CONTAINERS;

    if [ ! -e $PATH_CONFIGURE_DIR/product_installed ]; then
        sudo /opt/bin/installproduct;
        if [ $? -ne 0 ];then
            echo -e "\E[31mERROR: Product is'nt installed correctly.";tput sgr0;
        fi;
        sudo touch $PATH_CONFIGURE_DIR/product_installed;
    fi;

    wait_func 3;

    # hostname
    ping -c `hostname` > /dev/null 2>&1;
    if [ $? -ne 0 ];then
      echo -e "\E[31m Name '`hostname`' is'nt available." >&2;tput sgr0;
    fi;

    # obr
    ping -c obr.smilart.local > /dev/null 2>&1;
    if [ $? -ne 0 ];then
      echo -e "\E[31m Name 'obr.smilart.local' is'nt available." >&2;tput sgr0;
    fi;
    echo "Testing completed.";
    echo "Installation completed.";
    echo "System will reboot after 7 seconds.";
    wait_func 7;
    sudo /sbin/reboot;

  fi;
fi;
