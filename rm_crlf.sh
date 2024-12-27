#!/bin/bash

find "./cloudreve" -type f -name "*.sh" -exec sed -i 's/\r$//' {} \;