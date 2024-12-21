#! /usr/bin/env bash -e

CMD_CHROME='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'

target="$1"
options="$2"
buffer_size="${3:-9999999}"
port="9222"

function run_chrome() {
  echo "Running Chrome ($CMD_CHROME)" >&2

  "$CMD_CHROME" \
    --headless \
    --remote-debugging-port=$port \
    --remote-allow-origins=http://127.0.0.1:$port \
    --remote-allow-origins=http://localhost:$port \
    "$(realpath "$target")" 2>&1
}

coproc chrome (run_chrome)

trap 'kill $chrome_PID' EXIT
read -r output <&"${chrome[0]}"

function get_websocket_debugger_url() {
  http GET localhost:$port/json/list |
    jq -r '.[] | select(.type == "page") | .webSocketDebuggerUrl'
}

echo "Getting chrome websocket debugger url" >&2
url="$(get_websocket_debugger_url)"

function request_print_page() {
  echo "Page.printToPDF { $options }" |
    websocat --buffer-size "$buffer_size" -n1 --jsonrpc --jsonrpc-omit-jsonrpc "$url"
}

if [[ -t 1 ]]; then
  outfile="$target.pdf"
else
  outfile="&1"
fi

echo "Requesting chrome print page from debugger url ($url)" >&2
request_print_page |
  jq -r '.result.data' |
  base64 -d -i - >"$target.pdf"

echo "Wrote PDF to '$target.pdf'"
