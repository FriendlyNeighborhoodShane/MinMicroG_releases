#!/bin/sh -e

# MinMicroG autobuild script
# My pride and the epitome of my laziness

# KISS changes my attitude towards color escape sequences
prompta=" ==>>";
promptb=" []>>";
promptc="   <>";
promptd=" !!>>";

# Variables
variantlist="aurora minimal nogoolag standard unlp";
workdir="$(pwd)";
relzips="$workdir/zips";
mmgdir="../../MinMicroG";
reldir="..";

# Fatal error
abort() {
  echo;
  echo "!! FATAL: $1";
  echo;
  exit 1;
}

# Bincheck
for bin in curl jq; do
  [ "$(which "$bin")" ] || abort "Missing dependency: $bin"
done;

# Dircheck
[ -d "$mmgdir" ] && [ -d "$reldir" ] || abort "Directories not set up";

# Ask the user with a y/n prompt
# TODO posix timeout using wait or something
read_reply() {
  read REPLY;
  case "$REPLY" in
    Y*|y*)
      return 0;
    ;;
  esac;
  return 1;
}

# Launch given array of commands in child terminal
# I am not sure if any kind of terminal returns the exit code of the program run
# All of the || error-handling on this function might be useless after all
launch_terminal() {
  cmdstr="";
  for cmd in "$@"; do
    cmd="$(echo "$cmd" | sed -e "s|\\\|\\\\\\\\|g" -e "s|'|\\\'|g" -e 's|"|\\\"|g')";
    cmdstr="$cmdstr $cmd ';'";
  done;
  $TERMINAL -- $SHELL -c "eval $cmdstr";
}

# Open given array of files in child editor
launch_editor() {
  if [ "$EDITOR_TYPE" = "gui" ]; then
    $EDITOR "@";
  else
    filestr="";
    for file in "$@"; do
      filestr="$filestr '$file'";
    done;
    launch_terminal "$EDITOR $filestr";
  fi;
}

# Check if git repo is clean
clean_repo() {
  (
    cd "$1" || return 1;
    [ "$2" ] && {
      git status --porcelain | grep -q "$2$" && return 1 || return 0;
    } || {
      [ "$(git status --porcelain)" ] && return 1 || return 0;
    }
  )
}

# Decide SHELL, TERMINAL, EDITOR
SHELL="$SHELL";
if [ "$TERMINAL" ]; then
  true;
elif [ "$(which st)" ]; then
  TERMINAL="st";
elif [ "$(which konsole)" ]; then
  TERMINAL="konsole";
elif [ "$(which mintty)" ]; then
  TERMINAL="mintty --nodaemon";
else
  abort "No known terminal found!";
fi;
if [ "$EDITOR" ] && [ "$EDITOR_TYPE" ]; then
  true;
elif [ "$(which kate)" ]; then
  EDITOR="kate";
  EDITOR_TYPE="gui";
elif [ "$(which nano)" ]; then
  EDITOR="nano";
  EDITOR_TYPE="cli";
elif [ "$(which vim)" ]; then
  EDITOR="vim";
  EDITOR_TYPE="cli";
elif [ "$(which vi)" ]; then
  EDITOR="vi";
  EDITOR_TYPE="cli";
else
  abort "No known editor found!";
fi;

# Prompt for update.sh
echo;
printf "${promptb} Would you like to run the update script? ";
read_reply && {
  launch_terminal "cd '$mmgdir'" "'$mmgdir'/update.sh" "read REPLY" & pid_update="$!";
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
  launch_editor "$mmgdir"/conf/defconf-*.txt;
  launch_terminal "cd '$mmgdir'" "git add conf/defconf-*.txt" "git commit -m 'Update confs'" "git push" "read REPLY" || abort "Could not commit confs!";
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
    launch_terminal "cd '$mmgdir'" "'$mmgdir'/build.sh $variant" & pid_build="$pid_build $!";
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
  for zip in $(ls -t "$mmgdir"/releases/MinMicroG-*.zip | head -n $variants); do
    [ -f "$zip" ] && cp "$zip" "$relzips/" || abort "Could not copy zips!";
  done;

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
  relfile="$workdir/release.json";
  repo="friendlyneighborhoodshane/minmicrog_releases";
  token="$(cat "$workdir/token.txt")";
  auth="Authorization: token $token";
  ghgit="https://$token@github.com/$repo.git";
  ghapi="https://api.github.com/repos/$repo/releases";
  ghupl="https://uploads.github.com/repos/$repo/releases";

  [ -f "$relfile" ] || abort "No release file";
  [ "$token" ] || abort "No access token";

  # Prompt for updating release file
  echo;
  printf "${promptb} Would you like to update the release file? ";
  read_reply && launch_editor "$relfile";

  # Get variables fron json
  tag="$(jq -r '.tag_name' "$relfile")";
  name="$(jq -r '.name' "$relfile")";
  body="$(jq '.body' "$relfile")";
  body="${body##\"}";
  body="${body%%\"}";

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
      # TODO quoting issues?
      sed -i "3i### $name\n$body" "$reldir/CHANGELOG.md";
      launch_terminal "cd '$reldir'" "git add CHANGELOG.md" "git commit -m 'Changelog: $name'" "git push '$ghgit'" "git pull" "read REPLY" || abort "Could not commit changelog!";
    }
  }

  # Create release
  echo;
  echo "${prompta} Creating github release...";
  curl --data @"$relfile" -H "$auth" -H "Content-Type: application/json" "$ghapi" || abort "Could not create release";

  # Upload release
  echo;
  echo "${prompta} Uploading zips to release...";
  id="$(curl -s -H "$auth" "$ghapi/tags/$tag" | jq -r '.id')";
  [ "$id" ] && [ "$id" -gt 0 ] || abort "Failed to get release id";

  for file in "$relzips"/MinMicroG-*.zip; do

    echo "${promptc} Uploading $(basename "$file")";

    # Upload asset
    ghass="$ghupl/$id/assets?name=$(basename "$file")";
    curl --data-binary @"$file" -H "$auth" -H "Content-Type: application/octet-stream" "$ghass" -o /dev/null || { echo "${promptd} Uploading failed!"; continue; }
    rm -rf "$file";

  done;

}

#Done
rmdir "$relzips" 2>/dev/null;
echo;
echo "${prompta} Done!";
echo;
