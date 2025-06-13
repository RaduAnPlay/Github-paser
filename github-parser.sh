#!/bin/bash

REPOS_FILE="./repos.list"
LOCAL_DIR="./downloads"

# Extract user/repo from URL or accept user/repo directly
extract_repo_name() {
  local url="$1"
  url="${url#https://}"
  url="${url#http://}"
  url="${url#github.com/}"
  url="${url%%/}"
  echo "$url"
}

# Load repositories from file
load_repos() {
  if [[ -f "$REPOS_FILE" ]]; then
    mapfile -t REPOS <"$REPOS_FILE"
  else
    REPOS=()
  fi
}

# Save repos to file
save_repos() {
  printf "%s\n" "${REPOS[@]}" >"$REPOS_FILE"
}

# Check prerequisites
check_prerequisites() {
  command -v jq >/dev/null 2>&1 || {
    echo "Missing prerequisite: jq"
    return 1
  }
  command -v fzf >/dev/null 2>&1 || {
    echo "Missing prerequisite: fzf"
    return 1
  }
  return 0
}

install_prerequisites() {
  echo "Installing missing prerequisites..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y jq fzf
  elif command -v brew >/dev/null; then
    brew install jq fzf
  elif command -v dnf >/dev/null; then
    sudo dnf install -y jq fzf
  else
    echo "No supported package manager found. Please install jq and fzf manually."
    exit 1
  fi
}

setup_local_directory() {
  mkdir -p "$LOCAL_DIR"
}

download_latest() {
  local repo="$1"
  local file_type="$2"
  response=$(curl -s "https://api.github.com/repos/$repo/releases/latest")

  if [[ "$(echo "$response" | jq -r '.message')" == "Not Found" ]]; then
    echo "Error: Repository $repo not found or does not exist."
    return 1
  fi

  latest_release=$(echo "$response" | jq -r '.tag_name')
  if [[ -z "$latest_release" || "$latest_release" == "null" ]]; then
    echo "Failed to fetch latest release for $repo"
    return 1
  fi

  if [[ -z "$(echo "$response" | jq -r '.assets[]?')" ]]; then
    echo "No assets found for the latest release in $repo."
    return 1
  fi

  asset=$(echo "$response" | jq -r --arg file_type "$file_type" '.assets[] | select(.name | test("\\." + $file_type + "$")) | .name' | head -n1)
  if [[ -n "$asset" ]]; then
    download_url="https://github.com/$repo/releases/download/$latest_release/$asset"
    echo "Downloading $asset from $download_url..."
    if curl --output /dev/null --silent --head --fail "$download_url"; then
      curl -L -o "$LOCAL_DIR/$asset" "$download_url"
      echo "Downloaded $asset from $repo"
    else
      echo "Error: Invalid download URL: $download_url"
    fi
  else
    echo "No suitable asset found for type .$file_type in $repo."
  fi
}

list_repositories() {
  echo "Tracked repositories:"
  for repo in "${REPOS[@]}"; do
    echo "- $repo"
  done
}

remove_repository() {
  local repo_to_remove="$1"
  local found=0
  for i in "${!REPOS[@]}"; do
    if [[ "${REPOS[i]}" == "$repo_to_remove" ]]; then
      unset 'REPOS[i]'
      found=1
      echo "Removed repository: $repo_to_remove"
      save_repos
      break
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "Repository $repo_to_remove not found."
  fi
}

set_repositories() {
  echo "Enter GitHub repo URLs or user/repo (space-separated):"
  read -a repos
  REPOS=()
  for repo in "${repos[@]}"; do
    if [[ "$repo" == http* ]]; then
      repo=$(extract_repo_name "$repo")
    fi
    REPOS+=("$repo")
  done
  save_repos
  echo "Repositories set to: ${REPOS[*]}"
}

remove_file() {
  if ! ls -1 "$LOCAL_DIR" 1>/dev/null 2>&1; then
    echo "No files to remove."
    return
  fi
  local file_to_remove
  file_to_remove=$(ls -1 "$LOCAL_DIR" | fzf --prompt="Select file to remove: " | xargs)
  [[ -z "$file_to_remove" ]] && {
    echo "No file selected."
    return
  }
  local full_path="$LOCAL_DIR/$file_to_remove"
  if [[ -f "$full_path" ]]; then
    rm "$full_path"
    echo "Removed $file_to_remove"
  else
    echo "File $file_to_remove not found in $LOCAL_DIR."
  fi
}

setup_local_directory
load_repos

while true; do
  echo
  echo "Select an option:"
  echo "1) Install prerequisites"
  echo "2) Set tracked repositories"
  echo "3) List tracked repositories"
  echo "4) Remove a repository"
  echo "5) Download latest release from a specific repository"
  echo "6) Download latest release from all repositories"
  echo "7) Remove a downloaded file"
  echo "8) Exit"
  read -p "Enter your choice [1-8]: " choice

  case $choice in
  1)
    check_prerequisites || install_prerequisites
    ;;
  2)
    set_repositories
    ;;
  3)
    list_repositories
    ;;
  4)
    repo_to_remove=$(printf "%s\n" "${REPOS[@]}" | fzf --prompt="Select repository to remove: ")
    [[ -z "$repo_to_remove" ]] && {
      echo "No repository selected."
      continue
    }
    remove_repository "$repo_to_remove"
    ;;
  5)
    repo_to_download=$(printf "%s\n" "${REPOS[@]}" | fzf --prompt="Select repository: ")
    [[ -z "$repo_to_download" ]] && {
      echo "No repository selected."
      continue
    }
    file_type=$(printf "rpm\nAppImage\ndeb\n" | fzf --prompt="Select file type: ")
    [[ -z "$file_type" ]] && {
      echo "No file type selected."
      continue
    }
    download_latest "$repo_to_download" "$file_type"
    ;;
  6)
    file_type=$(printf "rpm\nAppImage\ndeb\n" | fzf --prompt="Select file type for all repos: ")
    [[ -z "$file_type" ]] && {
      echo "No file type selected."
      continue
    }
    for repo in "${REPOS[@]}"; do
      download_latest "$repo" "$file_type"
    done
    ;;
  7)
    remove_file
    ;;
  8)
    echo "Exiting..."
    exit 0
    ;;
  *)
    echo "Invalid option. Please try again."
    ;;
  esac
done
