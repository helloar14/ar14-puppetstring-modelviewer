# First build ARM64 version...
echo "Building arm64 binary..."
dub build --build=release --config=osx-full --arch=arm64-apple-macos
mv "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer" "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-arm64"

# Then the X86_64 version...
echo "Building x86_64 binary..."
dub build --build=release --config=osx-full --arch=x86_64-apple-macos
mv "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer" "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-x86_64"

# Glue them together with lipo
echo "Gluing them together..."
lipo "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-x86_64" "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-arm64" -output "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer" -create

# Print some nice info
echo "Done!"
lipo -info "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer"

# Cleanup and bundle
echo "Cleaning up..."
rm "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-x86_64" "out/Puppetstring Model Viewer.app/Contents/MacOS/puppetstring-modelviewer-arm64"
./osxbundle.sh