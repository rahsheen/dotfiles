#!/bin/bash

# 1. NX Monorepo Detection
if [ -f "nx.json" ]; then
  # If Aider is editing a specific file, we try to run the affected test
  # Or simply run the affected tests for the current workspace
  echo "Running Nx affected tests..."
  npx nx affected -t test --parallel=3
  exit $?
fi

# 2. Rails / Standard Ruby Detection
if [ -f "Gemfile" ]; then
  if [ -d "spec" ]; then
    bundle exec rspec
    exit $?
  elif [ -d "test" ]; then
    bundle exec rake test
    exit $?
  fi
fi

# 3. Prism-Specific / Generic Ruby Project
if [ -f "Rakefile" ] && grep -q "prism" Rakefile 2>/dev/null; then
  bundle exec rake test
  exit $?
fi

# 4. Standalone Vitest/TS projects (non-Nx)
if [ -f "vitest.config.ts" ] || [ -f "vitest.config.js" ]; then
  npx vitest run
  exit $?
fi

# Fallback: Exit 0 so Aider doesn't think a missing test suite is a "failure"
exit 0
