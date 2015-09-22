#!/bin/bash

#exist dialog?
dialog --clear;
if [[ $? != 0 ]];then
  echo -e "\E[31mERROR: Cannot run 'dialog'.">&2;tput sgr0;
  exit 1;
fi;

PATH_SYSTEM_NETWORK="/etc/systemd/network/static.network";
PATH_DNS_HOST="/etc/smilart/dns-host";

#**************log ERROR****************#
LOG_ERROR[1]="ERROR: Not checked interface.";
LOG_ERROR[2]="ERROR: Found symbol '_' in fields.";
LOG_ERROR[3]="ERROR: Field 'Mask' is incorrect.";
LOG_ERROR[4]="ERROR: Incorrect hostname.";
LOG_ERROR[5]="ERROR: Cannot change hostname.";
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


# valid_ip_func <ip> <name field>
# valid_ip_func 192.168.1.1 Ip
function valid_ip_func() {
  if ! [[ $1 =~ ^(25[0-5]|2[0-4][i0-9]|[0-1][0-9]{2}|[0-9]{2}|[0-9])(\.(25[0-5]|2[0-4][0-9]|[0-1][0-9]{2}|[0-9]{2}|[0-9])){3}$ ]]; then
    error_func "ERROR: Incorrectly field '$2'.";
    continue    
  fi;
}

# field_not_empty_func <field> <field name>
# field_not_empty_func $FORM_IP
function field_not_empty_func() {
if [[ -z $1 ]];then
  error_func "ERROR: Empty field '$2'.";
  continue
fi;
}

#translate netmask to cidr
# mask2cidr_func <mask>
# mask2cidr_func 255.255.254.0
function mask2cidr_func() {
  local nbits=0;
  local IFS=.;
  local dec='';
  for dec in $1 ; do
      case $dec in
          255) let nbits+=8;;
          254) let nbits+=7;;
          252) let nbits+=6;;
          248) let nbits+=5;;
          240) let nbits+=4;;
          224) let nbits+=3;;
          192) let nbits+=2;;
          128) let nbits+=1;;
          0);;
          *) return 1
      esac
  done
  echo "/$nbits"
}

# test_hostname_func <hostname>
function test_hostname_func() {
if ! [[ "$1" =~ ^[a-z][a-z0-9-]{0,}$ ]];then
  error_func ${LOG_ERROR[4]}"ERROR: Incorrect hostname."; 
  continue
fi
}

#****************CONFIGURE INTERFACE**************#
EXIT_FORM="0";
while [[ $EXIT_FORM == "0" ]];do
  # search current interfaces
  inet=`ls /sys/class/net | grep -v "\`ls /sys/devices/virtual/net\`"`

  # generate menu options
  MENU_OPTIONS='';
  COUNT=0
  for i in $inet
  do
    inet[$COUNT]=$i;
    COUNT=$[COUNT+1]
    if [[ `cat /sys/class/net/$i/operstate` == "up" ]];then
      CONNECT_i="$i Connect";
    else
      CONNECT_i="$i -"
    fi; 
    MENU_OPTIONS="${MENU_OPTIONS} ${CONNECT_i} off "
  done

  # Store data to $cmd variable
  exec 3>&1
  FORM_INTERFACE=$(DIALOGRC="$TMP_DIALOG_MENU" dialog --clear \
    --ok-label "NEXT" \
    --title "Smilart Operating System" \
    --radiolist "\nSelect the network interface for configure" \
      10 50 4 \
      ${MENU_OPTIONS} \
      2>&1 1>&3)
  DIALOG_RETURN_VALUE=$?
  exec 3>&-
  
  if [[ $DIALOG_RETURN_VALUE == 1 || $DIALOG_RETURN_VALUE == 255 ]]; then  
    exit 1;
  fi;

  #Correct interface?
  if [[ -z "$FORM_INTERFACE" ]]; then
     error_func "${LOG_ERROR[1]}";
     continue
  else
     #go next dialog
     EXIT_FORM="1";
  fi

done;

#**************CONFIGURE NETWORK**************#
EXIT_FORM="0";

  FORM_IP='';
  FORM_MASK='';
  FORM_GATEWAY='';
  FORM_DNS='';
  FORM_HOSTNAME="`hostname`";

while [[ $EXIT_FORM == "0" ]];do

  # display values just entered	
  MENU_HOSTNAME="'Host name:       ' 9 1 '${FORM_HOSTNAME}'     9 20 30 0"
  # open fd
  exec 3>&1

 #if [ -f $PATH_DNS_HOST ];then
  # Store data to $DIALOG_STRING variable
  DIALOG_STRING=$(DIALOGRC="$TMP_DIALOG_MENU" dialog --clear \
    --ok-label "OK" \
    --title "Smilart Operating System" \
    --form "\nEnter network settings" \
   0 0 0 \
   "Ip:              " 1 1 "$FORM_IP"           1 20 30 0 \
   "Mask:            " 3 1 "$FORM_MASK"         3 20 30 0 \
   "Gateway          " 5 1 "$FORM_GATEWAY"      5 20 30 0 \
   "DNS:             " 7 1 "$FORM_DNS"          7 20 30 0 \
   "Host name:       " 9 1 "$FORM_HOSTNAME"     9 20 30 0 \
   2>&1 1>&3)
  DIALOG_RETURN_VALUE=$?
  exec 3>&-
 
  if [[ $DIALOG_RETURN_VALUE == 1 || $DIALOG_RETURN_VALUE == 255 ]]; then
    exit 1;
  fi;
  
  # exist "_" in form?
  if [[ -n `echo "$DIALOG_STRING" | grep "_"` ]];then
	error_func "${LOG_ERROR[2]}";
        continue
  fi;
  #symbols "\n" to "_"
  DIALOG_STRING=`echo "$DIALOG_STRING" | tr "\n" "_"`

  # convert DIALOG_STRING to variables
  OIFS=$IFS
  IFS='_'
  DIALOG_STRING=($DIALOG_STRING)
  FORM_IP=${DIALOG_STRING[0]};
  FORM_MASK=${DIALOG_STRING[1]};
  FORM_GATEWAY=${DIALOG_STRING[2]};
  FORM_DNS=${DIALOG_STRING[3]};
  
  if [ -f $PATH_DNS_HOST ];then
    if [[ $FORM_HOSTNAME != ${DIALOG_STRING[4]} ]];then
      error_func "${LOG_ERROR[5]}";
      continue
    fi;
  fi;

  FORM_HOSTNAME=${DIALOG_STRING[4]};
  IFS=$OIFS

  #*********Correct ip*********#
  # empty field?
  field_not_empty_func "$FORM_IP" Ip; 

  # It is ip format?
  valid_ip_func "$FORM_IP" Ip;

  #*********Correct mask*********#
  # empty field?
  field_not_empty_func "$FORM_MASK" Mask;

  # Valid mask? 
  if ! [[ $FORM_MASK =~ ^[\/][0-3]{,1}[0-9]$ && ${FORM_MASK:1} -le 32 ]];then
    valid_ip_func "$FORM_MASK" Mask;
    OIFS=$IFS
    IFS="."
    BIN_MASK=""
    for i in ${FORM_MASK[@]};do
      if [[ $i > 255 ]];then 
        error_func "${LOG_ERROR[3]}";
        continue
      fi;
      BIN_MASK+=$(printf "%08d" $(echo "ibase = 10; obase = 2 ; $i" | bc));
    done
    IFS=$OIFS;
    if [[ $BIN_MASK =~ (1*0+1) ]];then
      error_func "${LOG_ERROR[3]}";
      continue
    fi;
    FORM_MASK=`mask2cidr_func "$FORM_MASK"`;
  fi;

  #*********Correct gateway*********#
  if [[ -n "$FORM_GATEWAY" ]]; then
    # It is ip format?
    valid_ip_func "$FORM_GATEWAY" Gateway;
  fi;

  #*********Correct dns*********#
  if [[ -n "$FORM_DNS" ]]; then
    # It is ip format?
    valid_ip_func "$FORM_DNS" DNS;
  fi;

  #*********Correct hostname*********#
  # empty field?
  field_not_empty_func "$FORM_HOSTNAME" Hostname;

  #valid hostname?
  test_hostname_func "$FORM_HOSTNAME";

  EXIT_FORM="1";
done;

#*******************Save to files****************#

#Create config network
echo "
[Match]
Name=$FORM_INTERFACE

[Network]
Address=$FORM_IP$FORM_MASK
`if [[ -n $FORM_GATEWAY ]];then echo "Gateway=$FORM_GATEWAY"; fi`
DNS=127.0.0.1
Domains=smilart.local
" > $PATH_SYSTEM_NETWORK;
sudo systemctl restart systemd-networkd;

#Save dns in temporary file for configure dns server
echo "$FORM_DNS" > $PATH_DNS_HOST;

#Set hostname
sudo hostnamectl set-hostname $FORM_HOSTNAME;



