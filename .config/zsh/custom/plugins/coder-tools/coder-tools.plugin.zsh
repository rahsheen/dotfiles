# Function to create and configure a Coder workspace from a Jira branch name
qa-coder() {
  if [ -z "$1" ]; then
    echo "Usage: qa-coder <jira-branch-name> <template>"
    echo "Example: qa-coder PT-840-Incorrect-floor-cap-showing..."
    return 1
  fi

  local FULL_BRANCH_NAME="$1"
  local SCRIPT_FILE="${HOME}/qa-setup.sh"
  local TEMPLATE_NAME="${2:-csdev}"  # Use the second argument as the template name, default to 'csdev'

  # 1. Parse Ticket ID from the branch name
  # Extracts 'PT-840' from the start of the branch name (e.g., PT-840-...)
  if [[ "${FULL_BRANCH_NAME}" =~ ^([A-Z]+-[0-9]+) ]]; then
    local TICKET_ID="${match[1]}"
  else
    echo "Error: Could not parse ticket ID from branch name: ${FULL_BRANCH_NAME}" >&2
    return 1
  fi

  local WORKSPACE_NAME="${TICKET_ID}-qa-review"
  # NOTE: The username is automatically prepended by Coder, so we need the user/name format for grep
  # We assume the current user is 'rporter' for the grep/list comparison based on your output example
  # A safer implementation would retrieve the current user from 'coder whoami'.
  local FULL_WORKSPACE_NAME="${$(coder whoami | awk '{print $NF}')}/${WORKSPACE_NAME}"
  local CODER_HOST="coder.${WORKSPACE_NAME}"
  
  echo "--- 🛠️  Starting Idempotent Coder QA Setup ---"
  echo "Workspace Name: ${FULL_WORKSPACE_NAME}"
  echo "Target Branch:  ${FULL_BRANCH_NAME}"

  # --- 2. IDEMPOTENCY CHECK & WORKSPACE MANAGEMENT ---
  
  local WORKSPACE_LINE
  local WORKSPACE_STATUS
  
  # a. Check if the workspace exists by grepping for the full name.
  WORKSPACE_LINE=$(coder list 2>/dev/null | grep "${FULL_WORKSPACE_NAME}")
  
  if [ -n "${WORKSPACE_LINE}" ]; then
    # Workspace exists. Extract the STATUS (which is the 3rd column, as determined by your list output)
    # Using NF (Number of Fields) and offsets is safer than assuming column 3 strictly.
    # The 'STATUS' word is the 3rd field in your output line.
    WORKSPACE_STATUS=$(echo "${WORKSPACE_LINE}" | awk '{print $3}')

    # b. Handle based on the extracted STATUS
    case "${WORKSPACE_STATUS}" in
      Started)
        echo "✅ Workspace '${WORKSPACE_NAME}' already RUNNING. Proceeding to config."
        ;;
      Stopped)
        echo "🟡 Workspace '${WORKSPACE_NAME}' exists but is STOPPED. Starting now..."
        coder start "${WORKSPACE_NAME}" -y
        ;;
      Failed)
        echo "❌ Workspace '${WORKSPACE_NAME}' is in a FAILED state. Restarting..."
        coder restart "${WORKSPACE_NAME}" -y
        ;;
      *)
        echo "🟡 Workspace '${WORKSPACE_NAME}' exists with status: ${WORKSPACE_STATUS}. Proceeding to config."
        ;;
    esac
  else
    # Workspace does not exist (EXIT_CODE != 0)
    echo "➕ Workspace '${WORKSPACE_NAME}' does not exist. Creating now..."

    local AMI_PARAM_NAME="ami_name_prefix"  # CHECK YOUR TEMPLATE FOR THE REAL NAME
    local AMI_DEFAULT_VALUE="csdev-main-ubuntu-jammy-amd64-"

    echo "Creating workspace from template ${TEMPLATE_NAME}..."
    if [ "${TEMPLATE_NAME}" = "csdev" ]; then
      coder create "${WORKSPACE_NAME}" -t "${TEMPLATE_NAME}" -y \
        --parameter "${AMI_PARAM_NAME}=${AMI_DEFAULT_VALUE}" \
        --parameter "csdev_branch=main" \
        --parameter "instance_type=t3.2xlarge" \
        --parameter "region=us-east-1"
    else
      coder create "${WORKSPACE_NAME}" -t "${TEMPLATE_NAME}" -y \
        --parameter "csdev_branch=main"
    fi
  fi

  # Give the workspace a moment to start provisioning
  # The next 'coder' commands will implicitly wait for the agent to be running.
  echo "Waiting for workspace connection..."

  # 3. Securely copy the setup script to the running workspace
  echo "Copying setup script (${SCRIPT_FILE}) to workspace..."
  scp "${SCRIPT_FILE}" "${CODER_HOST}":~/

  # 4. Execute the script remotely, passing the full branch name as an ENV variable
  echo "Executing branch checkout commands remotely..."
  # The '--' separates Coder CLI flags from the remote command.
  # The 'env' command is used to pass the BRANCH_NAME into the remote shell.
  # Run the remote command using the host entry defined by 'coder config-ssh'
  ssh -t "${CODER_HOST}" -- env BRANCH_NAME="${FULL_BRANCH_NAME}" bash /home/coder/qa-setup.sh

  echo "--- ✅ Workspace Setup Complete ---"
  # You can add the automatic browser open from the previous answer here for a one-stop solution.
}
