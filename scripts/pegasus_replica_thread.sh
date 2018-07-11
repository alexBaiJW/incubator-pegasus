#!/bin/bash

PID=$$

if [ $# -ne 3 ]
then
  echo "This tool is for stat replica dispatch count on replication threads."
  echo "USAGE: $0 <cluster-meta-list> <app-name> <replication-thread-num>"
  exit 1
fi

pwd="$( cd "$( dirname "$0"  )" && pwd )"
shell_dir="$( cd $pwd/.. && pwd )"
cd $shell_dir

cluster=$1
app_name=$2
thread_num=$3

echo "UID: $UID"
echo "PID: $PID"
echo "cluster: $cluster"
echo "app_name: $app_name"
echo "thread_num: $thread_num"
echo "Start time: `date`"
all_start_time=$((`date +%s`))
echo

echo "app $app_name -d" | ./run.sh shell --cluster $cluster &>/tmp/$UID.$PID.pegasus.app.$app_name
list_ok=`grep "list app $app_name succeed" /tmp/$UID.$PID.pegasus.app.$app_name | wc -l`
if [ $list_ok -ne 1 ]; then
  grep ERR /tmp/$UID.$PID.pegasus.app.$app_name
  echo "ERROR: list app failed, refer to /tmp/$UID.$PID.pegasus.app.$app_name"
  exit 1
fi

app_id=`cat /tmp/$UID.$PID.pegasus.app.$app_name | grep "^app_id" | awk '{print $3}'`
cat /tmp/$UID.$PID.pegasus.app.$app_name | grep " \[" | grep "\]$" >/tmp/$UID.$PID.pegasus.config.$app_name
cat /tmp/$UID.$PID.pegasus.config.$app_name | sed 's/\[//;s/\]//;s/,/ /' | awk '{print $4"\n"$5"\n"$6}' | sort | uniq >/tmp/$UID.$PID.pegasus.node.$app_name

# pad_str <str> <pad_length> <left|right>
pad_str()
{
  str=$1
  padlength=$2
  padtype=$3
  empty="$(printf '%*s' $padlength)"
  if [ "$padtype" == "left" ]; then
      printf '%s' "$str"
  fi
  printf '%*.*s' 0 $((padlength - ${#str})) "$empty"
  if [ "$padtype" == "right" ]; then
      printf '%s' "$str"
  fi
}

node_pad_length=22
thread_pad_length=3
pad_str "node  \\  thread_id" $node_pad_length left
for i in `seq 0 $((thread_num-1))` ; do
  pad_str $i $thread_pad_length right
done
pad_str "#replica" 9 right
pad_str "max" 5 right
pad_str "#max" 5 right
echo

max_max=0
while read node
do
  pad_str "$node" $node_pad_length left
  grep "\<$node\>" /tmp/$UID.$PID.pegasus.config.$app_name | awk '{print ('$app_id'*7179+$1)%'$thread_num'}' | sort -n | uniq -c >/tmp/$UID.$PID.pegasus.stat.$app_name.$node
  replica_count=0
  max=0
  max_time=0
  for i in `seq 0 $((thread_num-1))`
  do
    count=`awk '{if ($2=='$i') print $1}' /tmp/$UID.$PID.pegasus.stat.$app_name.$node`
    if [ "z$count" == "z" ]; then
      count=0
    fi
    pad_str "$count" $thread_pad_length right
    replica_count=$((replica_count+1))
    if [ $count -gt $max ]; then
      max=$count
      max_time=1
    elif [ $count -eq $max ]; then
      max_time=$((max_time+1))
    fi
  done
  pad_str "$replica_count" 9 right
  pad_str "$max" 5 right
  pad_str "$max_time" 5 right
  if [ $max -gt $max_max ]; then
    max_max=$max
  fi
  echo
done </tmp/$UID.$PID.pegasus.node.$app_name

pad_str "" $node_pad_length left
for i in `seq 0 $((thread_num-1))` ; do
  pad_str "" $thread_pad_length right
done
pad_str "" 9 right
pad_str "$max_max" 5 right
pad_str "" 5 right
echo

echo "Notes:"
echo "  max   : maximum replica count dispatching on single thread"
echo "  #max  : thread count dispatching maximum replicas"
echo

echo "Finish time: `date`"
all_finish_time=$((`date +%s`))
echo "Statistics done, elasped time is $((all_finish_time - all_start_time)) seconds."

rm -f /tmp/$UID.$PID.pegasus.* &>/dev/null
