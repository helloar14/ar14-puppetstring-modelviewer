echo "Creating directory structure..."
LASTPWD=$PWD

# Handle copying all the dylibs to their respective directories
# As well handle creating our directory structure
cd out/Puppetstring\ Model\ Viewer.app/Contents

# Remove old files
if [ -d "Frameworks" ]; then
    echo "Removing files from prior bundle..."
    rm -r Frameworks SharedSupport Resources
    rm Info.plist
fi

# Create new directories and move dylibs
mkdir -p Frameworks SharedSupport Resources Resources/i18n
mv MacOS/libSDL2-2.0.dylib Frameworks/libSDL2.dylib
mv -n MacOS/*.dylib Frameworks

# Move back to where we were
cd $LASTPWD

echo "Setting up file structure..."

# Copy info plist and icon
cp build-aux/osx/Info.plist out/Puppetstring\ Model\ Viewer.app/Contents/

# Move any translation files in if any.
mv -n out/*.mo out/Puppetstring\ Model\ Viewer.app/Contents/Resources/i18n/

# Copy license info to SharedSupport
cp res/licenses/*-LICENSE out/Puppetstring\ Model\ Viewer.app/Contents/SharedSupport/
cp LICENSE out/Puppetstring\ Model\ Viewer.app/Contents/SharedSupport/LICENSE


# Create icons dir
# TODO: check if dir exists, skip this step if it does
if [ ! -d "out/PuppetstringModelViewer.icns" ]; then
    iconutil -c icns -o out/PuppetstringModelViewer.icns build-aux/osx/PuppetstringModelViewer.iconset
else
    echo "Icons already exist, skipping..."
fi

echo "Applying Icon..."
cp out/InochiSession.icns out/Inochi\ Session.app/Contents/Resources/PuppetstringModelViewer.icns 

echo "Cleaning up..."
find out/Puppetstring\ Model\ Viewer.app/Contents/MacOS -type f ! -name "puppetstring-modelviewer" -delete

echo "Done!"