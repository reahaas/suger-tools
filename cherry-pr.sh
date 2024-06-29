#!/bin/bash

print_help() {
  echo "Usage: $0 -s <source_branch_name> [-d <destination_branch>] [-p <pull_request_id>]"
  echo "Options:"
  echo "    -s <source_branch_name>    The branch from which the changes will be cherry-picked. Mandatory argument."
  echo "    -d <destination_branch>    The branch to which the changes will be cherry-picked. If not provided, 'preprod' is used as the default."
  echo "    -p <pull_request_id>       If provided, the script will cherry-pick the commits from this pull request. If not provided, the script will cherry-pick the commits from the source branch."
  echo "Example: $0 -s feature-branch-name"
  echo "Example: $0 -s feature-branch-name -d preprod -p 123"
}

# Default values
SOURCE_BRANCH_NAME=""
DEST_BRANCH="preprod"
PR_ID=""

REPO_OWNER="$(git config --get remote.origin.url | sed -n 's/.*:\/\/github.com\/\([^\/]*\)\/.*/\1/p')"
REPO_NAME="$(basename `git rev-parse --show-toplevel`)"

echo "Current directory: $(pwd)"
echo "Repository owner: [$REPO_OWNER]"
echo "Repository name: [$REPO_NAME]"

# Parse command-line options
while getopts "s:d:p:" opt; do
  case ${opt} in
    s)
      SOURCE_BRANCH_NAME=$OPTARG
      ;;
    d)
      DEST_BRANCH=$OPTARG
      ;;
    p)
      PR_ID=$OPTARG
      ;;
    \?)
      print_help
      exit 1
      ;;
  esac
done

if [ -z "$SOURCE_BRANCH_NAME" ]; then
  echo "Error: Source branch name must be provided. Use [-s <source_branch_name>]"
  print_help
  exit 1
fi

echo "Source branch name: [$SOURCE_BRANCH_NAME]"
echo "Destination branch: [$DEST_BRANCH]"
echo "Pull request ID: [$PR_ID]"

# Checkout & pull to the DEST_BRANCH branch
git checkout "${DEST_BRANCH}" || { echo "Failed to checkout to ["${DEST_BRANCH}"] branch"; exit 1; }
git pull origin "${DEST_BRANCH}" || { echo "Failed to pull changes from ["${DEST_BRANCH}"] branch"; exit 1; }

# Fetch the latest changes from the remote repository
git fetch origin || { echo "Failed to fetch changes from origin"; exit 1; }

# Get the list of commits for the pull request
if [ -n "$PR_ID" ]; then
  echo "Getting PR commits for PR_ID: ${PR_ID}"
  gh_pr_view_argument="${PR_ID}"
else
  echo "Getting PR commits for source branch: ${SOURCE_BRANCH_NAME}"
  gh_pr_view_argument="${SOURCE_BRANCH_NAME}"
fi
pr_commits=$(gh pr view "${gh_pr_view_argument}" --json commits | jq -r '.commits[].oid') || { echo "Failed to get PR commits"; exit 1; }
echo "PR commits: $pr_commits"

# Create a new branch
new_branch_name="${SOURCE_BRANCH_NAME}--to--${DEST_BRANCH}" && echo "New branch name: $new_branch_name"
git checkout -b "${new_branch_name}" || { echo "Failed to create new branch ${new_branch_name}"; exit 1; }

# Loop over the commits and cherry pick them into the new branch
for commit in $pr_commits
do
  echo "Cherry-picking commit: $commit"
  git cherry-pick $commit
done

# Push the new branch to the remote repository
git push origin $new_branch_name || { echo "Failed to push the new branch to the remote repository"; exit 1; }

# Create a new pull request from the new branch to the DEST_BRANCH branch
pr_number=$(gh pr create --title "Cherry picking ${new_branch_name}" --body "" --base ${DEST_BRANCH} --head $new_branch_name --repo $REPO_OWNER/$REPO_NAME | awk -F'/' '{print $NF}') || { echo "Failed to create a new pull request"; exit 1; }
echo "Pull request created: $pr_number"

# Open the new pull request in a web browser
gh pr view $pr_number --web || { echo "Failed to open the new pull request in a web browser"; exit 1; }
