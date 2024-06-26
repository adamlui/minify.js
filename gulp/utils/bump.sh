#!/bin/bash

# This script automates:
# >>> bump versions in manifests + READMEs >>> commit bumps to Git
# >>> build minified JS to dist/ >>> update jsDelivr URLs for GH assets in cli.min.js
# >>> commit build to Git >>> push all changes to GitHub >>> publish to npm (optional)

# Init UI colors
nc="\033[0m"    # no color
br="\033[1;91m" # bright red
by="\033[1;33m" # bright yellow
bg="\033[1;92m" # bright green
bw="\033[1;97m" # bright white

# Validate version arg
ver_types=("major" "minor" "patch")
if [[ ! "${ver_types[@]}" =~ "$1" ]] ; then
    echo "${br}Invalid version argument. Please specify 'major', 'minor', or 'patch'.${nc}"
    exit 1 ; fi

# Determine new version to bump to
old_ver=$(node -pe "require('./package.json').version")
IFS='.' read -ra subvers <<< "$old_ver" # split old_ver into subvers array
case $1 in # edit subvers based on version type
    "patch") subvers[2]=$((subvers[2] + 1)) ;;
    "minor") subvers[1]=$((subvers[1] + 1)) ; subvers[2]=0 ;;
    "major") subvers[0]=$((subvers[0] + 1)) ; subvers[1]=0 ; subvers[2]=0 ;;
esac
new_ver=$(printf "%s.%s.%s" "${subvers[@]}")

# Bump version in package.json + package-lock.json
echo -e "${by}Bumping versions in package manifests...${bw}"
npm version --no-git-tag-version "$new_ver"

# Bump versions in READMEs
echo -e "${by}\nBumping versions in READMEs...${bw}"
pkg_name=$(node -pe "require('./package.json').name" | sed -e 's/^@[a-zA-Z0-9-]*\///' -e 's/^@//')
sed_actions=(
    # Latest Build shield link
    -exec sed -i -E "s|(tag/[^0-9]+)[0-9]+\.[0-9]+\.[0-9]+|\1$new_ver|g" {} +   
    # Latest Build shield src
    -exec sed -i -E "s|[0-9.]+(-.*logo=icinga)|$new_ver\1|" {} + 
    # Minified Size shield link/src
    -exec sed -i -E "s|-[0-9]+\.[0-9]+\.[0-9]+([^.]\|$)|-$new_ver\1|g" {} +
    # jsDelivr ver tags in import section
    -exec sed -i -E "s|@([0-9]+\.[0-9]+\.[0-9]+)|@$new_ver|g" {} +
)
find . -name 'README.md' "${sed_actions[@]}"
echo "v$new_ver"

# Commit bumps to Git
echo -e "${by}\nCommitting bumps to Git...\n${nc}"
find . -name "README.md" -exec git add {} +
git add package*.json
git commit -n -m "Bumped $pkg_name versions to $new_ver"

# Build minified JS to dist/
echo -e "${by}\nBuilding minified JS...\n${nc}"
bash utils/build.sh

# Update jsDelivr URLs for GitHub assets w/ commit hash
echo -e "${by}\nUpdating jsDelivr URLs for GitHub assets w/ commit hash...${nc}"
bump_hash=$(git rev-parse HEAD)
old_file=$(<dist/cli.min.js)
sed -i -E "s|(cdn\.jsdelivr\.net\/gh\/[^/]+\/[^@/\"']+)[^/\"']*|\1@$bump_hash|g" dist/cli.min.js
new_file=$(<dist/cli.min.js)
if [[ "$old_file" != "$new_file" ]]
    then echo -e "${bw}$bump_hash${nc}"
    else echo "No jsDelivr URLs for GH assets found in built files"
fi

# Commit build to Git
echo -e "${by}\nCommitting build to Git...\n${nc}"
git add ./dist/*.js
git commit -n -m "Built $pkg_name v$new_ver"

# Push all changes to GiHub
echo -e "${by}\nPushing to GitHub...\n${nc}"
git push

# Publish to NPM
if [[ "$*" == *"--publish"* ]] ; then
    echo -e "${by}\nPublishing to npm...\n${nc}"
    npm publish ; fi

# Print final summary
echo -e "\n${bg}Successfully bumped to v$new_ver$(
    [[ "$*" == *"--publish"* ]] && echo ' and published to npm' || echo ''
)!${nc}"
