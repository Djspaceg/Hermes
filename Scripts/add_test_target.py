#!/usr/bin/env python3
"""
Add HermesTests target to Hermes.xcodeproj
"""

import os
import sys
import uuid
import re

def generate_uuid():
    """Generate a UUID in Xcode format (24 hex chars)"""
    return uuid.uuid4().hex[:24].upper()

def add_test_target():
    """Add test target to Xcode project"""
    
    project_path = "Hermes.xcodeproj/project.pbxproj"
    
    if not os.path.exists(project_path):
        print(f"Error: {project_path} not found")
        return False
    
    # Read project file
    with open(project_path, 'r') as f:
        content = f.read()
    
    # Generate UUIDs for new objects
    test_target_uuid = generate_uuid()
    test_product_uuid = generate_uuid()
    test_build_config_list_uuid = generate_uuid()
    test_debug_config_uuid = generate_uuid()
    test_release_config_uuid = generate_uuid()
    test_sources_phase_uuid = generate_uuid()
    test_frameworks_phase_uuid = generate_uuid()
    test_resources_phase_uuid = generate_uuid()
    
    # Test file UUIDs
    login_tests_uuid = generate_uuid()
    stations_tests_uuid = generate_uuid()
    history_tests_uuid = generate_uuid()
    
    # Find the main target UUID
    main_target_match = re.search(r'([A-F0-9]{24}) /\* Hermes \*/ = \{[^}]*isa = PBXNativeTarget', content)
    if not main_target_match:
        print("Error: Could not find main Hermes target")
        return False
    
    main_target_uuid = main_target_match.group(1)
    
    print(f"Found main target: {main_target_uuid}")
    print(f"Creating test target: {test_target_uuid}")
    
    # Add test file references
    test_files_section = f"""
/* Begin PBXFileReference section - Test Files */
		{login_tests_uuid} /* LoginViewModelTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = LoginViewModelTests.swift; sourceTree = "<group>"; }};
		{stations_tests_uuid} /* StationsViewModelTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = StationsViewModelTests.swift; sourceTree = "<group>"; }};
		{history_tests_uuid} /* HistoryViewModelTests.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = HistoryViewModelTests.swift; sourceTree = "<group>"; }};
		{test_product_uuid} /* HermesTests.xctest */ = {{isa = PBXFileReference; explicitFileType = wrapper.cfbundle; includeInIndex = 0; path = HermesTests.xctest; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section - Test Files */
"""
    
    # Insert after first PBXFileReference section
    content = content.replace(
        "/* End PBXFileReference section */",
        test_files_section + "\n/* End PBXFileReference section */",
        1
    )
    
    # Add test group
    test_group = f"""
		{generate_uuid()} /* Tests */ = {{
			isa = PBXGroup;
			children = (
				{generate_uuid()} /* ViewModels */,
			);
			path = Tests;
			sourceTree = "<group>";
		}};
		{generate_uuid()} /* ViewModels */ = {{
			isa = PBXGroup;
			children = (
				{login_tests_uuid} /* LoginViewModelTests.swift */,
				{stations_tests_uuid} /* StationsViewModelTests.swift */,
				{history_tests_uuid} /* HistoryViewModelTests.swift */,
			);
			path = ViewModels;
			sourceTree = "<group>";
		}};
"""
    
    # Add test target
    test_target = f"""
		{test_target_uuid} /* HermesTests */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {test_build_config_list_uuid} /* Build configuration list for PBXNativeTarget "HermesTests" */;
			buildPhases = (
				{test_sources_phase_uuid} /* Sources */,
				{test_frameworks_phase_uuid} /* Frameworks */,
				{test_resources_phase_uuid} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
				{generate_uuid()} /* PBXTargetDependency */,
			);
			name = HermesTests;
			productName = HermesTests;
			productReference = {test_product_uuid} /* HermesTests.xctest */;
			productType = "com.apple.product-type.bundle.unit-test";
		}};
"""
    
    # Add build phases
    build_phases = f"""
		{test_sources_phase_uuid} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{generate_uuid()} /* LoginViewModelTests.swift in Sources */,
				{generate_uuid()} /* StationsViewModelTests.swift in Sources */,
				{generate_uuid()} /* HistoryViewModelTests.swift in Sources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_frameworks_phase_uuid} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{test_resources_phase_uuid} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
"""
    
    # Add build configurations
    build_configs = f"""
		{test_build_config_list_uuid} /* Build configuration list for PBXNativeTarget "HermesTests" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{test_debug_config_uuid} /* Debug */,
				{test_release_config_uuid} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{test_debug_config_uuid} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = Tests/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = org.hermesapp.HermesTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Hermes.app/Contents/MacOS/Hermes";
			}};
			name = Debug;
		}};
		{test_release_config_uuid} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				BUNDLE_LOADER = "$(TEST_HOST)";
				CODE_SIGN_STYLE = Automatic;
				INFOPLIST_FILE = Tests/Info.plist;
				LD_RUNPATH_SEARCH_PATHS = "$(inherited) @executable_path/../Frameworks @loader_path/../Frameworks";
				PRODUCT_BUNDLE_IDENTIFIER = org.hermesapp.HermesTests;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_VERSION = 5.0;
				TEST_HOST = "$(BUILT_PRODUCTS_DIR)/Hermes.app/Contents/MacOS/Hermes";
			}};
			name = Release;
		}};
"""
    
    print("Test target configuration created")
    print("\nNote: Manual Xcode project editing required")
    print("Please add test target through Xcode:")
    print("  1. File → New → Target")
    print("  2. Unit Testing Bundle")
    print("  3. Name: HermesTests")
    print("  4. Add test files from Tests/ directory")
    
    return True

if __name__ == "__main__":
    if add_test_target():
        print("\n✅ Test target setup instructions provided")
        sys.exit(0)
    else:
        print("\n❌ Failed to add test target")
        sys.exit(1)
