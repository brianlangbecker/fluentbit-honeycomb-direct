#!/bin/sh

# Replace environment variables in the config file
envsubst < /fluent-bit/etc/fluent-bit.yaml.template > /fluent-bit/etc/fluent-bit.yaml

# Start Fluent Bit
exec /fluent-bit/bin/fluent-bit --config=/fluent-bit/etc/fluent-bit.yaml