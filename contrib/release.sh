#!/bin/sh -e

# MinMicroG autobuild script
# My pride and the epitome of my laziness

# KISS changes my attitude towards color escape sequences
prompta=" ==>>";
promptb=" []>>";
promptc="   <>";
promptd=" !!>>";

# Variables
reply_timeout="15";
workdir="$(pwd)";
relzips="$workdir/zips";
mmgdir="../../MinMicroG";
variantlist="$(find "$mmgdir/conf" -type f -name "defconf-*.txt" -exec expr {} : ".*/defconf-\(.*\)\.txt$" ';')";
reldir="..";

# Fatal error
abort() {
  echo;
  echo "!! FATAL: $1";
  echo;
  exit 1;
}

# Bincheck
for bin in curl date jq; do
  command -v "$bin" >/dev/null || abort "Missing dependency: $bin"
done;

# Dircheck
[ -d "$mmgdir" ] && [ -d "$reldir" ] || abort "Directories not set up";

# Ask the user with a y/n prompt
read_reply() {
  # POSIX emulation of read -t
  # Bit hacky but works out perfectly
  # Some shell may unavoidably print 'Terminated\n' in the timeout case
  REPLY="$( (
    pid="$($SHELL -c 'echo $PPID')";
    (
      sleep "$reply_timeout" & spid="$!";
      trap 'kill "$spid"' TERM;
      wait "$spid"; kill "$pid";
    ) & dpid="$!";
    read -r REPLY;
    printf '%s\n' "$REPLY";
    kill "$dpid";
  ) )";
  case "$REPLY" in
    Y*|y*)
      return 0;
    ;;
  esac;
  return 1;
}

# Check if git repo is clean
clean_repo() {
  (
    cd "$1" || return 1;
    if [ "$2" ]; then
      [ "$(git status --porcelain -- "$2")" ] && return 1 || return 0;
    else
      [ "$(git status --porcelain)" ] && return 1 || return 0;
    fi;
  )
}

# Launch given array of commands in child terminal
# Terminal must be able to be launch from itself or outside, and block until exit
# I am not sure if any kind of terminal returns the exit code of the program run
# All of the || error-handling on this function might be useless after all
if false; then
  :;
elif command -v "st" >/dev/null; then
  launch_terminal() {
    cmdstr="$(printf '%s; ' "$@")";
    st -- $SHELL -c "$cmdstr";
  }
elif command -v "konsole" >/dev/null; then
  launch_terminal() {
    cmdstr="$(printf '%s; ' "$@")";
    konsole -- $SHELL -c "$cmdstr";
  }
elif command -v "mintty" >/dev/null; then
  launch_terminal() {
    cmdstr="$(printf '%s; ' "$@")";
    mintty --nodaemon -- $SHELL -c "$cmdstr";
  }
else
  abort "No known terminal found!";
fi;

# Open given array of files in child editor
# Can launch directly or through a terminal using launch_terminal
if false; then
  :;
elif command -v "kate" >/dev/null; then
  launch_editor() {
    kate -- "@";
  }
elif command -v "notepad++" >/dev/null; then
  launch_editor() {
    notepad++ -- "$@";
  }
elif command -v "nano" >/dev/null; then
  launch_editor() {
    filestr="$(printf '"%s" ' "$@")";
    launch_terminal "nano -- $filestr";
  }
elif command -v "vim" >/dev/null; then
  launch_editor() {
    filestr="$(printf '"%s" ' "$@")";
    launch_terminal "vim -- $filestr";
  }
elif command -v "vi" >/dev/null; then
  launch_editor() {
    filestr="$(printf '"%s" ' "$@")";
    launch_terminal "vi -- $filestr";
  }
else
  abort "No known editor found!";
fi;

# Prompt for update.sh
echo;
printf "${promptb} Would you like to run the update script? ";
read_reply && {
  launch_terminal "cd '$mmgdir'" "./update.sh" "read REPLY" & pid_update="$!";
}

# Prompt for conf update
echo;
printf "${promptb} Would you like to change the configs? ";
read_reply && {
  launch_terminal "cd '$mmgdir'" "git pull";
  while true; do
    clean_repo "$mmgdir" "conf/defconf-.*.txt" && break;
    echo;
    echo "${promptd} The repository is not clean. Please clean it first.";
    launch_terminal "cd '$mmgdir'" "$SHELL";
  done;
  launch_terminal "cd '$mmgdir'" "$SHELL";
  printf "${promptb} Please enter new {ver} value: ";
  read -r ver;
  printf "${promptb} Please enter new {verc} value: ";
  read -r verc;
  launch_terminal "cd '$mmgdir'" "./bump.sh '$ver' '$verc' '$(date -u +'%d %B, %Y')'" "git add conf/defconf-*.txt" "git commit -m 'Update confs'" "git push" "read REPLY" || abort "Could not commit confs!";
}

# Wait for update process
[ "$pid_update" ] && {
  echo;
  echo "${prompta} Waiting for update process to be done...";
  wait "$pid_update" || abort "Update process failed!";
}

# Testing loop

while true; do

  # Build all variants
  echo;
  echo "${prompta} Running build process.."
  pid_build="";
  variants="0";
  for variant in $variantlist; do
    echo "${promptc} Running build for variant $variant...";
    launch_terminal "cd '$mmgdir'" "./build.sh $variant" & pid_build="$pid_build $!";
    variants="$(( variants + 1 ))";
  done;

  # Wait for build process
  echo;
  echo "${prompta} Waiting for build process to be done..."
  wait $pid_build || abort "Could not build packages!";

  # Copy all zips
  echo;
  echo "${prompta} Copying zips.."
  rm -rf "$relzips";
  mkdir "$relzips";
  find "$mmgdir/releases" -type f -name "MinMicroG-*-*.zip" -exec expr {} : ".*/MinMicroG-.*-\([0-9]\{14\}\)\.zip$" ';' | sort -nr | head -n "$variants" | while read -r time; do
    zip="$( (set -- "$mmgdir/releases"/MinMicroG-*-$time.zip; echo "$1";) )";
    [ -f "$zip" ] && cp "$zip" "$relzips/" || abort "Could not copy zips!";
  done;
  (cd "$mmgdir/resdl/util/certs"; tar cz .;) > "$relzips/certs.tar.gz";

  # Prompt for zip testing
  echo;
  printf "${promptb} Would you like to test the zips on a device? ";
  read_reply || break;

  # Launch zip uploader
  launch_terminal "cd '$relzips'" "$SHELL" &

  # Prompt if everything okay
  echo;
  printf "${promptb} Did everything turn out okay? ";
  read_reply && break;

  # Open console in MMG dir
  launch_terminal "cd '$mmgdir'" "$SHELL";

done;

# Prompt for uploading
echo;
printf "${promptb} Do you want to make a release? ";
read_reply && {

  # Release variables
  repo="friendlyneighborhoodshane/minmicrog_releases";
  token="$GITHUB_TOKEN";
  auth="Authorization: token $token";
  ghgit="https://$token@github.com/$repo.git";
  ghapi="https://api.github.com/repos/$repo/releases";
  ghupl="https://uploads.github.com/repos/$repo/releases";

  [ "$token" ] || abort "No access token";

  # Set variables
  tag="$(date +"%Y.%m.%d")";
  name="$(date +"%d %b %Y")";

  # Prompt for changelog
  echo;
  echo "${prompta} Please write the changelog...";
  tmp="$(mktemp)";
  # TODO echo template?
  launch_terminal "cd '$mmgdir'" "$SHELL" &
  launch_editor "$tmp";
  changelog="$(cat "$tmp")";
  rm -f "$tmp";

  # Update changelog and commit
  grep -q "^### $name" "$reldir/CHANGELOG.md" || {
    launch_terminal "cd '$reldir'" "git pull";
    grep -q "^### $name" "$reldir/CHANGELOG.md" || {
      while true; do
        clean_repo "$reldir" "CHANGELOG.md" && break;
        echo;
        echo "${promptd} The repository is not clean. Please clean it first.";
        launch_terminal "cd '$reldir'" "$SHELL";
      done;
      echo;
      echo "${prompta} Updating and commiting changelog...";
      printf '### %s\n%s\n\n' "$name" "$changelog" | sed -i '2r/dev/stdin' "$reldir/CHANGELOG.md";
      launch_terminal "cd '$reldir'" "git diff CHANGELOG.md" "git add CHANGELOG.md" "git commit -m 'Changelog: $name'" "git push '$ghgit'" "git pull" "read REPLY" || abort "Could not commit changelog!";
    }
  }
  commit="$(git -C "$reldir" rev-parse HEAD)";
  [ "$commit" ] || abort "Failed to get changelog commit";

  # Prompt for release note
  echo;
  echo "${prompta} Please write the release note...";
  tmp="$(mktemp)";
  # TODO echo template?
  printf '%s\n' "$changelog" > "$tmp";
  launch_editor "$tmp";
  body="$(cat "$tmp")";
  rm -f "$tmp";

  # Create release
  echo;
  echo "${prompta} Creating github release...";
  cat <<EOF | curl -f --data "@-" -H "$auth" -H "Content-Type: application/json" "$ghapi" -o /dev/null || abort "Could not create release";
{
  "tag_name": "$tag",
  "target_commitish": "$commit",
  "name": "$name",
  "body": $(printf '%s\n' "$body" | jq -Rsr '@json'),
  "draft": true
}
EOF
  id="$(curl -fs -H "$auth" "$ghapi" | jq -r --arg tag "$tag" '. | sort_by(.created_at) | .[] | select(.tag_name == $tag and .draft == true) | .id' | tail -n1)";
  [ "$id" ] && [ "$id" != "null" ] && [ "$id" -gt 0 ] || abort "Failed to get release id";

  # Upload release
  echo;
  echo "${prompta} Uploading zips to release...";

  for file in "$relzips"/*; do

    echo "${promptc} Uploading $(basename "$file")";

    # Upload asset
    ghass="$ghupl/$id/assets?name=$(basename "$file")";
    curl -f --data-binary @"$file" -H "$auth" -H "Content-Type: application/octet-stream" "$ghass" -o /dev/null || { echo "${promptd} Uploading failed!"; continue; }
    rm -rf "$file";

  done;

  # Get HTML URL
  url="$(curl -fs -H "$auth" "$ghapi/$id" | jq -r '.html_url')";
  [ "$url" ] && [ "$url" != "null" ] && {
    echo;
    echo "${prompta} You can find the release draft at:";
    echo "${promptc} $url";
  }

  # Publish drafted release
  echo;
  printf "${promptb} Do you want to publish the release? ";
  read_reply && {
    echo;
    echo "${prompta} Publishing github release...";
    cat <<EOF | curl -f --data "@-" -H "$auth" -H "Content-Type: application/json" "$ghapi/$id" -o /dev/null;
{"draft":false}
EOF
  }

}

#Done
rmdir "$relzips" 2>/dev/null;
echo;
echo "${prompta} Done!";
echo;
