input=/app/helm-charts.yaml
output=/templates/%s/%s/
outputfile=/templates/%s/%s/%s.yaml
repositories=$(yq '.[].repository' $input)
echo "Templating ..."
for repository in ${repositories}; do
    name=$(yq -o json $input | jq -rc --arg repository $repository '.[] | select(.repository == $repository) | .name')
    entries=$(yq -o json $input | jq -rc --arg repository $repository '.[] | select(.repository == $repository) | .entries[]')
    printf '  - %s\n' "$repository"

    yq -o json $input | jq -rc --arg repository $repository '.[] | select(.repository == $repository) | .valuesFile // ""' > /tmp/values
    for entry in ${entries}; do
        #shellcheck disable=SC2059
        mkdir -p "$(printf "$output" "$name" "$entry")" || true
        printf '    - %s\n' "$entry"
        version=$(helm show chart "$name/$entry" | yq .version)
        #shellcheck disable=SC2059
        file=$(printf "$outputfile" "$name" "$entry" "$version")
        helm template --include-crds "$name" "$name/$entry" -f /tmp/values --version "$version" | yq 'select(.kind == "CustomResourceDefinition")' > "$file"
        groups=$(yq .spec.group < $file | grep -v '\---' | grep -v null | uniq)

        known=1
        for group in ${groups}; do
            if [ ! -d /schema/$group ]; then
                known=0
                echo "      - $group is unknown -> render all versions"
            fi
        done
        if [ $known -eq 1 ]; then
            printf '      - version %s\n' "$version"
            continue
        fi

        rm "$file"
        versions=$(helm search repo "$name" --versions -o json | jq -rc  --arg name "$name/$entry" '[.[] | select(.name == $name)] | reverse | .[].version')
        for version in ${versions}; do
            printf '      - version %s\n' "$version"
            #shellcheck disable=SC2059
            file=$(printf "$outputfile" "$name" "$entry" "$version")
            helm template --include-crds "$name" "$name/$entry" -f /tmp/values --version "$version" | yq 'select(.kind == "CustomResourceDefinition")' > "$file"
        done
    done
done
echo
