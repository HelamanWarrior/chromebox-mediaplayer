# ChromeBox Media Player

A minimal cast-only, high-quality media client. Designed for an elegant media experience, in a world filled with ads.

- Casting remote jellyfin playback via `jellyfin-mpv-shim`
- Local dvd/bluray playback

- jellyfin-mpv-shim
- hyprland

## Configuration

`inventory/group_vars/main.yml`

```
ansible-vault encrypt_string 'supersecretpassword' --name ansible_become_password
Encryption successful
ansible_become_password: !vault |
          $ANSIBLE_VAULT;1.1;AES256
          37383936346631306339623565366339393165353564346236373435316431633739656538313130
          6662366565643832343364636166626137643736373737320a353136336363393138393036333732
          34323133373935613065303239306661623530643235363839323033626438353862303265656362
          3234303536656562340a383064353863363235663064343530663839366365643762323732353639
          61306364376438333731343066613534626434313165643330336530653336313763
```
