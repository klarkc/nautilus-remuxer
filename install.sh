#!/bin/bash

echo "Installing..."
cp -R Remuxer ~/.local/share/nautilus/scripts/
echo "Done, we need restart nautilus to finish, please press enter when you are ready"
read
killall nautilus
nautilus -n &
echo "You can find the Remuxer scripts in the context menu option Remuxer. Press enter to exit"
read

