sleep 3 && cd /etc/sing-box/ && sing-box run  &>/dev/null &
sleep 10 && cd /root/ && hysteria -c /etc/config/hyster.config.yaml  &>/dev/null & 
