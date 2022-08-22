#!/bin/bash
# 保存发送到linux服务器需要更改CRLF换行方式为LF，因为git提交的时候会自动更改成CRLF
today=`date +%Y%m%d`
dateTime=`date +%Y-%m-%d_%H-%M-%S`
servers=("127.0.0.1" "127.0.0.1" "127.0.0.1")
logfile="/root/logs-auto-deploy/log-${today}.log"
functionNumber=$1
versionName=$2
number=0
if [ ! -x '/root/logs-auto-deploy' ]; then
    echo "自动创建log目录"
    eval "mkdir /root/logs-auto-deploy"
fi
# at命令定时任务
# at HH:MM YYYY-MM-DD 回车
# eg(at 9:00 2020-11-11)
# 敲 ./auto-deploy.sh 6 20201111 ctrl+d
testAction(){
    echo "-----------------------   进入测试   -----------------------"
    
    echo "-----------------------   测试结束   -----------------------"
}
deployProductionServer() {
    echo "请输入目录名（eg:20201106)"
    read folderName
    # echo $folderName
    echo "[ `date` ] start to update platform" >> $logfile
    for item in ${servers[@]}
    do
        echo "------ 开始更新 ${item} 服务器"
        echo "[ `date` ] 开始更新 ${item} 服务器" >> $logfile
        eval "scp -r /root/webapps/package/${folderName} apps@${item}:/apps/webapps/package/"
        eval "ssh apps@${item} 'ln -fs /apps/webapps/package/${folderName}/dist/* /apps/svr/nginx/html/;exit;'"
        echo "------ ${item} 服务器完成更新"
        echo "[ `date` ] ${item} 服务器完成更新" >> $logfile
    done
    echo "[ `date` ] update platform complete" >> $logfile
}
modifyNginxAndRestart() {
    echo "[ `date` ] 修改nginx配置" >> $logfile
    eval "scp apps@${servers[0]}:/apps/svr/nginx/conf/conf/nginxCnf.conf /root/"
    eval "vim /root/nginxCnf.conf"
    eval "nginx -c nginx_product.conf -t"
    if [[ $? == 1 ]]; then
        echo "nginx 错误"
    else
        for item in ${servers[@]}
        do
            echo "------ 开始更新 ${item} 服务器 nginx"
            echo "[ `date` ] 开始更新 ${item} 服务器 nginx" >> $logfile
            # 备份conf
            eval "ssh apps@${item} 'cp /apps/svr/nginx/conf/conf/nginxCnf.conf /apps/svr/nginx/conf/conf/nginxCnf.conf.${dateTime};exit;'"
            # 复制conf到server
            eval "scp /root/nginxCnf.conf apps@${item}:/apps/svr/nginx/conf/conf/"
            # 重启nginx
            eval "ssh apps@${item} '/apps/svr/nginx/sbin/nginx -s reload;exit;'"
            echo "------ 更新 ${item} 服务器 nginx 成功"
            echo "[ `date` ] 更新 ${item} 服务器 nginx 成功" >> $logfile
        done
    fi
    echo "[ `date` ] 更新服务器 nginx 完成" >> $logfile
}
rollbackProduction(){
    echo "请输入回滚版本的目录名（eg:20201106)"
    read folderName
    # echo $folderName
    for item in ${servers[@]}
    do
        echo "------ 开始回滚 ${item} 服务器"
        echo "[ `date` ] 开始回滚 ${item} 服务器" >> $logfile
        eval "ssh apps@${item} 'ln -fs /apps/webapps/package/${folderName}/dist/* /apps/svr/nginx/html/;exit;'"
        echo "------ ${item} 服务器回滚完成"
        echo "[ `date` ] ${item} 服务器回滚完成" >> $logfile
    done
    echo "[ `date` ] 完成服务器 nginx 回滚" >> $logfile
}

setTask(){
    if [ -z $versionName ]; then
        echo "请输入需要发的版本（eg:20201109）"
        exit
    else
        for item in ${servers[@]}
        do
            echo "------ 开始更新 ${item} 服务器"
            echo "[ `date` ] 开始更新 ${item} 服务器" >> $logfile
            # 更新 platform 前端到生产
            eval "scp -r /root/webapps/package/${versionName} apps@${item}:/apps/webapps/package/"
            # 更新软连接
            eval "ssh apps@${item} 'ln -fs /apps/webapps/package/${versionName}/dist/* /apps/svr/nginx/html/;exit;'"
            # 重启nginx
            eval "ssh apps@${item} '/apps/svr/nginx/sbin/nginx -s reload;exit;'"
            echo "[ `date` ] 更新 ${item} 服务器成功" >> $logfile
            echo "------ 更新 ${item} 服务器成功"
        done
        echo "------ 完成更新服务器版本"
        echo "[ `date` ] 完成更新服务器版本" >> $logfile
    fi
}

renewNginx() {
    eval "scp apps@${servers[0]}:/apps/svr/nginx/conf/conf/nginxCnf.conf /root/"
    eval "vim /root/nginxCnf.conf"
    echo "测试nginx"
    echo "[ `date` ] 测试nginx" >> $logfile
    eval "nginx -c nginx_product.conf -t"
    if [[ $? == 1 ]]; then
        echo "nginx 错误"
    else
        for item in ${servers[@]}
        do
            echo "------ 开始更新 ${item} 服务器 nginx"
            echo "[ `date` ] 开始更新 ${item} 服务器 nginx" >> $logfile
            # 备份conf
            eval "ssh apps@${item} 'cp /apps/svr/nginx/conf/conf/nginxCnf.conf /apps/svr/nginx/conf/conf/nginxCnf.conf.${dateTime};exit;'"
            # 复制conf到server
            eval "scp /root/nginxCnf.conf apps@${item}:/apps/svr/nginx/conf/conf/"
            echo "[ `date` ] 更新 ${item} 服务器 nginx 成功" >> $logfile
            echo "------ 更新 ${item} 服务器 nginx 成功"
        done
    fi
    echo "[ `date` ] 完成服务器 nginx 更新" >> $logfile
}

switchFunctional() {
    if [ $number == 1 ]; then
        # echo "-------------------   测试   -----------------"
        testAction
    elif [ $number == 2 ]; then
        # echo "-------------------   更新 platform 前端到生产   -----------------"
        deployProductionServer
    elif [ $number == 3 ]; then
        # echo "-------------------   更新 platform 前端nginx并restart   -----------------"
        modifyNginxAndRestart
    elif [ $number == 4 ]; then
        # echo "-------------------   回滚版本   -----------------"
        rollbackProduction
    elif [ $number == 5 ]; then
        # echo "-------------------   更新 platform 前端nginx   -----------------"
        renewNginx
    elif [ $number == 6 ]; then
        echo "-------------------   定时任务设定   -----------------"
        setTask
    else
        echo "-------------------   请输正确指令序号   -----------------"
        exit
    fi
    echo ""
    echo "-------------------   结束   -----------------"
}

if [ ! -z $functionNumber ] && [ ! -z $versionName ]; then
    echo "自动运行"
    number=$functionNumber
    echo $number
    switchFunctional
else
    echo "选择功能"
    echo "[1] 测试"
    echo "[2] 更新 platform 前端到生产"
    echo "[3] 更新 platform 前端nginx并restart"
    echo "[4] 回滚版本"
    echo "[5] 更新 platform 前端nginx"
    echo "[6] 定时任务用"

    read functionalType
    echo "你选择了选项 $functionalType "
    echo "[ `date` ] 你选择了选项 $functionalType " >> $logfile
    number=$functionalType
    switchFunctional
fi
