#!/bin/bash

# Default repositories (space-separated)
DEFAULT_REPOS=("username/repo1" "username/repo2") # Replace with your default GitHub repositories
LOCAL_DIR="./downloads"                   # Local directory to store downloaded files

# Function to check for prerequisites
check_prerequisites() {
  local missing=()
  command -v fzf >/dev/null 2>&1 || missing+=("fzf")
  command -v jq >/dev/null 2>&1 || missing+=("jq")

  if [ ${#missing[@]} -ne 0 ]; then
    echo "Error: Missing prerequisites: ${missing[*]}"
    exit 1
  fi
}

# Function to install prerequisites
install_prerequisites() {
  echo "Installing missing prerequisites..."
  if command -v apt-get >/dev/null; then
    sudo apt-get update
    sudo apt-get install -y fzf jq
  elif command -v brew >/dev/null; then
    brew install fzf jq
  elif command -v dnf >/dev/null; then
    sudo dnf install -y fzf jq
  else
    echo "Error: No supported package manager found. Please install fzf and jq manually."
    exit 1
  fi
}

# Function to create local directory if it doesn't exist
setup_local_directory() {
  mkdir -p "$LOCAL_DIR"
}

# Function to download the latest release from a repository based on selected file type
download_latest() {
  local repo=$1
  local file_type=$2
  response=$(curl -s "https://api.github.com/repos/$repo/releases/latest")

  if [ "$(echo "$response" | jq -r '.message')" == "Not Found" ]; then
    echo "Error: Repository $repo not found or does not exist."
    return
  fi

  latest_release=$(echo "$response" | jq -r '.tag_name') || {
    echo "Error: Failed to fetch latest release for $repo"
    return
  }

  if [ -z "$(echo "$response" | jq -r '.assets')" ]; then
    echo "Error: No assets found for the latest release in $repo."
    return
  fi

  # Check for the selected file type asset
  asset=$(echo "$response" | jq -r ".assets[] | select(.name | test(\"\\.$file_type$\")) | .name")

  if [ -n "$asset" ]; then
    download_url="https://github.com/$repo/releases/download/$latest_release/$asset"
    echo "Downloading $asset from $download_url..."

    # Validate the URL
    if curl --output /dev/null --silent --head --fail "$download_url"; then
      curl -L -o "$LOCAL_DIR/$asset" "$download_url"
      echo "Downloaded $asset from $repo"

      # Remove old file after update is detected
      old_file=$(find "$LOCAL_DIR" -name "*.$file_type" -not -name "$asset")
      if [ -n "$old_file" ]; then
        echo "Removing old file: $old_file"
        rm "$old_file"
      fi
    else
      echo "Error: Invalid download URL: $download_url"
    fi
  else
    echo "Error: No suitable asset found for type .$file_type in $repo."
  fi
}

# Function to list all repositories
list_repositories() {
  echo "Installed repositories:"
  for repo in "${REPOS[@]}"; do
    echo "- $repo"
  done
}

# Function to remove a repository
remove_repository() {
  read -p "Enter the repository to remove (e.g., username/repo): " repo_to_remove
  for i in "${!REPOS[@]}"; do
    if [[ "${REPOS[i]}" == "$repo_to_remove" ]]; then
      unset 'REPOS[i]'
      echo "Removed repository: $repo_to_remove"
      return
    fi
  done
  echo "Repository $repo_to_remove not found."
}

# Function to add a repository
add_repository() {
  read -p "Enter the repository to add (e.g., username/repo): " repo_to_add
  REPOS+=("$repo_to_add")
  echo "Added repository: $repo_to_add"
}

# Function to update a repository
update_repository() {
  read -p "Enter the repository to update (e.g., username/repo): " repo_to_update
  for i in "${!REPOS[@]}"; do
    if [[ "${REPOS[i]}" == "$repo_to_update" ]]; then
      read -p "Enter the new repository URL (e.g., username/repo):" new_repo_url
      REPOS[i]="$new_repo_url"
      echo "Updated repository: $repo_to_update to $new_repo_url"
      return
    fi
  done
  echo "Repository $repo_to_update not found."
}

# Function to set the repository URLs
set_repositories() {
  read -p "Enter the GitHub repository URLs (space-separated, e.g., username/repo1 username/repo2): " -a repos
  REPOS=("${repos[@]}")
  echo "Repositories set to: ${REPOS[*]}"
}

# Function to select file type
select_file_type() {
  echo "Select a file type:"
  echo "1) deb"
  echo "2) rpm"
  echo "3) appimage"
  read -p "Enter the number of your choice: " file_type_choice

  case $file_type_choice in
    1) echo "deb";;
    2) echo "rpm";;
    3) echo "appimage";;
    *) echo "Invalid choice"; exit 1;;
  esac
}

# Main script execution
setup_local_directory

# Main menu
while true; do
  echo "Select an option:"
  echo "1) Install prerequisites"
  echo "2) Set repository URLs"
  echo "3) List installed repositories"
  echo "4) Add a repository"
  echo "5) Remove a repository"
  echo "6) Update a repository"
  echo "7) Download latest release from a specific repository"
  read -p "Enter the number of your choice: " choice

  case $choice in
    1) install_prerequisites;;
    2) set_repositories;;
    3) list_repositories;;
    4) add_repository;;
    5) remove_repository;;
    6) update_repository;;
    7)
      read -p "Enter the repository to download from (e.g., username/repo): " repo
      file_type=$(select_file_type)
      download_latest "$repo" "$file_type";;
    *) echo "Invalid choice"; exit 1;;
  esac
done
