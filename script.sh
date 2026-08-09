#!/bin/env bash

# GitHub username and token
GITHUB_USERNAME="${GITHUB_USERNAME}"
USAGE_TOKEN="${USAGE_TOKEN}"
MIN_NON_FORK_REPOS="${MIN_NON_FORK_REPOS:-5}"

source "$(dirname "$0")/repository_criteria.sh"

# Function to fetch all pages of users
fetch_all_users() {
  local url=$1
  local users=()
  local page=1

  while : ; do
    response=$(curl -s -u "$GITHUB_USERNAME:$USAGE_TOKEN" "$url?per_page=100&page=$page")
    usernames=$(echo "$response" | jq -r '.[].login')

    if [[ -z "$usernames" ]]; then
      break
    fi

    while read -r username; do
      users+=("$username")
    done <<< "$usernames"

    ((page++))
  done

  echo "${users[@]}"
}

# Fetch all followers and following users
FOLLOWERS=($(fetch_all_users "https://api.github.com/users/$GITHUB_USERNAME/followers"))
FOLLOWING=($(fetch_all_users "https://api.github.com/users/$GITHUB_USERNAME/following"))
KEEP_USERS=()
declare -A USER_REPO_CRITERIA_CACHE=()

user_meets_repo_criteria() {
  local username=$1

  if [[ -n "${USER_REPO_CRITERIA_CACHE[$username]+x}" ]]; then
    return "${USER_REPO_CRITERIA_CACHE[$username]}"
  fi

  if has_minimum_non_fork_repos "$username" "$MIN_NON_FORK_REPOS"; then
    USER_REPO_CRITERIA_CACHE[$username]=0
  else
    USER_REPO_CRITERIA_CACHE[$username]=1
  fi

  return "${USER_REPO_CRITERIA_CACHE[$username]}"
}

if [[ -f "keepme.txt" ]]; then
  while read -r USERNAME; do
    USERNAME="$(echo "$USERNAME" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    [[ -z "$USERNAME" ]] && continue
    [[ "$USERNAME" == --* ]] && continue
    KEEP_USERS+=("$USERNAME")
  done < "keepme.txt"
fi

# Finds and follow back users that are following
for USERNAME in "${FOLLOWERS[@]}"; do
  if [[ ! " ${FOLLOWING[@]} " =~ " ${USERNAME} " ]] && user_meets_repo_criteria "$USERNAME"; then
    curl -s -L \
      -X PUT \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $USAGE_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/user/following/$USERNAME"
  fi
done

# Finds and unfollow users who aint following back
for USERNAME in "${FOLLOWING[@]}"; do
  if [[ ! " ${KEEP_USERS[@]} " =~ " ${USERNAME} " ]] && { [[ ! " ${FOLLOWERS[@]} " =~ " ${USERNAME} " ]] || ! user_meets_repo_criteria "$USERNAME"; }; then
    curl -s -L \
      -X DELETE \
      -H "Accept: application/vnd.github+json" \
      -H "Authorization: Bearer $USAGE_TOKEN" \
      -H "X-GitHub-Api-Version: 2022-11-28" \
      "https://api.github.com/user/following/$USERNAME"
  fi
done
