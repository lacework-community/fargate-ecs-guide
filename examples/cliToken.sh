#!/bin/sh
## Installing the LW CLI and Creating and LW Agent Token
## Follow steps listed in our [documentation here](https://github.com/lacework/go-sdk/wiki/CLI-Documentation#installation).

curl https://raw.githubusercontent.com/lacework/go-sdk/main/cli/install.sh | bash
lacework configure --json_file ~/Downloads/*.json
lacework agent token create dianademo
lacework agent token list | grep dianademo
