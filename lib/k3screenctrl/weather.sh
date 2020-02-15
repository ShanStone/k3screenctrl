#!/bin/bash

. /lib/network/config.sh
. /lib/functions.sh


TMP_DIR=/tmp/k3screenctrl
update_time=$(uci get k3screenctrl.@general[0].update_time 2>/dev/null)
city_checkip=$(uci get k3screenctrl.@general[0].city_checkip 2>/dev/null)
city=$(uci get k3screenctrl.@general[0].city 2>/dev/null)
key=$(uci get k3screenctrl.@general[0].key 2>/dev/null)
update_weather=0

function encodeurl(){
	url=`echo $1 | tr -d '\n' | od -x |awk '{
		w=split($0,linedata," ");
		for (j=2;j<w+1;j++)
		{
			for (i=7;i>0;i=i-2)
			{
				if (substr(linedata[j],i,2) != "00") {printf "%" ;printf toupper(substr(linedata[j],i,2));}
			}
		}
	}'`
	url_tmp=`echo $url | sed 's/.\{2\}/&%/g' | sed 's/.$//'`
	echo %$url_tmp
}

init_weather_data(){
	WENDU=0
	TYPE=99
}

check_update_time(){
	if [ -z "$update_time" ]; then
		update_time=3600
	fi

	if [ $update_time -gt 0 ]; then
		cur_time=`date +%s`
		last_time=`cat $TMP_DIR/weather_time 2>/dev/null`
	
		if [ -z "$last_time" ]; then
			update_weather=1
			echo $cur_time > $TMP_DIR/weather_time
		else
			time_tmp=`expr $cur_time - $last_time`

        		if [ $time_tmp -ge $update_time ]; then
				update_weather=1
				echo $cur_time > $TMP_DIR/weather_time
			fi
		fi
	fi
}

update_real_time(){
	DATE=$(date "+%Y-%m-%d %H:%M")
	DATE_DATE=$(echo $DATE | awk '{print $1}')
	DATE_TIME=$(echo $DATE | awk '{print $2}')
	DATE_WEEK=$(date "+%u")

	if [ "$DATE_WEEK" == "7" ]; then
		DATE_WEEK=0
	fi

}

check_ip_city(){
	if [ "$city_checkip" = "1" ]; then
		city_tmp=`cat $TMP_DIR/weather_city 2>/dev/null`
		if [ -z "$city_tmp" ]; then
			wan_city=`curl --connect-timeout 3 -s https://pv.sohu.com/cityjson | awk -F"=" '{print $2}' | sed 's/;//g'`
			wanip=`echo $wan_city | jq ".cip" | sed 's/"//g'`
			city_json=`curl --connect-timeout 3 -s http://ip.taobao.com/service/getIpInfo.php?ip=$wanip`
			ip_city=`echo $city_json | jq ".data.city" | sed 's/"//g'`
			ip_county=`echo $city_json | jq ".data.county" | sed 's/"//g'`
			if [ "$ip_county" != "XX" ]; then
				city=`echo $ip_county`
			else
				city=`echo $ip_city`
			fi
			echo $city > $TMP_DIR/weather_city
			uci set k3screenctrl.@general[0].city=$city
			uci commit k3screenctrl
		else
			city=`echo $city_tmp`
		fi
	fi
	[ "$city" == "" ] && city=NONE
}

get_weather(){
	[ ! -s $TMP_DIR/k3-weather.json ] && update_weather=1

	if [ "$update_weather" = "1" ]; then
		city_name=$(encodeurl $city)
		rm -rf $TMP_DIR/k3-weather.json
		wget "https://api.seniverse.com/v3/weather/now.json?key=$key&location=$city_name&language=zh-Hans&unit=c" -T 3 -O $TMP_DIR/k3-weather.json 2>/dev/null
	fi
}

update_weather(){
	if [ -s $TMP_DIR/k3-weather.json ]; then
		weather_json=$(cat $TMP_DIR/k3-weather.json 2>/dev/null)
        	WENDU=`echo $weather_json | jq ".results[0].now.temperature" | sed 's/"//g'`
        	TYPE=`echo $weather_json | jq ".results[0].now.code" | sed 's/"//g'`
	fi
}

output_data(){
	echo $city
	echo $WENDU
	echo $DATE_DATE
	echo $DATE_TIME
	echo $TYPE
	echo $DATE_WEEK
	echo 0
}

init_weather_data
check_update_time
check_ip_city
get_weather
update_weather
update_real_time
output_data
exit 0
