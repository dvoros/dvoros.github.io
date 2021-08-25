---
title: "Commenting Metapost"
date: 2021-08-25T16:51:25+02:00
tags:
- blog
- nginx
- docker
categories:
- notes
draft: false
---

Okay, okay, not really a metapost as this isn't a post about posts but a post
about commenting on this blog.

I wanted to introduce some commenting functionality as some of my posts (like this
one!) are meant to help others facing similar issues and having the ability to
ask/respond might benefit others.

I'm also planning on writing about stuff where I feel like I don't have a good
enough solution and would like to get feedback from others.

## Context

This website is backed by Github Pages.
[This repo](https://github.com/dvoros/dvoros.github.io)
holds all the source code and builds a static [Hugo](https://gohugo.io) website
automatically on every push.

I have an Nginx webserver hosted on a VPS (I'm not going to mention the
cloud provider this time to avoid looking like paid content 🙂) that takes care
of upgrading connections to HTTPS and proxies every request towards the Github
Pages site.

{{< container-image path="images/dvoros-com-without-comments.png" width=70% >}}

## Problem

With Hugo, it seems to be quite easy to use
[Disqus](https://disqus.com/)
as your commenting engine and it is the default that most Hugo templates
(including
[the one I'm using](https://github.com/monkeyWzr/hugo-theme-cactus))
are shipped with.

I didn't want to use Disqus though, as:
- their free tier has ads
- it isn't open-source

So I had to come up with something that checks these boxes and isn't much more
complicated to include in a Hugo site than Disqus.

## Solution

There's
[this list](https://gohugo.io/content-management/comments/#comments-alternatives)
of alternative commenting engines for Hugo. After a quick look
at some of them, I've decided to use
[Isso](https://posativ.org/isso/). It's a Python server that you need to host
yourself and a JS client that you need to include in your site.

Their
[quickstart guide](https://posativ.org/isso/docs/quickstart/)
is quite good and I've also found more
[detailed tutorials](https://stiobhart.net/2017-02-24-isso-comments/)
on the subject but none that ran Isso in Docker, even though it's listed under
the possible
[installation methods](https://posativ.org/isso/docs/install/#build-a-docker-image).
I like to run everything I can in Docker to avoid polluting my VPS with the
dependencies of everything I host.

### Docker image

I've found a very simple Docker image that seemed to be working well:
[machies/isso](https://hub.docker.com/r/machines/isso)

The only problem is that it has no tags other than `latest`. I needed a
reproducible solution so I've decided to tag `machies/isso:latest` as my own:
[`dvoros/isso:v1`](https://hub.docker.com/layers/dvoros/isso/v1/images/sha256-97d719ed64c0c27461b5c667a4bae0ad66cd6abae677d7d2f91c0ba3f5dbb095?context=repo)

{{< hint info >}}
**Why avoid the `latest` tag?**  
`latest` implies that it is subject to change. It just isn't intended to be
used in production (yes, I treat this blog as production 🙂).
[This post](https://vsupalov.com/docker-latest-tag/)
has a lot more background on the subject.
{{< /hint >}}

### Docker configuration

You need to give your Isso server configuration to the Docker image and
provide a volume to persist the comments. Here's what I did:

```sh
# Create the config and db folders
mkdir -p /mnt/data/dvoros-com-isso/{config,db}

# Initialize config
cat << EOF > /mnt/data/dvoros-com-isso/config/isso.conf
[general]
dbpath = /db/comments.db
host = https://dvoros.com/
[server]
listen = http://0.0.0.0:8080/
[guard]
enabled = true
ratelimit = 2
direct-reply = 3
reply-to-self = false
require-author = true
require-email = true
EOF
```

Then I could launch the Isso server with:

```sh
docker run -d --name isso \
    -p 127.0.0.1:37758:8080
    -v /mnt/data/dvoros-com-isso/config:/config \
    -v /mnt/data/dvoros-com-isso/db:/db \
    --restart always \
    dvoros/isso:v1
```

This leaves me with the Isso **server** running on port 377758 (a random
port) only accessible from localhost.

### Nginx configuration

To be able to access the Isso server from the outside world (this serves the
client JS code and is also called by the client) I had to set up a subdomain
that is forwarded to the Isso server by Nginx.

{{< container-image path="images/dvoros-com-with-comments.png" width=80% >}}

The Nginx configuration for this subdomain:

```nginx
server {
        server_name comments.dvoros.com;

        location / {
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-Proto https;
                proxy_set_header Host  $http_host;
                proxy_pass   http://127.0.0.1:37758/;
        }

        listen [::]:443 ssl;
        listen 443 ssl;
        
        # SSL configs cropped from here...
}
```

{{< hint info >}}
**Things that I didn't do**  
This method relies on having a **TLS certificate** and a **DNS record** for the
subdomain. Luckily enough, I've already had a
[wildcard Let's Encrypt certficate](https://community.letsencrypt.org/t/acme-v2-production-environment-wildcards/55578)
and a
[wildcard DNS record](https://en.wikipedia.org/wiki/Wildcard_DNS_record)
in place, so serving a new subdomain really only required extending the Nginx
configuration.
{{< /hint >}}

### Client code

With the server up and running on `comments.dvoros.com`, all I had to do was to
include the client at the bottom of every post page. This theme allows embedding
comments so I only had to extend that to work with Isso:

```html
{{ if (eq .Site.Params.Comments.Engine "isso") }}
<div class="blog-post-comments">
    <script data-isso="//comments.dvoros.com/"
    data-isso-reply-to-self="false"
    data-isso-require-author="true"
    data-isso-require-email="true"
    src="//comments.dvoros.com/js/embed.min.js"></script>

    <section id="isso-thread"></section>
</div>
{{ end }}
```

([here's the full change](https://github.com/dvoros/dvoros.github.io/commit/0c9a0bd44b2cfd59887040cf08c65d793794760f))

## Conclusion

Now I have a working commenting engine, so you can share your thoughts below!

It might not hold up against malicious bots flooding the site with comments and
administering comments is tricky (need to use `sqlite` CLI
as I didn't want to enable the admin UI for Isso), but I think it should be
sufficient for now.