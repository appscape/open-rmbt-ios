#!/bin/bash
 
set -o errexit
set -o nounset

INFO_PLIST="${TARGET_BUILD_DIR}"/"${INFOPLIST_PATH}"
 
# GIT_TAG=$(git --git-dir="${PROJECT_DIR}/.git" --work-tree="${PROJECT_DIR}" describe --dirty | sed -e 's/^v//' -e 's/g//')

GIT_COMMIT=$(git --git-dir="${PROJECT_DIR}/.git" --work-tree="${PROJECT_DIR}" rev-parse --short HEAD)
GIT_BRANCH=$(git --git-dir="${PROJECT_DIR}/.git" --work-tree="${PROJECT_DIR}" rev-parse --abbrev-ref HEAD) 
# Number of commits in the current branch
GIT_COMMIT_COUNT=$(git --git-dir="${PROJECT_DIR}/.git" --work-tree="${PROJECT_DIR}" rev-list ${GIT_BRANCH} | wc -l)
BUILD_DATE=$(date "+%Y-%m-%d %H:%M:%S")

defaults write $INFO_PLIST BuildDate "${BUILD_DATE}"
defaults write $INFO_PLIST GitCommit $GIT_COMMIT
defaults write $INFO_PLIST GitBranch $GIT_BRANCH
defaults write $INFO_PLIST GitCommitCount $GIT_COMMIT_COUNT