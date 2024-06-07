#!/bin/bash

base_dir="bugcrowd_recon_$(date +%Y-%m-%d-%T)"
mkdir -p "$base_dir" # Ensure the base directory exists
mkdir -p "$base_dir/engagements"
find "$base_dir" -type f -delete
total_pages=$(curl -s 'https://bugcrowd.com/engagements.json?category=bug_bounty&sort_by=promoted&sort_direction=desc&page=1' -H "cookie: _bugcrowd_session=$1" --compressed | jq '.paginationMeta.limit')

for ((i=1; i<=total_pages; i++)); do
    echo "Processing page $i of $total_pages"
    curl -s "https://bugcrowd.com/engagements.json?category=bug_bounty&page=$i&sort_by=promoted&sort_direction=desc" -H "cookie: _bugcrowd_session=$1" --compressed |
    jq -r '.engagements[].briefUrl' |
    while IFS= read -r code; do
        echo "Processing code: $code"
        program_dir="$base_dir/$code"
        mkdir -p "$program_dir"
        file_path="$program_dir/$code.txt"
        echo "Codename: $code" > "$file_path"
        
        curl -s "https://bugcrowd.com/$code/target_groups" -H "cookie: _bugcrowd_session=$1" --compressed |
        jq -r '.groups[] | .targets_url' |
        while IFS= read -r scope; do
            echo "Fetching scope for $scope"
            scope_name=$(basename "$scope")
            scope_file="$program_dir/$scope_name.txt"
            curl -s "https://bugcrowd.com/$scope" -H "cookie: _bugcrowd_session=$1" --compressed |
            jq -r '.targets[] | .name, .uri' |
            grep -v -E "(github\.com|play\.google\.com|apps\.apple\.com)" >> "$scope_file"
        done
        echo "Fetched URLs saved under $program_dir"
    done
done

echo "All program codes and URLs have been processed."

# Files for storing results
fqdn_file="$base_dir/unique_fqdns.txt"
wildcard_domains_file="$base_dir/unique_wildcard_domains.txt"

temp_fqdn="$base_dir/temp_fqdn.txt"
temp_wildcard="$base_dir/temp_wildcard.txt"

> "$temp_fqdn"
> "$temp_wildcard"

find "$base_dir" -type f -name "*.txt" | while read -r file; do
    grep -E '^[^*]' "$file" >> "$temp_fqdn"
    grep -E '^\*\.' "$file" >> "$temp_wildcard"
done

# Final deduplication and sorting
sort -u "$temp_fqdn" | grep -v ' ' > "$fqdn_file"
sort -u "$temp_wildcard" > "$wildcard_domains_file"

# Clean up temporary files
rm "$temp_fqdn" "$temp_wildcard"

echo "Processing complete. Unique FQDNs are in $fqdn_file and unique wildcard domains are in $wildcard_domains_file."
