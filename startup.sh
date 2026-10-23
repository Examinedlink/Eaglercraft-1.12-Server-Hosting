#!/usr/bin/env bash

lock_id=$(printf '%s' "$PWD" | cksum | awk '{print $1}')
exec 9>"${TMPDIR:-/tmp}/eaglercraft-hosting-${lock_id}.lock"
if ! flock -n 9; then
    echo 'Another startup script is already running; refusing to start a duplicate.'
    exit 1
fi

port_in_use() {
    local port="$1"
    bash -lc "cat </dev/null >/dev/tcp/127.0.0.1/$port" >/dev/null 2>&1
}

cd bungee || exit 1
if port_in_use 25577 || port_in_use 8081; then
    echo 'Bungee or Eaglercraft listener port is already in use. Another proxy is running; refusing to start another instance.'
    exit 1
fi
java -jar bungee.jar &
bungee_pid=$!
cd ../server || exit 1

if port_in_use 25565; then
    kill -TERM "$bungee_pid" 2>/dev/null || true
    echo 'Minecraft port 25565 is already in use. Another server is running; refusing to start another instance.'
    exit 1
fi

server_pid=
stopping=false

stop_servers() {
    stopping=true
    if [[ -n "$server_pid" ]]; then
        kill -TERM "$server_pid" 2>/dev/null || true
    fi
    kill -TERM "$bungee_pid" 2>/dev/null || true
}

trap stop_servers INT TERM

while [[ "$stopping" == false ]]; do
    java -jar server.jar &
    server_pid=$!
    wait "$server_pid"
    status=$?
    server_pid=

    if [[ "$stopping" == true ]]; then
        break
    fi

    if [[ "$status" -eq 137 || "$status" -eq 143 ]]; then
        printf 'Minecraft server was stopped intentionally; exiting without restart.\n'
        break
    fi

    if port_in_use 25565; then
        printf 'Minecraft port 25565 became occupied; stopping the restart loop.\n'
        kill -TERM "$bungee_pid" 2>/dev/null || true
        break
    fi

    printf 'Minecraft server exited with status %s; restarting in 5 seconds.\n' "$status"
    sleep 5
done

wait "$bungee_pid" 2>/dev/null || true
