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
  echo "!! FATAL: $!";
  echo;
  exit 1;
}

# Bincheck
for bin in curl jq; do
  [ "$(which "$bin")" ] || abort "Missing dependency: $bin"
done;

{

  # Release variables
  repo="friendlyneighborhoodshane/minmicrog_releases";
  token="$(cat "$workdir/token.txt")";
  auth="Authorization: token $token";
  ghapi="https://api.github.com/repos/$repo/releases";
  ghupl="https://uploads.github.com/repos/$repo/releases";

  [ "$token" ] || abort "No access token";
  [ "$#" -gt "1" ] || abort "Not enough arguments";
  tag="$1";
  shift 1;

  # Upload release
  echo;
  echo "${prompta} Uploading zips to release...";
  id="$(curl -s -H "$auth" "$ghapi/tags/$tag" | jq -r '.id')";
  [ "$id" ] && [ "$id" -gt 0 ] || abort "Failed to get release id";

  for file in "$@"; do

    echo "${promptc} Uploading $(basename "$file")";

    # Delete old asset
    assid="$(curl -s -H "$auth" "$ghapi/$id/assets" | jq -r --arg file "$(basename "$file")" '.[] | select(.name == $file) | .id')";
    [ "$assid" ] && [ "$assid" -gt 0 ] && {
      curl -X "DELETE" -H "$auth" "$ghapi/assets/$assid" -o /dev/null || { echo "${promptd} Deleting old asset failed!"; continue; }
    }

    # Upload asset
    ghass="$ghupl/$id/assets?name=$(basename "$file")";
    curl --data-binary @"$file" -H "$auth" -H "Content-Type: application/octet-stream" "$ghass" -o /dev/null || { echo "${promptd} Uploading asset failed!"; continue; }
    rm -rf "$file";

  done;

}

#Done
echo;
echo "${prompta} Done!";
echo;
