#!/bin/env bash

# Returns success when the user has at least the minimum number of non-fork repositories.
has_minimum_non_fork_repos() {
  local username=$1
  local min_repos=$2
  local page=1
  local total_non_fork_repos=0

  while : ; do
    response=$(curl -s -u "$GITHUB_USERNAME:$USAGE_TOKEN" "https://api.github.com/users/$username/repos?per_page=100&page=$page")

    repo_count=$(echo "$response" | jq 'if type == "array" then length else 0 end')
    [[ "$repo_count" -eq 0 ]] && break

    non_fork_count=$(echo "$response" | jq '[.[] | select(.fork == false)] | length')
    total_non_fork_repos=$((total_non_fork_repos + non_fork_count))

    ((page++))
  done

  [[ "$total_non_fork_repos" -ge "$min_repos" ]]
}
