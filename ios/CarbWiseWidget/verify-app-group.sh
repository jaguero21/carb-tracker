#!/bin/bash

# App Group Verification Script for CarpeCarb
# This script checks that App Group configuration is consistent across all files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# App Group ID to check for
EXPECTED_APP_GROUP="group.com.carpecarb.shared"
PROJECT_DIR="$(dirname "$0")"

echo -e "${BLUE}🔍 CarpeCarb App Group Verification${NC}\n"
echo -e "Expected App Group ID: ${GREEN}${EXPECTED_APP_GROUP}${NC}\n"

# Function to check file for app group references
check_file() {
    local file="$1"
    local description="$2"
    
    if [ ! -f "$file" ]; then
        echo -e "${YELLOW}⚠️  ${description}: File not found${NC}"
        echo -e "   ${file}\n"
        return 1
    fi
    
    # Check if file contains app group reference
    if grep -q "group\.com\." "$file" 2>/dev/null; then
        local found_group=$(grep -o "group\.com\.[a-zA-Z0-9._-]*" "$file" | head -1)
        
        if [ "$found_group" == "$EXPECTED_APP_GROUP" ]; then
            echo -e "${GREEN}✅ ${description}${NC}"
            echo -e "   ${found_group}\n"
        else
            echo -e "${RED}❌ ${description}: MISMATCH${NC}"
            echo -e "   Expected: ${EXPECTED_APP_GROUP}"
            echo -e "   Found:    ${found_group}\n"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  ${description}: No app group found${NC}\n"
        return 1
    fi
    
    return 0
}

# Check count
total_checks=0
passed_checks=0

# Check AppGroupConfig.swift
echo -e "${BLUE}📱 Checking Swift Source Files${NC}\n"

((total_checks++))
if check_file "AppGroupConfig.swift" "AppGroupConfig.swift"; then
    ((passed_checks++))
fi

((total_checks++))
if check_file "CarbWiseWidget.swift" "CarbWiseWidget.swift"; then
    ((passed_checks++))
fi

# Check entitlements files
echo -e "${BLUE}🔐 Checking Entitlements Files${NC}\n"

# Try to find entitlements files
RUNNER_ENTITLEMENTS=$(find . -name "Runner.entitlements" 2>/dev/null | head -1)
WIDGET_ENTITLEMENTS=$(find . -name "*Widget*.entitlements" 2>/dev/null | head -1)

if [ -n "$RUNNER_ENTITLEMENTS" ]; then
    ((total_checks++))
    if check_file "$RUNNER_ENTITLEMENTS" "Runner Entitlements"; then
        ((passed_checks++))
    fi
else
    echo -e "${YELLOW}⚠️  Runner.entitlements not found${NC}\n"
fi

if [ -n "$WIDGET_ENTITLEMENTS" ]; then
    ((total_checks++))
    if check_file "$WIDGET_ENTITLEMENTS" "Widget Entitlements"; then
        ((passed_checks++))
    fi
else
    echo -e "${YELLOW}⚠️  Widget entitlements file not found${NC}\n"
fi

# Check for hardcoded group references in other files
echo -e "${BLUE}🔎 Scanning for Hardcoded App Groups${NC}\n"

# Search for hardcoded app group strings
hardcoded_files=$(grep -r "group\.com\.[a-zA-Z0-9._-]*" \
    --include="*.swift" \
    --include="*.m" \
    --include="*.h" \
    --exclude-dir=Pods \
    --exclude-dir=build \
    --exclude-dir=.git \
    . 2>/dev/null | \
    grep -v "AppGroupConfig" | \
    grep -v "//.*group\.com" || true)

if [ -n "$hardcoded_files" ]; then
    echo -e "${RED}❌ Found hardcoded App Group references:${NC}"
    echo "$hardcoded_files"
    echo -e "\n${YELLOW}⚠️  Consider using AppGroupConfig.identifier instead${NC}\n"
else
    echo -e "${GREEN}✅ No hardcoded App Group references found${NC}\n"
fi

# Check UserDefaults usage
echo -e "${BLUE}🗃️  Checking UserDefaults Usage${NC}\n"

# Look for UserDefaults(suiteName:) calls
userdefaults_calls=$(grep -r "UserDefaults(suiteName:" \
    --include="*.swift" \
    --exclude-dir=Pods \
    --exclude-dir=build \
    --exclude-dir=.git \
    . 2>/dev/null || true)

if [ -n "$userdefaults_calls" ]; then
    echo -e "${YELLOW}Found UserDefaults(suiteName:) calls:${NC}"
    echo "$userdefaults_calls"
    echo -e "\n${BLUE}💡 Consider using AppGroupConfig.sharedDefaults instead${NC}\n"
else
    echo -e "${GREEN}✅ All using AppGroupConfig or standard defaults${NC}\n"
fi

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Summary${NC}\n"

echo -e "Checks passed: ${passed_checks}/${total_checks}"

if [ $passed_checks -eq $total_checks ]; then
    echo -e "\n${GREEN}✅ All checks passed!${NC}"
    echo -e "App Group configuration is consistent.\n"
    exit 0
else
    echo -e "\n${RED}❌ Some checks failed${NC}"
    echo -e "Please review the issues above.\n"
    
    echo -e "${YELLOW}Common fixes:${NC}"
    echo -e "1. Update all App Group references to: ${EXPECTED_APP_GROUP}"
    echo -e "2. Enable App Groups capability in Xcode for all targets"
    echo -e "3. Ensure entitlements files are included in build settings"
    echo -e "4. Regenerate provisioning profiles\n"
    exit 1
fi
