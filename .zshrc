export PATH="$HOME/.local/bin:$PATH"

# Rust (managed by brew-installed rustup)
export PATH="$(rustup which rustc 2>/dev/null | xargs dirname 2>/dev/null):$PATH"
