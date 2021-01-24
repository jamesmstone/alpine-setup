#!/bin/sh
set -eu # set  -e fail on error, -u treat unset variables as an error when substituting.

id=$(curl --location --request POST 'https://api.vultr.com/v2/instances' \
	--header 'Authorization: Bearer '${VULTR_API_KEY} \
	--header 'Content-Type: application/json' \
	--data-raw '{
          	"region" : "'${VULTR_REGION}'",
          	"plan" : "'${VULTR_PLAN}'",
            "label" : "'${VULTR_LABEL}'",
            "snapshot_id" : "'$(curl \
		--silent \
		--location \
		--request GET 'https://api.vultr.com/v2/snapshots' \
		--header 'Authorization: Bearer '${VULTR_API_KEY} |
		jq --raw-output .snapshots[0].id)'",
            "backups": "disabled"
          }' | jq --raw-output .instance.id)

echo ${id}

ip="0.0.0.0"
num=1
while [ "$ip" = "0.0.0.0" ] || [ "$ip" = "null "]; do
	if [ $num -le 10 ]; then
		echo "Failed to get ip, too many attempts"
	fi
	sleep 5
	echo "Attempt: ${num}"
	num=$(($num + 1))
	ip=$(
		curl --location --request GET 'https://api.vultr.com/v2/instances/'${id} \
			--header 'Authorization: Bearer '${VULTR_API_KEY} | jq --raw-output .instance.main_ip
	)
done

if [ "$ip" = "0.0.0.0" ] || [ "$ip" = "null "]; then
	echo "Failed to get IP"
	exit 1
fi

echo "Final IP: ${ip}"

CF_ZONE_ID=$(
	curl -X GET "https://api.cloudflare.com/client/v4/zones" \
		-H "Authorization: Bearer $CF_AUTH_KEY" \
		-H "Content-Type: application/json" | jq --raw-output .result[0].id
)

CF_A_RECORD_ID=$(
	curl -X GET "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$CF_RECORD_NAME" \
		-H "Authorization: Bearer $CF_AUTH_KEY" \
		-H "Content-Type: application/json" | jq --raw-output .result[0].id
)

# Record the new public IP address on Cloudflare using API v4
RECORD=$(
	cat <<EOF
{ "type": "A",
  "name": "$CF_RECORD_NAME",
  "content": "$ip",
  "ttl": 180,
  "proxied": false }
EOF
)

curl "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$CF_A_RECORD_ID" \
	-X PUT \
	-H "Content-Type: application/json" \
	-H "Authorization: Bearer $CF_AUTH_KEY" \
	-d "$RECORD" | jq .success
