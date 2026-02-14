#!/bin/bash

# Firebase Backend Quick Start Script
# This script automates parts of the Firebase setup process

set -e  # Exit on error

echo "🔥 CarbWise Firebase Backend Setup"
echo "=================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Step 1: Check Firebase CLI
echo "📋 Step 1: Checking Firebase CLI..."
if ! command -v firebase &> /dev/null; then
    echo -e "${RED}❌ Firebase CLI not installed${NC}"
    echo "Installing Firebase CLI..."
    npm install -g firebase-tools
    echo -e "${GREEN}✅ Firebase CLI installed${NC}"
else
    echo -e "${GREEN}✅ Firebase CLI already installed${NC}"
    firebase --version
fi
echo ""

# Step 2: Login prompt
echo "🔐 Step 2: Firebase Login"
echo "You need to login to Firebase with your Google account."
echo "Press Enter to open browser for login..."
read
firebase login

echo -e "${GREEN}✅ Logged in successfully${NC}"
echo ""

# Step 3: List projects
echo "📦 Step 3: Firebase Projects"
echo "Your existing Firebase projects:"
firebase projects:list
echo ""

# Step 4: Project selection
echo "Which project do you want to use?"
echo "1) Use existing project"
echo "2) Create new project"
read -p "Enter choice (1 or 2): " project_choice

if [ "$project_choice" == "2" ]; then
    read -p "Enter new project name (e.g., carbwise): " project_name
    echo "Creating project $project_name..."
    firebase projects:create "$project_name"
    echo -e "${GREEN}✅ Project created${NC}"
else
    read -p "Enter existing project ID: " project_name
fi

# Set the project
firebase use "$project_name"
echo -e "${GREEN}✅ Using project: $project_name${NC}"
echo ""

# Step 5: Initialize Functions
echo "⚡ Step 5: Initializing Firebase Functions"
if [ ! -d "functions" ]; then
    echo "Initializing functions directory..."
    firebase init functions --project "$project_name"
    echo -e "${GREEN}✅ Functions initialized${NC}"
else
    echo -e "${YELLOW}⚠️  functions/ directory already exists${NC}"
    read -p "Do you want to reinitialize? (y/N): " reinit
    if [ "$reinit" == "y" ] || [ "$reinit" == "Y" ]; then
        rm -rf functions
        firebase init functions --project "$project_name"
    fi
fi
echo ""

# Step 6: Copy function code
echo "📝 Step 6: Setting up function code"
if [ -f "firebase_backend_example/index.js" ]; then
    cp firebase_backend_example/index.js functions/index.js
    cp firebase_backend_example/package.json functions/package.json
    echo -e "${GREEN}✅ Function code copied${NC}"

    # Install dependencies
    echo "Installing dependencies..."
    cd functions
    npm install
    cd ..
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${RED}❌ firebase_backend_example/index.js not found${NC}"
    echo "Please make sure you're in the project root directory"
    exit 1
fi
echo ""

# Step 7: Set API key
echo "🔑 Step 7: Configure Perplexity API Key"
echo -e "${YELLOW}⚠️  IMPORTANT: Use your NEW rotated API key (not the old one)${NC}"
read -p "Enter your Perplexity API key: " api_key
firebase functions:config:set perplexity.key="$api_key"
echo -e "${GREEN}✅ API key configured${NC}"
echo ""

# Step 8: Deploy functions
echo "🚀 Step 8: Deploying functions to Firebase"
echo "This may take 1-2 minutes..."
firebase deploy --only functions

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅✅✅ SUCCESS! ✅✅✅${NC}"
    echo ""
    echo "Your Firebase backend is now deployed!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Test your function with:"
    echo "   firebase functions:log"
    echo ""
    echo "2. Add Firebase to your Flutter app:"
    echo "   flutter pub add firebase_core cloud_functions"
    echo ""
    echo "3. Configure FlutterFire:"
    echo "   dart pub global activate flutterfire_cli"
    echo "   flutterfire configure"
    echo ""
    echo "4. Update your app to use Firebase Functions"
    echo "   (See FIREBASE_SETUP_GUIDE.md Step 8)"
    echo ""
    echo "🎉 Your API key is now secure on the server!"
else
    echo -e "${RED}❌ Deployment failed${NC}"
    echo "Check the errors above and try again"
    echo "Or run: firebase deploy --only functions --debug"
fi
