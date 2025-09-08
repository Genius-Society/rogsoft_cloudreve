#!/bin/sh
alias echo_date='echo 【$(TZ=UTC-8 date -R +%Y年%m月%d日\ %X)】:'

echo_date "正在删除插件资源文件..."
sh /koolshare/scripts/cloudreve_config.sh stop
rm -rf /tmp/cloudreve.pid
rm -rf /tmp/upload/cloudreve_log.txt
find /koolshare/ -name '*cloudreve*' -print0 | xargs -0 rm -rf
echo_date "插件资源文件删除成功..."

echo_date "清理dbus缓存..."
for key in $(dbus listall | grep 'cloudreve_' | cut -d '=' -f1); do
    dbus remove "$key"
done
echo_date "已成功移除插件... Bye~Bye~"
