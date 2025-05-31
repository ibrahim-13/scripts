function installdmg {
    tempd=$(mktemp -d)
    curl $1 > "$tempd"/pkg.dmg
    listing=$(hdiutil attach "$tempd"/pkg.dmg -nobrowse | grep Volumes)
    volume=$(echo "$listing" | cut -f 3)
    if [ -e "$volume"/*.app ]; then
      cp -rf "$volume"/*.app /Applications
    elif [ -e "$volume"/*.pkg ]; then
      package=$(ls -1 "$volume" | grep .pkg | head -1)
      installer -pkg "$volume"/"$package" -target /
    fi
    hdiutil detach "$volume"
    rm -rf "$tempd"
}
