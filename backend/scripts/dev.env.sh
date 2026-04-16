echo -n "Env File: "
read -r env_file

if [[ ! -f "$env_file" ]]; then
  echo "error: env file not found: $env_file"
  return 1
fi

set -a
source "$env_file"

if [[ -f "./runtime/rotation.env" ]]; then
  source "./runtime/rotation.env"
fi

set +a