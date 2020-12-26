#! /bin/sh 

pkgListFile=/tmp/AURPkgList.txt
verbose=true
verbose2=false #very verbose
verbose3=false #use it to show some command output

#Needed so command substitution doesn't consume newline and everything after that.
#And then switch back when needed
IFS2=$IFS
IFS=


#List AUR packages
#(technically it lists foregin packages, which is flagged when user installed package file directly but I will use the word "AUR package" for convenience)
AURList=$(pacman -Qqm)
if $verbose; then echo "$AURList"; fi
#print how many AUR package the user has installed
echo "There are $(echo $AURList | grep -c $ -) AUR package(s) in total."


#THE MAIN PART WHERE THINGS ARE HAPPENING
#1. Iterate through package list
#2. Find files associated with the package (that is being iterated)
#3. Try to find associated executables and library files
#4. Test if the required (linked) library file exists or not
#5. Warns user about the package that needs rebuild
IFS=$IFS2
numOfNormalPackages=0
numOfBrokenPackages=0
for pkg in $AURList; do
	isBroken=false
	echo "Testing package $pkg."
	#2. Find files associated with the package
	if $verbose3; then echo "$(pacman -Qlq $pkg)"; fi
	for filepath in $(pacman -Qlq $pkg); do		
		#3. Try to find associated executables and library files
		if $verbose2; then echo "testing $filepath"; fi
		if [[ -d $filepath ]]; then
			if $verbose2; then echo "$filepath is a directory, skip."; fi
		elif [[ -x $filepath ]]; then
			if $verbose2; then echo "$filepath is executable"; fi
			#4. Test if the required (linked) library file exists or not
			#Some research on internet tells me not to use ldd on untrusted executables....
			#But I think if a user already installed an AUR package, they trust whatever executable got installed.
			#So I use ldd anyway, please tell me if there is a safer and not complex way to check if dependency is installed.
			IFS=
			result=$(LC_ALL=C ldd -d $filepath 2>/dev/null | grep -o "\S* => not found" | tr -d '\r')
			IFS=$IFS2
			if [[ $result != "\n" ]] && [[ ! -z $result ]] ; then
				if $verbose3; then echo "$result"; fi
				#Sometimes there are cases where a .so file reference another .so file in the same directory...
				#and ldd marks the dependency as not found because it doesn't catch this.
				#(Can be reproduced with jre8-adoptopenjdk package)
				#We have to check that the "another .so file" doesn't exist before marking the package as broken.
				
				for sofile in $(echo $str | sed "s/ => not found /\\n/g" | sed "s/ => not found$//"); do
					another_so_file=$(echo $filepath | sed 's/[^/]*$//')+$sofile
					if $verbose; then echo "checking existence of $another_so_file"; fi
					if [[ ! -e $another_so_file ]]; then
						echo "<broken> $another_so_file doesn't exist"
						isBroken=true
					fi
				done
			fi
		else
			if $verbose2; then echo "$filepath is other file type, skip."; fi
		fi
	done
	#5. Warns user about the package that needs rebuild
	if $isBroken; then
		echo "Package $pkg is broken! Please fix it."
		numOfBrokenPackages=$((numOfBrokenPackages + 1))
	else
		numOfNormalPackages=$((numOfNormalPackages + 1))
	fi
done
echo "Checks are complete."
echo "$numOfBrokenPackages package(s) are broken, and $numOfNormalPackages package(s) are working."