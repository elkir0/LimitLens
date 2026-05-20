#!/usr/bin/env bash
set -euo pipefail

PROJECT_PATH="${1:-LimitLens.xcodeproj}"

PROJECT_PATH="$PROJECT_PATH" ruby <<'RUBY'
require "xcodeproj"

project_path = ENV.fetch("PROJECT_PATH")
project = Xcodeproj::Project.open(project_path)
target_names = ["LimitLens", "LimitLensWidgetExtension"]

target_attributes = project.root_object.attributes["TargetAttributes"] ||= {}

target_names.each do |target_name|
  target = project.targets.find { |candidate| candidate.name == target_name }
  abort("Target not found: #{target_name}") unless target

  attributes = target_attributes[target.uuid] ||= {}
  capabilities = attributes["SystemCapabilities"]
  capabilities = {} unless capabilities.is_a?(Hash)

  capabilities["com.apple.ApplicationGroups"] = { "enabled" => 1 }
  attributes["SystemCapabilities"] = capabilities
end

project.save
RUBY
