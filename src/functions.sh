#!/bin/bash
#
# This script has basic functions like a random password generator
LXC_RANDOMPWD=32

random_password() {
    set +o pipefail
    C_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c${LXC_RANDOMPWD}
}

convert_domain_to_ldap_format() {
    local domain=$1

    # Split the domain into parts based on the dot separator
    IFS='.' read -ra ADDR <<< "$domain"

    # Initialize an empty string for the LDAP format
    local ldap_format=""

    # Loop through the parts and append them in LDAP format
    for i in "${ADDR[@]}"; do
        # Append each part in 'dc=part' format
        ldap_format+="dc=$i,"
    done

    # Remove the trailing comma
    ldap_format=${ldap_format%,}

    echo "$ldap_format"
}