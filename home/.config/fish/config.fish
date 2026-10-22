# base setup lives in conf.d/maia.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end
export PATH="$HOME/.local/bin:$PATH"

# Prompt
if type -q starship
    starship init fish | source
end
