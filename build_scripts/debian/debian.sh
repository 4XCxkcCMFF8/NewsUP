#!/bin/bash
# Author: David Santiago <demanuel@ymail>
# Note: This bash script sucks, but i don't care as long it does what i need without fuss

miss_deps=0
use_sudo=1
if [[ ! -x "$(command -v bc)" ]]
then
    echo "To use this script install: bc"
    miss_deps=1
fi

if [[ ! -x "$(command -v git)" ]]
then
    echo "To use this script install: git"
    miss_deps=1
fi

if [[ ! -x "$(command -v sed)" ]]
then
    echo "To use this script install: sed"
    miss_deps=1
fi

if [[ ! -x "$(command -v awk)" ]]
then
    echo "To use this script install: awk"
    miss_deps=1
fi

if [[ ! -x "$(command -v patch)" ]]
then
    echo "To use this script install: patch"
    miss_deps=1
fi

if [[ ! -x "$(command -v wget)" ]]
then
    echo "To use this script install: wget"
    miss_deps=1
fi

if [[ ! -x "$(command -v date)" ]]
then
    echo "To use this script install: date"
    miss_deps=1
fi

if [[ ! -x "$(command -v sudo)" ]]
then
    use_sudo=0
fi


if [[ miss_deps -eq 1 ]]
then
    echo ""
    echo "Please install the utilities mentioned above"
    exit 1
fi

if [[ ! -d NewsUP ]]
then
    git clone https://github.com/demanuel/NewsUP.git
fi

#declare -A versions=( ["debian"]="5.24" ["ubuntu"]="5.28" )
mkdir -p newsup/DEBIAN
mkdir -p newsup/usr/local/bin newsup/usr/share/perl5/ newsup/etc/newsup
cp -r NewsUP/bin/newsup.pl newsup/usr/local/bin/newsup
chmod +x newsup/usr/local/bin/newsup
cp -r NewsUP/lib/NewsUP newsup/usr/share/perl5/
cp -r NewsUP/conf/newsup.conf newsup/etc/newsup/newsup.conf.example
cd NewsUP
version="`date +'%Y%m%d'`-`git rev-parse --short HEAD`"
required_perl_version=`awk 'NR==2{a=(($2+0)%5)*1000}END{print 5"."a}' ./bin/newsup.pl`
cd -

installed_perl_version=`apt-cache show perl|grep Version | tail -n 1 | awk '{print substr($2, 1, 4)}'`
#installed_perl_version=5.26

# if (( $(echo "${installed_perl_version} < ${required_perl_version}" | bc -l ) ))
if [[ 1 -eq 1 ]]
then
    echo ""
    echo " WARNING:"
    echo "         The perl right version to run this program is: ${required_perl_version}"
    echo "         You have ${installed_perl_version}"
    echo ""
    echo " Going to decreasing the required perl version. Unable to guarantee that it will"
    echo " run without problems and with optimal performance!"
    echo ""
    echo " It is recommended that you upgrade your perl version! [1]"
    echo ""
    echo " [1] - If you don't have admin rights, or your repo doesn't contain the right version"
    echo "      please take a look into https://perlbrew.pl/"
    echo ""
    echo ""
    echo " Press enter to continue or <Ctrl-c> if you don't want to continue"
    read
    CURRENT_DIR=`pwd`
    cd newsup/usr/share/perl5/NewsUP/
    if (( $(echo "${installed_perl_version} < 5.28" | bc -l) ))
    then
       wget https://gist.githubusercontent.com/demanuel/87e0eac62dd6d0919031131dd8fbad3d/raw/2a9a9db3694c8622b1fb06d5a880db1fa3a62230/newsup.526.patch
       patch -p0 Utils.pm <newsup.526.patch
       rm -rf newsup.526.patch
    fi
    cd $CURRENT_DIR

    if (( $(echo "${installed_perl_version} < 5.26" | bc -l) ))
    then

	find newsup/usr -type f -exec sed -i "s/5.03[[:digit:]]/${installed_perl_version/./.0}/g" {} \;
    fi


    required_perl_version=${installed_perl_version}
fi

cat > newsup/DEBIAN/control << EOT
Package: NewsUP
Version: ${version}
Maintainer: David Santiago <demanuel@ymail.com>
Description: Fully featured binary usenet uploader/poster
Homepage: https://github.com/demanuel/NewsUP
Architecture: all
Depends: perl (>= ${required_perl_version}), libio-socket-ssl-perl, libnet-ssleay-perl, libxml-libxml-perl, libfile-copy-recursive-perl, libconfig-tiny-perl, libinline-c-perl, make
Recommends: par2, rar, p7zip
EOT

echo "echo \"Create a ~/.config/newsup.conf for the user\\nPlease check /etc/newsup/newsup.conf.example\"" >> newsup/DEBIAN/postinst
chmod 755 newsup/DEBIAN/postinst


dpkg-deb --build newsup
if [[ $use_sudo -eq 1 ]]
then

    sudo apt-get install $packages
    sudo apt --fix-broken install
    sudo dpkg -i newsup.deb
else
    su -c "apt-get install $packages && apt --fix-broken install && dpkg -i newsup.deb"
fi

if [[ $? -eq 0 ]]
then

    echo "Installation successfull!"

    #  rm -rf NewsUP newsup newsup.deb

else
        echo "Creating the package failed! Please check the error message above."
        echo ""
        echo "Please make sure you have all the dependencies installed: "
        echo "perl, libio-socket-ssl-perl, libnet-ssleay-perl, libxml-libxml-perl, libfile-copy-recursive-perl, libconfig-tiny-perl, libinline-c-perl, make"
        echo ""
fi