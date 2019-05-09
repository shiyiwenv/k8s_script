#!/bin/bash
# Copyright (c) 2008-2012 Aerospike, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is furnished to do
# so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# 适用于:
#	1、linux kernel 2.6.32+
#	2、CentOS 6+

# 定义 CPU 掩码，通过掩码来绑定中断号到指定 CPU
# echo MASK > /proc/irq/${IRQ_NUM}/smp_affinity
IRQ_AFFINITY_FOR_CORE[0]=1
IRQ_AFFINITY_FOR_CORE[1]=2
IRQ_AFFINITY_FOR_CORE[2]=4
IRQ_AFFINITY_FOR_CORE[3]=8
IRQ_AFFINITY_FOR_CORE[4]=10
IRQ_AFFINITY_FOR_CORE[5]=20
IRQ_AFFINITY_FOR_CORE[6]=40
IRQ_AFFINITY_FOR_CORE[7]=80
IRQ_AFFINITY_FOR_CORE[8]=100
IRQ_AFFINITY_FOR_CORE[9]=200
IRQ_AFFINITY_FOR_CORE[10]=400
IRQ_AFFINITY_FOR_CORE[11]=800
IRQ_AFFINITY_FOR_CORE[12]=1000
IRQ_AFFINITY_FOR_CORE[13]=2000
IRQ_AFFINITY_FOR_CORE[14]=4000
IRQ_AFFINITY_FOR_CORE[15]=8000
IRQ_AFFINITY_FOR_CORE[16]=10000
IRQ_AFFINITY_FOR_CORE[17]=20000
IRQ_AFFINITY_FOR_CORE[18]=40000
IRQ_AFFINITY_FOR_CORE[19]=80000
IRQ_AFFINITY_FOR_CORE[20]=100000
IRQ_AFFINITY_FOR_CORE[21]=200000
IRQ_AFFINITY_FOR_CORE[22]=400000
IRQ_AFFINITY_FOR_CORE[23]=800000

function check_app_installed {
  if [ -z "$1" ]; then
    echo "Usage: $0 appname"
    exit 1
  fi
  RES=$(which "$1" 2>&1);
  MISS=$?
  if [ $MISS -eq 1 ]; then return 0;
  else                     return 1; fi
}
function check_required_apps {
  check_app_installed numactl
  OK=$?
  if [ $OK -ne 1 ]; then
    echo "Required application not found: (numactl)"
    exit 1;
  fi
}

function check_is_user_root {
  RES=$(whoami)
  if [ "$RES" != "root" ]; then
    echo "ERROR: $0 must be run as user: root"
    exit 1;
  fi
}

function find_eths {
  RES=$(/sbin/ip link show | grep "state UP")
  # NETH : 正在使用的网卡总数
  NETH=$(echo "${RES}" | wc -l)
  I=0; for eth in $(echo "$RES" | cut -f 2 -d : ); do
    ETH[$I]="$eth"; I=$[${I}+1];
  done
}
# NOTE: if the last word in /proc/interrupt does not have a "-"
#       then it is not an active nic-queue, rather a placeholder for the nic
function validate_eth_q {
  echo $1 |rev | cut -f 1 -d \ | rev | grep \- |wc -l
}

# NUM_TOT_ETH_QUEUES	 : 所有网卡的队列总数
# NUM_QUEUES_PER_ETH[$I] : 每个网卡的队列总数
# IRQS_PER_ETH[$I]	 : 网络接口队列所对应的中断号
function count_eth_queues {
  find_eths
  NUM_TOT_ETH_QUEUES=0
  I=0; while [ $I -lt $NETH ]; do
    eth="${ETH[$I]}";
    INTERRUPTS=$(grep "$eth" /proc/interrupts)
    GOOD_INTERRUPTS=$(echo "${INTERRUPTS}" |while read intr; do
                       GOOD=$(validate_eth_q "$intr")
                       if [ "$GOOD" == "1" ]; then echo "$intr"; fi
                     done)
    NUM_QUEUES_PER_ETH[$I]=$(echo "${GOOD_INTERRUPTS}" | wc -l)
    NUM_TOT_ETH_QUEUES=$[${NUM_QUEUES_PER_ETH[$I]}+${NUM_TOT_ETH_QUEUES}];
    IRQS_PER_ETH[$I]=$(echo "${GOOD_INTERRUPTS}" | cut -f 1 -d :)
    #echo eth: $eth NUMQ: ${NUM_QUEUES_PER_ETH[$I]} IRQS: ${IRQS_PER_ETH[$I]}
    I=$[${I}+1];
  done
}

function get_num_cpu_sockets {
  NCS=$(numactl --hardware |grep cpus: | wc -l)
}

function get_cpu_socket_cores {
  get_num_cpu_sockets
  # NUM_TOT_CPU_CORES : CPU 逻辑核总数
  NUM_TOT_CPU_CORES=0
  I=0; while [ $I -lt $NCS ]; do
    SOCKET_CORES[$I]=$(numactl --hardware |grep "node $I cpus:" | cut -f 2 -d :)
    NUM_CORE_PER_SOCKET[$I]=$(echo ${SOCKET_CORES[$I]} | wc -w)
    NUM_TOT_CPU_CORES=$[${NUM_CORE_PER_SOCKET[$I]}+${NUM_TOT_CPU_CORES}];
    I=$[${I}+1];
  done
}
