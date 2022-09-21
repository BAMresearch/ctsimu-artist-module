#!/bin/bash
# Call: ./deploy.sh <version>
# Creates an .artp file for aRTist.

# Check if a version number is provided as an argument:
if [ $# -eq 0 ]
	then
		echo "ERROR: Please give the new version number: ./deploy.sh <VERSION>"
		echo "Example: ./deploy.sh 0.8.13"
		exit
fi
VERSION=$1

# Create and go to build directory
rm -R build
mkdir build
cd build

# Assemble files from parent directories:
mkdir -p CTSimU/Modules/CTSimU
cp ../CTSimU/* ./CTSimU/Modules/CTSimU/
cp ../aRTpackage ./CTSimU/

# Replace VERSION string in aRTpackage with version number:
sed -i "s/VERSION/$VERSION/g" ./CTSimU/aRTpackage

# Zip the CTSimU folder to create the aRTist module:
zip -r "CTSimU-$VERSION.artp" "CTSimU"

# Copy to root directory:
cp CTSimU*.artp ../

# Go to root and delete temporary build directory:
cd ..
rm -R build