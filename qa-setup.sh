#!/bin/bash
set -e

# Script to run inside the remote Coder workspace

# The target branch name is expected to be passed via the BRANCH_NAME environment variable
TARGET_BRANCH="${BRANCH_NAME}"
PROJECTS_DIR="/workspaces"

if [ -z "${TARGET_BRANCH}" ]; then
    echo "Error: BRANCH_NAME environment variable is not set." >&2
    exit 1
fi

echo "Starting QA setup for branch: ${TARGET_BRANCH}"

# --- PROJECTS TO CHECKOUT ---
# List all project directories that need a specific branch checkout
PROJECT_DIRS=("coyote" "lyra")

for PROJECT in "${PROJECT_DIRS[@]}"; do
    PROJECT_PATH="${PROJECTS_DIR}/${PROJECT}"
    
    if [ -d "${PROJECT_PATH}" ]; then
        echo "Checking out ${TARGET_BRANCH} in ${PROJECT}..."
        
        # Navigate, fetch, and checkout the branch
        cd "${PROJECT_PATH}"
        git fetch origin > /dev/null 2>&1  # Fetch silently
        
        # Try checking out the branch, creating it locally if it doesn't exist
        git reset --hard

        if git checkout "${TARGET_BRANCH}" 2> /dev/null; then
            echo "Successfully checked out existing branch: ${TARGET_BRANCH}"
        elif git checkout -b "${TARGET_BRANCH}" "origin/${TARGET_BRANCH}" 2> /dev/null; then
            echo "Successfully checked out and created new branch: ${TARGET_BRANCH}"
        else
            echo "Warning: Could not checkout or create branch ${TARGET_BRANCH} in ${PROJECT}. Moving to next project." >&2
        fi
    else
        echo "Warning: Project directory ${PROJECT_PATH} not found. Skipping." >&2
    fi
done

/usr/local/bin/tilt trigger lyra-coyote-base

RAILS_PROJECT_PATH="${PROJECTS_DIR}/coyote"

if [ -d "${RAILS_PROJECT_PATH}" ]; then
    source /etc/profile.d/asdf.sh
    source /workspaces/.env.secrets
    echo "Running migrations for Rails project..."
    cd "${RAILS_PROJECT_PATH}"
    
    bundle install # Ensure all gems are installed/updated for the new branch
    bundle exec rake db:migrate # Run pending database migrations
    
    echo "Rails migrations completed."
else
    echo "Rails project directory not found or named differently. Skipping migrations."
fi

echo "Installing dotfiles..."
coder dotfiles -y https://github.com/rahsheen/dotfiles.git

echo "QA setup script finished."
