#!/usr/bin/env bash

host=$1
log_file=$2

ALLOWED_LAG_MIN=5

sent_times=()
sent_errors=()

while true; do
	log=$(ssh $host "cat \"$log_file\"")
	last_log_line=$(tail -n1 <<<"$log")
	last_time=$(cut -d']' -f1 <<<"$last_log_line" | cut -d' ' -f2)
	last_time_hr=${last_time%:*}
	last_time_hr=${last_time_hr#0}
	last_time_min=${last_time#*:}
	last_time_min=${last_time_min#0}
	last_time_num=$((last_time_hr * 60 + last_time_min))
	now=$(date +%H:%M)
	now_hr=${now%:*}
	now_hr=${now_hr#0}
	now_min=${now#*:}
	now_min=${now_min#0}
	now_num=$((now_hr * 60 + now_min))

	if (( now_num > (last_time_num + ALLOWED_LAG_MIN) )); then
		if printf "%s\n" "${sent_times[@]}" | grep -- "$last_log_line" &>/dev/null; then
			# already sent an email for this
			true
		else
			echo "[$(date +'%m/%d %H:%M')] mailing for lag"
			echo "$log" | mail -s "[down-mon] Substantial download lag" uluyol@umich.edu
			sent_times+=("$last_log_line")
		fi
	fi

	IFS=$'\n'
	possible_errors=($(grep "possible error" <<<"$log"))
	unset IFS

	sent=0
	for ((i=0; i < ${#possible_errors[@]}; i++)); do
		if printf "%s\n" "${sent_errors[@]}" | grep "${possible_errors[i]}" &>/dev/null; then
			true
		else
			if [[ $sent -eq 0 ]]; then
				echo "[$(date +'%m/%d %H:%M')] mailing for possible error"
				echo "$log" | mail -s "[down-mon] Possible error on node" uluyol@umich.edu
				sent=1
			fi
			sent_errors+=("${possible_errors[i]}")
		fi
	done
	echo "[$(date +'%m/%d %H:%M')] sleep"
	sleep 60
done
