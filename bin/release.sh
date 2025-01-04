#!/bin/bash

# Check if version argument is provided
if [ -z "$1" ]; then
    echo "Please provide a version number (e.g., 0.0.0.dev20)"
    exit 1
fi

NEW_VERSION=$1
FORMULA_FILE="Formula/clockr-agent.rb"
REPO_URL="https://github.com/alrocar/homebrew-clockr-agent"

echo "Creating new release $NEW_VERSION..."

# Create and push new tag
git tag $NEW_VERSION
git push origin $NEW_VERSION

# Wait a moment for GitHub to process the tag
sleep 5

# Get the new SHA256
TARBALL_URL="$REPO_URL/archive/refs/tags/$NEW_VERSION.tar.gz"
SHA256=$(curl -sL $TARBALL_URL | shasum -a 256 | cut -d ' ' -f 1)

echo "New SHA256: $SHA256"

# Update the formula
sed -i '' \
    -e "s|url \".*\"|url \"$TARBALL_URL\"|" \
    -e "s|sha256 \".*\"|sha256 \"$SHA256\"|" \
    $FORMULA_FILE

# Commit and push changes
git add $FORMULA_FILE
git commit -m "Release $NEW_VERSION"
git push origin main

echo "Updating Homebrew..."
brew update

echo "Upgrading clockr-agent..."
brew upgrade clockr-agent --verbose

echo "Release $NEW_VERSION completed!" 
