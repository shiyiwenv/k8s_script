#!/bin/bash
#
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

# 此脚本摘自 Aerospike，用于均衡 CPU0 的网络中断到多个 CPU 上。
# 适用于:
#       1、linux kernel 2.6.32+
#       2、CentOS 6+

CURRENT_DIR=$(dirname $0)
SCRIPT_HOME=$(cd $CURRENT_DIR; pwd)
#echo $SCRIPT_HOME

. $SCRIPT_HOME/helper.sh

check_is_user_root
check_required_apps

count_eth_queues
get_cpu_socket_cores

# 正在使用的 CPU 插槽数
NCS=1 # jerry-rig NCS for non cpu-socket aware community edition

# NETH：正在使用的网卡总数
# NUM_TOT_ETH_QUEUES：网络接口队列总数
if [ $NETH -gt 1 -a $NUM_TOT_ETH_QUEUES -gt 1 ]; then
  echo "Number of Ethernet interfaces detected: ($NETH)"
  echo "Apply NIQ queue IRQ smp_affinity to ALL ethernet interfaces: [y/n]"
  read ans
  if [ "$ans" != "Y" -a "$ans" != "y" ]; then
    echo "Skipping NIQ queue IRQ smp_affinity optimizations"
    exit 0;
  fi
fi

# CL_IRQS_PER_ETH[$I]、IRQS_PER_ETH[$I]：网络接口队列所对应的中断号
# CL_NUM_QUEUES_PER_ETH[$I]、NUM_QUEUES_PER_ETH[$I] : 每个网卡的队列总数
I=0; while [ $I -lt $NETH ]; do
  CL_ETH[$I]=${ETH[$I]}
  CL_NUM_QUEUES_PER_ETH[$I]=${NUM_QUEUES_PER_ETH[$I]}
  CL_IRQS_PER_ETH[$I]=${IRQS_PER_ETH[$I]}
  I=$[${I}+1];
done

# NUM_TOT_CPU_CORES : CPU 逻辑核总数
# CL_NUM_QUEUES_PER_ETH[$I] : 每个网卡的队列总数
# IRQ[$J] : 网络接口队列所对应的中断号
I=0; while [ $I -lt $NETH ]; do
  J=0; for irq in ${CL_IRQS_PER_ETH[$I]}; do
    IRQ[$J]=$irq J=$[${J}+1];
  done
  J=0; while [ $J -lt $NUM_TOT_CPU_CORES -a $J -lt ${CL_NUM_QUEUES_PER_ETH[$I]} ]; do
    echo "Configuring core: $J; ETH: ${CL_ETH[$I]}; IRQ: ${IRQ[$J]}; AFFINITY: ${IRQ_AFFINITY_FOR_CORE[${J}]}"
    # 核心代码只有这一句
    echo ${IRQ_AFFINITY_FOR_CORE[${J}]} > /proc/irq/${IRQ[$J]}/smp_affinity
    J=$[${J}+1];
  done
  I=$[${I}+1];
done

exit 0;

