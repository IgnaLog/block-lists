#!/bin/bash

# update_blocklists.sh (C) 2024 Ignacio Llorente https://ignacio.vercel.app
# Licensed under the GNU-GPLv2+

# --- Script Processes and Functions --- #

# Function that checks if there is internet
check_internet() {
  ping -q -c 1 -W 1 google.com >/dev/null 2>&1
}

# Function to check if build-essential is installed
check_build_tool() { 
  dpkg -s build-essential &> /dev/null
}

# Process to create directories if they do not exist
create_directory() {
  [ ! -d "$1" ] && mkdir -p "$1"
}

# Process that sends notifications to the user
handle_notifications() {  
  if [ "$NOTIFY_CACHE" -gt 0 ]; then
    notify-send --urgency=normal "Updating Block Lists" "The block lists have been updated but some lists were obtained from the cache. Run the BlockIPs/update_blocklist.sh script to see why."
  fi

  if [ "$NOTIFY_NO_FILES" -gt 0 ]; then
    notify-send --urgency=critical "Updating Block Lists" "Some block lists could not be updated. Run the BlockIPs/update_blocklist.sh script to see why."
  fi

  if [ "$NOTIFY_ERROR" -gt 0 ]; then
    notify-send --urgency=critical "Updating Block Lists" "Block lists could not be updated. Run the BlockIPs/update_blocklist.sh script on its own."
  fi
  
  if [ "$NOTIFY_CACHE" -eq 0 ] && [ "$NOTIFY_NO_FILES" -eq 0 ] && [ "$NOTIFY_ERROR" -eq 0 ]; then
    notify-send --urgency=low "Updating Block Lists" "Block lists have been updated."
  fi
}

# Process to download and process bluetack lists
process_bluetack_lists() {
  # Get IBlockList lists
  # They are in a special format
  # ConvertIPs is needed to create our lists in the correct format
  for ((i = 0; i < ${#BLUETACK[@]}; i++)); do
    echo "Importing bluetack list ${BLUETACKALIAS[i]}..."
    if wget --quiet -O /tmp/${BLUETACKALIAS[i]}.gz "http://list.iblocklist.com/?list=${BLUETACK[i]}&fileformat=p2p&archiveformat=gz"; then
       mv /tmp/${BLUETACKALIAS[i]}.gz $LISTDIR/${BLUETACKALIAS[i]}.gz
    else
       echo "Using cached list for ${BLUETACKALIAS[i]}."
       ((NOTIFY_CACHE++))
    fi
    
    if [ -f $LISTDIR/${BLUETACKALIAS[i]}.gz ]; then
       zcat $LISTDIR/${BLUETACKALIAS[i]}.gz > $LISTDIR/${BLUETACKALIAS[i]}.txt
    else
       echo "The file does not exist $LISTDIR/${BLUETACKALIAS[i]}.gz."
       ((NOTIFY_NO_FILES++))
       continue
    fi
    
    if [ -f $LISTDIR/${BLUETACKALIAS[i]}.txt ]; then
       ./convertIPs "$LISTDIR/${BLUETACKALIAS[i]}.txt"
       if [ $? -gt 0 ]; then
         ((NOTIFY_ERROR++))
         handle_notifications
         exit 1
       fi
    else
       echo "The file does not exist $LISTDIR/${BLUETACKALIAS[i]}.txt."
       ((NOTIFY_NO_FILES++))
    fi
  done
}

# Process to download and process country lists
process_country_lists() {
  # get the country lists and cat them into a single file
  for ((i = 0; i < ${#COUNTRIES[@]}; i++)); do
    echo "Importing country ${COUNTRIES[i]} to the list..."
    if wget --quiet -O /tmp/${COUNTRIES[i]}.txt "http://www.ipdeny.com/ipblocks/data/countries/${COUNTRIES[i]}.zone"; then
      cat /tmp/${COUNTRIES[i]}.txt > $LISTDIR/${COUNTRIES[i]}.txt
      cat /tmp/${COUNTRIES[i]}.txt >> $RANGESDIR/listsOfNETs.txt
      rm /tmp/${COUNTRIES[i]}.txt
    else
      if [ -f "$LISTDIR/${COUNTRIES[i]}.txt" ]; then
        echo "Using cached list for ${COUNTRIES[i]}."
        cat $LISTDIR/${COUNTRIES[i]}.txt >> $RANGESDIR/listsOfNETs.txt
        ((NOTIFY_CACHE++))
      else
        echo "No cached list available for ${COUNTRIES[i]}."
        ((NOTIFY_NO_FILES++))
      fi
    fi
  done
}

# Process to download and process Tor lists
process_tor_lists() {
  # Get the tor lists and cat them into a single file
  for ip in $(ip -4 -o addr | awk '!/^[0-9]*: ?lo|link\/ether/ {gsub("/", " "); print $4}'); do
    for ((i = 0; i < ${#PORTS[@]}; i++)); do
      echo "Importing Tor port ${PORTS[i]} to the list..."
      if wget --quiet -O /tmp/${PORTS[i]}.txt "https://check.torproject.org/cgi-bin/TorBulkExitList.py?ip=$ip&port=${PORTS[i]}"; then
        cat /tmp/${PORTS[i]}.txt > $LISTDIR/${PORTS[i]}.txt
        cat /tmp/${PORTS[i]}.txt >> $ADDRESSESDIR/listsOfIPs.txt
         rm /tmp/${PORTS[i]}.txt
      else
        if [ -f "$LISTDIR/${PORTS[i]}.txt" ]; then
      	  echo "Using cached list for ${PORTS[i]}."
      	  cat $LISTDIR/${PORTS[i]}.txt >> $ADDRESSESDIR/listsOfIPs.txt
      	  ((NOTIFY_CACHE++))
      	else
      	  echo "No cached list available for ${PORTS[i]}."
      	  ((NOTIFY_NO_FILES++))
      	fi
      fi
    done
  done
}

# --- Script Start --- #

# Notification variables
NOTIFY_CACHE=0
NOTIFY_NO_FILES=0
NOTIFY_ERROR=0

# If there is no Internet connection it does not proceed
if ! check_internet; then
 echo "There is no Internet connection."
 ((NOTIFY_ERROR++))
 handle_notifications
 exit 1
fi

# Check that the build tool exists
if ! check_build_tool; then
 echo "No build tool."
 ((NOTIFY_ERROR++))
 handle_notifications
 exit 1
fi

# Enable/disable features
ENABLE_BLUETACK=1
ENABLE_COUNTRY=1
ENABLE_TORBLOCK=1

# Countries to block
COUNTRIES=(af ae ir iq tr cn sa sy ru ua hk id kz kw ly)

# Bluetack lists to use - you can get them from:
# https://www.iblocklist.com/lists.php
BLUETACKALIAS=(DShield Hijacked DROP ForumSpam WebExploit Ads Proxies BadSpiders CruzIT Zeus Palevo Malicious Malcode Adservers)
BLUETACK=(xpbqleszmajjesnzddhv usrcshglbiilevmyfhse zbdlwrqkabxbcppvrnos ficutxiwawokxlcyoeye ghlzqtqxnzctvvajwwag dgxtneitpuvgqqcpfulq xoebmbyexwuiogmbyprb mcvxsnihddgutbjfbghy czvaehmjpsnwwttrdoyl ynkdjqsjyfmilsgbogqf erqajhwrxiuvjxqrrwfj npkuuhuxcsllnhoamkvm pbqcylkejciyhmwttify zhogegszwduurnvsyhdf) 

# Ports to block Tor users from
PORTS=(80 443 6667 22 21)

# Directories for our block lists
LISTDIR="lists"
ADDRESSESDIR="addresses"
RANGESDIR="ranges"

# Create directories if they do not exist
create_directory "$LISTDIR"
create_directory "$ADDRESSESDIR"
create_directory "$RANGESDIR"

# Remove old lists of NETs and IPs if they exist, no error if it does not exist
rm -f "$RANGESDIR/listsOfNETs.txt"
rm -f "$ADDRESSESDIR/listsOfIPs.txt"

# Process lists based on enable/disable flags
if [ $ENABLE_BLUETACK = 1 ]; then
  # Compile convertIPs if it does not exist
  [ -e convertIPs ] || gcc convertIPs.c -o convertIPs
  if [ $? -gt 0 ]; then
    echo "convertIPs could not be compiled."
    ((NOTIFY_ERROR++))
    handle_notifications
    exit 1
  fi
  process_bluetack_lists
fi

# Wait for the convertIPs program to finish
wait

if [ $ENABLE_COUNTRY = 1 ]; then
  # Get the country lists and cat them into a single file
  process_country_lists
fi

if [ $ENABLE_TORBLOCK = 1 ]; then
  # Get the tor lists and cat them into a single file
  process_tor_lists
fi

# Send notification to user
handle_notifications

# Check if the script is already in cron
if ! crontab -l | grep -q "$(readlink -f "$0")"; then
  # Add the script to cron to run every week at 11 PM
  (crontab -l ; echo "0 23 * * 0 $(readlink -f "$0")") | crontab -
fi