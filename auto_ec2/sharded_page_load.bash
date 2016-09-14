#!/usr/bin/env bash

set -e

EMULATE_DEVICE="Apple iPhone 6"
RECORD_TIME_MIN=30

cd "${0%/*}"

dest="$1"; shift
page_list="$1"; shift
nodes=("$@")

if [[ -z $dest || -z $page_list ]]; then
	echo invalid args >&2
	exit 2
fi

for ((i=0; i < ${#nodes[@]}; i++)); do
(
	# shard by taking every nth
	cat ../page_list/"$page_list" | (
		line_count=0
		while read line; do
			if (( ((line_count+i) % ${#nodes[@]}) == 0 )); then
				echo "$line"
			fi
			((line_count = line_count + 1))
		done
	) | ssh "${nodes[i]}" "cat >shard_${i}_page_list"
	(cd ../.. && tar cz WebpageOptimization) | ssh "${nodes[i]}" "tar xz"
	cat <<EOF | ssh "${nodes[i]}" "cat >run_shard_work.bash && chmod +x run_shard_work.bash"
#!/usr/bin/env bash

set -e

date
export EMULATE_DEVICE="$EMULATE_DEVICE"
cd WebpageOptimization/ChromeMessageCollector 

rm -rf \$HOME/${dest}_shard_$i || true
mkdir -p \$HOME/${dest}_shard_$i || true

for j in {01..30}; do
	start=\$(date +%s)
	python page_load_wrapper.py "\$HOME/shard_${i}_page_list" 1 \
		--use-device ubuntu \
		--dont-start-measurements \
		--disable-tracing \
		--collect-streaming \
		--output-dir "\$HOME/${dest}_shard_$i/run\$j" \
		--record-content
	end=\$(date +%s)
	sleep_time=\$(( (end - start) - $((RECORD_TIME_MIN*60)) ))
	if (( sleep_time > 0 )); then
		sleep \$sleep_time
	fi
done

EOF

	cat <<EOF | ssh "${nodes[i]}" "cat >run_shard_work_in_xvfb.bash && chmod +x run_shard_work_in_xvfb.bash"
#!/usr/bin/env bash
xvfb-run --server-args='-screen 0, 1920x1080x16' bash \$HOME/run_shard_work.bash || true
cat
EOF
	ssh "${nodes[i]}" "sudo killall -9 Xvfb &>/dev/null; tmux kill-session -t 0 &>/dev/null; tmux new-session -d \"bash \$HOME/run_shard_work_in_xvfb.bash\""
)
done

for j in $(jobs -p); do
	wait $j
done
