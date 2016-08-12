#!/usr/bin/perl

###############################################################################
#     Uploadit - create backups of your files to the usenet.
#     Copyright (C) David Santiago
#
#     This program is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 3 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with this program.  If not, see <http://www.gnu.org/licenses/>.
##############################################################################

use utf8;
use warnings;
use strict;
use Config::Tiny;
use Getopt::Long;
use 5.018;
use Compress::Zlib;
use File::Spec::Functions qw/splitdir catfile/;
use File::Find;
use File::Copy::Recursive qw/rcopy/;
$File::Copy::Recursive::CPRFComp=1;
use File::Copy qw/cp/;
use File::Path qw/remove_tree/;
use File::Basename;


my @VIDEO_EXTENSIONS = qw/.avi .mkv .mp4/;



sub main{
	my %OPTIONS=(delete=>1);

	GetOptions(
		'help'=>sub{help();},
		#Options in the config file
		'create_sfv!'=>\$OPTIONS{create_sfv},
		'group=s@'=>\$OPTIONS{group},
		'archive!'=>\$OPTIONS{archive},
		'par!'=>\$OPTIONS{par},
		'save_nzb!'=>\$OPTIONS{save_nzb},
		'rename_par!'=>\$OPTIONS{rename_par},
		'reverse!'=>\$OPTIONS{reverse},
		'force_repair!'=>\$OPTIONS{force_repair},
		'upload_nzb!'=>\$OPTIONS{upload_nzb},
		#'force_rename|rename!'=>\$FORCE_RENAME
		#OptionsAtRuntime
		'directory=s'=>\$OPTIONS{directory},
		'debug!'=>\$OPTIONS{debug},
		'args=s'=>\$OPTIONS{args},
		'delete!'=>\$OPTIONS{delete},
		'nfo=s'=>\$OPTIONS{nfo},
		'name=s@'=>\$OPTIONS{name},
		);
		if(!defined $OPTIONS{directory}){
			say 'You need to configure the switch -directory to point to a valid directory';
			exit 0;
		}
		$OPTIONS{debug}=0 if(!defined $OPTIONS{debug});
		$OPTIONS{args}='' if(!defined $OPTIONS{args});
		$OPTIONS{delete}=0 if(!defined $OPTIONS{delete});
		$OPTIONS{name}=[] if(!defined $OPTIONS{name});
		$OPTIONS{nfo}='' if(!defined $OPTIONS{nfo});
		
		%OPTIONS= %{_load_options(\%OPTIONS)};
	
		
		#Algorithm Steps:
		#1- copy the folder to the tmp_dir
		#2- search for files to rename.
		#3- create a Rename.with.this.par2 for the files in 2.
		#4- rename files in 2
		#5- reverse names
		#6- rar the files
		#7- copy the nfo to the rar location
		#8- create sfv
		#9- par the rars and the nfo
		#10- delete the nfo
		#11- upload rars and pars
		#12- upload nzb
		
		#step 1
		rcopy($OPTIONS{directory}, $OPTIONS{temp_dir}) or die "Unable to copy files to the temp dir: $!";
	
		#step 2,3 and 4
		my @folders = splitdir( $OPTIONS{directory} );
		pop @folders if($folders[-1] eq '');
		my $dir = $OPTIONS{temp_dir}.'/'.$folders[-1];
		push @{$OPTIONS{name}}, '' if scalar @{$OPTIONS{name}} == 0;
		
		my $file_list = [];
		my $counter = 0;
		my $previous_name = '';
		for my $name (@{$OPTIONS{name}}){
			$dir = rename_files($name, $dir,\%OPTIONS);
		
			#step 5
			reverse_filenames($dir, \%OPTIONS);
			
			#step 6
			if($previous_name eq ''){
				$file_list = archive_files($name, $dir, \%OPTIONS);
			}else{
				$file_list = rename_archived_files($previous_name, $name, $dir, \%OPTIONS);
			}
			
			#step 7
			if(defined $OPTIONS{nfo} && $OPTIONS{nfo} ne ''){
				my $filename = fileparse($OPTIONS{nfo});
				cp($OPTIONS{nfo}, $OPTIONS{temp_dir}) or die "Error copying the NFO file: $!";
				push @$file_list, catfile($OPTIONS{temp_dir},$filename);
			}
			
			#step 8
			$file_list = create_sfv($name, $file_list, \%OPTIONS);
			
			if($previous_name eq ''){
				#step 9
				$file_list = par_files($name, $file_list, \%OPTIONS);
			}else{
				# step 9
				$file_list = rename_par_files($previous_name, $name, $file_list, \%OPTIONS);	
			}
			
			#step 10
			$file_list = force_repair($file_list, \%OPTIONS);

			#step 11
			my $nzb = upload_file_list($name, $file_list, \%OPTIONS);
			cp($nzb, $OPTIONS{save_nzb_path}) or warn "Unable to copy the NZB file: $!" if($OPTIONS{save_nzb});
			
			if($previous_name eq ''){
				#step 12
				unlink upload_file_list('', [$nzb], \%OPTIONS) if($OPTIONS{upload_nzb});
			}
			
			#newsup specific
			unlink $nzb;
			
			$previous_name = $name;
		}
		#step 14
		if($OPTIONS{delete}){
			unlink @$file_list;
		}
		remove_tree($dir);
		

}

sub upload_file_list{
	my ($name, $file_list, $OPTIONS) = @_;
	
	my $CMD = $OPTIONS->{uploader}.' ';
	$CMD .= $OPTIONS->{args}.' ';
	$CMD .= "-group $_ " for (@{$OPTIONS->{group}});
	$CMD .= '-file '.quotemeta($_).' ' for (@$file_list);
	
	if($name eq ''){
		my @folders = splitdir( $OPTIONS->{directory} );
		pop @folders if($folders[-1] eq '');
		$name = $folders[-1];
	}
	
	$name .= '.nzb';
	$CMD .= '-nzb '.quotemeta($name).' ';
	
	say $CMD if $OPTIONS->{debug};
	my @CMD_output = `$CMD`;
	for(@CMD_output){
		print $_ if /speed|headercheck|nzb|error|exception/i;
	}
	
	return $name;
}

sub force_repair{
	my ($file_list, $OPTIONS) = @_;
	return $file_list if(!defined $OPTIONS->{force_repair} || !$OPTIONS->{force_repair});
	
	my @new_file_list = ();
	
	for(@$file_list){
		if($_ =~ /.nfo$/i){
			unlink $_;
		}else{
			push @new_file_list, $_;
		}
	}
	
	return \@new_file_list;
}

sub rename_par_files{
	my ($previous_name, $name, $file_list, $OPTIONS) = @_;
	return $file_list if(!defined $OPTIONS->{par} || !$OPTIONS->{par});
	
	my @par_files = @$file_list;
	my $regexp = qr/$OPTIONS->{par_filter}/;
	my $previous_name_regexp = qr/$previous_name/;
	
	opendir my $dh, $OPTIONS->{temp_dir} or die 'Couldn\'t open \''.$OPTIONS->{temp_dir}."' for reading: $!";
	while(my $file = readdir $dh){
		if($file =~ /$regexp/ && $file =~ /$previous_name/){
			my $old_filename = catfile($OPTIONS->{temp_dir}, $file);
			(my $new_filename = $old_filename) =~ s/$previous_name/$name/g;
			rename($old_filename, $new_filename);
			push @par_files, $new_filename;
		}
		#push @archived_files, catfile($OPTIONS->{temp_dir}, $file) 
	}
	closedir $dh;
	
	return \@par_files;
}

sub par_files{
	my ($name, $file_list, $OPTIONS) = @_;
	return $file_list if(!defined $OPTIONS->{par} || !$OPTIONS->{par});
	
	
	if($name eq ''){
		my @folders = splitdir( $OPTIONS->{directory} );
		pop @folders if($folders[-1] eq '');
		$name = $folders[-1];
	}
	
	my $par_name = quotemeta(catfile($OPTIONS->{temp_dir}, $name));
	
	my $CMD = $OPTIONS->{par_arguments}." $par_name " ;
	for(@$file_list){
		$CMD .= quotemeta($_).' ';
	}
	
	say $CMD if $OPTIONS->{debug};
	
	my $CMD_output = `$CMD`;
	say $CMD_output if $OPTIONS->{debug};
	
	opendir my $dh, $OPTIONS->{temp_dir} or die 'Couldn\'t open \''.$OPTIONS->{temp_dir}."' for reading: $!";
	my $regexp = qr/$OPTIONS->{par_filter}/;
	while(my $file = readdir $dh){
		push @$file_list, catfile($OPTIONS->{temp_dir}, $file) if($file =~ /$regexp/);
	}
	closedir $dh;
	
	return $file_list;
}

sub create_sfv{
	my ($name, $files, $OPTIONS) = @_;
	return $files if(!$OPTIONS->{create_sfv});
	
	my $sfv_file = $name;
	
	if($sfv_file eq '' || !defined $sfv_file){
		my @folders = splitdir( $OPTIONS->{directory} );
		pop @folders if($folders[-1] eq '');
		$sfv_file = $folders[-1];
	}
	
	# TODO
	# We can't reuse the old SFV, because the content will be different.
	opendir my $dh, $OPTIONS->{temp_dir} or die 'Couldn\'t open \''.$OPTIONS->{temp_dir}."' for reading: $!";
	while(my $file = readdir $dh){
		if($file =~ /sfv$/){
			my $old_sfv_filename = catfile($OPTIONS->{temp_dir}, $file);
			unlink $old_sfv_filename;
			last;
		}
		
	}
	closedir $dh;
	
	open my $ofh, '>', catfile($OPTIONS->{temp_dir},"$sfv_file.sfv") or die 'Unable to create sfv file!';
 
	for (@$files) {
	  my $file = $_;
	  my $fileName=(fileparse($file))[0];
	  open my $ifh, '<', $file or die "Couldn't open file $file : $!";
	  binmode $ifh;
	  my $crc32 = 0;
	  while (read ($ifh, my $input, 512*1024)!=0) {
		$crc32 = crc32($input,$crc32);
	  }
  
	  say sprintf('%s %08x',$fileName, $crc32) if $OPTIONS->{debug};
	  print $ofh sprintf('%s %08x\r\n',$fileName, $crc32);
	  close $ifh;
	}
  
	close $ofh;
	push @$files, catfile($OPTIONS->{temp_dir},"$sfv_file.sfv");
	return $files;	
}

sub rename_archived_files{
	my ($previous_name,$name, $dir, $OPTIONS) = @_;
	return [$dir] if(!$OPTIONS->{archive});
	
	my @archived_files = ();
	my $regexp = qr/$OPTIONS->{archive_filter}/;
	my $previous_name_regexp = qr/$previous_name/;
	
	opendir my $dh, $OPTIONS->{temp_dir} or die 'Couldn\'t open \''.$OPTIONS->{temp_dir}."' for reading: $!";
	while(my $file = readdir $dh){
		if($file =~ /$regexp/ && $file =~ /$previous_name/){
			my $old_filename = catfile($OPTIONS->{temp_dir}, $file);
			(my $new_filename = $old_filename) =~ s/$previous_name/$name/g;
			rename($old_filename, $new_filename);
			push @archived_files, $new_filename;
		}
	}
	closedir $dh;
	
	return \@archived_files;
}

sub archive_files{
	my ($name, $dir, $OPTIONS) = @_;
	return [$dir] if(!$OPTIONS->{archive});
	
	if($name eq ''){
		my @folders = splitdir( $OPTIONS->{directory} );
		pop @folders if($folders[-1] eq '');
		
		#TODO fix the .rar part. This is only for rar compression
		$name = $folders[-1].'.rar';
	}
	
	my $CMD=$OPTIONS->{archive_arguments}.' '.quotemeta(catfile( $OPTIONS->{temp_dir}, $name)).' '.quotemeta($dir);
	$CMD.=" ".quotemeta($OPTIONS->{nfo}) if(defined $OPTIONS->{nfo} && $OPTIONS->{nfo} ne '' && -e $OPTIONS->{nfo});
	say $CMD if $OPTIONS->{debug};
	my $CMD_output = `$CMD`;
	say $CMD_output if $OPTIONS->{debug};
	
	my @archived_files = ();
	my $regexp = qr/$OPTIONS->{archive_filter}/;
	opendir my $dh, $OPTIONS->{temp_dir} or die 'Couldn\'t open \''.$OPTIONS->{temp_dir}."' for reading: $!";
	while(my $file = readdir $dh){
		push @archived_files, catfile($OPTIONS->{temp_dir}, $file) if($file =~ /$regexp/);
	}
	closedir $dh;
	
	return \@archived_files;
}

sub reverse_filenames{
	my ($dir, $OPTIONS) = @_;
	return if(!$OPTIONS->{reverse});

	my $regexp = qr/$OPTIONS->{files_filter}/;
	my @matched_files = ();
	find(sub{
		if($File::Find::name =~ /$regexp/){
			push @matched_files, $File::Find::name;
		}
		}, ($dir));
	
	for my $file (@matched_files){
		my($filename, $dirs, $suffix) = fileparse($file, qr/\.[^.]*$/);
		rename $file, $dirs.scalar (reverse ($filename)).$suffix;
	}
}

sub rename_files{
	my ($name, $dir, $OPTIONS) = @_;

	return $dir if(!$OPTIONS->{rename_par});
	my $regexp = qr/$OPTIONS->{files_filter}/;
	
	my @matched_files = ();
	find(sub{
		if($File::Find::name =~ /$regexp/){
			push @matched_files, quotemeta($File::Find::name);
		}
		}, ($dir));
	
	my $CMD = $OPTIONS->{rename_par_arguments}.' '.quotemeta("$dir/Rename.with.this.par2 ").join(' ', @matched_files);
	say $CMD if $OPTIONS->{debug};
	
	my $CMD_output = `$CMD`;
	say $CMD_output if $OPTIONS->{debug};
	
	my $i=0;
	for my $file (@matched_files){
		my($filename, $dirs, $suffix) = fileparse($file, qr/\.[^.]*$/);
		my $newName = 'Use.the.renaming.par';
		if($name ne ''){
			$newName=$name;
		}
		$newName.=$i if($i++>0);
		$newName.=$suffix;
		rename $dirs.$filename.$suffix, $dirs.$newName;
	}
	
	my $new_dirname = (fileparse($dir))[1].$OPTIONS->{name} if($name ne '');
	rename $dir, $new_dirname;
	return $new_dirname;
}

sub _load_options{
	my %OPTIONS =  %{shift @_};

	if (defined $ENV{HOME} && -e $ENV{HOME}.'/.config/newsup.conf') {
		my $config = Config::Tiny->read( $ENV{HOME}.'/.config/newsup.conf' );

		if(!defined $config){
			say 'Error while reading the config file:';
			say Config::Tiny->errstr;
			exit 0;
		}

		my %other_configs = %{$config->{uploadit}};
		
		for my $key (keys(%other_configs)){
			if(!exists $OPTIONS{$key}){
				$OPTIONS{$key} = $other_configs{$key};
			}elsif(!defined $OPTIONS{$key} && $other_configs{$key} ne ''){
				$OPTIONS{$key}=$other_configs{$key} == 1?1:0;	
			}
		}
	}
	
	if (!defined $OPTIONS{directory} || $OPTIONS{directory}  eq '' || !-e $OPTIONS{directory} ) {
		my @possible_folders = split(/,/,$OPTIONS{upload_root});
		my $found = 0;
		for my $folder (@possible_folders){
			if(-e catfile($folder,$OPTIONS{directory})){
				$found=1;
				$OPTIONS{directory}=catfile($folder,$OPTIONS{directory});
				last;
			}
		}
		if(!$found){
			say 'You need to configure the switch -directory to point to a valid directory';
			exit 0;
		}
	}
	
	if (!exists $OPTIONS{temp_dir} || $OPTIONS{temp_dir}  eq '' || !-e $OPTIONS{temp_dir} ) {
		say 'You need to configure the option temp_dir in the configuration file';
		exit 0;

	}
	
	return \%OPTIONS;
}

sub help{
  say << "END";
This program is part of NewsUP.

The goal of this program is to make your uploading more easy.

This is an auxiliary script that will compress and/or split the files to be uploaded,
create the parity files, create sfv files and finally invoke the newsup to upload the
files.

Options available:
\t-directory <folder> = the directory to upload

\t-debug = to show debug messages. Usefull when you're configuring the switches on the several
\t\tprograms that this invokes.

\t-args <extra args> = extra args to be passed to newsup. Usually they need to be between double quotes ('"')

\t-delete = if you want the temporary folder (the folder where the compressed/split and pars are
\t\tgoing to be created) deleted.

\t-group <group> = group to where you want to upload. You can have multiple `group` switches.

\t-sfv = if you want a sfv to be generated.

\t-nfo <.NFO> = if you have a NFO to be uploaded. Usually the .nfo files aren't inside of the rars, so
\t\tthey live somewhere else in the filesystem.

\t-force_rename = option that is used in the IRC bot.

\t-rename = the same as `force_rename`

END

exit 0;

}


main();
