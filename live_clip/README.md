# LiveClip

## Building a release

- `MIX_ENV=prod mix compile` (needs to be run for phoenix_colocated hooks)
- then `MIX_ENV=prod mix assets.deploy`
- and `MIX_ENV=prod mix release`

## Releasing to GitHub
- if the file is bigger than 25MB the browser client will complain
- can use github cli instead, `gh release upload v<version> _build/prod/live_clip-<version>.tar.gz` (after creating a release)

## Running

Get release archive from GitHub 
- <https://github.com/myown-build/live-clip/releases/tag/v0.0.1)>

- `wget <url>`
- `tar -xvf <file>`

- set environment variables
- `bin/live_clip daemon` <https://kaiwern.com/posts/2020/07/20/deploying-elixir/phoenix-release-to-production/>


### Environment variables

- `export SECRET_KEY_BASE=<secret key>`
- `export SUPABASE_URL=<url>`
- `export SUPABASE_KEY=<publishable key>`

### Certbot
- install and run certbot to create certificate files (fullchain.pem and privkey.pem)

## Releasing
- `MIX_ENV=prod mix release`

