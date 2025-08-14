#!/bin/bash

# Script for downloading a branch of element-web matching the branch a PR is contributed from

set -x

deforg="quynhXEM"
defrepo="chat.socjsc.com"

# The PR_NUMBER variable must be set explicitly.
default_org_repo=${GITHUB_REPOSITORY:-"$deforg/$defrepo"}
PR_ORG=${PR_ORG:-${default_org_repo%%/*}}
PR_REPO=${PR_REPO:-${default_org_repo##*/}}

# A function that clones a branch of a repo based on the org, repo and branch
clone() {
    org=$1
    repo=$2
    branch=$3
    if [ -n "$branch" ]
    then
        echo "Trying to use $org/$repo#$branch"
        # Disable auth prompts: https://serverfault.com/a/665959
        GIT_TERMINAL_PROMPT=0 git clone https://github.com/$org/$repo.git $repo --branch "$branch" --depth 1 && exit 0
    fi
}

# Fallback function to try different repositories if the primary one fails
clone_with_fallback() {
    local branch=$1
    
    # Try quynhXEM/chat.socjsc.com first (custom repo)
    clone "quynhXEM" "$defrepo" "$branch" || \
    # Fallback to main branch if specific branch doesn't exist
    clone "quynhXEM" "$defrepo" "main" || \
    # Final fallback to vector-im/element-web if custom repo fails
    clone "vector-im" "element-web" "master" || \
    clone "vector-im" "element-web" "main"
}

echo "Getting info about a PR with number $PR_NUMBER"
apiEndpoint="https://api.github.com/repos/$PR_ORG/$PR_REPO/pulls/$PR_NUMBER"
head=$(curl "$apiEndpoint" | jq -r '.head.label')

# for forks, $head will be in the format "fork:branch", so we split it by ":"
# into an array. On non-forks, this has the effect of splitting into a single
# element array given ":" shouldn't appear in the head - it'll just be the
# branch name. Based on the results, we clone.
BRANCH_ARRAY=(${head//:/ })
TRY_ORG=$deforg
TRY_BRANCH=${BRANCH_ARRAY[0]}
if [[ "$head" == *":"* ]]; then
    # ... but only match that fork if it's a real fork
    if [ "${BRANCH_ARRAY[0]}" != "$PR_ORG" ]; then
        TRY_ORG=${BRANCH_ARRAY[0]}
    fi
    TRY_BRANCH=${BRANCH_ARRAY[1]}
fi

# Try with fallback mechanism
clone_with_fallback "$TRY_BRANCH"

exit 1
