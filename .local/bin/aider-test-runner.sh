#!/bin/bash

# $@ captures the specific files Aider modified
FILES="$@"

# 1. NX Monorepo Detection
if [ -f "nx.json" ]; then
  if [ -n "$FILES" ]; then
    echo "Running Nx tests for specific files..."
    # Convert spaces to commas for Nx --files flag
    NX_FILES=$(echo $FILES | tr ' ' ',')
    npx nx affected -t test --base=origin/staging --files="$NX_FILES" --parallel=3 --output-style=static --no-interactive --color=false --args="--reporter=summary --no-api"
  else
    echo "Running Nx affected tests (branch vs staging)..."
    npx nx affected -t test --base=origin/staging --parallel=3 --output-style=static --no-interactive --color=false --args="--reporter=summary --no-api"
  fi
  exit $?
fi

# 2. Rails / Standard Ruby Detection
if [ -f "Gemfile" ]; then
  export RAILS_ENV=test

  # If /spec exists, we are in an RSpec project
  if [ -d "spec" ]; then
    echo "Running RSpec on $FILES"
    rspec-smart-test $FILES
    exit $?
  # If /test exists, we are in a Minitest/Rails-default project
  elif [ -d "test" ]; then
    echo "Running Rails Minitest on $FILES"
    # bin/rails test is the modern way to run Minitest
    [ -f "bin/rails" ] && bin/rails test $FILES || bundle exec rake test TEST="$FILES"
    exit $?
  fi
fi

# 3. Standalone Vitest/TS projects (non-Nx)
if [ -f "vitest.config.ts" ] || [ -f "vitest.config.js" ]; then
  echo "Running Vitest on $FILES"
  # Use 'run' to ensure it doesn't enter watch mode
  npx vitest run $FILES
  exit $?
fi

exit 0
