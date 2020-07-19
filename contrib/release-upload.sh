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
relzips="$workdir/zips";

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
  relfile="$workdir/release.json";
  repo="friendlyneighborhoodshane/minmicrog_releases";
  token="$(cat "$workdir/token.txt")";
  auth="Authorization: token $token";
  ghapi="https://api.github.com/repos/$repo/releases";
  ghupl="https://uploads.github.com/repos/$repo/releases";

  [ -f "$relfile" ] || abort "No release file";
  [ "$token" ] || abort "No access token";

  # Get variables fron json
  tag="$(jq -r '.tag_name' "$relfile")";

  # Upload release
  echo;
  echo "${prompta} Uploading zips to release...";
  id="$(curl -s -H "$auth" "$ghapi/tags/$tag" | jq -r '.id')";
  [ "$id" ] && [ "$id" -gt 0 ] || abort "Failed to get release id";

  for file in "$relzips"/MinMicroG-*.zip; do

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
rmdir "$relzips" 2>/dev/null;
echo;
echo "${prompta} Done!";
echo;
