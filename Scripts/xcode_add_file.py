#!/usr/bin/env python3
"""
Add files to the Hermes Xcode project.

Supports: .swift, .m, .h, .c, .xib, .storyboard, and resource files.

Usage:
    python3 Scripts/xcode_add_file.py <file_path> [--target <target_name>]
    
Examples:
    python3 Scripts/xcode_add_file.py Sources/Swift/Utilities/NewFile.swift
    python3 Scripts/xcode_add_file.py Sources/Pandora/NewClass.m
    python3 Scripts/xcode_add_file.py Resources/Icons/icon.png
"""

import argparse
import os
import re
import sys
import uuid

PROJECT_PATH = 'Hermes.xcodeproj/project.pbxproj'
MAIN_TARGET_SOURCES_UUID = '8D11072C0486CEB800E47090'  # Hermes target Sources build phase


def generate_uuid():
    """Generate a 24-character hex UUID for Xcode."""
    return uuid.uuid4().hex[:24].upper()


def get_file_type(filename):
    """Return Xcode file type for a given filename."""
    ext = os.path.splitext(filename)[1].lower()
    types = {
        '.swift': 'sourcecode.swift',
        '.m': 'sourcecode.c.objc',
        '.h': 'sourcecode.c.h',
        '.c': 'sourcecode.c.c',
        '.xib': 'file.xib',
        '.storyboard': 'file.storyboard',
        '.png': 'image.png',
        '.pdf': 'image.pdf',
        '.icns': 'image.icns',
        '.plist': 'text.plist.xml',
        '.strings': 'text.plist.strings',
        '.rtf': 'text.rtf',
        '.json': 'text.json',
        '.sdef': 'sourcecode.sdef',
    }
    return types.get(ext, 'file')


def is_source_file(filename):
    """Check if file should be added to Sources build phase."""
    ext = os.path.splitext(filename)[1].lower()
    return ext in ['.swift', '.m', '.c']


def is_resource_file(filename):
    """Check if file should be added to Resources build phase."""
    ext = os.path.splitext(filename)[1].lower()
    return ext in ['.xib', '.storyboard', '.png', '.pdf', '.icns', '.plist', 
                   '.strings', '.rtf', '.json', '.sdef']


def find_group_for_path(content, file_path):
    """Find the appropriate group UUID for a file path."""
    # Extract directory from path
    dir_path = os.path.dirname(file_path)
    dir_name = os.path.basename(dir_path)
    
    # Map common directories to their group names
    group_mappings = {
        'Utilities': 'Utilities',
        'ViewModels': 'ViewModels', 
        'Views': 'Views',
        'Models': 'Models',
        'Swift': 'Swift',
        'Pandora': 'Pandora',
        'Controllers': 'Controllers',
        'Integration': 'Integration',
        'AudioStreamer': 'AudioStreamer',
        'Icons': 'Icons',
        'Resources': 'Resources',
    }
    
    group_name = group_mappings.get(dir_name, dir_name)
    
    # Find the group UUID
    pattern = rf'([A-F0-9]{{24}}) /\* {re.escape(group_name)} \*/ = \{{'
    match = re.search(pattern, content)
    
    if match:
        return match.group(1), group_name
    
    return None, None


def add_file_to_project(file_path, target_name='Hermes'):
    """Add a file to the Xcode project."""
    
    if not os.path.exists(file_path):
        print(f"❌ Error: File does not exist: {file_path}")
        sys.exit(1)
    
    if not os.path.exists(PROJECT_PATH):
        print(f"❌ Error: Project file not found: {PROJECT_PATH}")
        sys.exit(1)
    
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()
    
    filename = os.path.basename(file_path)
    
    # Check if file already exists in project
    if filename in content:
        print(f"⚠️  Warning: {filename} may already be in the project")
    
    # Generate UUIDs
    file_ref_uuid = generate_uuid()
    build_file_uuid = generate_uuid()
    
    file_type = get_file_type(filename)
    
    # 1. Add PBXBuildFile entry (if it's a source or resource file)
    if is_source_file(filename) or is_resource_file(filename):
        build_phase = "Sources" if is_source_file(filename) else "Resources"
        build_file_entry = f"\t\t{build_file_uuid} /* {filename} in {build_phase} */ = {{isa = PBXBuildFile; fileRef = {file_ref_uuid} /* {filename} */; }};\n"
        content = content.replace(
            "/* Begin PBXBuildFile section */\n",
            f"/* Begin PBXBuildFile section */\n{build_file_entry}"
        )
    
    # 2. Add PBXFileReference entry
    file_ref_entry = f"\t\t{file_ref_uuid} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = {file_type}; name = {filename}; path = {file_path}; sourceTree = SOURCE_ROOT; }};\n"
    content = content.replace(
        "/* Begin PBXFileReference section */\n",
        f"/* Begin PBXFileReference section */\n{file_ref_entry}"
    )
    
    # 3. Add to appropriate group
    group_uuid, group_name = find_group_for_path(content, file_path)
    if group_uuid:
        # Find the children array for this group and add the file
        group_pattern = rf'({group_uuid} /\* {re.escape(group_name)} \*/ = \{{[^}}]*children = \([^)]*)'
        match = re.search(group_pattern, content, re.DOTALL)
        if match:
            insert_pos = match.end()
            group_entry = f"\n\t\t\t\t{file_ref_uuid} /* {filename} */,"
            content = content[:insert_pos] + group_entry + content[insert_pos:]
    
    # 4. Add to build phase (Sources or Resources)
    if is_source_file(filename):
        # Add to main target's Sources build phase
        sources_pattern = rf'({MAIN_TARGET_SOURCES_UUID} /\* Sources \*/ = \{{[^}}]*files = \([^)]*)'
        match = re.search(sources_pattern, content, re.DOTALL)
        if match:
            insert_pos = match.end()
            sources_entry = f"\n\t\t\t\t\t\t{build_file_uuid} /* {filename} in Sources */,"
            content = content[:insert_pos] + sources_entry + content[insert_pos:]
    elif is_resource_file(filename):
        # Find Resources build phase
        resources_pattern = r'([A-F0-9]{24}) /\* Resources \*/ = \{[^}]*files = \([^)]*'
        match = re.search(resources_pattern, content, re.DOTALL)
        if match:
            insert_pos = match.end()
            resources_entry = f"\n\t\t\t\t{build_file_uuid} /* {filename} in Resources */,"
            content = content[:insert_pos] + resources_entry + content[insert_pos:]
    
    # Write back
    with open(PROJECT_PATH, 'w') as f:
        f.write(content)
    
    print(f"✅ Added {filename} to Xcode project")
    print(f"   File ref UUID: {file_ref_uuid}")
    if is_source_file(filename) or is_resource_file(filename):
        print(f"   Build file UUID: {build_file_uuid}")


def main():
    parser = argparse.ArgumentParser(description='Add a file to the Hermes Xcode project')
    parser.add_argument('file_path', help='Path to the file to add (relative to project root)')
    parser.add_argument('--target', default='Hermes', help='Target name (default: Hermes)')
    
    args = parser.parse_args()
    add_file_to_project(args.file_path, args.target)


if __name__ == '__main__':
    main()
