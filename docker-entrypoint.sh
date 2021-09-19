#!/bin/sh

## Uncomment for multi, else comment
## LW Agent (4) running the agent  
## ./var/lib/lacework/datacollector &

# Uncomment for baked, else comment
## Starting the LW Agent
## service datacollector start

curl -s  https://stream.wikimedia.org/v2/stream/recentchange | grep data | sed 's/^data: //g' | jq -rc 'with_entries(if .key == "$schema" then .key = "schema" else . end)'

exit 1