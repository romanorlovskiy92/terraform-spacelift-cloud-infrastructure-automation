# https://docs.spacelift.io/concepts/policy/git-push-policy
# GIT_PUSH policy that triggers tracked runs when component files or YAML config files are modified on commits to the default branch

package spacelift

# Get all affected files
# `input.push.affected_files` contains a list of file names (relative to the project root)
# that were changed in the current push to the default branch
affected_files := input.push.affected_files

# Track these extensions in the project folder
tracked_extensions := {".tf", ".tf.json", ".tfvars", ".yaml", ".yml", ".tpl", ".sh", ".shell", ".bash", ".json"}

# Project root
project_root := input.stack.project_root

# Track if project files are affected and the push was to the stack's tracked branch
# https://docs.spacelift.io/concepts/run/tracked
track {
    project_affected
    input.push.branch == input.stack.branch
}

# Track if stack config files are affected and the push was to the stacks' tracked branch
# https://docs.spacelift.io/concepts/run/tracked
track {
    stack_config_affected
    input.push.branch == input.stack.branch
}

# Check if any of the tracked extensions were modified in the project folder
# https://www.openpolicyagent.org/docs/latest/policy-language/#some-keyword
# https://www.openpolicyagent.org/docs/latest/policy-language/#variable-keys
# https://www.openpolicyagent.org/docs/latest/policy-reference/#iteration
project_affected {
    some i, j
    startswith(affected_files[i], project_root)
    endswith(affected_files[i], tracked_extensions[j])
}

# Split the stack name into a list
stack_name_parts := split(input.stack.name, "-")

# Check if the environment has been modified
stack_config_affected {
    contains(affected_files[_], concat("-", [stack_name_parts[0], stack_name_parts[1]]))
}

# Get labels
labels := input.stack.labels

# Get stack imports from the provided `labels`
# NOTE: procesing of stack imports is disabled in the module (var.imports_processing_enabled = false),
# and the below rules will not be evaluated by default
# https://www.openpolicyagent.org/docs/latest/policy-language/#comprehensions
imports := [imp | startswith(labels[i], "import:"); imp := split(labels[i], ":")[1]]

# Check if any of the imports have been modified
stack_config_affected {
    endswith(affected_files[_], imports[_])
}

# Get all stack dependencies for the component from the provided `labels` (all stacks where the component is defined)
# NOTE: procesing of all stack dependencies is disabled in the module (var.stack_deps_processing_enabled = false),
# and the below rules will not be evaluated by default
stack_deps := [stack_dep | startswith(labels[i], "stack:"); stack_dep := split(labels[i], ":")[1]]

# Check if any of the stack dependencies have been modified
stack_config_affected {
    endswith(affected_files[_], stack_deps[_])
}

# Get stack dependencies for the component from the provided `labels`
# NOTE: procesing of component stack dependencies is controlled by var.component_deps_processing_enabled
deps := [dep | startswith(labels[i], "deps:"); dep := split(labels[i], ":")[1]]

# Check if any of the component stack dependencies have been modified
stack_config_affected {
    endswith(affected_files[_], deps[_])
}

# Checking startswith allows `deps:*` to reference top level folders
stack_config_affected {
    startswith(affected_files[_], deps[_])
}
