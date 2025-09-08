#!/bin/sh

source /koolshare/scripts/base.sh
eval $(dbus export cloudreve_)
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'
LOG_FILE=/tmp/upload/cloudreve_log.txt
LOCK_FILE=/var/lock/cloudreve.lock
BASH=${0##*/}
ARGS=$@
MAX_RETRY=10
# 初始化配置变量
CloudreveBaseDir=$(dbus get cloudreve_old_dir)
configPort=5212
configHttpsPort=5213
configDisableHttp=false
configHttps=false
configCertFile=''
configKeyFile=''

set_lock() {
  exec 233>${LOCK_FILE}
  flock -n 233 || {
    # bring back to original log
    http_response "$ACTION"
    exit 1
  }
}

unset_lock() {
  flock -u 233
  rm -rf ${LOCK_FILE}
}

number_test() {
  case $1 in
  '' | *[!0-9]*)
    echo 1
    ;;
  *)
    echo 0
    ;;
  esac
}

detect_url() {
  local fomart_1=$(echo $1 | grep -E "^https://|^http://")
  local fomart_2=$(echo $1 | grep -E "\.")
  if [ -n "${fomart_1}" -a -n "${fomart_2}" ]; then
    return 0
  else
    return 1
  fi
}

dbus_rm() {
  # remove key when value exist
  if [ -n "$1" ]; then
    dbus remove $1
  fi
}

detect_running_status() {
  local BINNAME=$1
  local PID
  local i=40
  until [ -n "${PID}" ]; do
    usleep 250000
    i=$(($i - 1))
    PID=$(pidof ${BINNAME})
    if [ "$i" -lt 1 ]; then
      echo_date "🔴$1进程启动失败, 请检查你的配置!"
      return
    fi
  done
  echo_date "🟢$1启动成功, pid: ${PID}"
}

check_usb2jffs_used_status() {
  # 查看当前/jffs的挂载点是什么设备, 如/dev/mtdblock9, /dev/sda1；有usb2jffs的时候, /dev/sda1, 无usb2jffs的时候, /dev/mtdblock9, 出问题未正确挂载的时候, 为空
  local cur_patition=$(df -h | /bin/grep /jffs | awk '{print $1}')
  local jffs_device="not mount"
  if [ -n "${cur_patition}" ]; then
    jffs_device=${cur_patition}
  fi
  local mounted_nu=$(mount | /bin/grep "${jffs_device}" | grep -E "/tmp/mnt/|/jffs" | /bin/grep -c "/dev/s")
  if [ "${mounted_nu}" -eq "2" ]; then
    echo "1" # 已安装并成功挂载
  else
    echo "0" # 未安装或未挂载
  fi
}

check_run_mode() {
  if [ $(check_usb2jffs_used_status) == "1" ] && [ "${1}" == "start" ]; then
    echo_date "➡️检测到已安装插件usb2jffs并成功挂载, 插件可以正常启动!"
  fi
}

del_sec() {
  sed -i "/^\[$2\]/,/^\[.*\]/ { /^\[$2\]/! { /^\[.*\]/!d } }" "$1"
}

upd_ini() {
  local ini_file="$1"
  local section="$2"
  local key="$3"
  local value="$4"

  if [[ ! -f "$ini_file" ]]; then
    echo "Error: INI file '$ini_file' does not exist."
    return 1
  fi

  # 转义特殊字符，避免 `sed` 出现问题
  local escaped_section
  local escaped_key
  local escaped_value
  escaped_section=$(printf '%s' "$section" | sed 's/[][\/.^$*]/\\&/g')
  escaped_key=$(printf '%s' "$key" | sed 's/[][\/.^$*]/\\&/g')
  escaped_value=$(printf '%s' "$value" | sed 's/[&/]/\\&/g') # 转义 `/` 和 `&`

  # 检查 Section 是否存在
  if grep -q "^\[$escaped_section\]$" "$ini_file"; then
    # Section 存在，检查 Key 是否存在
    if sed -n "/^\[$escaped_section\]/,/^\[/p" "$ini_file" | grep -q "^$escaped_key ="; then
      # Key 存在，更新值
      sed -i "/^\[$escaped_section\]/,/^\[/s/^$escaped_key = .*/$escaped_key = $escaped_value/" "$ini_file"
    else
      # Key 不存在，添加键值
      sed -i "/^\[$escaped_section\]/a$key = $value" "$ini_file"
    fi
  else
    # Section 不存在，添加 Section 和键值
    echo -e "\n[$section]\n$key = $value" >>"$ini_file"
  fi
}

makeConfig() {
  # 初始化端口
  if [ $(number_test ${cloudreve_port}) != "0" ]; then
    dbus set cloudreve_port=${configPort}
  else
    configPort=${cloudreve_port}
  fi

  # 初始化https端口
  if [ $(number_test ${cloudreve_https_port}) != "0" ]; then
    dbus set cloudreve_https_port=${configHttpsPort}
  else
    configHttpsPort=${cloudreve_https_port}
  fi

  # 初始化https, 条件:
  # 1. 必须要开启公网访问
  # 2. https开关要打开
  # 3. 证书文件路径和密钥文件路径都不能为空
  # 4. 证书文件和密钥文件要在路由器内找得到
  # 5. 证书文件和密钥文件要是合法的
  # 6. 证书文件和密钥文件还必须得相匹配
  # 7. 继续往下的话就是验证下证书中的域名是否和URL中的域名匹配...算了太麻烦没必要做了
  if [ "${cloudreve_publicswitch}" == "1" ]; then
    # 1. 必须要开启公网访问
    if [ "${cloudreve_https}" == "1" ]; then
      # 2. https开关要打开
      if [ -n "${cloudreve_cert_file}" -a -n "${cloudreve_key_file}" ]; then
        # 3. 证书文件路径和密钥文件路径都不能为空
        if [ -f "${cloudreve_cert_file}" -a -f "${cloudreve_key_file}" ]; then
          # 4. 证书文件和密钥文件要在路由器内找得到
          local CER_VERFY=$(openssl x509 -noout -pubkey -in ${cloudreve_cert_file} 2>/dev/null)
          local KEY_VERFY=$(openssl pkey -pubout -in ${cloudreve_key_file} 2>/dev/null)
          if [ -n "${CER_VERFY}" -a -n "${KEY_VERFY}" ]; then
            # 5. 证书文件和密钥文件要是合法的
            local CER_MD5=$(echo "${CER_VERFY}" | md5sum | awk '{print $1}')
            local KEY_MD5=$(echo "${KEY_VERFY}" | md5sum | awk '{print $1}')
            if [ "${CER_MD5}" == "${KEY_MD5}" ]; then
              # 6. 证书文件和密钥文件还必须得相匹配
              echo_date "🆗证书校验通过!为cloudreve面板启用https..."
              configHttps=true
              configCertFile=${cloudreve_cert_file}
              configKeyFile=${cloudreve_key_file}
            else
              echo_date "⚠️无法启用https, 原因如下: "
              echo_date "⚠️证书公钥:${cloudreve_cert_file} 和证书私钥: ${cloudreve_key_file}不匹配!"
              dbus set cloudreve_cert_error=1
              dbus set cloudreve_key_error=1
            fi
          else
            echo_date "⚠️无法启用https, 原因如下: "
            if [ -z "${CER_VERFY}" ]; then
              echo_date "⚠️证书公钥Cert文件错误, 检测到这不是公钥文件!"
              dbus set cloudreve_cert_error=1
            fi
            if [ -z "${KEY_VERFY}" ]; then
              echo_date "⚠️证书私钥Key文件错误, 检测到这不是私钥文件!"
              dbus set cloudreve_key_error=1
            fi
          fi
        else
          echo_date "⚠️无法启用https, 原因如下: "
          if [ ! -f "${cloudreve_cert_file}" ]; then
            echo_date "⚠️未找到证书公钥Cert文件!"
            dbus set cloudreve_cert_error=1
          fi
          if [ ! -f "${cloudreve_key_file}" ]; then
            echo_date "⚠️未找到证书私钥Key文件!"
            dbus set cloudreve_key_error=1
          fi
        fi
      else
        echo_date "⚠️无法启用https, 原因如下: "
        if [ -z "${cloudreve_cert_file}" ]; then
          echo_date "⚠️证书公钥Cert文件路径未配置!"
          dbus set cloudreve_cert_error=1
        fi
        if [ -z "${cloudreve_key_file}" ]; then
          echo_date "⚠️证书私钥Key文件路径未配置!"
          dbus set cloudreve_key_error=1
        fi
      fi
    fi
  fi

  # 检查关闭http访问
  if [ "${configHttps}" == "true" ]; then
    if [ "${configHttpsPort}" == "${configPort}" ]; then
      configHttps=false
      configHttpsPort="-1"
      echo_date "⚠️ Cloudreve 管理面板http和https端口相同, 本次启动关闭https!"
    fi
  else
    configHttpsPort="-1"
  fi

  # 公网/内网访问
  local BINDADDR
  local LANADDR=$(ifconfig br0 | grep -Eo "inet addr.+" | awk -F ":| " '{print $3}' 2>/dev/null)
  if [ "${cloudreve_publicswitch}" != "1" ]; then
    if [ -n "${LANADDR}" ]; then
      BINDADDR=${LANADDR}
    else
      BINDADDR="0.0.0.0"
    fi
  else
    BINDADDR="0.0.0.0"
  fi

  echo_date "➡️更新cloudreve配置到${CloudreveBaseDir}/data/conf.ini文件!"
  upd_ini "${CloudreveBaseDir}/data/conf.ini" "System" "Listen" ":$configPort"
  if [ "${configHttps}" == "true" ]; then
    upd_ini "${CloudreveBaseDir}/data/conf.ini" "SSL" "Listen" ":$configHttpsPort"
    upd_ini "${CloudreveBaseDir}/data/conf.ini" "SSL" "CertPath" "$configCertFile"
    upd_ini "${CloudreveBaseDir}/data/conf.ini" "SSL" "KeyPath" "$configKeyFile"
  else
    del_sec "${CloudreveBaseDir}/data/conf.ini" "SSL"
  fi
}

# 检查已开启插件
check_enable_plugin() {
  echo_date "ℹ️当前已开启如下插件: "
  local titles=""
  for mod in $(dbus listall | grep 'enable=1' | awk -F '_' '!a[$1]++ {print $1}'); do
    t=$(dbus get "softcenter_module_${mod}_title")
    [ -n "$t" ] && titles="$titles$t,"
  done
  # 去掉末尾多余逗号
  titles=${titles%,}
  echo_date "➡️$titles"
}

# 检查内存是否合规
check_memory() {
  local swap_size=$(free | grep Swap | awk '{print $2}')
  echo_date "ℹ️检查系统内存是否合规!"
  if [ "$swap_size" != "0" ]; then
    echo_date "✅️当前系统已经启用虚拟内存!容量: ${swap_size}KB"
  else
    local memory_size=$(free | grep Mem | awk '{print $2}')
    if [ "$memory_size" != "0" ]; then
      if [ $memory_size -le 750000 ]; then
        echo_date "❌️插件启动异常!"
        echo_date "❌️检测到系统内存为: ${memory_size}KB, 需挂载虚拟内存!"
        echo_date "❌️Cloudreve程序对路由器开销极大, 请挂载1G及以上虚拟内存后重新启动插件!"
        stop_process
        dbus set cloudreve_memory_error=1
        dbus set cloudreve_enable=0
        exit
      else
        echo_date "⚠️Cloudreve程序对路由器开销极大, 建议挂载1G及以上虚拟内存, 以保证稳定!"
        dbus set cloudreve_memory_warn=1
      fi
    else
      echo_date"⚠️未查询到系统内存, 请自行注意系统内存!"
    fi
  fi
  echo_date "=============================================="
}

start_process() {
  CLOUDREVE_RUN_LOG=/tmp/upload/cloudreve_run_log.txt
  rm -rf ${CLOUDREVE_RUN_LOG}
  if [ "${cloudreve_watchdog}" == "1" ]; then
    echo_date "🟠启动 cloudreve 进程, 开启进程实时守护..."
    mkdir -p /koolshare/perp/cloudreve
    cat >/koolshare/perp/cloudreve/rc.main <<-EOF
			#!/bin/sh
			source /koolshare/scripts/base.sh
			CMD="${CloudreveBaseDir}/cloudreve"
			if test \${1} = 'start' ; then
				exec >${CLOUDREVE_RUN_LOG} 2>&1
				exec \$CMD
			fi
			exit 0

		EOF
    chmod +x /koolshare/perp/cloudreve/rc.main
    chmod +t /koolshare/perp/cloudreve/
    sync
    perpctl A cloudreve >/dev/null 2>&1
    perpctl u cloudreve >/dev/null 2>&1
    detect_running_status cloudreve
  else
    echo_date "🟠启动 cloudreve 进程..."
    rm -rf /tmp/cloudreve.pid
    start-stop-daemon --start --quiet --make-pidfile --pidfile /tmp/cloudreve.pid --background --startas /bin/bash -- -c "${CloudreveBaseDir}/cloudreve >${CLOUDREVE_RUN_LOG} 2>&1"
    detect_running_status cloudreve
  fi
}

normalize_path() {
  local path="$1"
  path=$(echo "$path" | sed 's/\\/\//g') # 替换反斜杠为正斜杠
  path="${path%"${path##*[!/]}"}"        # 去掉结尾所有的分隔符
  echo "$path"
}

start() {
  # stop first
  stop_process

  # fix input path
  cloudreve_work_dir=$(dbus get cloudreve_work_dir)
  cloudreve_work_dir=$(normalize_path ${cloudreve_work_dir})
  dbus set cloudreve_work_dir=${cloudreve_work_dir}

  # prepare folder if not exist
  if [ "${CloudreveBaseDir}" != "${cloudreve_work_dir}" ]; then
    echo_date "➡️正在转移部署目录..."
    mkdir -p "${CloudreveBaseDir}_tmp"
    mv -f "${CloudreveBaseDir}/cloudreve" "${CloudreveBaseDir}_tmp/"
    mv -f "${CloudreveBaseDir}/data/cloudreve.db" "${CloudreveBaseDir}_tmp/" >/dev/null 2>&1
    mv -f "${CloudreveBaseDir}/data/conf.ini" "${CloudreveBaseDir}_tmp/" >/dev/null 2>&1
    mv -f "${CloudreveBaseDir}/data/uploads" "${CloudreveBaseDir}_tmp/" >/dev/null 2>&1
    mv -f "${CloudreveBaseDir}/admin.account" "${CloudreveBaseDir}_tmp/" >/dev/null 2>&1
    mkdir -p "${cloudreve_work_dir}"
    mv -f "${CloudreveBaseDir}_tmp"/* "${cloudreve_work_dir}/"
    if [ -z "$(ls -A "${CloudreveBaseDir}_tmp")" ]; then
      rm -rf "${CloudreveBaseDir}_tmp"
      if [ -f "${cloudreve_work_dir}/cloudreve" ]; then
        CloudreveBaseDir="${cloudreve_work_dir}"
        dbus set cloudreve_old_dir="${CloudreveBaseDir}"
        chmod +x "${CloudreveBaseDir}/cloudreve" >/dev/null 2>&1
      fi
    fi
  fi

  # 检查主程序完整性
  if [ ! -d "$CloudreveBaseDir" ] || [ ! -f "$CloudreveBaseDir/cloudreve" ]; then
    echo_date "❌Cloudreve 主程序缺失, 请重新安装插件!"
    dbus set cloudreve_enable=0
    stop_plugin
    exit 1
  fi

  # remove error
  dbus_rm cloudreve_cert_error
  dbus_rm cloudreve_key_error
  dbus_rm cloudreve_memory_error
  dbus_rm cloudreve_memory_warn

  # system_check
  if [ "${cloudreve_disablecheck}" = "1" ]; then
    echo_date "⚠️您已关闭系统检测功能, 请自行留意路由器性能!"
    echo_date "⚠️插件对路由器性能的影响请您自行处理!!!"
  else
    echo_date "==================== 系统检测 ===================="
    # memory_check
    check_memory
    # enable_plugin
    check_enable_plugin
    echo_date "==================== 系统检测结束 ===================="
  fi

  # 检测首次运行, 给出账号密码
  if [ ! -f "${CloudreveBaseDir}/data/cloudreve.db" ] || [ ! -f "${CloudreveBaseDir}/data/conf.ini" ]; then
    rm -rf "${CloudreveBaseDir}/admin.account"
    nohup "${CloudreveBaseDir}/cloudreve" >"${CloudreveBaseDir}/admin.account" 2>&1 &
    if [ ! -f "${CloudreveBaseDir}/data/conf.ini" ]; then
      echo_date "ℹ️检测到 conf.ini 缺失, 通过启动 cloudreve 自动生成..."
      retry_cnt=0
      while [ ! -f "${CloudreveBaseDir}/data/conf.ini" ]; do
        echo_date "ℹ️等 1s 待 conf.ini 文件生成..."
        sleep 1
        retry_cnt=$((retry_cnt + 1))
        if [ "$retry_cnt" -gt "$MAX_RETRY" ]; then
          echo_date "❌等待 conf.ini 超时 $MAX_RETRY 次, 终止脚本执行!"
          stop_plugin
          exit 1
        fi
      done
    fi
    killall cloudreve
    local BIN_VER=$(grep "   V" ${CloudreveBaseDir}/admin.account | awk '{print $1}')
    BIN_VER=$(echo "$BIN_VER" | cut -c 2-)
    dbus set cloudreve_binver=$BIN_VER
    rm -rf "${CloudreveBaseDir}/admin.account"
  fi

  # gen config.json
  makeConfig

  # start process
  start_process

  # open port
  if [ "${cloudreve_publicswitch}" == "1" ]; then
    close_port >/dev/null 2>&1
    open_port
  fi

  # 更新cloudreve二进制程序版本号
  retry_cnt=0
  while [ ! -f "/tmp/upload/cloudreve_run_log.txt" ] || ! grep -q "   V" "/tmp/upload/cloudreve_run_log.txt"; do
    echo_date "ℹ️未检测到运行日志, 等待3s..."
    sleep 3
    retry_cnt=$((retry_cnt + 1))
    if [ "$retry_cnt" -gt "$MAX_RETRY" ]; then
      echo_date "❌检测运行日志超时 $MAX_RETRY 次, 终止脚本执行!"
      stop_plugin
      exit 1
    fi
  done
  local BIN_VER=$(grep "   V" /tmp/upload/cloudreve_run_log.txt | awk '{print $1}')
  BIN_VER=$(echo "$BIN_VER" | cut -c 2-)
  dbus set cloudreve_binver=$BIN_VER
  echo_date "✅成功获取二进制程序版本号: $BIN_VER"
}

stop_process() {
  local CLOUDREVE_PID=$(pidof cloudreve)
  # checkDbFilePath stop
  if [ -n "${CLOUDREVE_PID}" ]; then
    echo_date "⛔关闭cloudreve进程..."
    if [ -f "/koolshare/perp/cloudreve/rc.main" ]; then
      perpctl d cloudreve >/dev/null 2>&1
    fi
    rm -rf /koolshare/perp/cloudreve
    killall cloudreve >/dev/null 2>&1
    kill -9 "${CLOUDREVE_PID}" >/dev/null 2>&1
  fi
}

stop_plugin() {
  # stop cloudreve
  stop_process
  # remove log
  rm -rf /tmp/upload/cloudreve_run_log.txt
  # close port
  close_port
}

open_port() {
  local CM=$(lsmod | grep xt_comment)
  local OS=$(uname -r)
  if [ -z "${CM}" -a -f "/lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko" ]; then
    echo_date "ℹ️加载 xt_comment.ko 内核模块!"
    insmod /lib/modules/${OS}/kernel/net/netfilter/xt_comment.ko
  fi

  if [ $(number_test ${cloudreve_port}) != "0" ]; then
    dbus set cloudreve_port="5212"
  fi

  if [ $(number_test ${cloudreve_https_port}) != "0" ]; then
    dbus set cloudreve_https_port="5213"
  fi

  # 开启IPV4防火墙端口
  local MATCH=$(iptables -t filter -S INPUT | grep "cloudreve_rule")
  if [ -z "${MATCH}" ]; then
    if [ "${configDisableHttp}" != "true" -a "${cloudreve_open_http_port}" == "1" ]; then
      echo_date "🧱添加防火墙入站规则, 打开cloudreve http 端口:  ${cloudreve_port}"
      iptables -I INPUT -p tcp --dport ${cloudreve_port} -j ACCEPT -m comment --comment "cloudreve_rule" >/dev/null 2>&1
    fi
    if [ "${cloudreve_https}" == "1" -a "${cloudreve_open_https_port}" == "1" ]; then
      echo_date "🧱添加防火墙入站规则, 打开 cloudreve https 端口:  ${cloudreve_https_port}"
      iptables -I INPUT -p tcp --dport ${cloudreve_https_port} -j ACCEPT -m comment --comment "cloudreve_rule" >/dev/null 2>&1
    fi
  fi
  # 开启IPV6防火墙端口
  local v6tables=$(which ip6tables)
  local MATCH6=$(ip6tables -t filter -S INPUT | grep "cloudreve_rule")
  if [ -z "${MATCH6}" ] && [ -n "${v6tables}" ]; then
    if [ "${configDisableHttp}" != "true" -a "${cloudreve_open_http_port}" == "1" ]; then
      ip6tables -I INPUT -p tcp --dport ${cloudreve_port} -j ACCEPT -m comment --comment "cloudreve_rule" >/dev/null 2>&1
    fi
    if [ "${cloudreve_https}" == "1" -a "${cloudreve_open_https_port}" == "1" ]; then
      ip6tables -I INPUT -p tcp --dport ${cloudreve_https_port} -j ACCEPT -m comment --comment "cloudreve_rule" >/dev/null 2>&1
    fi
  fi

}

close_port() {
  local IPTS=$(iptables -t filter -S | grep -w "cloudreve_rule" | sed 's/-A/iptables -t filter -D/g')
  if [ -n "${IPTS}" ]; then
    echo_date "🧱关闭本插件在防火墙上打开的所有端口!"
    iptables -t filter -S | grep -w "cloudreve_rule" | sed 's/-A/iptables -t filter -D/g' >/tmp/cloudreve_clean.sh
    chmod +x /tmp/cloudreve_clean.sh
    sh /tmp/cloudreve_clean.sh >/dev/null 2>&1
    rm /tmp/cloudreve_clean.sh
  fi
  local v6tables=$(which ip6tables)
  local IPTS6=$(ip6tables -t filter -S | grep -w "cloudreve_rule" | sed 's/-A/ip6tables -t filter -D/g')
  if [ -n "${IPTS6}" ] && [ -n "${v6tables}" ]; then
    ip6tables -t filter -S | grep -w "cloudreve_rule" | sed 's/-A/ip6tables -t filter -D/g' >/tmp/cloudreve_clean.sh
    chmod +x /tmp/cloudreve_clean.sh
    sh /tmp/cloudreve_clean.sh >/dev/null 2>&1
    rm /tmp/cloudreve_clean.sh
  fi
}

check_status() {
  local CLOUDREVE_PID=$(pidof cloudreve)
  if [ "${cloudreve_enable}" == "1" ]; then
    if [ -n "${CLOUDREVE_PID}" ]; then
      if [ "${cloudreve_watchdog}" == "1" ]; then
        local cloudreve_time=$(perpls | grep cloudreve | grep -Eo "uptime.+-s\ " | awk -F" |:|/" '{print $3}')
        if [ -n "${cloudreve_time}" ]; then
          http_response "cloudreve 进程运行正常! (PID: ${CLOUDREVE_PID} , 守护运行时间: ${cloudreve_time}) "
        else
          http_response "cloudreve 进程运行正常! (PID: ${CLOUDREVE_PID}) "
        fi
      else
        http_response "cloudreve 进程运行正常! (PID: ${CLOUDREVE_PID}) "
      fi
    else
      http_response "cloudreve 进程未运行!"
    fi
  else
    http_response "Cloudreve 插件未启用"
  fi
}

case $1 in
start)
  if [ "${cloudreve_enable}" == "1" ]; then
    sleep 20 # 延迟启动等待虚拟内存挂载
    true >${LOG_FILE}
    start | tee -a ${LOG_FILE}
    echo XU6J03M16 >>${LOG_FILE}
    logger "[软件中心-开机自启]: Cloudreve自启动成功!"
  else
    logger "[软件中心-开机自启]: Cloudreve未开启, 不自动启动!"
  fi
  ;;
boot_up)
  if [ "${cloudreve_enable}" == "1" ]; then
    true >${LOG_FILE}
    start | tee -a ${LOG_FILE}
    echo XU6J03M16 >>${LOG_FILE}
  fi
  ;;
start_nat)
  if [ "${cloudreve_enable}" == "1" ]; then
    if [ "${cloudreve_publicswitch}" == "1" ]; then
      logger "[软件中心-NAT重启]: 打开cloudreve防火墙端口!"
      sleep 10
      close_port
      sleep 2
      open_port
    else
      logger "[软件中心-NAT重启]: Cloudreve未开启公网访问, 不打开湍口!"
    fi
  fi
  ;;
stop)
  stop_plugin
  ;;
esac

case $2 in
web_submit)
  set_lock
  true >${LOG_FILE}
  http_response "$1"
  if [ "${cloudreve_enable}" == "1" ]; then
    echo_date "▶️开启cloudreve!" | tee -a ${LOG_FILE}
    start | tee -a ${LOG_FILE}
  elif [ "${cloudreve_enable}" == "2" ]; then
    echo_date "🔁重启cloudreve!" | tee -a ${LOG_FILE}
    dbus set cloudreve_enable=1
    start | tee -a ${LOG_FILE}
  else
    echo_date "ℹ️停止 cloudreve!" | tee -a ${LOG_FILE}
    stop_plugin | tee -a ${LOG_FILE}
  fi
  echo XU6J03M16 | tee -a ${LOG_FILE}
  unset_lock
  ;;
status)
  check_status
  ;;
esac
