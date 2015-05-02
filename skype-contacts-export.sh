#!/bin/bash

contacts_list_file=~/.local/share/kupfer/plugins/skype-contacts.list

usage()
{
cat << EOF
usage: $0 [OPTIONS] [SKYPE_DB_FILE]
If SKYPE_DB_FILE is omitted, it will be searched for in default locations
OPTIONS:
  -h            Show this message
  -g <groups>   Only export contacts from those groups
                  <groups> is comma-separated list of groups
  -b            Also export bookmarked chats
EOF
}

#ask function is taken from here: https://gist.github.com/davejamesmiller/1965569
ask() {
    # http://djm.me/ask
    while true; do
 
        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi
 
        # Ask the question - use /dev/tty in case stdin is redirected from somewhere else
        read -p "$1 [$prompt] " REPLY </dev/tty
 
        # Default?
        if [ -z "$REPLY" ]; then
            REPLY=$default
        fi
 
        # Check if the reply is valid
        case "$REPLY" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac
 
    done
}

run_query() {
  sqlite3 "file://$SKYPE_DB_FILE" "$1"
  if [ "$?" -ne "0" ]; then
    echo "Error running sqlite"
    exit 1
  fi
}

groups_list=""
bookmarked=""

while getopts ":g:bh" OPTION
  do
    case "$OPTION" in
      "h")
        usage
        exit 1
        ;;
      "g")
        groups_list=$OPTARG
        ;;
      "b")
        bookmarked="yes"
        ;;
      "?")
        echo "Unknown option '$OPTARG'"
        exit 1;
        ;;
      ":")
        echo "'$OPTARG' option requires an argument"
        exit 1;
        ;;
      *)
        echo "Unknown error while processing options"
        exit 1;
        ;;
    esac
  done

shift $(($OPTIND - 1))

SKYPE_DB_FILE=$1

if [ -z "$SKYPE_DB_FILE" ]; then
  found=$(find ~/.Skype/ -name main.db)
  foundCount=$(find ~/.Skype/ -name main.db | wc -l)
  if [ $foundCount == "1" ]; then 
    if ask "SKYPE_DB_FILE is not set. Do you want to use automatically found '$found'? " Y; then
      SKYPE_DB_FILE=$found
    else
      echo "SKYPE_DB_FILE is not set. Please set SKYPE_DB_FILE to be a path to your main skype db file. It's usually something like ~/.Skype/account.name/main.db"
      exit 1
    fi
  else
    echo "SKYPE_DB_FILE is not set and several main.db files found. Please set SKYPE_DB_FILE to be a path to your main skype db file."
    echo "Possible files: "
    find ~/.Skype/ -name main.db
    exit 1
  fi
fi

if [ ! -f "$SKYPE_DB_FILE" ]; then
  echo "Path to skype's db file '$SKYPE_DB_FILE' isn't correct."
  exit 1
fi

if [ -z `which sqlite3` ]; then
  echo "'sqlite3' isn't found. You need to install it to run this script"
  exit 1
fi

echo "Exporting $SKYPE_DB_FILE..."

if [ ! -z "$groups_list" ]; then
  groups_list=$(echo $groups_list | sed -r "s/\w+/'&'/g")
  query="
    SELECT members
    FROM contactgroups
    WHERE given_displayname IN ($groups_list)
  "
  members=$(run_query "$query" | paste -s | sed "s/[[:alnum:][:punct:]]\+/'&'/g" | sed "s/[[:blank:]]\+/,/g")
  members_filter=" AND skypename IN ($members)"
fi

query="
  SELECT skypename,displayname
  FROM contacts
  WHERE revoked_auth IS NULL AND is_permanent = 1 $members_filter
"

run_query "$query" > "$contacts_list_file"

if [ ! -z "$bookmarked" ]; then
  query="
    SELECT GROUP_CONCAT(p.identity, ';'), c.displayname
    FROM conversations c JOIN participants p ON c.id=p.convo_id AND p.last_leavereason IS NULL
    WHERE type=2 AND is_bookmarked=1
    GROUP BY c.id
  "
  run_query "$query" >> "$contacts_list_file"
fi
