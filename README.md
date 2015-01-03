NewsUP
======

NewsUP a binary usenet uploader/poster. Backup your personal files to the usenet!
It will run on any platform that supports perl (Windows, *nix, bsd)

# Intro

This program will upload binary files to the usenet and generate a NZB file. It supports SSL and multiple connections.
This program is licensed with GPLv3.


## note
This is a completely rewrite of the previous version (some options changed) and the creation of the parity files was dropped amongst others... but now it supports SSL! :-D

## Alternatives
* newsmangler (https://github.com/madcowfred/newsmangler)
* newspost (https://github.com/joehillen/newspost)
* pan (http://pan.rebelbase.com/)
* sanguinews (https://github.com/tdobrovolskij/sanguinews)


# What does this program do

It will upload a file or folder to the usenet. 
If it is a folder it will create a 7zip archive (it can consist of multiple 10Megs file with *no password*).
The compressed format will be 7z (although it won't really compress. The level of compression is 0).
A NZB file will be generated for later retrieving.

## What doesn't do

* Create archive passworded files 
* Create compressed archive files to upload [1]
* Create rars [1]
* Create zips [1]
* Create parity archives


### Notes
1- If you are uploading a folder it will create a 7zip file containing the folder and all the files inside. This 7zip will be split in 10 meg volumes.
The 7zip will not have any password and no compression.


#Requirements:
* Perl (5.018 -> i can change it to a version >= 5.10)
* Perl modules: Config::Tiny, IO::Socket::SSL, String::CRC32, XML::LibXML (all other modules should exist on core.)
* 7Zip

# Installation
1. Check if you have all the requirements installed.
2. Download the source code (https://github.com/demanuel/NewsUP/archive/master.zip)
3. Copy the sample.conf file ~/.config/newsup.conf and edit the options as appropriate. This step is optional since everything can be done by command line.

If you have any issue installing/running this, not please send me an email so i can try to help you.

## Linux
If you have linux, the required perl modules should be on your package management system. 

## Windows
On windows with strawberry perl please do:

1- cpan

2- Do the next step if you haven't yet installed any perl module
2.1- If you don't need a proxy to connect to the internet: o conf init
choose the right options for you. The default ones should be enough
2.2- If you need a proxy to connect to internet: o conf init /proxy/
2.2.2- After the proxy is configured: o conf commit

3- install Config::Tiny

4- install IO::Socket::SSL

The other modules are included with strawberry perl.



# Running
The most basic way to run it (please check the options section) is:
$ perl newsup.pl -file my_file -con 2 -news alt.binaries.test

Everytime the newsup runs, it will create a NZB file for later retrieval of the uploaded files. The filename will consist on the unixepoch of the creation.


## Options

## Config file
This file doesn't support all the options of the command line. Everytime an option from the command line and an option from the config file, the command line takes precedence.
Check sample newsup.conf for the available options

### Command line options

-username: credential for authentication on the server.

-password: credential for authentication on the server.

-server: server where the files will be uploaded to (SSL supported)

-port: port. For non SSL upload use 119, for SSL upload use 563 or 995

-file: the file or folder you want to upload. You can have as many as you want. If the you're uploading a folder then it will compress it and split it in files of 10Megs for uploading. These temp files are then removed. 

-comment: comment. Subject will have your comment. You can use two. The subject created will be something like "[first comment] my file's name [second comment]"

-uploader: the email of the one who is uploading, so it can be later emailed for whoever sees the post. Usually this value is a bogus one.

-newsgroup: newsgroups. You can have as many as you want. This will crosspost the file.

-groups: alias for newsgroups option

-connections: number of connections (or threads) for uploading the files (default: 2). Tip: you can use this to throttle your bandwidth usage :-P

-metadata: metadata for the nzb. You can put every text you want! Example: 
```bash
-metadata powered=NewsUP -metadata subliminar_message="NewsUp: the best usenet autoposter crossplatform"
```

The NZB file It will have on the ```<head>``` tag the childs:
```html 
<metadata type="powered">NewsUP</metadata>
<metadata type="subliminar_message">NewsUp: the best usenet autoposter crossplatform</metadata>
```
# END

Enjoy it. Email me at demanuel@ymail.com if you have any request, info or question. You're also free to ping me if you just use it.

Best regards!
