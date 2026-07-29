#!/bin/sh
# shellcheck shell=dash
# Entrypoint to split secrets from the user's `config.yml`

echo 'Hello from new entry!'

# generate random secret key if not already present
CONFIG_TEMPLATE="/usr/local/searxng/settings.template.yml"
USER_CONFIG="/etc/searxng-user/settings.yml"
SECRETS_TARGET="$__SEARXNG_DATA_PATH/secrets.yml"
CONFIG_TARGET="$__SEARXNG_CONFIG_PATH/settings.yml"

if [ ! -f "$SECRETS_TARGET" ]; then
    cat <<EOF
... Creating "$SECRETS_TARGET" from template...
EOF
    cp -pfT "$CONFIG_TEMPLATE" "$SECRETS_TARGET"
    sed -i "s/ultrasecretkey/$(head -c 24 /dev/urandom | base64 | \
    	tr -dc 'a-zA-Z0-9')/g" "$SECRETS_TARGET"
fi

# now merge them together
mkdir -p "$__SEARXNG_CONFIG_PATH/"
/usr/local/searxng/.venv/bin/python3 /usr/share/searxng-extra/merge_settings.py \
	"$USER_CONFIG" "$SECRETS_TARGET" "$CONFIG_TARGET"
chown -R searxng:searxng "$__SEARXNG_CONFIG_PATH"

# now run the original entrypoint
exec /usr/local/searxng/entrypoint.sh

