#!/bin/bash

base_dir="bugcrowd_recon"
mkdir -p "$base_dir" # Ensure the base directory exists

find "$base_dir" -type f -delete
total_pages=$(curl -s 'https://bugcrowd.com/engagements.json?category=bug_bounty&sort_by=promoted&sort_direction=desc&page=1' -H "cookie: _crowdcontrol_session=$1" --compressed | jq '.paginationMeta.limit')

for ((i=1; i<=total_pages; i++)); do
    curl -s "https://bugcrowd.com/engagements.json?category=bug_bounty&sort_by=promoted&sort_direction=desc&page=$i" -H "cookie: _crowdcontrol_session=$1" --compressed |
    jq -r '.engagements[].briefUrl' |
    while IFS= read -r code; do
        # For each program code, fetch scope URLs
        echo "Fetching for $code"
        file_path="$base_dir/$code.txt"
        echo "Codename: $code" > "$file_path"
        curl -s "https://bugcrowd.com/$code/target_groups" -H "cookie: _crowdcontrol_session=$1" --compressed |
        jq -r '.groups[] | .targets_url' |
        while IFS= read -r scope; do
            # Fetch and filter detailed URLs and names for each scope
            curl -s "https://bugcrowd.com/$scope" -H "cookie: _crowdcontrol_session=$1" --compressed |
            jq -r '.targets[] | .name, .uri' |
            grep -v -E "(github\.com|play\.google\.com|apps\.apple\.com)" >> "$file_path"
        done
        echo "Fetched URLs saved under $file_path"
    done
done

echo "All program codes and URLs have been processed."

base_dir="bugcrowd_recon"

fqdn_file="unique_fqdns.txt"
wildcard_domains_file="unique_wildcard_domains.txt"

temp_fqdn="temp_fqdn.txt"
temp_wildcard="temp_wildcard.txt"

> "$temp_fqdn"
> "$temp_wildcard"

find "$base_dir" -type f | while read -r file; do
    # Extract FQDNs and wildcard domains, appending to temporary files
    grep -E '^[^*]' "$file" >> "$base_dir/$temp_fqdn"
    grep -E '^\*\.' "$file" >> "$base_dir/$temp_wildcard"
done

sort -u "$base_dir/$temp_fqdn" > "$base_dir/$fqdn_file"
sort -u "$base_dir/$temp_wildcard" > "$base_dir/$wildcard_domains_file"

rm "$base_dir/$temp_fqdn" "$base_dir/$temp_wildcard"

echo "Processing complete. Unique FQDNs are in $base_dir/$fqdn_file and unique wildcard domains are in $base_dir/$wildcard_domains_file."

