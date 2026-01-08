#!/usr/bin/env ruby
# add_files_to_xcode.rb
# Adds new Swift files to the WhisperType Xcode project

require 'securerandom'

PROJECT_FILE = "WhisperType.xcodeproj/project.pbxproj"

# New files to add
NEW_SOURCE_FILES = [
  # Processing files
  { path: "WhisperType/Meeting/Processing/TranscriptUpdate.swift", group: "Processing" },
  { path: "WhisperType/Meeting/Processing/StreamingWhisperProcessor.swift", group: "Processing" },
  # Utilities files  
  { path: "WhisperType/Meeting/Utilities/WERCalculator.swift", group: "Utilities" },
  { path: "WhisperType/Meeting/Utilities/LatencyMeasurement.swift", group: "Utilities" },
  { path: "WhisperType/Meeting/Utilities/PartialTranscriptStore.swift", group: "Utilities" },
  # Views files
  { path: "WhisperType/Meeting/Views/SubtitleEntryView.swift", group: "Views" },
  { path: "WhisperType/Meeting/Views/LiveSubtitleView.swift", group: "Views" },
  { path: "WhisperType/Meeting/Views/LiveSubtitleWindow.swift", group: "Views" },
]

NEW_TEST_FILES = [
  { path: "WhisperTypeTests/Meeting/WERCalculatorTests.swift" },
  { path: "WhisperTypeTests/Meeting/PartialTranscriptStoreTests.swift" },
  { path: "WhisperTypeTests/Meeting/LatencyMeasurementTests.swift" },
  { path: "WhisperTypeTests/Meeting/StreamingWhisperProcessorTests.swift" },
]

def generate_uuid
  SecureRandom.hex(12).upcase
end

def read_project
  File.read(PROJECT_FILE)
end

def write_project(content)
  File.write(PROJECT_FILE, content)
end

def file_name(path)
  File.basename(path)
end

# Read existing project
content = read_project

# Track UUIDs
source_uuids = []
test_uuids = []

# Add PBXFileReference entries for source files
NEW_SOURCE_FILES.each do |file|
  uuid = generate_uuid
  name = file_name(file[:path])
  
  # Check if already exists
  next if content.include?(name)
  
  file_ref = "\t\t#{uuid} /* #{name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{name}; sourceTree = \"<group>\"; };\n"
  
  # Find the PBXFileReference section end marker (any existing swift file) and add before it
  content = content.sub(
    /(\t\t7BBD[A-F0-9]+ \/\* \w+\.swift \*\/ = \{isa = PBXFileReference;)/,
    "#{file_ref}\\1"
  )
  
  source_uuids << { uuid: uuid, name: name, path: file[:path], group: file[:group] }
  puts "Added file reference: #{name}"
end

# Add PBXFileReference entries for test files
NEW_TEST_FILES.each do |file|
  uuid = generate_uuid
  name = file_name(file[:path])
  
  next if content.include?(name)
  
  file_ref = "\t\t#{uuid} /* #{name} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = #{name}; sourceTree = \"<group>\"; };\n"
  
  content = content.sub(
    /(\t\t7BBD[A-F0-9]+ \/\* \w+\.swift \*\/ = \{isa = PBXFileReference;)/,
    "#{file_ref}\\1"
  )
  
  test_uuids << { uuid: uuid, name: name, path: file[:path] }
  puts "Added test file reference: #{name}"
end

# Add PBXBuildFile entries for Sources phase
source_uuids.each do |file|
  build_uuid = generate_uuid
  build_file = "\t\t#{build_uuid} /* #{file[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{file[:uuid]} /* #{file[:name]} */; };\n"
  
  content = content.sub(
    /(\t\t7BBD[A-F0-9]+ \/\* \w+\.swift in Sources \*\/ = \{isa = PBXBuildFile;)/,
    "#{build_file}\\1"
  )
  
  # Also need to add to build phase
  file[:build_uuid] = build_uuid
  puts "Added build file: #{file[:name]}"
end

# Add PBXBuildFile entries for Test Sources phase
test_uuids.each do |file|
  build_uuid = generate_uuid
  build_file = "\t\t#{build_uuid} /* #{file[:name]} in Sources */ = {isa = PBXBuildFile; fileRef = #{file[:uuid]} /* #{file[:name]} */; };\n"
  
  content = content.sub(
    /(\t\t7BBD[A-F0-9]+ \/\* \w+\.swift in Sources \*\/ = \{isa = PBXBuildFile;)/,
    "#{build_file}\\1"
  )
  
  file[:build_uuid] = build_uuid
  puts "Added test build file: #{file[:name]}"
end

# Write back
write_project(content)

puts "\n✅ Added #{source_uuids.length} source files and #{test_uuids.length} test files to project"
puts "\n⚠️  IMPORTANT: You need to open Xcode and manually add the new files to the correct groups."
puts "Files added (need manual group assignment):"
source_uuids.each { |f| puts "  - #{f[:path]}" }
test_uuids.each { |f| puts "  - #{f[:path]}" }
