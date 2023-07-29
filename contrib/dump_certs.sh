#!/bin/sh

# Update all assets
#
# Copyright 2018-2020 FriendlyNeighborhoodShane
# Distributed under the terms of the GNU GPL v3

abort() {
  echo " " >&2;
  echo "!!! FATAL ERROR: $1" >&2;
  echo " " >&2;
  [ -d "$tmpdir" ] && rm -rf "$tmpdir";
  exit 1;
}

workdir="$(pwd)";
cd "$workdir" || abort "Can't cd to $workdir";
confdir="$workdir/conf";
resdir="$workdir/res";
resdldir="$workdir/resdl";
reldir="$workdir/releases";
updatetime="$(date -u +%Y%m%d%H%M%S)";
updatelog="$reldir/update-$updatetime.log";

select_word() {
  select_term="$1";
  cat | while read -r select_line; do
    select_current=0;
    select_found="";
    for select_each in $select_line; do
      select_current="$(( select_current + 1 ))";
      [ "$select_current" = "$select_term" ] && { select_found="yes"; break; }
    done;
    [ "$select_found" = "yes" ] && echo "$select_each";
  done;
}

echo " ";
echo "--       Minimal MicroG Update Script       --";
echo "--      The Essentials Only MicroG Pack     --";
echo "--      From The MicroG Telegram group      --";
echo "--         No, not the Official one         --";

# Bin check
for bin in cp grep rm unzip; do
  command -v "$bin" >/dev/null || abort "No $bin found";
done;

echo " ";
echo " - Working from $workdir";

echo " ";
echo " - Update started at $updatetime";

echo " ";
echo " - Cleaning...";

tmpdir="$(mktemp -d)";
rm -rf "$tmpdir";
mkdir -p "$tmpdir";

# Config

# Verify certs
{

  command -v "apksigner" >/dev/null || {
    echo " ";
    echo " !! Not checking certificates (missing apksigner)";
    return 0;
  }

  certdir="$resdldir/util/certs";

  echo " ";
  echo " - Checking certs for APKs...";

  for object in $(find -H "$resdldir/system" -type f -name "*.apk" | sed "s|^$resdldir||g"); do
    certobject="$(dirname "$object")/$(basename "$object" .apk).cer";
    apksigner verify "$resdldir/$object" > /dev/null || {
      echo "  !! Verification failed for APK ($object)" >&2;
      continue;
    }
    [ -f "$certdir/$certobject" ] || {
      echo "  -- Adding cert for new APK ($object)";
      mkdir -p "$certdir/$(dirname "$certobject")";
      apksigner verify --print-certs-pem "$resdldir/$object" | grep -v '^WARNING: ' > "$certdir/$certobject";
      continue;
    }
    apksigner verify --print-certs-pem "$resdldir/$object" | grep -v '^WARNING: ' > "$tmpdir/tmp.cer";
    [ "$(diff -w "$tmpdir/tmp.cer" "$certdir/$certobject")" ] && {
      echo "  !! Cert mismatch for APK ($object)" >&2;
      cp -f "$tmpdir/tmp.cer" "$certdir/$certobject.new";
    }
  done;

}

# Done

echo " ";
echo " - Done!";

rm -rf "$tmpdir";
echo " ";
