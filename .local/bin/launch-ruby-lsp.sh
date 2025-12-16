#!/bin/bash

# Logic: Attempts 'bundle exec' first if a Gemfile exists and ruby-lsp is in the bundle.
# Fallback: If Gemfile exists but ruby-lsp is excluded/missing, or if no Gemfile exists,
# it checks for a global installation via asdf. If global gem is missing, it installs it.

RUBY_LSP_NAME="ruby-lsp"

# Function to display error message to Neovim user
error_msg() {
    # Neovim captures output to stderr for notifications.
    echo "--- ${RUBY_LSP_NAME} ERROR ---" >&2
    echo "$1" >&2
    echo "---------------------------" >&2
}

# Function to handle global installation and execution fallback
# This function always exits (via exec) upon successful launch or failure.
launch_global_or_install() {
    # Check 1: Is the global executable already available?
    if command -v "$RUBY_LSP_NAME" > /dev/null 2>&1; then
        error_msg "Launching unbundled LSP via 'asdf exec'."
        # Execute the command directly via asdf shims. This replaces the current shell process.
        exec asdf exec "$RUBY_LSP_NAME" "$@"
    fi
    
    # Check 2: Command not found. Install it now.
    error_msg "The '${RUBY_LSP_NAME}' gem is missing for this Ruby version."
    error_msg "Action: Attempting to automatically run 'gem install ${RUBY_LSP_NAME}' now..."

    if ! asdf exec gem install "$RUBY_LSP_NAME" --no-document; then
        error_msg "FATAL: 'gem install' failed. Check your global Ruby environment and permissions."
        exit 1
    fi
    
    error_msg "Gem install successful. Launching LSP."
    # Execute the newly installed command. This replaces the current shell process.
    exec asdf exec "$RUBY_LSP_NAME" "$@"
}


# --- MAIN EXECUTION LOGIC ---

if [ -f "./Gemfile" ]; then
    
    # Check 1: Are all the project's dependencies installed?
    if ! bundle check > /dev/null 2>&1; then
        # Check 1 FAILED: Dependencies are missing. The project is not ready.
        error_msg "Project dependencies are missing. Please run 'bundle install' in the project root."
        exit 1
    fi
    
    # --- PROJECT DEPENDENCIES ARE MET. ---
    
    # Check 2: Is the ruby-lsp gem explicitly included and installed in the current Bundler environment?
    if bundle info "$RUBY_LSP_NAME" > /dev/null 2>&1; then
        # SUCCESS PATH 1 (Bundled): ruby-lsp is in the Gemfile and installed. Use 'bundle exec'.
        error_msg "Launching bundled LSP via 'bundle exec'."
        exec bundle exec "$RUBY_LSP_NAME" "$@"
    else
        # FALLBACK PATH (Gemfile present but ruby-lsp not included): 
        # The project is ready, but the LSP is excluded from the bundle. 
        # Fallback to the global (asdf) installation.
        error_msg "Project Gemfile exists, but '${RUBY_LSP_NAME}' is not included in the bundle."
        launch_global_or_install "$@"
        # Note: launch_global_or_install executes 'exec' and never returns here.
    fi

else
    # --- NO GEMFILE CONTEXT ---
    # Fallback directly to the global/asdf installation and execution logic.
    error_msg "No Gemfile found. Falling back to global LSP."
    launch_global_or_install "$@"
    # Note: launch_global_or_install executes 'exec' and never returns here.
fi
