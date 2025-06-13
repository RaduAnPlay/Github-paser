/bin/bash

# Default repositories (space-separated)
REPOS=("username/repo1" "username/repo2") # Replace with your default GitHub repositories
LOCAL_DIR="./downloads"                   # Local directory to store downloaded files

# Function to check for prerequisites
check_prerequisites() {
  local missing=()
  command -v fzf >/dev/null 2>&1 || missing+=("fzf")
  command -v jq >/dev/null 2>&1 || missing+=("jq")

  if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing prerequisites: ${missing[*]}"
    return 1
  fi
  return 0
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
    echo "No supported package manager found. Please install fzf and jq manually."
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
    echo "Failed to fetch latest release for $repo"
    return
  }

  if [ -z "$(echo "$response" | jq -r '.assets')" ]; then
    echo "No assets found for the latest release in $repo."
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
    else
      echo "Error: Invalid download URL: $download_url"
    fi
  else
    echo "No suitable asset found for type .$file_type in $repo."
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

# Function to set the repository URLs
set_repositories() {
  read -p "Enter the GitHub repository URLs (space-separated, e.g., username/repo1 username/repo2): " -a repos
  REPOS=("${repos[@]}")
  echo "Repositories set to: ${REPOS[*]}"
}

# Main script execution
setup_local_directory

# Main menu
while true; do
  echo "Select an option:"
  echo "1) Install prerequisites"
  echo "2) Set repository URLs"
  echo "3) List installed repositories"
  echo "4) Remove a repository"
  echo "5) Download latest release from a specific repository"
  echo "6) Download latest release from a specific repository"
  echo "7) Remove a file"
  echo "8) Exit"
  read -p "Enter your choice: " choice

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
    remove_repository
    ;;
  5)
    list_repositories
    read -p "Enter the repository to download from (e.g., username/repo): " repo_to_download
    read -p "Select file type to download (rpm, AppImage, deb): " file_type
    download_latest "$repo_to_download" "$file_type"
    ;;
  6)
    echo "Exiting..."
    exit 0
    ;;
  *)
    echo "Invalid option. Please try again."
    ;;
  esac
done
