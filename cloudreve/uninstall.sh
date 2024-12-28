#!/bin/sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

echo_date "正在删除插件资源文件..."
sh /koolshare/scripts/cloudreve_config.sh stop
rm -rf /koolshare/cloudreve
rm -rf /koolshare/scripts/cloudreve_config.sh
rm -rf /koolshare/webs/Module_cloudreve.asp
rm -rf /koolshare/res/*cloudreve*
find /koolshare/init.d/ -name "*cloudreve*" | xargs rm -rf
rm -rf /koolshare/bin/cloudreve >/dev/null 2>&1
sed -i '/cloudreve_watchdog/d' /var/spool/cron/crontabs/* >/dev/null 2>&1
echo_date "插件资源文件删除成功..."

rm -rf /koolshare/scripts/uninstall_cloudreve.sh

echo_date "清理dbus缓存..."
dbus remove cloudreve_binver
dbus remove cloudreve_cert_file
dbus remove cloudreve_disablecheck
dbus remove cloudreve_enable
# dbus remove cloudreve_force_https
dbus remove cloudreve_https
dbus remove cloudreve_https_port
dbus remove cloudreve_key_file
dbus remove cloudreve_old_dir
dbus remove cloudreve_open_http_port
dbus remove cloudreve_open_https_port
dbus remove cloudreve_port
dbus remove cloudreve_publicswitch
dbus remove cloudreve_version
dbus remove cloudreve_watchdog
dbus remove cloudreve_work_dir

echo_date "已成功移除插件... Bye~Bye~"
