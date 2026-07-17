#!/bin/sh

exec /usr/bin/security find-generic-password \
  -a "$USER" \
  -s "office-infrastructure-ansible-vault" \
  -w
