#!/bin/bash

directory="/var/log"
options=$(find $directory -mindepth 1 -maxdepth 1 -type f -not -name '.*' -printf "%f %TY-%Tm-%Td off\n");
selected_files=$(dialog --checklist "Pick files out of $directory" 60 70 25 2 $options --output-fd 1);

for f in $selected_files
do
 echo "User selected $f"
done
