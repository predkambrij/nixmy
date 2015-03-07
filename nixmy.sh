#!/bin/sh

# !!!MODIFY NEXT 3 LINES BEFORE RUNNING ANY COMMANDS!!!
export NIX_MY_PKGS='/home/lojze/newhacks/nnixmy/pkgs/nixpkgs'  # where the local repo will be after nixmy-init (note, put /nixpkgs at the end - it will be created by git clone)
#export NIX_USER_PROFILE_DIR='/nix/var/nix/profiles/per-user/lojze'  # change your user name
export NIX_USER_PROFILE_DIR='/nix/var/nix/profiles/per-user/loj'  # change your user name
export NIX_MY_GITHUB='https://github.com/predkambrij/nixpkgs.git'  # your nixpkgs git repository
export NIX_MY_LOGDIR='/home/lojze/newhacks/nixmy_logs'  # don't put "/" at the end
export NIX_MY_CUR_CHAN_REV='cur_channel_rev'  # name of the file where current channel revision will be saved (used for logging in nixmy-rebuild)


# after running nixmy-init you will have nixpkgs directory in current working directory
#
# BRANCHES:
#   local - where you will do your work and modifications
#           this is also where you want to be where nixmy-rebuild is called
#   master - this is where master branch of git://github.com/NixOS/nixpkgs.git is
#
# REMOTES:
#   origin - $NIX_MY_GITHUB
#   upstream - official repository git://github.com/NixOS/nixpkgs.git

# before running nixmy-update make sure that you commit or stash changes
# running nixmy-update will rebase from NixOS/nixpkgs to master and then checkout local branch back

# every now and then you can update your $NIX_MY_GITHUB repository by pushing to it:
# ex:
#    git checkout master
#    git push origin master
# do not forget to checkout local branch after as this is your work branch


export NIX_PATH="nixpkgs=$NIX_MY_PKGS:nixos=$NIX_MY_PKGS/nixos:nixos-config=/etc/nixos/configuration.nix:services=/etc/nixos/services"

# alias nixmy-profile="nix-env -f '$NIX_MY_PKGS' -p $NIX_USER_PROFILE_DIR/"
alias nixmy-py27="nix-env -f '$NIX_MY_PKGS' -p $NIX_USER_PROFILE_DIR/py27 -i py27"

alias nixmy-robotenv="nix-env -f '$NIX_MY_PKGS' -p $NIX_USER_PROFILE_DIR/robotenv -i robotenv"
alias nixmy-makeenv="nix-env -f '$NIX_MY_PKGS' -p $NIX_USER_PROFILE_DIR/makeenv -i makeenv"

alias nixmy-cd="cd '$NIX_MY_PKGS'"

alias nix-env="nix-env -f $NIX_MY_PKGS"

# Sudo helper
_asroot() {
  case `whoami` in
    root)
      echo "" ;;
    *)
      echo "sudo -H " ;;
  esac
}

nixmy-profile() {
    nix-env -f "$NIX_MY_PKGS" -p $NIX_USER_PROFILE_DIR/"$1" -i "$1" ;
}

nixmy-rebuild() {
    `_asroot` nixos-rebuild -I $NIX_MY_PKGS "$@";
    if [ $? -eq 0 ]; then
        cur_dir=$(pwd)
        cur_channel_rev_loc="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$NIX_MY_CUR_CHAN_REV"
        cd $cur_dir # go back where we started
        cur_channel_rev=$(cat $cur_channel_rev_loc)
        echo "$(date) rebuild with channel rev:"$"$cur_channel_rev" >> $NIX_MY_LOGDIR"/nixmy-rebuild.log"
    fi
}

# Print latest Hydra's revision
nixmy-revision() {
  local rev=`wget -q  -S --output-document - http://nixos.org/channels/nixos-14.12/ 2>&1 | grep Location | awk -F '/' '{print $7}' | awk -F '.' '{print $4}'`
  #local rev=`wget -q  -S --output-document - http://nixos.org/channels/nixos-unstable/ 2>&1 | grep Location | awk -F '/' '{print $6}' | awk -F '.' '{print $3}'`
  printf "%s" $rev
}

nixmy-update() {
    cd $NIX_MY_PKGS

    local diffoutput="`git --no-pager diff`"
    if [ -z $diffoutput ]; then
        {
            echo "git diff is empty, preceding ..." &&
            #git checkout master &&
            #git pull --rebase upstream master &&
            git fetch --all &&
            
            git checkout "local" &&
            #local rev=`nixmy-revision` &&
            #echo "rebasing 'local' to '$rev'" &&

            git rebase remotes/upstream/release-14.12 &&
            if [ $? -eq 0 ]; then
                # save last channel revision which will be used in track nixmy-rebuild
                cur_dir=$(pwd)
                cur_channel_rev_loc="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/$NIX_MY_CUR_CHAN_REV"
                cd $cur_dir # go back where we started
                echo $rev > $cur_channel_rev_loc 
                echo "$(date) local rebased to $rev" >> $NIX_MY_LOGDIR"/nixmy-update.log"
            fi
            echo "UPDATE done, enjoy!"
        } || {
            echo "ERROR with update!"
            return 1
        }
    else
        git status
        echo "STAGE IS NOT CLEAN! CLEAR IT BEFORE UPDATE!"
        return 1
    fi

}

nixmy-init() {
    {
        cd $(dirname $NIX_MY_PKGS) # go one directory back to root of destination (/nixpkgs will be created by git clone)
        git clone $NIX_MY_GITHUB nixpkgs &&
        cd nixpkgs &&
        git remote add upstream git://github.com/NixOS/nixpkgs.git &&
        git pull --rebase upstream master &&
        local rev=`nixmy-revision` &&
        echo "creating local branch of unstable channel '$rev'" &&
        git branch "local" $rev &&
        git checkout "local" &&
        echo "INIT done! You can update with nixmy-update and rebuild with nixmy-rebuild eg: nixmy-rebuild build"
    } || {
        echo "ERROR with init!"
        return 1
    }
}
