#!/bin/bash

PATH_TIMEZONE='/usr/share/zoneinfo';

#exist dialog?
dialog --clear;
if [[ $? != 0 ]];then
  echo -e "\E[31mERROR: Cannot run 'dialog'.">&2;tput sgr0;
  exit 1;
fi;

set_timezone_func(){
  sudo /usr/bin/timedatectl set-timezone "$1";
  sudo echo "$1" > /etc/timezone;
}

set_date_func(){
  sudo /usr/bin/timedatectl set-time "$1 $2";
}

# echo ERROR to dialog
# error_func <text>
error_func() {
  DIALOGRC="$TMP_DIALOG_ERROR" \
    dialog --msgbox "\n$1" 10 50
}

#****************CONFIGURE DATA INTERFACE**************#
EXIT_FORM="0";

MENU_TIMEZONE=`timedatectl status 2>/dev/null |grep 'Time zone:' |awk '{print $3}'`
if [[ $MENU_TIMEZONE == 'n/a' ]];then 
  MENU_TIMEZONE='UTC';
fi;
MENU_DATE=`date '+%F'`;
MENU_TIME=`date '+%T'`;


while [[ $EXIT_FORM == "0" ]];do
  
  # Store data to variable
  exec 3>&1
  FORM_DATA=$(dialog --clear --ok-label "Change" \
       --cancel-label "OK" \
       --title "Smilart Operating System" \
       --menu "\nConfigure date and time\n" 0 0 0 \
              "Timezone:     " "$MENU_TIMEZONE" \
              "Date:         " "$MENU_DATE" \
              "Time:         " "$MENU_TIME" \
                2>&1 1>&3)
  DIALOG_RETURN_VALUE=$?;
  exec 3>&-
  
  if [[ $DIALOG_RETURN_VALUE == 255 ]]; then
    exit 1;
  fi;

  #Timezone
  if [[ "$FORM_DATA" == "Timezone:     " ]];then
      CHTZ_EXIT_FORM="0";
      while [[ $CHTZ_EXIT_FORM == "0" ]];do
         CHTZ_COUNT=0;
         CHTZ_MENU_LIST='';
         CHTZ_TIMEZONE_RESULT="$MENU_TIMEZONE";
         CHTZ_LIST_TIMEZONES=`ls $PATH_TIMEZONE/ | grep -E -v "SystemV|posix|right|iso3166.tab|localtime|posixrules|zone1970.tab|zone.tab" | sort`
         #Generate menu 
         for i in $CHTZ_LIST_TIMEZONES
         do
           CHTZ_COUNT=$[CHTZ_COUNT+1];
           CHTZ_LIST_TIMEZONES[$CHTZ_COUNT]=$i
           if [ -d "$PATH_TIMEZONE/$i" ];then
             i="$i/"
           fi;
           CHTZ_MENU_LIST="${CHTZ_MENU_LIST} $CHTZ_COUNT $i ";
         done;
         #
         #Start dialog
         exec 3>&1
         CHTZ_FORM_TIMEZONE=$(dialog --clear --ok-label "OK" \
           --cancel-label "Back" \
           --title "Smilart Operating System" \
           --menu "Select timezone" 40 0 35 \
                  ${CHTZ_MENU_LIST} \
                2>&1 1>&3)
         CHTZ_DIALOG_RETURN_VALUE=$?
         exec 3>&-
         #Stop dialog
         if [[ $CHTZ_DIALOG_RETURN_VALUE == 1 || $CHTZ_DIALOG_RETURN_VALUE == 255 ]]; then
           MENU_TIME=`date '+%T'`;
           CHTZ_EXIT_FORM="1";
           continue
         fi;

         #Result 
         CHTZ_TIMEZONE_RESULT="${CHTZ_LIST_TIMEZONES[$CHTZ_FORM_TIMEZONE]}";

           #check dirrectory?
           if [ -d "$PATH_TIMEZONE/${CHTZ_LIST_TIMEZONES[$CHTZ_FORM_TIMEZONE]}" ];then
              CHTZ_MENU_LIST='';
              CHTZ_COUNT=0;
              CHTZ_LIST_TIMEZONES_IN_DIR=`ls $PATH_TIMEZONE/${CHTZ_LIST_TIMEZONES[$CHTZ_FORM_TIMEZONE]} | sort`;
              for i in $CHTZ_LIST_TIMEZONES_IN_DIR
              do
                CHTZ_COUNT=$[CHTZ_COUNT+1];
                CHTZ_LIST_TIMEZONES_IN_DIR[$CHTZ_COUNT]=$i
                CHTZ_MENU_LIST="${CHTZ_MENU_LIST} $CHTZ_COUNT $i ";
              done;
              exec 3>&1
              CHTZ_FORM_TIMEZONE=$(dialog --clear --ok-label "OK" \
                --cancel-label "Back" \
                --title "Smilart Operating System" \
                --menu "Select timezone" 40 0 35 \
                  ${CHTZ_MENU_LIST} \
                  2>&1 1>&3)
              CHTZ_DIALOG_RETURN_VALUE=$?;
              exec 3>&-
              if [[ $CHTZ_DIALOG_RETURN_VALUE == 1 || $CHTZ_DIALOG_RETURN_VALUE == 255 ]]; then
                 continue
              fi;
              CHTZ_TIMEZONE_RESULT="$CHTZ_TIMEZONE_RESULT/${CHTZ_LIST_TIMEZONES_IN_DIR[$CHTZ_FORM_TIMEZONE]}";
           fi;
      CHTZ_EXIT_FORM="1";
      done;
      MENU_TIMEZONE="$CHTZ_TIMEZONE_RESULT";
      set_timezone_func $MENU_TIMEZONE;
      MENU_TIME=`date '+%T'`;
      continue
  fi;

  if [[ "$FORM_DATA" == "Date:         " ]];then
    CHD_DATE_RESULT="$MENU_DATE";
    CHD_MENU_DATE=`echo "$MENU_DATE" | awk -F "-" '{ print $3 " " $2 " " $1 }'`;
    exec 3>&1
    CHD_FORM_DATE=$(dialog --clear --ok-label "OK" \
       --cancel-label "Back" \
       --title "Smilart Operating System" \
       --calendar "Select date" 0 0 \
         ${CHD_MENU_DATE} \
         2>&1 1>&3)
    CHD_DIALOG_RETURN_VALUE=$?;
    exec 3>&-
    MENU_TIME=`date '+%T'`;    
    if [[ $CHD_DIALOG_RETURN_VALUE == 1 || $CHD_DIALOG_RETURN_VALUE == 255 ]]; then
       continue
    fi;
    MENU_DATE=`echo "$CHD_FORM_DATE" | awk -F "/" '{ print $3 "-" $2 "-" $1 }'`;
    set_date_func "$MENU_DATE" "$MENU_TIME";
    continue
  fi;

  if [[ "$FORM_DATA" == "Time:         " ]];then
    CHT_MENU_TIME=`date '+%H %M %S'`;
    exec 3>&1
    CHT_FORM_TIME=$(dialog --clear --ok-label "OK" \
       --cancel-label "Back" \
       --title "Smilart Operating System" \
       --timebox "\nSelect time\n" 0 0 \
         ${CHT_MENU_TIME} \
         2>&1 1>&3)
    CHT_DIALOG_RETURN_VALUE=$?;
    exec 3>&-
    if [[ $CHD_DIALOG_RETURN_VALUE == 1 || $CHD_DIALOG_RETURN_VALUE == 255 ]]; then
       MENU_TIME=`date '+%T'`;
       continue
    fi;
    MENU_TIME="$CHT_FORM_TIME"
    set_date_func "$MENU_DATE" "$MENU_TIME";
    continue
  fi;

  EXIT_FORM="1";
done;
