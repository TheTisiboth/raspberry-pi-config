# Persistent journal

Raspberry Pi OS keeps the systemd journal in RAM (`Storage=volatile`). After
an unclean restart there is nothing left to say why it happened. Between
2026-09-16 and 2026-10-29 the Pi hung and was reset by the hardware watchdog
8 times (`rootfs: recovering journal` in `/var/log/boot.log*`), with no logs.

`50-persistent.conf` keeps the journal on disk, capped at 200M, synced every
30s.

## Install

```sh
sudo install -D -m 644 50-persistent.conf /etc/systemd/journald.conf.d/50-persistent.conf
sudo systemctl restart systemd-journald
sudo journalctl --flush   # move the running journal from /run to disk now
```

## After a crash

```sh
journalctl --list-boots
journalctl -b -1 -e                      # end of the previous boot
journalctl -b -1 -k | grep -iE 'oom|hung|watchdog'
```
