#!/usr/bin/env python3
"""
Remove files from the Hermes Xcode project.

Removes all references to a file including:
- PBXBuildFile entries
- PBXFileReference entries  
- Group membership
- Build phase membership

Usage:
    python3 Scripts/xcode_remove_file.py <filename_or_path>
    python3 Scripts/xcode_remove_file.py <file1> <file2> ...
    
Examples:
    python3 Scripts/xcode_remove_file.py OldFile.swift
    python3 Scripts/xcode_remove_file.py Sources/Legacy/OldClass.m Sources/Legacy/OldClass.h
    python3 Scripts/xcode_remove_file.py Keychain.m Keychain.h
"""

import argparse
import os
import re
import sys

PROJECT_PATH = 'Hermes.xcodeproj/project.pbxproj'


def find_uuids_for_file(content, filename):
    """Find all UUIDs that reference a file."""
    uuids = set()
    
    # Extract just the filename if a path was provided
    basename = os.path.basename(filename)
    
    # Pattern 1: UUID /* filename */ or UUID /* filename in Sources */
    pattern1 = rf'([A-F0-9]{{24}})\s+/\*\s*{re.escape(basename)}(?:\s+in\s+\w+)?\s*\*/'
    matches = re.findall(pattern1, content)
    uuids.update(matches)
    
    # Pattern 2: path = filename or path = "filename"
    pattern2 = rf'([A-F0-9]{{24}})[^;]*path\s*=\s*"?[^"]*{re.escape(basename)}"?\s*;'
    matches = re.findall(pattern2, content)
    uuids.update(matches)
    
    # Pattern 3: name = filename
    pattern3 = rf'([A-F0-9]{{24}})[^;]*name\s*=\s*"?{re.escape(basename)}"?\s*;'
    matches = re.findall(pattern3, content)
    uuids.update(matches)
    
    return uuids


def remove_uuid_references(content, uuid):
    """Remove all references to a UUID from the project file."""
    
    # Remove complete object definitions (PBXBuildFile, PBXFileReference entries)
    # Pattern: UUID /* comment */ = { ... };
    pattern = rf'\s*{uuid}\s+/\*[^*]*\*/\s*=\s*\{{[^}}]*\}};?\n?'
    content = re.sub(pattern, '', content)
    
    # Remove from arrays with comments: UUID /* comment */,
    pattern = rf',?\s*{uuid}\s+/\*[^*]*\*/,?\n?'
    content = re.sub(pattern, '', content)
    
    # Remove standalone UUID references in arrays
    pattern = rf',?\s*{uuid},?\n?'
    content = re.sub(pattern, '', content)
    
    return content


def cleanup_project_file(content):
    """Clean up formatting issues after removals."""
    
    # Fix trailing commas before closing parenthesis
    content = re.sub(r',(\s*\n\s*\))', r'\1', content)
    
    # Fix leading commas after opening parenthesis
    content = re.sub(r'\(\s*\n\s*,', '(\n', content)
    
    # Remove excessive blank lines
    content = re.sub(r'\n{3,}', '\n\n', content)
    
    # Fix double commas
    content = re.sub(r',\s*,', ',', content)
    
    return content


def remove_files_from_project(filenames):
    """Remove one or more files from the Xcode project."""
    
    if not os.path.exists(PROJECT_PATH):
        print(f"❌ Error: Project file not found: {PROJECT_PATH}")
        sys.exit(1)
    
    with open(PROJECT_PATH, 'r') as f:
        content = f.read()
    
    original_content = content
    total_uuids_removed = 0
    
    for filename in filenames:
        basename = os.path.basename(filename)
        
        # Find all UUIDs for this file
        uuids = find_uuids_for_file(content, filename)
        
        if not uuids:
            print(f"⚠️  Warning: No references found for {basename}")
            continue
        
        print(f"Found {len(uuids)} UUID(s) for {basename}")
        
        # Remove all references
        for uuid in uuids:
            content = remove_uuid_references(content, uuid)
        
        total_uuids_removed += len(uuids)
    
    # Clean up the file
    content = cleanup_project_file(content)
    
    # Only write if changes were made
    if content != original_content:
        with open(PROJECT_PATH, 'w') as f:
            f.write(content)
        
        print(f"\n✅ Removed {total_uuids_removed} reference(s) from Xcode project")
        print(f"   Files processed: {len(filenames)}")
    else:
        print("\n⚠️  No changes made to project file")


def main():
    parser = argparse.ArgumentParser(
        description='Remove files from the Hermes Xcode project',
        epilog='Examples:\n'
               '  %(prog)s OldFile.swift\n'
               '  %(prog)s Keychain.m Keychain.h\n'
               '  %(prog)s Sources/Legacy/OldClass.m',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument('files', nargs='+', help='File(s) to remove (filename or path)')
    
    args = parser.parse_args()
    remove_files_from_project(args.files)


if __name__ == '__main__':
    main()
