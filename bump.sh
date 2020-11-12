

filesToChange=(
    version
    README.md
    mx.sh
    install.sh
)

current=$(cat version)
echo $current $1
for file in "${filesToChange[@]}"; do
    echo "$file updated"
    awk -v srch="$current" -v repl="$1" '{sub(srch, repl)}1' ${file} > temp.txt && mv temp.txt ${file}
done
