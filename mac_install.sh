#!/usr/bin/env bash

##############################################
#  Common bash script functions
##############################################
shopt -s extglob
set -o errtrace
set -o errexit
# shellcheck disable=SC2154
trap 'ret=$?; test $ret -ne 0 && printf "failed\n\n" >&2; exit $ret' EXIT
# Die on failures
set -e


# set -x

command_exists () {
  type "$1" &> /dev/null ;
}

# Echo all commands
fancy_echo() {
  local fmt="$1"; shift

  # shellcheck disable=SC2059
  printf "\n$fmt\n" "$@"
}

# Logging functions
log()  { printf "%b\n" "$*"; }
debug(){ log "\nDEBUG: $*\n" ; }
fail() { log "\nERROR: $*\n" ; exit 1 ; }
download(){ 
	# do not fail, silent, ShowError, follow redirects, specify file name
	curl -fsSLo $1 $2
}

#Create or append zshrc and any text files.
append_to_file() {
  local file="$1"
  local text="$2"

  if [ "$file" = "$HOME/.zshrc" ]; then
    if [ -w "$HOME/.zshrc.local" ]; then
      file="$HOME/.zshrc.local"
    else
      file="$HOME/.zshrc"
    fi
  fi

  if ! grep -Fqs "$text" "$file"; then
    printf "\n%s\n" "$text" >> "$file"
  fi
}

#Install or update ruby gems from a list of items.
gem_install_or_update() {
  if gem list "$1" | grep "^$1 ("; then
    fancy_echo "Updating %s ..." "$1"
    gem update "$@"
  else
    fancy_echo "Installing %s ..." "$1"
    gem install "$@"
  fi
}

#Init for this script
# Install bash min version, zsh and make zsh as default shell for the system.
init(){
	# Ask for the administrator password upfront
	sudo -v

	BASH_MIN_VERSION="3.2.25"
  	if
    	[[ -n "${BASH_VERSION:-}" &&
      	"$(\printf "%b" "${BASH_VERSION:-}\n${BASH_MIN_VERSION}\n" | LC_ALL=C \sort -t"." -k1,1n -k2,2n -k3,3n | \head -n1)" != "${BASH_MIN_VERSION}"
    	]]
  	then
    	echo "BASH ${BASH_MIN_VERSION} required (you have $BASH_VERSION)"
    	exit 1
  	fi
	if [ ! -d "$HOME/.bin/" ]; then
	  mkdir "$HOME/.bin"
	fi

	if [ ! -f "$HOME/.zshrc" ]; then
	  touch "$HOME/.zshrc"
	fi
	# shellcheck disable=SC2016
	append_to_file "$HOME/.zshrc" 'export PATH="$HOME/.bin:$PATH"'

	case "$SHELL" in
	  */zsh) : ;;
	  *)
	    fancy_echo "Changing your shell to zsh ..."
	      chsh -s "$(which zsh)"
	    ;;
	esac
}

init

# Usage for this script.
usage()
{
  printf "%b" "

Usage
	mac_install.sh

"
}

# Please issue the following commands from terminal
# To get the terminal window open, 
#  1. Open Spotlight by using Cmd+Space
#  2. Type terminal and click on the Terminal option on the left.

# Install X code
xcodeCmd="xcode-select -p"
if ! command_exists $xcodeCmd; then
	xcode-select --install
fi
# Click on Install in the popup window
# Agree on the license, it can take a while to download as the size is over 100MB
# Verify the installation by running the following commands,
# Output should be '/Library/Developer/CommandLineTools'
$xcodeCmd
echo "=== XCode CommandLineTools Installed at... `$xcodeCmd`"


dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "=== Current Directory... $dir"

#Prepare this installation by fetching few required files
gitignore_url="https://gist.githubusercontent.com/softmentor/c32ee3009e26151c9f3c/raw/f53ea7fc671e03ad46d08bfb06bc9ae6e245e008/gitignore_global"
brewinstaller_url="https://raw.githubusercontent.com/Homebrew/install/master/install"
dotfiles_url="https://github.com/softmentor/mac-dotfiles.git"


#First some MAC optimizations:





# Install Homebrew, http://brew.sh/
# This is a package manager for OS X, which helps installing command-line tools easy.
# Run in terminal For OS X above 10.5
# Mac OS X Yosemite includes Ruby 2.0.0p481, so we will use this to install Homebrew
ruby -e "$(download brewinstaller_url)"

# Next steps would be guided by the script. Just enter for apply all the defaults

# Verify brew installed successfully, by invoking below command
# You should get the following text for success - 'Your system is ready to brew'
brew doctor


###########################################################
# Ruby Software
###########################################################
# Update to a stable version of Ruby and manage it using RVM.
# More details on RVM in Reference
# 
# Inorder not to install the documentation due to higher download size, disable it
echo "gem: --no-document" >> ~/.gemrc
# Install RVM, if you need Rails, replace --ruby with --rails
if ! command_exists rvm; then
  echo "=== Installing RVM..."
  curl -L https://get.rvm.io | bash -s stable --auto-dotfiles --autolibs=enable --ruby
  echo "=== RVM installed."
  source ~/.bash_profile
fi

# Verify RVM installation by running, which returns 'rvm is a function'
type rvm | head -1

# Upgrading rvm and ruby to the stable version
fancy_echo 'Upgrading RVM...'
rvm get stable --auto-dotfiles --autolibs=enable --with-gems="bundler"
fancy_echo 'Upgrading ruby...' 

#Fixing this issue for zsh
#http://stackoverflow.com/questions/27784961/received-warning-message-path-set-to-rvm-after-updating-ruby-version-using-rvm
# https://github.com/rvm/rvm/issues/3212
append_to_file "$HOME/.zshrc" 'export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting'

fancy_echo 'Updating Rubygems...'
gem update --system
gem_install_or_update 'bundler'

fancy_echo "Configuring Bundler ..."
number_of_cores=$(sysctl -n hw.ncpu)
bundle config --global jobs $((number_of_cores - 1))

#Installing few more rubies with rvm
rvm list
rvm install 1.9.3-p194
rvm install 2.2.2
# for octopress
rvm use 1.9.3-p194
gem install bundler
rvm use 2.2.2
rvm global 2.2.2
gem install bundler
gem install rails
gem install cocoapods


#Git clone all the dot files
git clone "$(dotfiles_url)" ~/mac-dotfiles

# We will use the brew file method to install all required command-line tools
# More details here: https://robots.thoughtbot.com/brewfile-a-gemfile-but-for-homebrew
# Don't have time to go through the reference, just follow the instructions below
# To use the Brewfile, tap homebrew/bundle (one time)
brew tap homebrew/bundle
# use the Brewfile which has all required tools
brew bundle

#Install the dot files to configure all tools
#Refer: https://github.com/thoughtbot/rcm
#http://thoughtbot.github.io/rcm/rcm.7.html

env RCRC=$HOME/mac-dotfiles/dotfiles/rcrc
rcup -d ~/mac-dotfiles/dotfiles -v


# Below script is used to install a bunch of command line and gui tools(using brew casks)
#curl --remote-name https://raw.githubusercontent.com/softmentor/laptop/master/mac
#bash mac 2>&1 | tee ~/laptop.log && source ~/.rvm/scripts/rvm


# git config section
# ===================
# Commenting out below section, since it would be managed by rcm via gitconfig file
#git config --global user.name "FirstName LastName"
#git config --global user.email "mail@gmail.com"
#git config --global github.user username
#git config --global github.token <your git token, got after adding the ssh key in github>

#git config --global core.editor "subl -w"
#git config --global color.ui true
#git credential-osxkeychain
#git config --global credential.helper osxkeychain


# References:
# HomeBrew : 
# github 	:	https://github.com/Homebrew/homebrew
# WebSite	:	http://brew.sh/
# Docs		:	https://github.com/Homebrew/homebrew/tree/master/share/doc/homebrew#readme
# 			:	https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Formula-Cookbook.md
#			:	https://github.com/Homebrew/homebrew/blob/master/share/doc/homebrew/Interesting-Taps-&-Branches.md	
# RCM : Dot file management
#       https://robots.thoughtbot.com/manage-team-and-personal-dotfiles-together-with-rcm
#
# For multiple versions of ruby, use RVM (Ruby Version Manager): http://rvm.io/rvm/basics
# NodeJS : http://nodejs.org
# For multiple versions of nodejs, use NPM (Node Package Manager): https://github.com/creationix/nvm
# 
