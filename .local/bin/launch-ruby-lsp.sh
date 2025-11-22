#!/bin/bash
# Logic: Respects Bundler dependencies first. If all Bundler dependencies are met, 
# but the LSP still isn't found, it defaults to a global/asdf 'gem install' for the user.

RUBY_LSP_NAME="ruby-lsp"

# Function to display error message to Neovim user
error_msg() {
    # Neovim captures output to stderr for notifications.
    echo "--- ${RUBY_LSP_NAME} ERROR ---" >&2
    echo "$1" >&2
    echo "---------------------------" >&2
}

# --- 1. Bundler Execution Context Check ---
if [ -f "./Gemfile" ]; then
    
    # Check 1: Are all the project's dependencies installed? (The Gemfile's required gems)
    if ! bundle check > /dev/null 2>&1; then
        # Check 1 FAILED: Dependencies are missing. The project is not ready.
        error_msg "Project dependencies are missing. Please run 'bundle install' in the project root."
        exit 1
    fi
    
    # --- PROJECT DEPENDENCIES ARE MET. The environment is safe to use. ---
    
    # Check 2: Now, check if the ruby-lsp gem exists in the current Bundler environment.
    # Since 'bundle check' passed, if 'bundle info' fails, it means the gem is missing 
    # either because it was intentionally excluded from the Gemfile, or not installed in the bundle.
    if ! bundle info "$RUBY_LSP_NAME" > /dev/null 2>&1; then
        error_msg "The '${RUBY_LSP_NAME}' gem is not installed in this Ruby project."
        error_msg "Action: Attempting to automatically run 'gem install ${RUBY_LSP_NAME}' now..."
        
        # Attempt 'gem install'. If it fails, exit and notify.
        if ! asdf exec gem install "$RUBY_LSP_NAME" --no-document; then
            error_msg "FATAL: 'gem install' failed. Please check your permissions and Ruby environment."
            exit 1
        fi
        
        error_msg "Gem install successful. Launching LSP."

        # Execute the command directly via asdf shims.
        exec asdf exec "$RUBY_LSP_NAME" "$@"
    fi
    
    # FINAL LAUNCH (Bundler): Project dependencies are met, and ruby-lsp is available globally/locally.
    # We MUST use 'bundle exec' because the rest of the gems are in the bundle.
    exec bundle exec "$RUBY_LSP_NAME" "$@"

else
    # --- 2. Direct asdf Execution Context (No Gemfile) ---

    # Check if the ruby-lsp executable is present in the current asdf environment/path.
    if ! command -v "$RUBY_LSP_NAME" > /dev/null 2>&1; then
        
        # Command not found. Install it now.
        error_msg "The '${RUBY_LSP_NAME}' gem is missing for this Ruby version."
        error_msg "Action: Attempting to automatically run 'gem install ${RUBY_LSP_NAME}' now..."

        if ! asdf exec gem install "$RUBY_LSP_NAME" --no-document; then
            error_msg "FATAL: 'gem install' failed. Check your global Ruby environment."
            exit 1
        fi
        
        error_msg "Gem install successful. Launching LSP."
    fi
    
    # Execute the command directly via asdf shims.
    exec asdf exec "$RUBY_LSP_NAME" "$@"
fi
