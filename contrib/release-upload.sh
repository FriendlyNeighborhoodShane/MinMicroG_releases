#!/bin/sh -e

# MinMicroG autoupload script
# My pride and the epitome of my laziness

# KISS changes my attitude towards color escape sequences
prompta=" ==>>";
promptb=" []>>";
promptc="   <>";
promptd=" !!>>";

# Variables
workdir="$(pwd)";

# Fatal error
abort() {
  echo;
  echo "!! FATAL: $1";
  echo;
  exit 1;
}

# Bincheck
for bin in curl jq; do
  command -v "$bin" >/dev/null || abort "Missing dependency: $bin"
done;

{

  # Release variables
  repo="friendlyneighborhoodshane/minmicrog_releases";
  token="$GITHUB_TOKEN";
  auth="Authorization: token $token";
  ghapi="https://api.github.com/repos/$repo/releases";
  ghupl="https://uploads.github.com/repos/$repo/releases";

  [ "$token" ] || abort "No access token";
  [ "$#" -gt "1" ] || abort "Not enough arguments";
  tag="$1";
  shift 1;

  # Get release ID
  id="$(curl -fs -H "$auth" "$ghapi" | jq -r --arg tag "$tag" '. | sort_by(.created_at) | .[] | select(.tag_name == $tag) | .id' | tail -n1)";
  [ "$id" ] && [ "$id" != "null" ] && [ "$id" -gt 0 ] || abort "Failed to get release id";

  # Upload release
  echo;
  echo "${prompta} Uploading zips to release...";

  for file in "$@"; do

    echo "${promptc} Uploading $(basename "$file")";

    # Delete old asset
    assid="$(curl -fs -H "$auth" "$ghapi/$id/assets" | jq -r --arg file "$(basename "$file")" '.[] | select(.name == $file) | .id')";
    [ "$assid" ] && [ "$assid" != "null" ] && [ "$assid" -gt 0 ] && {
      curl -f -X "DELETE" -H "$auth" "$ghapi/assets/$assid" -o /dev/null || { echo "${promptd} Deleting old asset failed!"; continue; }
    }

    # Upload asset
    ghass="$ghupl/$id/assets?name=$(basename "$file")";
    curl -f --data-binary @"$file" -H "$auth" -H "Content-Type: application/octet-stream" "$ghass" -o /dev/null || { echo "${promptd} Uploading asset failed!"; continue; }
    rm -rf "$file";

  done;

}

#Done
echo;
echo "${prompta} Done!";
echo;
