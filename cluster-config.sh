#!/bin/bash
PATH_CLUSTER_INSTALLED="/etc/smilart/cluster_installed";
ETCD_PORT=2379;

#exist dialog?
dialog --clear;
if [[ $? != 0 ]];then
  echo -e "\E[31mERROR: Cannot run 'dialog'.">&2;tput sgr0;
  exit 1;
fi;

#**************log ERROR****************#
LOG_ERROR[1]="ERROR: Not checked configure server.";
LOG_ERROR[2]="ERROR: Field 'Ip' is empty.";
LOG_ERROR[3]="ERROR: Field 'Ip' is incorrect.";
LOG_ERROR[4]="ERROR: Failed to ping the network interface."
#********Genetate tempfiles from dialog*********#
tempfile() {
    tempprefix=$(basename "$0");
    mktemp /tmp/${tempprefix}.XXXXXX;
}

TMP_DIALOG_MENU=$(tempfile)
TMP_DIALOG_ERROR=$(tempfile)

echo "
bindkey formbox   TAB  form_next
bindkey formfield TAB  form_next
bindkey formfield BTAB form_prev
bindkey formbox   BTAB form_prev
" > $TMP_DIALOG_MENU;

echo "
dialog_color = (RED,WHITE,OFF)
title_color = (RED,WHITE,ON)
" > $TMP_DIALOG_ERROR

trap 'rm -f $TMP_DIALOG_MENU $TMP_DIALOG_ERROR' EXIT
#***********************************************#

# echo ERROR to dialog
# error_func <text>
error_func() {
  DIALOGRC="$TMP_DIALOG_ERROR" \
    dialog --msgbox "\n$1" 10 50
}

# valid_ip_func <ip>
# valid_ip_func 192.168.1.1 
function valid_ip_func() {
  if ! [[ $1 =~ ^(25[0-5]|2[0-4][i0-9]|[0-1][0-9]{2}|[0-9]{2}|[0-9])(\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[0-9]{2}|[0-9])){3}$ ]]; then
    error_func "${LOG_ERROR[3]}";
    continue
  fi;
}

#****************CONFIGURE CLUSTER**************#
EXIT_FORM="0";
FORM_IP='';
while [[ $EXIT_FORM == "0" ]];do
  # Store data to $cmd variable
  exec 3>&1
  FORM_CLUSTER=$(DIALOGRC="$TMP_DIALOG_MENU" dialog --clear \
    --ok-label "NEXT" \
    --title "Smilart Operating System" \
    --radiolist "\nAdditional cluster node or standalone server (first node in cluster):" \
      11 50 4 \
      1 "Standalone server" off \
      2 "Additional node" off \
      2>&1 1>&3)
  DIALOG_RETURN_VALUE=$?
  exec 3>&-
  
  if [[ $DIALOG_RETURN_VALUE == 1 || $DIALOG_RETURN_VALUE == 255 ]]; then
    exit 1;
  fi;
  
  #Empty ?
  if [[ -z "$FORM_CLUSTER" ]]; then
     error_func "${LOG_ERROR[1]}";
     continue
  fi
   
  if [[ "$FORM_CLUSTER" == "2" ]];then
      # display values just entered
      # open fd
      exec 3>&1

      # Store data to $DIALOG_STRING variable
      FORM_IP=$(DIALOGRC="$TMP_DIALOG_MENU" dialog --clear \
        --ok-label "OK" \
        --title "Smilart Operating System" \
        --form "\nEnter address from etcd-server:" \
       0 0 0 \
       "Ip:              " 1 1 "$FORM_IP"           1 20 30 0 \
       2>&1 1>&3)
       DIALOG_RETURN_VALUE=$?
       exec 3>&-
      
      #ESC in dialog?
      if [[ $DIALOG_RETURN_VALUE == 1 || $DIALOG_RETURN_VALUE == 255 ]]; then
        continue
      fi;

      #Empty?
      if [[ -z "$FORM_IP" ]]; then
        error_func "${LOG_ERROR[2]}";
        continue
      fi;
      
      #Valid ip?
      valid_ip_func $FORM_IP;

      #Ping?
      nc -vz -w 2 $FORM_IP $ETCD_PORT > /dev/null 2>&1;
      if [[ $? != 0 ]];then
        error_func "${LOG_ERROR[4]}";
        continue
      fi;
      CLUSTER_INSTALLED="$FORM_IP"
  else
      CLUSTER_INSTALLED="single"
  fi;

  EXIT_FORM="1";
done;

#*******************Save to file****************#
echo "$CLUSTER_INSTALLED" > $PATH_CLUSTER_INSTALLED;
if [[ $? != 0 ]];then
  echo -e "\E[31mERROR: Cannot create '$PATH_CLUSTER_INSTALLED'.">&2;tput sgr0;
  exit 1;
fi;
