# MinMicroG_releases
Prebuilt flashable zips for the MinMicroG project

The main README for the project:
 - https://github.com/FriendlyNeighborhoodShane/MinMicroG/blob/master/README.md
 - Also inside the zips

Read the above document carefully before using any of the provided zip files.

Main repo for sources and build scripts:
 - https://github.com/FriendlyNeighborhoodShane/MinMicroG

In the event of any damages to your device, house, ego barrier, baby, relationships, galaxy, worldview, or in general the local fabric of spacetime, I shall be held morally responsible, but in no way legally.

### How?
Built on my computer from MinMicroG's master using
```
  ./update.sh
  ./build.sh all
```

### Why a separate repo?
All modules have different version codes and I've never tagged in the MinMicroG repo. (You could say that MinMicroG is rolling-release.)

### On what terms are they distributed?
Well, technically these zips are what the GPL considers 'aggregates', collections of software. So all the individual components of the zip obey their own licenses. The scripts that are part of MinMicroG are under GPLv3, under my copyright. Most of the included software is also free software, under license and copyright of their individual authors given in the zip's readme.

Exception is the nonfree Google software that is packaged in the Standard and MinimalIAP edition zips.

### What's hidden inside contrib?
Oh, nothing. Just a bunch of lazy scripts I use myself to make MinMicroG releases, along with a bunch of MinMicroG confs and hooks that may be interesting.
