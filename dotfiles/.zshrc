# Sample .zshrc configuration
# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load
ZSH_THEME="powerlevel10k/powerlevel10k"

# Which plugins would you like to load?
plugins=(
    git
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    autojump
    thefuck
)

source $ZSH/oh-my-zsh.sh

# User configuration
export LANG=en_US.UTF-8
export EDITOR='nvim'

# Aliases
alias ll='eza -la --icons'
alias la='eza -a --icons'
alias ls='eza --icons'
alias tree='eza --tree --icons'
alias cat='batcat'
alias vim='nvim'
alias vi='nvim'

# Add Cargo to PATH if it exists
if [ -d "$HOME/.cargo/bin" ]; then
    export PATH="$HOME/.cargo/bin:$PATH"
fi

# Add Neovim to PATH if it exists
if [ -d "/opt/neovim/bin" ]; then
    export PATH="$PATH:/opt/neovim/bin"
fi

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
