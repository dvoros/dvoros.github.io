---
title: "On-demand VPN"
date: 2021-09-23T16:51:25+02:00
tags:
- vpn
- discord
- openvpn
categories:
- notes
draft: false
---

For about a month now I've been travelling abroad and been surviving on
dodgy public Wi-Fis and networks operated by my Airbnb hosts. Under
such circumstances I prefer tunneling all my traffic through VPN to
avoid eavesdropping.

For a long time I've had an always-on beefy VPS with OpenVPN running so this
wasn't an issue. However, a while back I've decided to save some money
by scaling it down to a very small instance and running bigger workloads
(VPN included) on ephemeral instances.

In this post I'll describe how I ended up with an on-demand personal VPN
controlled by a Discord bot.

## The experience

Whenever I need a VPN connection I have to hop on Discord and message a
bot running on my Discord server:

{{< container-image path="images/vpn-discord-start.png" width=80% >}}

It immediately acknowledges the request with the `working on it` response
and then replies within a few minutes with `VPN started` once the VPN is
ready. It even adds a little check mark to your request, lovely!

I can also check the current status and list connected users via Discord:

{{< container-image path="images/vpn-discord-status-list.png" width=80% >}}

Output is a little cryptic but it has the IP address of the connected
hosts which is usually what I'm interested in.

How to shut down the VPN once I'm done with it? If you've guessed I
need to message `vpn-stop`, you're smart but wrong. Do you really believe
I would remember to do that? The instance is paid by the minute so it
is terminated once no one is using it! (Do you think I remember to
disconnect from the VPN once I don't need it anymore? 🤔)

{{< hint info >}}
**Why is it called `mc-bot`?**

This bot started off as a way to spin up/down my Minecraft server, but then
VPN proved to be more important so I've implemented that first. 🙂
{{< /hint >}}

## How does it work?

When you message the bot, Discord will notify a Go service backing the bot
running on the always-on server. This service is capable of spinning up a
new
[Scaleway compute](https://www.scaleway.com/en/docs/compute/)
instance to launch the VPN and then ask for its status later.

{{< container-image path="images/on-demand-vpn-architecture.png" width=80% >}}

A `cron` job is configured to run every minute to check if there are users
connected to the VPN. If no one used the VPN for 5 minutes, it will terminate
the instance.

Now let's see these components in a little more detail.

### The Discord bot

The Discord bot is backed by a Go service that's running on the always-on
instance. You can find its source code
[here](https://github.com/dvoros/scw-bot).

It relies on a 3rd party Go library
([`github.com/bwmarrin/discordgo`](https://github.com/bwmarrin/discordgo))
to handle the connection to the Discord servers. It receives every request on
every channel where the bot is added and also private messages. On seeing
certain keywords associated with its commands, it executes custom functions.
For most commands it executes shell scripts where the infrastrucure operations
are handled. For example:

```go
func VpnStatusCallback(s *discordgo.Session, m *discordgo.MessageCreate) {
	out, err := exec.Command("/bin/bash", "/root/scw-automation/bin/scw-vpn-status.sh").CombinedOutput()
	if err != nil {
		s.ChannelMessageSend(m.ChannelID, fmt.Sprintf("❌ %s", strings.TrimSpace(string(out))))
		return
	}
	s.ChannelMessageSend(m.ChannelID, fmt.Sprintf("✅ %s", strings.TrimSpace(string(out))))
}
```

### Scaleway automation

The infrastructure operations the bot is doing (starting, monitoring the
instances) are written as shell scripts. In hindsight, they could have been
implemented in Go, but I had them lying around before I've made the Discord
bot in Go.

These scripts rely on the
[Scaleway CLI](https://www.scaleway.com/en/cli/)
to interact with the instances. Starting a new instance is this simple:

```bash
scw instance server create type=DEV1-S zone=fr-par-1 image=ubuntu_focal root-volume=l:20G  name=vpn -o template="{{ .ID }}"
```

SSH public keys of the always-on instance are automatically added to every
new instance, so all scripts can SSH to the running instances.

### OpenVPN

For installing OpenVPN, I'm relying on this project:
https://github.com/angristan/openvpn-install

If I need to add/remove users or modify any OpenVPN configuration, I can
manually SSH into the running instance and execute the `openvpn-install.sh`
script again to do so. To persist the configuration, I download it from the
instance to the location where it will be copied from to any new instances:

```bash
# Prepare config tgz on VPN server
cat << EOF | ssh -q -o BatchMode=yes -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" vpn.asdasd.hu 'bash -'
        rm -f /tmp/openvpn-conf.tar.gz
        tar -czf /tmp/openvpn-conf.tar.gz /etc/openvpn
EOF

# Backup old config
mv $OWN_DIR/openvpn-conf.tar.gz $OWN_DIR/old-configs/openvpn-conf-`date +%Y-%m-%dT%H-%M`.tar.gz

# Save new
scp -o "StrictHostKeyChecking=no" vpn.asdasd.hu:/tmp/openvpn-conf.tar.gz $OWN_DIR/
```

### Termination

As mentioned above, I'd like to avoid forgetting to terminate the VPN
instance, so I have a `cron` job in place that terminates the instance once no
one's using it anymore:

```bash
PREV_INACTIVE=`cat /tmp/vpn-inactive-since`

CONN_COUNT=`$OWN_DIR/bin/scw-vpn-connection-count.sh`
if [ ! $? -eq 0 ]; then
        echo "unable to connect to VPN, probably not running"
        exit 3
fi
if [ $CONN_COUNT -eq 0 ]; then
        let PREV_INACTIVE=$PREV_INACTIVE+1
else
        let PREV_INACTIVE=0
fi

if [ $PREV_INACTIVE -ge 5 ]; then
        $OWN_DIR/bin/scw-vpn-terminate.sh
fi

echo $PREV_INACTIVE > /tmp/vpn-inactive-since
```

The connection count was ugly enough to put into its own file:

```bash
cat << EOF | ssh -q -o BatchMode=yes -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" vpn.asdasd.hu 'bash -'
        { echo "load-stats"; sleep 1; } | telnet localhost 7505 2>/dev/null | grep SUCCESS | sed -E 's/^.*nclients=([0-9]+),.*$/\1/'
EOF
```


## Should you do this?

Probably not. It's a lot easier to just buy the VPN service. I had a pleasant
experience with
[NordVPN](https://nordvpn.com/)
earlier and it has the added benefit of being able
to select from a great variety of host countries to get around
[geo-blocking](https://en.wikipedia.org/wiki/Geo-blocking).
There are two downsides. One is the price, but with intensive use it's
comparable to hosting your own. The other is the question of trust and
privacy, but
[NordVPN seems to be delivering on that front](https://www.troyhunt.com/im-partnering-with-nord-as-a-strategic-adviser/).