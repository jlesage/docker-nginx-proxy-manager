#!/bin/sh

usage() {
    echo "usage: $(basename "$0") USER_EMAIL [PASSWORD]

Reset password of a Nginx Proxy Manager user.

Arguments:
  USER_EMAIL      Email address of the user to reset the password.
  PASSWORD        Optional new password of the user.  If not set, password
                  is set to 'changeme'.
"
    exit 1
}

USER_EMAIL="$1"
if [ -z "$USER_EMAIL" ]; then
    echo "ERROR: User email address must be set."
    usage
fi
PASSWORD_HASH="$(/usr/bin/bcrypt-tool hash "${2:-changeme}" 13)"

/usr/bin/mysql --execute "UPDATE user,auth SET auth.secret = '$PASSWORD_HASH' WHERE user.id = auth.user_id and user.email = '$USER_EMAIL'" nginxproxymanager
