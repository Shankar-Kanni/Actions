if [ -n "$1" ]; then
    case "$1" in
        "minor")
            VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
                        # Assuming the current version is x.y.z
                        IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
                        MINOR=${VERSION_PARTS[1]}
                        MINOR=$((MINOR + 1))  # Increment PATCH version
                        NEW_VERSION="${VERSION_PARTS[0]}.$MINOR.0"

                        echo "New Version: $NEW_VERSION"
                        mvn versions:set -DnewVersion=$NEW_VERSION
            ;;
        "major")
            VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
                        # Assuming the current version is x.y.z
                        IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
                        MAJOR=${VERSION_PARTS[0]}
                        MAJOR=$((MAJOR + 1))  # Increment PATCH version
                        NEW_VERSION="${MAJOR}.0.0"

                        echo "New Version: $NEW_VERSION"
                        mvn versions:set -DnewVersion=$NEW_VERSION
            ;;
    esac
else
        VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
        # Assuming the current version is x.y.z
        IFS='.' read -r -a VERSION_PARTS <<< "$VERSION"
        PATCH=${VERSION_PARTS[2]}
        PATCH=$((PATCH + 1))  # Increment PATCH version
        NEW_VERSION="${VERSION_PARTS[0]}.${VERSION_PARTS[1]}.$PATCH"

        echo "New Version: $NEW_VERSION"
        mvn versions:set -DnewVersion=$NEW_VERSION
fi
