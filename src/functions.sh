#!/bin/bash
#
# This script has basic functions like a random password generator
LXC_RANDOMPWD=32

random_password() {
    set +o pipefail
    LC_CTYPE=C tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c${LXC_RANDOMPWD}
}

generate_dhparam() {
    openssl dhparam -out /etc/nginx/dhparam.pem 2048
    cat << EOF > /etc/cron.monthly/generate-dhparams
#!/bin/bash
openssl dhparam -out /etc/nginx/dhparam.gen 4096 > /dev/null 2>&1
mv /etc/nginx/dhparam.gen /etc/nginx/dhparam.pem
systemctl restart nginx
EOF
    chmod +x /etc/cron.monthly/generate-dhparams
}

apt_repo() {
    apt_name=$1
    apt_key_url=$2
    apt_key_path=/usr/share/keyrings/${apt_name}.gpg
    apt_repo_url=$3

    wget -q -O - ${apt_key_url} | gpg --dearmor -o ${apt_key_path}
    echo "deb [signed-by=${apt_key_path}] ${apt_repo_url}" > /etc/apt/sources.list.d/${apt_name}.list

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

add_line_under_section_to_conf() {
    local conf_file="$1"
    local match_section="$2"
    local add_line="$3"
    local temp_file="$(mktemp)"

    # Check if the line already exists
    if grep -qF -- "$add_line" "$conf_file"; then
        echo "Line already exists in $conf_file."
        return
    fi

    # Use awk to add the line under the [global] section
    awk -v section="$match_section" -v newline="$add_line" '
    $0 == section {print; print newline; next}
    {print}
    ' "$conf_file" > "$temp_file"

    # Replace the original file with the modified file
    mv "$temp_file" "$conf_file"
    echo "Updated $conf_file"
}

set_conf_variable() {
  local file_path=$1
  local variable_name=$2
  local new_value=$3
  sed -i "s/^\($variable_name\s*=\s*\).*\$/\1$new_value/" "$file_path"
}

function push_to_container() {
    local lxc_id=$1
    local source_files=$2
    local destination=$3
    local script_dir=$PWD

    # Create a temporary tar file
    local tmp_tar="temp_$(date +%s).tar.gz"
    
    # Change to the directory and create tar from there to handle wildcards
    local source_dir=$(dirname "$source_files")
    local source_pattern=$(basename "$source_files")
    
    # Create tar file of the specified files
    #(cd "$source_dir" && eval "tar -czf \"../$tmp_tar\" $source_pattern")
    echo "$source_dir"
    echo "../../$tmp_tar"
    echo "$source_pattern"
    (cd "$source_dir" && tar -cvzf $script_dir/$tmp_tar $source_pattern)

    echo "Push the tar file to the specified container and destination"
    # pct push "$lxc_id" "$tmp_tar" "$destination/$(basename "$tmp_tar")" && echo "==== push success ==="
    pct push $lxc_id $script_dir/$tmp_tar $destination/$tmp_tar && echo "==== push success ==="

    echo "tar -xzf \"$destination/$tmp_tar\" -C \"$destination\" && rm \"$destination/$tmp_tar\""
    # Enter the container, extract the tar file, and remove the tar file
    pct exec "$lxc_id" -- bash -c "tar -xzf \"$destination/$tmp_tar\" -C \"$destination\" && rm \"$destination/$tmp_tar\""

    # Remove the local temporary tar file
    rm "$tmp_tar"
}
