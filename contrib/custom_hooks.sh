# custom hook funcs for MinMicroG


# deltadownload: Don't download the unchanged URLs for dynamic URL sources
# Function to retrieve dynamic URLs before the download process
# And trim out entries with same URL as last log from the download table
# Unfortunately has to download repos one more time because hook is executed before repo download

# pre_update_actions hook
deltadownload() {

  echo " ";
  echo " - Checking objects whose links have been updated...";

  oldlogs="$(find "$reldir" -type f -name "update-*.log" -exec expr {} : ".*/update-\([0-9]\{14\}\)\.log$" ';' | sort -nr)";
  [ "$oldlogs" ] || return 0;

  echo "  -- Getting repos";
  for repo in $(echo "$stuff_repo" | select_word 1); do
    line="$(echo "$stuff_repo" | grep -E "^[ ]*$repo[ ]+" | head -n1)";
    repourl="$(echo "$line" | select_word 2)";
    [ "$repourl" ] || continue;
    curl -L "$repourl/index-v1.jar" -o "$tmpdir/repos/$repo.jar" || { echo "ERROR: Repo $repo failed to download"; continue; }
    [ -f "$tmpdir/repos/$repo.jar" ] || continue;
    unzip -oq "$tmpdir/repos/$repo.jar" "index-v1.json" -d "$tmpdir/repos/";
    [ -f "$tmpdir/repos/index-v1.json" ] || continue;
    mv -f "$tmpdir/repos/index-v1.json" "$tmpdir/repos/$repo.json";
    [ -f "$tmpdir/repos/$repo.json" ] || continue;
  done;

  for object in $(echo "$stuff_download" | select_word 1); do
    line="$(echo "$stuff_download" | grep -E "^[ ]*$object[ ]+" | head -n1)";
    source="$(echo "$line" | select_word 2)";
    objectpath="$(echo "$line" | select_word 3)";
    objectarg="$(echo "$line" | select_word 4)";
    [ "$objectpath" ] || continue;
    oldline="";
    for log in $oldlogs; do
      oldline="$(grep "FILE: $object[,;]" "$reldir/update-$log.log" | head -n1)";
      [ "$oldline" ] && break;
    done;
    oldurl="$(echo "$oldline" | grep -oE "URL: [^,;]*" | cut -d" " -f2)";
    [ "$oldurl" ] && {
      case "$source" in
        github)
          objecturl="$(curl -sN "https://api.github.com/repos/$objectpath/releases" | jq -r '.[].assets[].browser_download_url' | grep "$objectarg$" | head -n1)";
        ;;
        gitlab)
          objectid="$(echo "$objectpath" | jq -Rr "@uri")";
          [ "$objectid" ] || continue;
          objectupload="$(curl -sN "https://gitlab.com/api/v4/projects/$objectid/repository/tags" | jq -r '.[].release.description' | grep -oE "(/uploads/[^()]*$objectarg)" | head -n1 | tr -d "()")";
          [ "$objectupload" ] || continue;
          objecturl="https://gitlab.com/$objectpath$objectupload";
        ;;
        repo)
          objectrepo="$(dirname "$objectpath")";
          objectpackage="$(basename "$objectpath")";
          [ "$objectarg" ] && {
            objectarch="$(echo "$objectarg" | sed "s|:| |g" | select_word 1)";
            objectsdk="$(echo "$objectarg" | sed "s|:| |g" | select_word 2)";
          }
          [ "$objectrepo" ] && [ "$objectpackage" ] || continue;
          [ -f "$tmpdir/repos/$objectrepo.json" ] || continue;
          objectserver="$(jq -r '.repo.address' "$tmpdir/repos/$objectrepo.json")";
          if [ "$objectarg" ]; then
            objectserverfile="$(jq -r --arg pkg "$objectpackage" --arg arch "$objectarch" --arg sdk "$objectsdk" '.packages[$pkg][] | if $arch != "" and has("nativecode") then select(.nativecode[]? == $arch) else . end | if $sdk != "" then select((.minSdkVersion|tonumber?) <= ($sdk|tonumber?)) else . end | .apkName' "$tmpdir/repos/$objectrepo.json" | head -n1)";
          else
            objectserverfile="$(jq -r --arg pkg "$objectpackage" '.packages[$pkg][].apkName' "$tmpdir/repos/$objectrepo.json" | head -n1)";
          fi;
          [ "$objectserver" ] && [ "$objectserver" != "null" ] && [ "$objectserverfile" ] && [ "$objectserverfile" != "null" ] || continue;
          objecturl="$objectserver/$objectserverfile";
        ;;
        *)
          continue;
        ;;
      esac;
      [ "$objecturl" = "$oldurl" ] && {
        echo "  -- Stripping up-to-date $object";
        stuff_download="$(echo "$stuff_download" | sed -E "s|^[ ]*$object[ ]+.*||")";
      }
    }
  done;

  stuff_repo_new="";
  repo_apps="$(echo "$stuff_download" | grep -E "^[ ]*[^ ]+[ ]+repo[ ]+")";
  for repo in $(echo "$repo_apps" | select_word 3); do
    stuff_repo_new="$stuff_repo_new
$(echo "$stuff_repo" | grep -E "^[ ]*$(dirname "$repo")[ ]+" | head -n1)
";
  done;
  stuff_repo="$(echo "$stuff_repo_new" | sort -u)";

  rm -rf "$tmpdir/repos"/*;

}


# ultra_compress + ultra_extract: Use tar with gzip over main contents of zip
# Free build and install cost with almost 0 size difference

# pre_build_actions hook
ultra_compress() {

  echo "";
  echo " - Doing ultra compression...";

  (
    cd "$tmpdir" || abort "Could not cd";
    for file in ./*; do
      [ -f "$file" ] || [ "$file" = "./META-INF" ] && continue;
      tar cv "$file" | gzip -9 | cat > "./$file.arc" && rm -rf "$file";
    done;
  )

}

# pre_install_actions hook
ultra_extract() {

  echo "";
  echo " - Doing ultra extraction...";

  (
    cd "$filedir" || abort "Could not cd";
    for file in ./*.arc; do
      cat "$file" | gzip -d | tar xv;
    done;
  )

}


# user_conf: Config system to let the user flexibly decide what they want to install
# Helps me stay lazy

# Pre-install hook
user_conf() {

  for dir in "$(dirname "$0")" "$(dirname "$zipfile")" "$moddir" "/data/adb"; do
    [ -f "$dir/includelist.txt" ] || [ -f "$dir/excludelist.txt" ] && {
      ui_print " ";
      if [ -f "$dir/includelist.txt" ]; then
        ui_print "Processing include config from $dir...";
        includelist="$(sed -e 's|\#.*||g' -e 's|[^a-zA-Z0-9.-]| |g' "$dir/includelist.txt")";
      else
        ui_print "Processing exclude config from $dir...";
        excludelist="$(sed -e 's|\#.*||g' -e 's|[^a-zA-Z0-9.-]| |g' "$dir/excludelist.txt")";
      fi;
      break;
    }
  done;

  [ "$includelist" ] && {
    new_stuff="";
    new_stuff_arch="";
    new_stuff_sdk="";
    new_stuff_arch_sdk="";
    for include in $includelist; do
      log "Including keyword $include";
      new_stuff="$new_stuff $(echo "$stuff" | grep -oi "[ ]*[^ ]*$include[^ ]*[ ]*")";
      new_stuff_arch="$new_stuff_arch $(echo "$stuff_arch" | grep -oi "[ ]*[^ ]*$include[^ ]*[ ]*")";
      new_stuff_sdk="$new_stuff_sdk $(echo "$stuff_sdk" | grep -oi "[ ]*[^ ]*$include[^ ]*[ ]*")";
      new_stuff_arch_sdk="$new_stuff_arch_sdk $(echo "$stuff_arch_sdk" | grep -oi "[ ]*[^ ]*$include[^ ]*[ ]*")";
    done;
    stuff="$new_stuff";
    stuff_arch="$new_stuff_arch";
    stuff_sdk="$new_stuff_sdk";
    stuff_arch_sdk="$new_stuff_arch_sdk";
  }

  [ "$excludelist" ] && {
    new_stuff="$stuff";
    new_stuff_arch="$stuff_arch";
    new_stuff_sdk="$stuff_sdk";
    new_stuff_arch_sdk="$stuff_arch_sdk";
    for exclude in $excludelist; do
      log "Including keyword $include";
      new_stuff="$(echo "$new_stuff" | sed "s|[ ]*[^ ]*$exclude[^ ]*[ ]*| |ig")";
      new_stuff_arch="$(echo "$new_stuff_arch" | sed "s|[ ]*[^ ]*$exclude[^ ]*[ ]*| |ig")";
      new_stuff_sdk="$(echo "$new_stuff_sdk" | sed "s|[ ]*[^ ]*$exclude[^ ]*[ ]*| |ig")";
      new_stuff_arch_sdk="$(echo "$new_stuff_arch_sdk" | sed "s|[ ]*[^ ]*$exclude[^ ]*[ ]*| |ig")";
    done;
    stuff="$new_stuff";
    stuff_arch="$new_stuff_arch";
    stuff_sdk="$new_stuff_sdk";
    stuff_arch_sdk="$new_stuff_arch_sdk";
  }

  [ "$includelist" ] || [ "$excludelist" ] && {
    stuff="$(echo "$stuff" | sed 's| |\n|g' | tr -s '\n' | sort -u | sed 's|^|  |g')
";
    stuff_arch="$(echo "$stuff_arch" | sed 's| |\n|g' | tr -s '\n' | sort -u | sed 's|^|  |g')
";
    stuff_sdk="$(echo "$stuff_sdk" | sed 's| |\n|g' | tr -s '\n' | sort -u | sed 's|^|  |g')
";
    stuff_arch_sdk="$(echo "$stuff_arch_sdk" | sed 's| |\n|g' | tr -s '\n' | sort -u | sed 's|^|  |g')
";
  }

  [ "$stuff" ] || [ "$stuff_arch" ] || [ "$stuff_sdk" ] || [ "$stuff_arch_sdk" ] || abort "Nothing left to install after config";

}
