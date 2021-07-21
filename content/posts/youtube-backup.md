---
title: Saving endangered YouTube videos
date: 2021-07-20T15:17:03+02:00
tags:
- youtube
- backup
categories:
- notes
---

Remember that video that you thought was funny ten years ago but didn't age well
enough to stay on YouTube? I do too and I hate that I can't find it anymore! To
avoid this from happening again, I've decided to save my favorites to a playlist
and regularly back it up.

I have a short shell script `cron`'d to run every morning on a
[Scaleway](https://www.scaleway.com) server that saves new additions to
[Object Storage](https://www.scaleway.com/en/object-storage/).


## Downloading videos

Downloading videos is super-simple with [youtube-dl](https://youtube-dl.org/):

```sh
youtube-dl -i https://www.youtube.com/playlist?list=XXXXXX
```

This will download videos to the working directory with filenames generated from
the video's ID and title. During the last few years I've run into various
hiccups that required some fine tuning of `youtube-dl`:

- Hitting YouTube API limits: need to space out the downloads over a longer
period. I've also decided to download the playlist in random order so even if
I always get blocked after N requests, I'll eventually download every video.
- Funky filenames: At some point YouTube decided to allow emojis to appear in
video titles. I don't want emojis in filenames though. Luckily enough
`youtube-dl` has you covered.

Here's what the download command looks like now:

```sh
youtube-dl \
        --no-color \
        --playlist-random \
        --restrict-filenames \
        --sleep-interval 9 \
        -i https://www.youtube.com/playlist?list=XXXXXX \
        > ../log/yt-backup-`date +%F-%H-%M-%S` 2>&1
```

{{< hint info >}}
**Downloading everything over and over?**  
Will this download every video over and over again every day? Fortunately not!
Youtube-dl will skip videos if the output file already exists. So do I need to
keep every video in local storage? Keep on reading to find out. (:
{{< /hint >}}

## Uploading videos

Uploading to [Object Storage](https://www.scaleway.com/en/object-storage/) is
really easy. It has an S3-compatible API so you can use the `aws` CLI to
interact with it.

To avoid uploading every video every day I could delete everything once uploaded.
But it would be re-downloaded the next day then... (see blue box above) So
instead of deleting I'm replacing uploaded videos with an empty file of the same
name:

```sh
NEW=`find videos -size +0 -type f`
for f in $NEW; do
    aws s3 cp "$f" "s3://my-bucket/$f"
    rm "$f"
    touch "$f"
done
```

## Conclusion

With the right tools (youtube-dl + aws CLI) it really is this simple. The full
script looks like this:

```sh
#!/bin/bash

# update youtube-dl to adapt to latest YT APIs
pip3 install --upgrade youtube-dl

# download
cd /mnt/data/youtube/videos
/usr/local/bin/youtube-dl \
        --no-color \
        --playlist-random \
        --restrict-filenames \
        --sleep-interval 9 \
        -i \
        https://www.youtube.com/playlist?list=XXXXXX \
        > ../log/yt-backup-`date +%F-%H-%M-%S` 2>&1

# upload
cd /mnt/data/youtube
NEW=`find videos -size +0 -type f`
for f in $NEW; do
        aws s3 cp "$f" "s3://my-bucket/$f"
        rm "$f"
        touch "$f"
done

```